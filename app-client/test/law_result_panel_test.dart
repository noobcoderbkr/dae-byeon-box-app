import 'package:blackbox_driver_care/widgets/law_result_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _law({
  required String status,
  String provider = 'real',
  List<Map<String, dynamic>> evidence = const [],
  List<String> unknowns = const [],
}) =>
    {
      'providers': {'law': provider},
      'law': {
        'status': status,
        'unknowns': unknowns,
        'evidence': evidence,
      },
    };

Map<String, dynamic> _evidence(
  int index, {
  String source = 'video',
  String? url,
  String? excerpt,
}) =>
    {
      'id': 'ref-$index',
      'kind': index.isEven ? 'statute' : 'precedent',
      'title': '근거 $index',
      'excerpt': excerpt ?? '근거 요지 $index',
      'url': url ??
          'https://www.law.go.kr/LSW/precInfoP.do?precSeq=${175119 + index}',
      'issue_type': 'signal',
      'source': source,
    };

Widget _host(Map<String, dynamic> analysis) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LawResultPanel(analysis: analysis),
        ),
      ),
    );

void main() {
  testWidgets('shows six references and category warning with source labels',
      (tester) async {
    await tester.pumpWidget(_host(_law(
      status: 'incomplete',
      unknowns: ['category_model_unavailable'],
      evidence: [
        for (var i = 0; i < 5; i++) _evidence(i),
        _evidence(5, source: 'user_keyword'),
      ],
    )));

    expect(find.text('영상 분류 모델 결과가 없어 법률 매칭이 제한됩니다.'), findsOneWidget);
    expect(find.textContaining('영상 후보 관련 검색'), findsNWidgets(5));
    expect(find.textContaining('사용자 추가 검색'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.text('근거 요지 $i'), findsOneWidget);
    }
  });

  testWidgets('shows empty state for complete result without evidence',
      (tester) async {
    await tester.pumpWidget(_host(_law(status: 'complete')));
    expect(find.text('검색된 법령·판례가 없습니다.'), findsOneWidget);
    expect(find.text('LAW 결과를 사용할 수 없습니다.'), findsNothing);
  });

  testWidgets('shows unavailable when LAW result is missing', (tester) async {
    await tester.pumpWidget(_host({}));
    expect(find.text('LAW 결과를 사용할 수 없습니다.'), findsOneWidget);
    expect(find.text('법률 결과가 일부만 생성되었습니다.'), findsNothing);
  });

  testWidgets('prioritizes unavailable message and rejects unsafe URL action',
      (tester) async {
    await tester.pumpWidget(_host(_law(
      status: 'unavailable',
      unknowns: ['provider_contract'],
      evidence: [
        _evidence(
          0,
          url: 'https://www.law.go.kr/LSW/precInfoP.do?token=secret',
        ),
      ],
    )));
    expect(find.text('LAW 결과를 사용할 수 없습니다.'), findsOneWidget);
    expect(find.text('원문 열기'), findsNothing);
    expect(find.text('근거 요지 0'), findsNothing);
  });

  testWidgets('suppresses safe-looking evidence from non-real LAW providers',
      (tester) async {
    await tester.pumpWidget(_host(_law(
      status: 'complete',
      provider: 'mock',
      unknowns: ['provider_contract'],
      evidence: [_evidence(0)],
    )));

    expect(find.text('LAW 결과를 사용할 수 없습니다.'), findsOneWidget);
    expect(find.text('근거 0'), findsNothing);
    expect(find.text('근거 요지 0'), findsNothing);
    expect(find.text('원문 열기'), findsNothing);
  });

  testWidgets('collapses long excerpts to three lines and expands per item',
      (tester) async {
    final excerpt = List.filled(
      24,
      '운전자는 교통 신호와 도로 상황을 살피고 안전하게 운전할 주의 의무가 있습니다.',
    ).join(' ');
    await tester.pumpWidget(_host(_law(
      status: 'complete',
      evidence: [_evidence(0, excerpt: excerpt)],
    )));

    final excerptText = tester.widget<Text>(find.text(excerpt));
    expect(excerptText.maxLines, 3);
    expect(excerptText.overflow, TextOverflow.ellipsis);
    expect(find.text('더보기'), findsOneWidget);

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    final expanded = tester.widget<Text>(find.text(excerpt));
    expect(expanded.maxLines, isNull);
    expect(find.text('접기'), findsOneWidget);
  });
}
