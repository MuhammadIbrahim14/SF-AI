import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/student_batch_provider.dart';

class StudentJoinBatchScreen extends ConsumerStatefulWidget {
  const StudentJoinBatchScreen({super.key});

  @override
  ConsumerState<StudentJoinBatchScreen> createState() =>
      _StudentJoinBatchScreenState();
}

class _StudentJoinBatchScreenState extends ConsumerState<StudentJoinBatchScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Join class batch',
      subtitle: 'Enter the invite code from your teacher to request roster access.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentMyBatches),
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Joining adds you to the teacher’s batch roster after approval. '
                'It does not enroll you in courses.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  hintText: 'e.g. AB12CD3',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                enabled: !_submitting,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Request to join'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => context.pushNamed(
                          RouteNames.studentClassAnnouncements,
                        ),
                child: const Text('My class announcements'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the invite code from your teacher.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final success = await ref
        .read(studentBatchActionProvider.notifier)
        .requestJoinByInviteCode(code);
    if (!mounted) return;
    if (success) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Join request sent. Wait for your teacher to approve.',
          ),
        ),
      );
      _codeController.clear();
      ref.invalidate(studentJoinRequestsProvider);
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed(RouteNames.studentMyBatches);
      }
      return;
    }
    final err = ref.read(studentBatchActionProvider).error;
    var message = err?.toString() ?? 'Unable to send join request.';
    if (message.startsWith('Bad state: ')) {
      message = message.substring('Bad state: '.length);
    }
    setState(() {
      _submitting = false;
      _error = message;
    });
  }
}
