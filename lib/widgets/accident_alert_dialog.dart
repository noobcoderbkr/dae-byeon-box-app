// lib/widgets/accident_alert_dialog.dart
import 'package:flutter/material.dart';

class AccidentAlertDialog extends StatelessWidget {
  final double gForce;
  final VoidCallback onAccident;
  final VoidCallback onDismiss;

  const AccidentAlertDialog({
    super.key,
    required this.gForce,
    required this.onAccident,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text('충격이 감지되었습니다', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('충격 강도: ${gForce.toStringAsFixed(1)}G'),
          const SizedBox(height: 8),
          const Text(
            '사고가 발생했나요?\n10초 후 자동으로 신고됩니다.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('아니요, 괜찮아요'),
        ),
        ElevatedButton(
          onPressed: onAccident,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('네, 사고 났어요', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
