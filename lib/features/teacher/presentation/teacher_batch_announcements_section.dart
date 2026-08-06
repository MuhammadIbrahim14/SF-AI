import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_announcement_model.dart';
import '../../../models/teacher_batch_model.dart';
import '../../ai_usage/models/ai_usage_models.dart';
import '../ai_tools/models/teacher_ai_generation_request_model.dart';
import '../ai_tools/models/teacher_ai_generation_result_model.dart';
import '../ai_tools/services/teacher_ai_generation_service.dart';
import '../ai_tools/widgets/teacher_ai_preview_dialog.dart';
import '../providers/teacher_batch_ops_provider.dart';
import '../providers/teacher_batch_provider.dart';
import '../utils/teacher_batch_intelligence.dart';

class TeacherBatchAnnouncementsSection extends ConsumerWidget {
  const TeacherBatchAnnouncementsSection({
    super.key,
    required this.batch,
    this.courseTitles = const <String>[],
  });

  final TeacherBatchModel batch;
  final List<String> courseTitles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final announcementsAsync = ref.watch(
      teacherBatchAnnouncementsProvider(batch.batchId),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Announcements',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _compose(context, ref),
                icon: const Icon(Icons.campaign_rounded),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visible to students on this batch roster. Not emailed or pushed. '
            'AI drafts never auto-save.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          announcementsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Unable to load announcements: $error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No announcements yet. Compose one for this batch workspace.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _AnnouncementTile(item: items[i]),
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

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final summary = ref.read(teacherBatchProgressProvider(batch));
    final digest = TeacherBatchRiskDigest.fromSummary(summary);
    final studentCount = batch.studentIds.isNotEmpty
        ? batch.studentIds.length
        : summary.totalStudents;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateAnnouncementDialog(
        batchId: batch.batchId,
        batchTitle: batch.title,
        courseTitles: courseTitles,
        studentCount: studentCount,
        riskDigestSummary: digest.toAiContextSummary(
          batchTitle: batch.title,
          courseTitles: courseTitles,
          studentCount: studentCount,
        ),
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Announcement saved — visible to students on this roster.',
          ),
        ),
      );
    }
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.item});

  final TeacherBatchAnnouncementModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.body.isEmpty ? 'No body.' : item.body,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.yMMMd().add_jm().format(item.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateAnnouncementDialog extends ConsumerStatefulWidget {
  const _CreateAnnouncementDialog({
    required this.batchId,
    required this.batchTitle,
    required this.courseTitles,
    required this.studentCount,
    required this.riskDigestSummary,
  });

  final String batchId;
  final String batchTitle;
  final List<String> courseTitles;
  final int studentCount;
  final String riskDigestSummary;

  @override
  ConsumerState<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState
    extends ConsumerState<_CreateAnnouncementDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final _aiService = TeacherAiGenerationService();
  bool _saving = false;
  bool _drafting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost =
        AiUsageDefaults.featureCosts[TeacherAiTaskType.batchAnnouncementDraft] ??
        2;
    return AlertDialog(
      title: const Text('New announcement'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Visible to students on this batch roster once saved. '
                'AI Apply fills fields — you still Save manually. '
                'Not emailed or pushed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                enabled: !_saving && !_drafting,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_saving && !_drafting,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving || _drafting ? null : _draftWithAi,
                icon: _drafting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _drafting
                      ? 'Drafting…'
                      : 'Draft with AI ($cost credits)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving || _drafting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _drafting ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teacherPrimary,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _draftWithAi() async {
    setState(() {
      _drafting = true;
      _error = null;
    });
    try {
      final result = await _aiService.generate(
        TeacherAiGenerationRequestModel(
          taskType: TeacherAiTaskType.batchAnnouncementDraft,
          prompt:
              'Draft a concise batch announcement for students on the roster. '
              'Use the risk digest context. Do not invent student names or '
              'scores beyond the provided summary. Return title and body only. '
              'Never send, email, or push notify.',
          courseId: widget.batchId,
          courseTitle: widget.batchTitle,
          currentTitle: _titleController.text.trim(),
          currentDescription: _bodyController.text.trim(),
          extraContext: {
            'targetScreen': 'teacherBatchAnnouncement',
            'manualApplyOnly': true,
            'requiresManualReview': true,
            'batchTitle': widget.batchTitle,
            'courseTitles': widget.courseTitles,
            'studentCount': widget.studentCount,
            'riskDigestSummary': widget.riskDigestSummary,
            'firestoreWritesAllowed': false,
            'autoSendAllowed': false,
          },
        ),
      );
      if (!mounted) return;
      final apply = await TeacherAiPreviewDialog.show(context, result);
      if (!mounted || !apply) return;
      _applyDraft(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to draft with AI: $error');
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  void _applyDraft(TeacherAiGenerationResultModel result) {
    final title = result.stringValue(
      'title',
      fallback: result.title.trim().isEmpty ? '' : result.title.trim(),
    );
    var body = result.stringValue('body');
    if (body.trim().isEmpty) {
      body = result.stringValue('description');
    }
    if (body.trim().isEmpty) {
      body = result.stringValue('improvedContent');
    }
    setState(() {
      if (title.trim().isNotEmpty) {
        _titleController.text = title.trim();
      }
      if (body.trim().isNotEmpty) {
        _bodyController.text = body.trim();
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await ref
        .read(teacherBatchOpsProvider.notifier)
        .createAnnouncement(
          batchId: widget.batchId,
          title: title,
          body: _bodyController.text,
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Unable to save announcement.';
    });
  }
}
