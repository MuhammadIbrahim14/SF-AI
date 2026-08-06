import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_join_request_model.dart';
import '../../../models/teacher_batch_model.dart';
import '../providers/teacher_batch_ops_provider.dart';
import '../providers/teacher_batch_provider.dart';

class TeacherBatchJoinRequestsSection extends ConsumerWidget {
  const TeacherBatchJoinRequestsSection({super.key, required this.batch});

  final TeacherBatchModel batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requestsAsync = ref.watch(
      teacherBatchJoinRequestsProvider(batch.batchId),
    );

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
            'Join requests',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Approve adds the student to this batch roster only — '
            'not LMS enrollments.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          requestsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Unable to load join requests: $error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No pending join requests.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _JoinRequestTile(batch: batch, request: items[i]),
                    if (i != items.length - 1) const Divider(height: 1),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JoinRequestTile extends ConsumerStatefulWidget {
  const _JoinRequestTile({required this.batch, required this.request});

  final TeacherBatchModel batch;
  final TeacherBatchJoinRequestModel request;

  @override
  ConsumerState<_JoinRequestTile> createState() => _JoinRequestTileState();
}

class _JoinRequestTileState extends ConsumerState<_JoinRequestTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final name = request.studentName.trim().isEmpty
        ? 'Student'
        : request.studentName.trim();
    final email = request.studentEmail.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMd().add_jm().format(request.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _deny,
            child: const Text('Deny'),
          ),
          FilledButton(
            onPressed: _busy ? null : _approve,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teacherPrimary,
            ),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    final success = await ref
        .read(teacherBatchActionProvider.notifier)
        .approveJoinRequest(batch: widget.batch, request: widget.request);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Student added to roster.'
              : 'Unable to approve request.',
        ),
      ),
    );
  }

  Future<void> _deny() async {
    setState(() => _busy = true);
    final success = await ref
        .read(teacherBatchActionProvider.notifier)
        .denyJoinRequest(batch: widget.batch, request: widget.request);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Request denied.' : 'Unable to deny request.',
        ),
      ),
    );
  }
}
