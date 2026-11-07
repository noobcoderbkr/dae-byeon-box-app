// lib/widgets/keyword_tag_widget.dart
import 'package:flutter/material.dart';

class KeywordTagWidget extends StatelessWidget {
  final String tag;
  final bool compact;

  const KeywordTagWidget({super.key, required this.tag, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
