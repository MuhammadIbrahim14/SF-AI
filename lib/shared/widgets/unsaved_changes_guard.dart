import 'package:flutter/material.dart';

class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.title = 'Unsaved changes',
    this.message =
        'You have unsaved changes. If you leave now, your edits will be lost.',
  });

  final bool hasUnsavedChanges;
  final Widget child;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !hasUnsavedChanges) return;
        final leave = await confirmDiscardChanges(context);
        if (!context.mounted || leave != true) return;
        Navigator.of(context).pop();
      },
      child: child,
    );
  }

  Future<bool?> confirmDiscardChanges(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave anyway'),
          ),
        ],
      ),
    );
  }
}
