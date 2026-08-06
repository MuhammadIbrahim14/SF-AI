import 'package:flutter/material.dart';

class TeacherAiGenerateButton extends StatelessWidget {
  const TeacherAiGenerateButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    this.label = 'Generate with AI',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : const Icon(Icons.auto_awesome_rounded),
      label: Text(
        isLoading ? 'Generating...' : label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}
