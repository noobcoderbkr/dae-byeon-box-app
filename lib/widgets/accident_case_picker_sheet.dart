// lib/widgets/accident_case_picker_sheet.dart
//
// 사고 영상 선택 시트
// 아래에서 위로 올라오는 시트에 내 계정의 사고 사건 목록을 보여주고,
// 사용자가 고른 사건 ID를 돌려준다. (취소하면 null)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/case_service.dart';
import '../utils/theme.dart';

Future<String?> showAccidentCasePicker(
  BuildContext context, {
  String? currentCaseId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.84,
        ),
        child: _AccidentCasePickerSheet(currentCaseId: currentCaseId),
      ),
    ),
  );
}

class _AccidentCasePickerSheet extends ConsumerStatefulWidget {
  const _AccidentCasePickerSheet({this.currentCaseId});

  final String? currentCaseId;

  @override
  ConsumerState<_AccidentCasePickerSheet> createState() =>
      _AccidentCasePickerSheetState();
}

class _AccidentCasePickerSheetState
    extends ConsumerState<_AccidentCasePickerSheet> {
  final List<BackendCase> _cases = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      if (_nextCursor == null || _loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref
          .read(caseServiceProvider)
          .listCases(limit: 20, cursor: reset ? null : _nextCursor);
      if (!mounted) return;
      setState(() {
        if (reset) _cases.clear();
        _cases.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '사고 영상 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded,
                    color: AppTheme.textSub),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child:
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return _message('사고 기록을 불러올 수 없습니다', _error!);
    }
    if (_cases.isEmpty) {
      return _message(
        '기록된 사고 영상이 없습니다',
        '블랙박스에서 사고 영상이 업로드되면 여기에 표시됩니다',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _cases.length + (_nextCursor != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _cases.length) return _buildMoreButton();
        return _buildTile(_cases[index], isLatest: index == 0);
      },
    );
  }

  Widget _buildTile(BackendCase item, {required bool isLatest}) {
    final selected = item.id == widget.currentCaseId;
    final hasGps = item.lat != null && item.lon != null;
    return GestureDetector(
      onTap: () => Navigator.pop(context, item.id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          border: Border.all(
            color: selected ? Colors.white : const Color(0xFF2A2A2E),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title.isEmpty ? '사고 영상' : item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isLatest) _badge('최신', AppTheme.successGreen),
                      if (selected) _badge('보는 중', Colors.white),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(item.createdAt),
                    style:
                        const TextStyle(color: AppTheme.textSub, fontSize: 12),
                  ),
                  if (hasGps)
                    Text(
                      '${item.lat!.toStringAsFixed(5)}, '
                      '${item.lon!.toStringAsFixed(5)}',
                      style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 11),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }

  Widget _buildMoreButton() {
    return GestureDetector(
      onTap: _loadingMore ? null : () => _load(reset: false),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: _loadingMore
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('더 보기',
                style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
      ),
    );
  }

  Widget _message(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined,
                color: AppTheme.textSub, size: 40),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textHint, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
