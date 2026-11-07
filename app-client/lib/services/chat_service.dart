import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'consent_service.dart';
import 'model_analysis_service.dart';

enum ChatRole { user, assistant }

enum ChatLlmStatus { mock, complete, unavailable }

enum ChatEvidenceStatus { complete, unavailable, notRequested }

class CaseChatMessage {
  static const _analysisFactNames = {
    'parking_lot',
    'no_lane_markings',
    'opponent_lane_change',
    'opponent_signal_violation',
    'opponent_speeding_suspected',
    'bad_weather',
    'school_zone',
    'ego_straight',
  };

  final String id;
  final ChatRole role;
  final String text;
  final String? kind;
  final DateTime createdAt;

  const CaseChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.kind,
    required this.createdAt,
  });

  String get displayText {
    return _internalRecordType == 'road_selection' ? '도로유형 선택을 저장했습니다.' : text;
  }

  bool get isInternalRecord => _internalRecordType != null;

  String? get _internalRecordType {
    if (role != ChatRole.user) return null;
    if (kind == 'conversation') return null;
    if (kind == 'internal') return 'internal';
    if (kind != null && kind != 'legacy') return null;

    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (_isValidRoadSelection(decoded)) return 'road_selection';
    if (_isValidAnalysisFeedback(decoded)) return 'analysis_feedback';
    return null;
  }

  static bool _isValidRoadSelection(Map<String, dynamic> decoded) {
    if (decoded.length != 4 ||
        !const {'type', 'place', 'other_action', 'revision'}
            .every(decoded.containsKey)) {
      return false;
    }

    final place = decoded['place'];
    final action = decoded['other_action'];
    final revision = decoded['revision'];
    final validAction = action == null ||
        (place == 1 &&
            const {'left', 'right', 'u_turn', 'straight_other', 'unknown'}
                .contains(action)) ||
        (place == 6 &&
            const {'entering', 'circulating', 'lane_change', 'unknown'}
                .contains(action));
    if (decoded['type'] != 'road_selection' ||
        place is! int ||
        place < 0 ||
        place > 7 ||
        revision is! int ||
        revision < 1 ||
        !validAction) {
      return false;
    }
    return true;
  }

  static bool _isValidAnalysisFeedback(Map<String, dynamic> decoded) {
    if (decoded.length != 3 ||
        !const {'type', 'facts', 'keywords'}.every(decoded.containsKey) ||
        decoded['type'] != 'analysis_feedback') {
      return false;
    }
    final facts = decoded['facts'];
    final keywords = decoded['keywords'];
    if (facts is! Map || keywords is! List || keywords.length > 20) {
      return false;
    }
    for (final entry in facts.entries) {
      if (entry.key is! String ||
          !_analysisFactNames.contains(entry.key) ||
          entry.value is! bool) {
        return false;
      }
    }
    final seen = <String>{};
    for (final item in keywords) {
      if (item is! String ||
          item.isEmpty ||
          item != item.trim() ||
          item.runes.length > 100 ||
          !seen.add(item)) {
        return false;
      }
    }
    return true;
  }

  factory CaseChatMessage.fromJson(Map<String, dynamic> json) {
    return CaseChatMessage(
      id: json['id'] as String,
      role: json['role'] == 'assistant' ? ChatRole.assistant : ChatRole.user,
      text: json['text'] as String,
      kind: json['kind'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ChatLlmResult {
  final String provider;
  final ChatLlmStatus status;
  final String? errorCode;
  final ChatEvidenceStatus evidenceStatus;

  const ChatLlmResult({
    required this.provider,
    required this.status,
    this.errorCode,
    this.evidenceStatus = ChatEvidenceStatus.notRequested,
  });

  factory ChatLlmResult.fromJson(Map<String, dynamic>? json) {
    final status = switch (json?['status']) {
      'mock' => ChatLlmStatus.mock,
      'complete' => ChatLlmStatus.complete,
      _ => ChatLlmStatus.unavailable,
    };
    return ChatLlmResult(
      provider: json?['provider'] as String? ?? 'mock',
      status: status,
      errorCode: json?['error_code'] as String?,
      evidenceStatus: switch (json?['evidence_status']) {
        'complete' => ChatEvidenceStatus.complete,
        'unavailable' => ChatEvidenceStatus.unavailable,
        _ => ChatEvidenceStatus.notRequested,
      },
    );
  }
}

class ChatSendResult {
  final List<CaseChatMessage> messages;
  final ChatLlmResult llm;

  const ChatSendResult({required this.messages, required this.llm});
}

class ChatServiceException implements Exception {
  final String message;
  const ChatServiceException(this.message);

  @override
  String toString() => message;
}

class ExternalAiConsentRequiredException extends ChatServiceException {
  const ExternalAiConsentRequiredException()
      : super('현재 서버의 외부 AI 텍스트 답변에는 선택 동의가 필요합니다.');
}

class ChatService {
  ChatService({
    Dio? dio,
    required Future<String?> Function() accessToken,
    bool Function()? canUseExternalAi,
  })  : _dio = dio ?? _defaultDio(),
        _accessToken = accessToken,
        _canUseExternalAi = canUseExternalAi ?? (() => true);

  final Dio _dio;
  final Future<String?> Function() _accessToken;
  final bool Function() _canUseExternalAi;

  Future<List<CaseChatMessage>> fetchHistory(String caseId) async {
    final options = await _authOptions();
    final messages = <CaseChatMessage>[];
    String? cursor;
    do {
      final response = await _dio.get(
        '/api/v1/cases/$caseId/chats',
        queryParameters: {
          'limit': 100,
          if (cursor != null) 'cursor': cursor,
        },
        options: options,
      );
      if (response.statusCode != 200) {
        throw const ChatServiceException('대화 기록을 불러오지 못했습니다.');
      }
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      messages.addAll(_parseMessages(data['chats']));
      cursor = data['next_cursor'] as String?;
    } while (cursor != null && cursor.isNotEmpty);

    final unique = <String, CaseChatMessage>{};
    for (final message in messages) {
      unique[message.id] = message;
    }
    final ordered = unique.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ordered;
  }

  Future<ChatSendResult> sendMessage(
    String caseId,
    String text, {
    List<String> fileIds = const [],
    VehicleMovements? movements,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ChatServiceException('메시지를 입력해 주세요.');
    }
    if (fileIds.length > 3 || fileIds.any((id) => id.trim().isEmpty)) {
      throw const ChatServiceException('첨부 파일은 최대 3개까지 선택할 수 있습니다.');
    }
    if (fileIds.isNotEmpty && !_canUseExternalAi()) {
      throw const ChatServiceException(
        '사진·추가 영상 분석에는 외부 AI 선택 동의가 필요합니다.',
      );
    }
    Map<String, String>? movementJson;
    try {
      movementJson = movements?.toJson();
    } on ModelAnalysisException catch (error) {
      throw ChatServiceException(error.message);
    }
    final response = await _dio.post(
      '/api/v1/cases/$caseId/chats',
      data: {
        'text': trimmed,
        if (fileIds.isNotEmpty) 'file_ids': fileIds,
        if (movementJson != null) 'movements': movementJson,
      },
      options: await _authOptions(),
    );
    if (response.statusCode != 201) {
      if (_requiresExternalAiConsent(response)) {
        throw const ExternalAiConsentRequiredException();
      }
      throw const ChatServiceException('메시지를 저장하지 못했습니다.');
    }
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    final llm = ChatLlmResult.fromJson(
      data['llm'] == null
          ? null
          : Map<String, dynamic>.from(data['llm'] as Map),
    );
    if (llm.status == ChatLlmStatus.unavailable && llm.errorCode != null) {
      debugPrint(
        '[chat_send_failure] errorCode=${_safeErrorCode(llm.errorCode!)}',
      );
    }
    final unique = <String, CaseChatMessage>{};
    for (final message in _parseMessages(data['messages'])) {
      unique[message.id] = message;
    }
    return ChatSendResult(
      messages: unique.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      llm: llm,
    );
  }

  Future<Options> _authOptions() async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const ChatServiceException('로그인이 필요합니다.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  static List<CaseChatMessage> _parseMessages(Object? value) {
    return ((value as List?) ?? const [])
        .map((item) =>
            CaseChatMessage.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static bool _requiresExternalAiConsent(Response<dynamic> response) {
    if (response.statusCode != 403 || response.data is! Map) return false;
    final error = (response.data as Map)['error'];
    if (error is! Map || error['code'] != 'consent_required') return false;
    final details = error['details'];
    final documents = details is Map ? details['documents'] : null;
    return documents is List && documents.contains('external_ai');
  }

  static String _safeErrorCode(String value) {
    return RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(value)
        ? value
        : 'invalid_error_code';
  }
}

Dio _defaultDio() => Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (code) => code != null && code < 500,
    ));

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(
    accessToken: () => ref.read(authProvider.notifier).validAccessToken(),
    canUseExternalAi: () =>
        ref.read(consentControllerProvider).canUseExternalAi,
  );
});
