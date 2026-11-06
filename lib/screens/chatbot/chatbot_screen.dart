// lib/screens/chatbot/chatbot_screen.dart
// 백엔드 사고 건별 채팅 + 기존 UI
// - ChatbotScreen : 전체화면 버전 (기존)
// - ChatbotSheet  : 플로팅 바텀시트 버전 (신규, 모든 화면 공용)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/blackbox_video_service.dart';
import '../../services/case_service.dart';
import '../../services/chat_service.dart';
import '../../services/consent_service.dart';
import '../../services/model_analysis_service.dart';
import '../../utils/theme.dart';
import '../../widgets/accident_case_picker_sheet.dart';

const externalAiTextConsentDescription =
    '채팅 내용은 서버 구성에 따라 Groq 또는 Google Gemini에서 텍스트 처리될 수 있습니다. '
    '동의하지 않으면 질문을 전송하지 않습니다.';

// ── 빠른 질문 기본 안내 (사고 미선택 시, 서버·AI 미사용) ──────
const Map<String, String> kLocalQuickAnswers = {
  '과실 비율이 뭔가요?': '''**과실 비율**은 사고의 책임을 당사자끼리 몇 대 몇으로 나누는지 나타낸 비율이에요.

- 보통 보험사가 손해보험협회의 **자동차사고 과실비율 인정기준**을 참고해 정해요.
- 과실 비율에 따라 내가 받는 보상금과 다음 해 보험료가 달라질 수 있어요.
- 보험사가 정한 비율에 동의하기 어렵다면 **과실비율분쟁심의위원회**에 심의를 청구할 수 있어요.

Dae-Byeon-BOX가 보여주는 과실 비율은 영상을 분석한 **AI 예측값**이라 참고용이에요. 사고를 선택하면 그 사고에 맞춰 더 자세히 상담할 수 있어요.''',
  '사고 후 신고 방법': '''사고가 나면 이 순서로 움직이세요.

1. **안전 확보**: 비상등을 켜고, 가능하면 차를 갓길로 옮기고, 안전삼각대를 세운 뒤 도로 밖으로 피하세요.
2. **119 · 112 신고**: 다친 사람이 있으면 바로 **119**에 연락하고 **112**에 신고하세요. 부상자를 구호하고 신고하는 것은 운전자의 의무예요.
3. **보험사 사고 접수**: 가입한 보험사 콜센터에 사고를 접수하세요.
4. **현장 기록**: 차량 위치, 파손 부위, 번호판, 신호등, 차선을 여러 각도로 찍어두세요.

현장에서 합의서나 각서에 바로 서명하지 마세요. 앱의 **사고 접수 시작**을 누르면 이 과정을 단계별로 안내해요.''',
  '블랙박스 영상 보존': '''블랙박스 영상은 과실을 따질 때 가장 중요한 증거예요.

- 일반 블랙박스는 저장 공간이 차면 **오래된 영상부터 덮어써요.** 사고 직후 영상을 따로 백업하거나 메모리카드를 빼두세요.
- 영상은 **자르거나 편집하지 말고 원본 그대로** 보관하세요.
- 상대 차량이나 주변 가게·도로 CCTV 영상이 필요하면 **최대한 빨리 요청**하세요. 보관 기간이 짧아 금방 지워질 수 있어요.

Dae-Byeon-BOX 블랙박스는 충격이 감지되면 **사고 전후 영상을 서버로 자동 업로드**해요. 홈의 **사고 영상 기록**에서 확인할 수 있어요.''',
  '보험사 연락 방법': '''가입한 보험사의 **사고 접수(긴급출동) 번호**로 연락하세요.

- **내 정보**에 보험사와 전화번호를 등록해두면, 사고 접수 화면에서 버튼 한 번으로 바로 전화할 수 있어요.
- 연락할 때는 **차량 번호, 사고 시각과 장소, 다친 사람 여부**를 알려주세요. 증권번호를 알면 더 빨라요.
- 상대 운전자와는 **연락처, 차량 번호, 가입 보험사**를 서로 확인해 두세요.
- 견인이 필요하면 보험사 긴급출동을 이용하는 것이 안전해요. 현장에 먼저 온 견인차를 바로 따라가지 마세요.''',
};

// ── 채팅 메시지 모델 ─────────────────────────────────────
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });
}

// ── 챗봇 상태 ────────────────────────────────────────────
class ChatbotState {
  final List<ChatMessage> messages;
  final bool isLoadingHistory;
  final bool isAwaitingReply;
  final bool requiresCase;
  final String? notice;

