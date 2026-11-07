import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blackbox_driver_care/screens/verdict/verdict_library_screen.dart';
import 'package:blackbox_driver_care/services/verdict_search_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders canonical real LAW evidence without invented metadata',
      (tester) async {
    await _showSearch(
      tester,
      _service(_response(results: [
        _evidence(
          title: '도로교통법 제25조',
          excerpt: '교차로 통행방법에 관한 법령 본문',
          kind: 'statute',
          source: 'user_keyword',
        ),
        _evidence(
          id: 'precedent-1',
          title: '대법원 판례',
          excerpt: '교차로 사고 판단 근거',
          kind: 'precedent',
          source: 'user_keyword',
        ),
      ])),
    );

    expect(find.textContaining('사용자 추가 검색 · 법령 · 도로교통법 제25조'), findsOneWidget);
    expect(find.textContaining('사용자 추가 검색 · 판례 · 대법원 판례'), findsOneWidget);
    expect(find.textContaining('영상 후보 관련 검색'), findsNothing);
    expect(find.text('교차로 통행방법에 관한 법령 본문'), findsOneWidget);
    expect(find.text('법원'), findsNothing);
    expect(find.textContaining('유사도'), findsNothing);
    expect(find.textContaining('원고 '), findsNothing);
    expect(find.textContaining('피고 '), findsNothing);
  });

  for (final provider in ['mock', 'unavailable']) {
    testWidgets('$provider provider never displays fabricated LAW evidence',
        (tester) async {
      await _showSearch(
        tester,
        _service(_response(
          provider: provider,
          status: 'unavailable',
          results: [_evidence(title: '표시되면 안 되는 결과')],
        )),
      );

      expect(find.text('표시되면 안 되는 결과'), findsNothing);
      expect(find.text('LAW 결과를 사용할 수 없습니다.'), findsOneWidget);
    });
  }

  testWidgets('unavailable real LAW response displays no evidence',
      (tester) async {
    await _showSearch(
      tester,
      _service(_response(
        status: 'unavailable',
        unknowns: ['law_service_unavailable'],
        results: [_evidence(title: '표시되면 안 되는 결과')],
      )),
    );

    expect(find.text('표시되면 안 되는 결과'), findsNothing);
    expect(find.text('법률 검색 서비스를 일시적으로 사용할 수 없습니다.'), findsOneWidget);
  });

  testWidgets('standalone search rejects forged video-source evidence',
      (tester) async {
    await _showSearch(
      tester,
      _service(_response(results: [
        _evidence(
          title: '위조된 영상 출처 결과',
          source: 'video',
        ),
      ])),
    );

    expect(find.text('위조된 영상 출처 결과'), findsNothing);
    expect(find.textContaining('영상 후보 관련 검색'), findsNothing);
    expect(find.text('검색된 법령·판례가 없습니다.'), findsOneWidget);
  });

  testWidgets('mismatched backend query is rejected', (tester) async {
    await _showSearch(
      tester,
      _service(_response(
        query: '다른 검색어',
        results: [_evidence(title: '잘못 연결된 결과')],
      )),
    );

    expect(find.text('잘못 연결된 결과'), findsNothing);
    expect(find.text('판례 검색을 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
  });

  testWidgets('only canonical official URLs expose an open action',
      (tester) async {
    await _showSearch(
      tester,
      _service(_response(results: [
        _evidence(
          title: '공식 원문',
          url: 'https://www.law.go.kr/LSW/precInfoP.do?precSeq=1',
        ),
        _evidence(
          id: 'unsafe-1',
          title: '비공식 원문',
          url: 'https://evil.example/precedent',
        ),
        _evidence(
          id: 'secret-1',
          title: '민감 쿼리 원문',
          url: 'https://www.law.go.kr/LSW/precInfoP.do?token=secret',
        ),
      ])),
    );

    expect(find.text('원문 열기'), findsOneWidget);
  });

  testWidgets('newest query wins when responses finish out of order',
      (tester) async {
    final service = _DeferredVerdictSearchService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        verdictSearchProvider.overrideWith(
          (ref) => VerdictSearchNotifier(searchService: service),
        ),
      ],
      child: const MaterialApp(home: VerdictLibraryScreen()),
    ));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VerdictLibraryScreen)),
    );
    final notifier = container.read(verdictSearchProvider.notifier);
    final first = notifier.search('첫 검색');
    await tester.pump();
    final second = notifier.search('둘째 검색');
    await tester.pump();

    service.complete('둘째 검색', '최신 결과');
    await second;
    await tester.pump();
    expect(find.textContaining('최신 결과'), findsOneWidget);

    service.complete('첫 검색', '오래된 결과');
    await first;
    await tester.pump();

    expect(find.textContaining('최신 결과'), findsOneWidget);
    expect(find.textContaining('오래된 결과'), findsNothing);
    expect(container.read(verdictSearchProvider).query, '둘째 검색');
  });
}

Future<void> _showSearch(
  WidgetTester tester,
  VerdictSearchService service,
) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      verdictSearchProvider.overrideWith(
        (ref) => VerdictSearchNotifier(searchService: service),
      ),
    ],
    child: const MaterialApp(home: VerdictLibraryScreen()),
  ));
  await tester.pump();
  await tester.enterText(find.byType(TextField), '교차로');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Map<String, Object?> _response({
  String provider = 'real',
  String status = 'complete',
  String query = '교차로',
  List<Map<String, Object?>> results = const [],
  List<String> unknowns = const [],
}) =>
    {
      'provider': provider,
      'version': 'law-service-v1',
      'status': status,
      'query': query,
      'results': results,
      'unknowns': unknowns,
    };

Map<String, Object?> _evidence({
  String id = 'statute-1',
  String title = '도로교통법',
  String excerpt = '법률 근거 요지',
  String kind = 'statute',
  String source = 'user_keyword',
  String? url,
}) =>
    {
      'id': id,
      'title': title,
      'excerpt': excerpt,
      'url': url,
      'kind': kind,
      'source': source,
      'issue_type': 'custom_keyword',
    };

VerdictSearchService _service(Map<String, Object?> data, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
    ..httpClientAdapter = _LawAdapter(data, status);
  return VerdictSearchService(dio: dio, accessToken: () async => 'token');
}

class _LawAdapter implements HttpClientAdapter {
  _LawAdapter(this.data, this.status);
  final Map<String, Object?> data;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, '/api/v1/law/search');
    expect(options.headers['Authorization'], 'Bearer token');
    return _body(data, status);
  }

  @override
  void close({bool force = false}) {}
}

class _DeferredVerdictSearchService extends VerdictSearchService {
  _DeferredVerdictSearchService()
      : super(
          dio: Dio(BaseOptions(baseUrl: 'http://example.test')),
          accessToken: () async => 'token',
        );

  final _responses = <String, Completer<VerdictSearchResult>>{};

  @override
  Future<VerdictSearchResult> search(String query, {int limit = 10}) =>
      (_responses[query] ??= Completer<VerdictSearchResult>()).future;

  void complete(String query, String title) {
    _responses[query]!.complete(VerdictSearchResult(
      provider: 'real',
      status: VerdictSearchStatus.complete,
      query: query,
      results: [
        SearchedVerdict(
          id: '$query-id',
          title: title,
          excerpt: '판례 근거 요지',
          kind: 'precedent',
          source: 'user_keyword',
          issueType: 'custom_keyword',
        ),
      ],
      unknowns: const [],
    ));
  }
}

ResponseBody _body(Map<String, Object?> data, int status) =>
    ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
