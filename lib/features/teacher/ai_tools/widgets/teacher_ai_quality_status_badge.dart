import 'package:flutter/material.dart';

class TeacherAiQualityStatusBadge extends StatelessWidget {
  const TeacherAiQualityStatusBadge({
    super.key,
    required this.status,
    required this.isValid,
  });

  final String status;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final color = isValid ? Colors.greenAccent.shade400 : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
