import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/verdict_search_service.dart';
import '../../utils/theme.dart';
import '../../widgets/law_result_panel.dart';

class VerdictSearchState {
  const VerdictSearchState({
    this.isLoading = false,
    this.query = '',
    this.status,
    this.provider,
    this.analysis,
  });

  final bool isLoading;
  final String query;
  final VerdictSearchStatus? status;
  final String? provider;
  final Map<String, dynamic>? analysis;
}

class VerdictSearchNotifier extends StateNotifier<VerdictSearchState> {
  VerdictSearchNotifier({VerdictSearchService? searchService})
      : _searchService = searchService ?? VerdictSearchService(),
        super(const VerdictSearchState());

  final VerdictSearchService _searchService;
  int _request = 0;

  Future<void> search(String query) async {
    final request = ++_request;
    query = query.trim();
    if (query.isEmpty) {
      state = const VerdictSearchState();
      return;
    }
    state = VerdictSearchState(isLoading: true, query: query);

    try {
      final result = await _searchService.search(query, limit: 10);
      if (!mounted || request != _request) return;
      state = VerdictSearchState(
        query: query,
        provider: result.provider,
        status: result.status,
        analysis: result.queryMismatch ? null : result.toAnalysis(),
      );
    } catch (_) {
      if (!mounted || request != _request) return;
      state = VerdictSearchState(
        query: query,
        status: VerdictSearchStatus.unavailable,
      );
    }
  }
}

final verdictSearchProvider = StateNotifierProvider.autoDispose<
    VerdictSearchNotifier, VerdictSearchState>((ref) {
  ref.watch(authProvider.select((auth) => (auth.status, auth.email)));
  return VerdictSearchNotifier(
    searchService: VerdictSearchService(
      accessToken: () => ref.read(authProvider.notifier).validAccessToken(),
    ),
  );
});

class VerdictLibraryScreen extends ConsumerStatefulWidget {
  const VerdictLibraryScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<VerdictLibraryScreen> createState() =>
      _VerdictLibraryScreenState();
}

class _VerdictLibraryScreenState extends ConsumerState<VerdictLibraryScreen> {
  final _searchController = TextEditingController();
  final List<String> _suggestions = ['신호위반', '스쿨존', '야간주행', '과속', '교차로'];

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery?.trim();
    if (query != null && query.isNotEmpty) {
      _searchController.text = query;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(verdictSearchProvider.notifier).search(query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(verdictSearchProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(searchState),
            if (searchState.query.isEmpty) _buildSuggestions(),
            Expanded(child: _buildBody(searchState)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(VerdictSearchState searchState) {
    if (searchState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    final analysis = searchState.analysis;
    if (analysis != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: LawResultPanel(analysis: analysis),
      );
    }
    return _buildEmpty(searchState);
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          const Text(
            '판례 검색',
            style: TextStyle(
              color: AppTheme.textSub,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearchBar(VerdictSearchState searchState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.textSub, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: '법령·판례 검색',
                hintStyle: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (query) =>
                  ref.read(verdictSearchProvider.notifier).search(query),
              onChanged: (query) {
                if (query.isEmpty) {
                  ref.read(verdictSearchProvider.notifier).search('');
                }
              },
            ),
          ),
          if (searchState.query.isNotEmpty)
            IconButton(
              tooltip: '검색어 지우기',
              onPressed: () {
                _searchController.clear();
                ref.read(verdictSearchProvider.notifier).search('');
              },
              icon: const Icon(
                Icons.close_rounded,
                color: AppTheme.textSub,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: _suggestions
            .map((keyword) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(keyword),
                    onPressed: () {
                      _searchController.text = keyword;
                      ref.read(verdictSearchProvider.notifier).search(keyword);
                    },
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: AppTheme.divider),
                    shape: const StadiumBorder(),
                    labelStyle: const TextStyle(
                      color: AppTheme.textSub,
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildEmpty(VerdictSearchState searchState) {
    final message = searchState.query.isEmpty
        ? '검색어를 입력해 주세요'
        : searchState.status == VerdictSearchStatus.unavailable
            ? '판례 검색을 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.'
            : '검색 결과가 없습니다';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: AppTheme.textHint,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSub,
                fontSize: 15,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