  const ChatbotState({
    this.messages = const [],
    this.isLoadingHistory = false,
    this.isAwaitingReply = false,
    this.requiresCase = false,
    this.notice,
  });

  bool get isTyping => isAwaitingReply;
  bool get canSubmit => !isLoadingHistory && !isAwaitingReply;

  ChatbotState copyWith({
    List<ChatMessage>? messages,
    bool? isLoadingHistory,
    bool? isAwaitingReply,
    bool? requiresCase,
    String? notice,
    bool clearNotice = false,
  }) =>
      ChatbotState(
        messages: messages ?? this.messages,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        isAwaitingReply: isAwaitingReply ?? this.isAwaitingReply,
        requiresCase: requiresCase ?? this.requiresCase,
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

enum ChatSendOutcome { sent, failed, externalAiConsentRequired }

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  ChatbotNotifier({
    required ChatService chatService,
    required this.caseId,
    required this.userId,
    this.screenContext,
  })  : _chatService = chatService,
        super(const ChatbotState()) {
    if (caseId == null) _showCaseRequired();
  }

  final ChatService _chatService;
  final String? caseId;
  final String userId;
  final String? screenContext;
  int _historyRequest = 0;
  int _conversationRevision = 0;
  int _pendingMessage = 0;
  final Set<String> _knownServerMessageIds = {};

  /// 사고를 선택하지 않은 상태에서 빠른 질문을 누르면
  /// 서버·AI 없이 앱에 넣어둔 기본 안내를 바로 보여준다.
  void addLocalAnswer(String question, String answer) {
    final now = DateTime.now();
    final stamp = now.microsecondsSinceEpoch;
    state = state.copyWith(messages: [
      ...state.messages,
      ChatMessage(id: 'local-q:$stamp', text: question, isUser: true, timestamp: now),
      ChatMessage(
        id: 'local-a:$stamp',
        text: answer,
        isUser: false,
        timestamp: now.add(const Duration(milliseconds: 1)),
      ),
    ]);
  }

  Future<void> loadHistory() async {
    final selectedCase = caseId;
    if (selectedCase == null) {
      _showCaseRequired();
      return;
    }
    if (state.isAwaitingReply) return;
    final request = ++_historyRequest;
    final conversationRevision = _conversationRevision;
    state = state.copyWith(isLoadingHistory: true, clearNotice: true);
    try {
      final history = await _chatService.fetchHistory(selectedCase);
      if (!mounted || request != _historyRequest) return;
      if (conversationRevision != _conversationRevision) {
        state = state.copyWith(isLoadingHistory: false);
        return;
      }
      _knownServerMessageIds.addAll(history.map((message) => message.id));
      // Missing/legacy provenance uses the bounded reserved-shape fallback.
      final visible = history.where((message) => !message.isInternalRecord);
      state = state.copyWith(
        messages: visible.isEmpty
            ? [_greetingMessage()]
            : visible.map(_fromServer).toList(),
        isLoadingHistory: false,
        requiresCase: false,
      );
    } catch (_) {
      if (!mounted || request != _historyRequest) return;
      state = state.copyWith(
        isLoadingHistory: false,
        notice: '대화 기록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  String _getContextualGreeting() {
    switch (screenContext) {
      case 'accident':
        return '🚨 **당황하지 마세요!**\n\n저 문처리가 도와드릴게요. 지금 어떤 상황인지 말씀해 주시면 단계별로 안내해 드리겠습니다.\n\n현재 다친 분이 계신가요?';
      case 'analysis':
        return '📊 저장된 사건 정보를 참고해 안내해 드릴게요.\n\n확인된 내용과 미확인 정보를 구분해 설명하겠습니다. 궁금한 점을 말씀해 주세요.';
      default:
        return '안녕하세요! 저는 교통사고 전문 AI 어시스턴트 **문처리**입니다. ✨\n\n교통사고 관련 궁금한 점이 있으시면 무엇이든 물어보세요!';
    }
  }

  Future<ChatSendOutcome> sendMessage(
    String text, {
    List<String> fileIds = const [],
    VehicleMovements? movements,
  }) async {
    if (text.trim().isEmpty) return ChatSendOutcome.failed;
    final selectedCase = caseId;
    if (selectedCase == null) {
      _showCaseRequired();
      return ChatSendOutcome.failed;
    }
    if (!state.canSubmit) return ChatSendOutcome.failed;
    _historyRequest++;
    _conversationRevision++;
    final trimmed = text.trim();
    final pendingId = 'pending:${++_pendingMessage}';
    final knownMessageIds = {
      ..._knownServerMessageIds,
      ...state.messages
          .where((message) =>
              !message.id.startsWith('greeting:') &&
              !message.id.startsWith('pending:'))
          .map((message) => message.id),
    };
    state = state.copyWith(
      messages: [
        ...state.messages
            .where((message) => !message.id.startsWith('greeting:')),
        ChatMessage(
          id: pendingId,
          text: trimmed,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      ],
      isLoadingHistory: false,
      isAwaitingReply: true,
      clearNotice: true,
    );
    try {
      final result = await _chatService.sendMessage(
        selectedCase,
        trimmed,
        fileIds: fileIds,
        movements: movements,
      );
      if (!mounted) return ChatSendOutcome.sent;
      _knownServerMessageIds
          .addAll(result.messages.map((message) => message.id));
      final byId = <String, ChatMessage>{
        for (final message in state.messages)
          if (!message.id.startsWith('greeting:')) message.id: message,
      };
      for (final message in result.messages) {
        if (message.role == ChatRole.user && message.text.trim() == trimmed) {
          byId.remove(pendingId);
        }
        byId[message.id] = _fromServer(message, useRawText: true);
      }
      final notice = result.llm.evidenceStatus == ChatEvidenceStatus.unavailable
          ? '추가 사진/영상 AI 분석을 사용할 수 없습니다. 미디어를 확인했다고 간주하지 않습니다.'
          : switch (result.llm.status) {
              ChatLlmStatus.mock => '현재 자동 답변을 제공할 수 없습니다. 메시지는 저장되었습니다.',
              ChatLlmStatus.unavailable => '메모는 저장됐지만 AI 답변을 받을 수 없습니다.',
              ChatLlmStatus.complete => null,
            };
      state = state.copyWith(
        messages: byId.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        isAwaitingReply: false,
        notice: notice,
        clearNotice: notice == null,
      );
      return ChatSendOutcome.sent;
    } on ExternalAiConsentRequiredException catch (error) {
      if (!mounted) return ChatSendOutcome.externalAiConsentRequired;
      state = state.copyWith(
        messages:
            state.messages.where((message) => message.id != pendingId).toList(),
        isAwaitingReply: false,
        notice: error.message,
      );
      return ChatSendOutcome.externalAiConsentRequired;
    } on ChatServiceException catch (_) {
      if (!mounted) return ChatSendOutcome.failed;
      state = state.copyWith(
        messages:
            state.messages.where((message) => message.id != pendingId).toList(),
        isAwaitingReply: false,
        notice: '메시지를 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
      return ChatSendOutcome.failed;
    } catch (_) {
      if (!mounted) return ChatSendOutcome.failed;
      state = state.copyWith(
        isAwaitingReply: false,
        isLoadingHistory: true,
        notice: '전송 결과를 확인하지 못했습니다. 대화 기록을 다시 확인해 주세요.',
      );
      await _reconcileUnknownSend(
        selectedCase,
        pendingId: pendingId,
        text: trimmed,
        knownMessageIds: knownMessageIds,
      );
      return ChatSendOutcome.failed;
    }
  }

  Future<void> _reconcileUnknownSend(
    String selectedCase, {
    required String pendingId,
    required String text,
    required Set<String> knownMessageIds,
  }) async {
    final request = ++_historyRequest;
    try {
      final history = await _chatService.fetchHistory(selectedCase);
      if (!mounted || request != _historyRequest) return;
      CaseChatMessage? persistedQuestion;
      for (final message in history) {
        if (message.role == ChatRole.user &&
            message.text.trim() == text &&
            !knownMessageIds.contains(message.id)) {
          persistedQuestion = message;
        }
      }
      final byId = <String, ChatMessage>{
        for (final message in state.messages)
          if (!message.id.startsWith('greeting:')) message.id: message,
      };
      for (final message in history) {
        if (message.isInternalRecord && message.id != persistedQuestion?.id) {
          continue;
        }
        byId[message.id] = _fromServer(
          message,
          useRawText: message.id == persistedQuestion?.id,
        );
      }
      if (persistedQuestion != null) byId.remove(pendingId);
      _knownServerMessageIds.addAll(history.map((message) => message.id));
      state = state.copyWith(
        messages: byId.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        isLoadingHistory: false,
      );
    } catch (_) {
      if (!mounted || request != _historyRequest) return;
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  void _showCaseRequired() {
    state = ChatbotState(
      requiresCase: true,
      messages: [
        ChatMessage(
          id: 'case-required:$userId',
          text: '어떤 사고에 대해 상담할까요? 아래에서 사고를 선택해 주세요.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  ChatMessage _greetingMessage() => ChatMessage(
        id: 'greeting:$userId:$caseId',
        text: _getContextualGreeting(),
        isUser: false,
        timestamp: DateTime.now(),
      );

  ChatMessage _fromServer(
    CaseChatMessage message, {
    bool useRawText = false,
  }) =>
      ChatMessage(
        id: message.id,
        text: useRawText ? message.text : message.displayText,
        isUser: message.role == ChatRole.user,
        timestamp: message.createdAt,
      );
}

class ChatSessionKey {
  final String userId;
  final String? caseId;
  final String screenContext;

  const ChatSessionKey({
    required this.userId,
    required this.caseId,
    required this.screenContext,
  });

  @override
  bool operator ==(Object other) =>
      other is ChatSessionKey &&
      other.userId == userId &&
      other.caseId == caseId &&
      other.screenContext == screenContext;

  @override
  int get hashCode => Object.hash(userId, caseId, screenContext);
}

final chatbotProvider = StateNotifierProvider.autoDispose
    .family<ChatbotNotifier, ChatbotState, ChatSessionKey>((ref, key) {
  final notifier = ChatbotNotifier(
    chatService: ref.read(chatServiceProvider),
    caseId: key.caseId,
    userId: key.userId,
    screenContext: key.screenContext,
  );
  notifier.loadHistory();
  return notifier;
});

// ════════════════════════════════════════════════════════
//  공용 대화 본문 (전체화면 / 바텀시트 둘 다 사용)
// ════════════════════════════════════════════════════════
class _ChatBody extends ConsumerStatefulWidget {
  final String screenCtx;
  final String? caseId;
  final String userId;
  final bool isSheet;
  const _ChatBody({
    required this.screenCtx,
    required this.caseId,
    required this.userId,
    this.isSheet = false,
  });

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _egoMovementController = TextEditingController();
  final TextEditingController _otherMovementController =
      TextEditingController();
  List<BackendCaseFile> _selectedFiles = const [];

  final List<String> _quickQuestions = [
    '과실 비율이 뭔가요?',
    '사고 후 신고 방법',
    '블랙박스 영상 보존',
    '보험사 연락 방법',
  ];

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatbotProvider(_sessionKey));
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            itemCount: chatState.messages.length,
            itemBuilder: (_, i) => _buildMessage(chatState.messages[i]),
          ),
        ),
        if (chatState.requiresCase) ...[
          if (!widget.isSheet || !keyboardVisible)
            _buildQuickQuestions(chatState),
          _buildCaseSelectButton(),
        ] else if (chatState.messages.length <= 1 &&
            (!widget.isSheet || !keyboardVisible))
          _buildQuickQuestions(chatState),
        if (chatState.notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              chatState.notice!,
              style: const TextStyle(
                color: AppTheme.textSub,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        if (chatState.isAwaitingReply)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'AI 답변을 기다리는 중',
                  style: TextStyle(
                    color: AppTheme.textSub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            legalReferenceWarning,
            style: TextStyle(
              color: AppTheme.warningOrange,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
        _buildInputArea(chatState),
      ],
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 2),
              child: Text(
                '문처리',
                style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? AppTheme.pointWhite : AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(18),
            ),
            child: msg.isLoading
                ? _buildTyping()
                : (isUser
                    ? Text(
                        msg.text,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                        ),
                      )
                    : MarkdownBody(
                        data: msg.text,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            height: 1.5,
                          ),
                          strong: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          listBullet: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return const SizedBox(
      width: 30,
      child: Text(
        '...',
        style: TextStyle(color: AppTheme.textSub, fontSize: 20),
      ),
    );
  }

  // ── 사고 선택 (선택된 사고가 없을 때) ─────────────────────
  bool _selectingCase = false;

  Future<void> _selectCase() async {
    if (_selectingCase) return;
    final selected = await showAccidentCasePicker(context);
    if (!mounted || selected == null) return;
    setState(() => _selectingCase = true);
    try {
      // 선택한 사고를 '지금 보고 있는 사고'로 지정하면
      // 상담 화면이 그 사고 기준으로 다시 열린다.
      await ref.read(caseServiceProvider).selectOwnedCase(selected);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppTheme.surfaceDark,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _selectingCase = false);
    }
  }

  Widget _buildCaseSelectButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: GestureDetector(
        onTap: _selectingCase ? null : _selectCase,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.pointWhite,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectingCase)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                )
              else
                const Icon(Icons.video_library_outlined,
                    color: Colors.black, size: 18),
              const SizedBox(width: 8),
              const Text(
                '상담할 사고 선택',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _answerLocally(String question) {
    final answer = kLocalQuickAnswers[question];
    if (answer == null) return;
    ref
        .read(chatbotProvider(_sessionKey).notifier)
        .addLocalAnswer(question, answer);
  }

  Widget _buildQuickQuestions(ChatbotState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _quickQuestions
            .map((q) => GestureDetector(
                  onTap: chatState.requiresCase
                      ? () => _answerLocally(q)
                      : (chatState.canSubmit ? () => _send(q) : null),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.north_east_rounded,
                            color: AppTheme.textHint, size: 16),
                        const SizedBox(width: 12),
                        Text(
                          q,
                          style: const TextStyle(
                            color: AppTheme.textSub,
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInputArea(ChatbotState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedFiles.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedFiles
                  .map((file) => InputChip(
                        label: Text(
                            file.kind == 'evidence_photo' ? '현장 사진' : '추가 영상'),
                        onDeleted: !chatState.canSubmit
                            ? null
                            : () => setState(() => _selectedFiles =
                                _selectedFiles
                                    .where((item) => item.id != file.id)
                                    .toList()),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (_egoMovementController.text.trim().isNotEmpty ||
              _otherMovementController.text.trim().isNotEmpty) ...[
            const Text(
              '설명 맥락 · 내 차량 / 상대 차량',
              style: TextStyle(color: AppTheme.textHint, fontSize: 11),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'AI 지원 사진 또는 MP4 영상 첨부',
                onPressed: chatState.canSubmit ? _pickAttachments : null,
                icon: const Icon(Icons.attach_file_rounded),
              ),
              IconButton(
                tooltip: '차량 움직임 설명 맥락',
                onPressed: chatState.canSubmit ? _editMovements : null,
                icon: const Icon(Icons.notes_rounded),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: '메시지 입력',
                      hintStyle: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: chatState.canSubmit ? _send : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: chatState.canSubmit
                    ? () => _send(_msgController.text)
                    : null,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: !chatState.canSubmit
                        ? AppTheme.surfaceDark
                        : AppTheme.pointWhite,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color:
                        !chatState.canSubmit ? AppTheme.textHint : Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final session = chatbotProvider(_sessionKey);
    if (!ref.read(session).canSubmit) return;
    try {
      validateAiAttachmentSelection(_selectedFiles);
    } on EvidenceServiceException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    _msgController.clear();
    final files = _selectedFiles;
    final movements = VehicleMovements(
      ego: _egoMovementController.text,
      other: _otherMovementController.text,
    );
    setState(() => _selectedFiles = const []);
    final outcome = await ref.read(session.notifier).sendMessage(
          text,
          fileIds: files.map((file) => file.id).toList(growable: false),
          movements: movements,
        );
    if (outcome == ChatSendOutcome.externalAiConsentRequired && mounted) {
      await _showExternalAiTextConsent();
    }
  }

  Future<void> _showExternalAiTextConsent() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('외부 AI 선택 동의 필요'),
          content: const Text(externalAiTextConsentDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/consents');
              },
              child: const Text('동의 관리'),
            ),
          ],
        ),
      );

  Future<void> _pickAttachments() async {
    final caseId = widget.caseId;
    if (caseId == null) return;
    if (!ref.read(consentControllerProvider).canUseExternalAi) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('외부 AI 선택 동의 필요'),
          content: const Text(
            '추가 사진·영상은 별도 구성된 Gemini 미디어 분석에만 전송됩니다. 동의하지 않아도 내부 모델 분석은 사용할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/consents');
              },
              child: const Text('동의 관리'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      final files = await ref
          .read(backendEvidenceServiceProvider)
          .listAiEligibleFiles(caseId);
      if (!mounted) return;
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'AI 첨부에는 JPEG/PNG 사진 또는 MP4 영상이 필요합니다. '
            'MOV/MKV 영상은 사건 자료로 저장되지만 AI 첨부는 지원되지 않습니다.',
          ),
        ));
        return;
      }
      var selected = _selectedFiles.map((file) => file.id).toSet();
      final result = await showModalBottomSheet<Set<String>>(
        context: context,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    leading: Icon(Icons.auto_awesome_outlined),
                    title: Text('외부 AI로 확인할 자료'),
                    subtitle: Text(
                      'JPEG/PNG 사진과 MP4 영상만 최대 3개 · 합계 10MB 이하\n'
                      'MOV/MKV 영상은 사건 자료로 저장되지만 AI 첨부는 지원되지 않습니다.',
                    ),
                  ),
                  for (final file in files)
                    CheckboxListTile(
                      value: selected.contains(file.id),
                      title: Text(
                          file.kind == 'evidence_photo' ? '현장 사진' : '추가 영상'),
                      subtitle: Text(file.id),
                      onChanged: (value) {
                        setSheetState(() {
                          if (value == true && selected.length < 3) {
                            selected = {...selected, file.id};
                          } else if (value != true) {
                            selected = {...selected}..remove(file.id);
                          }
                        });
                      },
                    ),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, selected),
                    child: const Text('선택 완료'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (result != null && mounted) {
        final selectedFiles = files
            .where((file) => result.contains(file.id))
            .toList(growable: false);
        try {
          validateAiAttachmentSelection(selectedFiles);
          setState(() => _selectedFiles = selectedFiles);
        } on EvidenceServiceException catch (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _editMovements() async {
    final ego = TextEditingController(text: _egoMovementController.text);
    final other = TextEditingController(text: _otherMovementController.text);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('차량 움직임 설명 맥락'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '현재 과실 모델은 도로유형과 구조화된 상대 차량 움직임 답변을 사용합니다. 아래 자유 설명은 답변 설명 맥락이며 비율 변경을 보장하지 않습니다.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ego,
                maxLength: 500,
                decoration: const InputDecoration(labelText: '내 차량 움직임'),
              ),
              TextField(
                controller: other,
                maxLength: 500,
                decoration: const InputDecoration(labelText: '상대 차량 움직임'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (save == true && mounted) {
      setState(() {
        _egoMovementController.text = ego.text;
        _otherMovementController.text = other.text;
      });
    }
    ego.dispose();
    other.dispose();
  }

  ChatSessionKey get _sessionKey => ChatSessionKey(
        userId: widget.userId,
        caseId: widget.caseId,
        screenContext: widget.screenCtx,
      );

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _egoMovementController.dispose();
    _otherMovementController.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════
//  바텀시트 버전 (플로팅 버튼에서 호출)
// ════════════════════════════════════════════════════════
class ChatbotSheet extends ConsumerWidget {
  final String screenContext;
  final String? caseId;
  final String userId;
  const ChatbotSheet({
    super.key,
    this.screenContext = 'home',
    required this.caseId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 시트가 열린 뒤 상담할 사고를 고르면 그 사고로 바로 전환되도록
    // 현재 선택된 사고를 계속 지켜본다.
    final activeCaseId = ref.watch(activeCaseProvider) ?? caseId;
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final preferredHeight = media.size.height * 0.82;
    final availableHeight = media.size.height - keyboardInset;
    final height =
        availableHeight < preferredHeight ? availableHeight : preferredHeight;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppTheme.bgBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textHint,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            _buildSheetHeader(context),
            Expanded(
              child: _ChatBody(
                screenCtx: screenContext,
                caseId: activeCaseId,
                userId: userId,
                isSheet: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '문처리',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                children: [
                  _StatusDot(),
                  SizedBox(width: 5),
                  Text(
                    'AI 상담',
                    style: TextStyle(
                      color: AppTheme.textSub,
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close_rounded,
                size: 24, color: AppTheme.textSub),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: AppTheme.successGreen,
          shape: BoxShape.circle,
        ),
      );
}

// ════════════════════════════════════════════════════════
//  전체화면 버전 (기존 /chatbot 라우트 유지)
// ════════════════════════════════════════════════════════
class ChatbotScreen extends ConsumerWidget {
  final Map<String, dynamic>? initialContext;
  const ChatbotScreen({super.key, this.initialContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenCtx = initialContext?['screen'] ?? 'home';
    final userId = ref.watch(authProvider).email ?? 'signed-out';
    final caseId = ref.watch(activeCaseProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _ChatBody(
                screenCtx: screenCtx,
                caseId: caseId,
                userId: userId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '문처리',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                children: [
                  _StatusDot(),
                  SizedBox(width: 5),
                  Text(
                    'AI 상담',
                    style: TextStyle(
                      color: AppTheme.textSub,
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
