import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/model_analysis_service.dart';
import '../utils/theme.dart';

class LawResultPanel extends StatelessWidget {
  const LawResultPanel({super.key, required this.analysis});

  final Map<String, dynamic> analysis;

  @override
  Widget build(BuildContext context) {
    final law = LawReportResult.fromAnalysis(analysis);
    final warning = law.status != 'complete';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '법령·판례 근거',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (law.keywords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '검색 키워드: ${law.keywords.join(' · ')}',
              style: const TextStyle(
                color: AppTheme.textSub,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (warning)
            Text(
              _statusText(law),
              style: const TextStyle(
                color: AppTheme.warningOrange,
                fontSize: 12,
              ),
            ),
          if (!warning && law.references.isEmpty)
            const Text(
              '검색된 법령·판례가 없습니다.',
              style: TextStyle(color: AppTheme.textSub, fontSize: 12),
            ),
          ...law.issues.map((issue) => _LawIssueTile(issue: issue)),
          ...law.references.map(
            (reference) => _LawReferenceTile(reference: reference),
          ),
        ],
      ),
    );
  }

  String _statusText(LawReportResult law) {
    if (law.status == 'unavailable') {
      return law.unknowns.contains('law_service_unavailable')
          ? '법률 검색 서비스를 일시적으로 사용할 수 없습니다.'
          : 'LAW 결과를 사용할 수 없습니다.';
    }
    if (law.unknowns.contains('category_model_unavailable')) {
      return '영상 분류 모델 결과가 없어 법률 매칭이 제한됩니다.';
    }
    if (law.unknowns.contains('law_service_unavailable')) {
      return '법률 검색 서비스를 일시적으로 사용할 수 없습니다.';
    }
    return '법률 결과가 일부만 생성되었습니다.';
  }
}

class _LawIssueTile extends StatelessWidget {
  const _LawIssueTile({required this.issue});

  final LawIssue issue;

  @override
  Widget build(BuildContext context) {
    final role = switch (issue.legalRole) {
      'search_only' => '사용자 검색어',
      'rule_candidate' => '규칙 후보',
      'hint_only' => '참고 힌트',
      _ => '분류 결과',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$role · ${issue.label}',
        style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
      ),
    );
  }
}

class _LawReferenceTile extends StatefulWidget {
  const _LawReferenceTile({required this.reference});

  final LawReference reference;

  @override
  State<_LawReferenceTile> createState() => _LawReferenceTileState();
}

class _LawReferenceTileState extends State<_LawReferenceTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;
    final kind = reference.kind == 'statute'
        ? '법령'
        : reference.kind == 'precedent'
            ? '판례'
            : reference.kind;
    final origin = reference.source == 'video' ? '영상 후보 관련 검색' : '사용자 추가 검색';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$origin · $kind · ${reference.title}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              const style = TextStyle(
                color: AppTheme.textSub,
                fontSize: 12,
                height: 1.4,
              );
              final painter = TextPainter(
                text: TextSpan(text: reference.excerpt, style: style),
                maxLines: 3,
                textDirection: Directionality.of(context),
              )..layout(maxWidth: constraints.maxWidth);
              final canExpand = painter.didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reference.excerpt,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: style,
                  ),
                  if (canExpand || _expanded)
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.only(top: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(_expanded ? '접기' : '더보기'),
                    ),
                ],
              );
            },
          ),
          if (reference.url != null)
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(reference.url!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('원문 열기'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
