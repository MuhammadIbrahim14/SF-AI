import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_model.dart';
import '../providers/teacher_batch_provider.dart';

class TeacherBatchInviteSection extends ConsumerStatefulWidget {
  const TeacherBatchInviteSection({super.key, required this.batch});

  final TeacherBatchModel batch;

  @override
  ConsumerState<TeacherBatchInviteSection> createState() =>
      _TeacherBatchInviteSectionState();
}

class _TeacherBatchInviteSectionState
    extends ConsumerState<TeacherBatchInviteSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = widget.batch;
    final code = batch.inviteCode.trim().toUpperCase();
    final enabled = batch.inviteEnabled && code.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite code',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Students enter this code to request joining the roster. '
            'Approving adds them to the batch only — not course enrollments.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (code.isEmpty)
            Text(
              'No invite code yet. Generate one to let students request access.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
                Chip(
                  label: Text(enabled ? 'Enabled' : 'Disabled'),
                  backgroundColor: enabled
                      ? AppColors.success.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _regenerate,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(code.isEmpty ? 'Generate code' : 'Regenerate'),
              ),
              if (code.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _setEnabled(!enabled),
                  icon: Icon(
                    enabled
                        ? Icons.link_off_rounded
                        : Icons.link_rounded,
                  ),
                  label: Text(enabled ? 'Disable invite' : 'Enable invite'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    final success = await ref
        .read(teacherBatchActionProvider.notifier)
        .regenerateInvite(widget.batch, enable: true);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Invite code updated and enabled.'
              : 'Unable to update invite code.',
        ),
      ),
    );
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _busy = true);
    final success = await ref
        .read(teacherBatchActionProvider.notifier)
        .setInviteEnabled(widget.batch, enabled);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (enabled ? 'Invite enabled.' : 'Invite disabled.')
              : 'Unable to update invite.',
        ),
      ),
    );
  }
}
