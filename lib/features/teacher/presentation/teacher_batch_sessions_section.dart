import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_model.dart';
import '../../../models/teacher_batch_session_model.dart';
import '../providers/teacher_batch_ops_provider.dart';

Future<void> showTeacherBatchSessionEditor(
  BuildContext context, {
  required String batchId,
  TeacherBatchSessionModel? session,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => _SessionEditorDialog(
      batchId: batchId,
      session: session,
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          session == null ? 'Session created.' : 'Session updated.',
        ),
      ),
    );
  }
}

class TeacherBatchSessionsSection extends ConsumerWidget {
  const TeacherBatchSessionsSection({super.key, required this.batch});

  final TeacherBatchModel batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(
      teacherBatchSessionsProvider(batch.batchId),
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
                  'Session calendar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => showTeacherBatchSessionEditor(
                  context,
                  batchId: batch.batchId,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add session'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Schedule class sessions for this batch. Mark completed or cancelled when done.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          sessionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Unable to load sessions: $error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No sessions yet. Add an upcoming class meeting.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              final now = DateTime.now();
              final upcoming = items
                  .where(
                    (s) =>
                        s.status == TeacherBatchSessionStatus.scheduled &&
                        !s.startsAt.isBefore(now),
                  )
                  .toList();
              final past = items
                  .where(
                    (s) =>
                        !(s.status == TeacherBatchSessionStatus.scheduled &&
                            !s.startsAt.isBefore(now)),
                  )
                  .toList()
                ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (upcoming.isNotEmpty) ...[
                    Text(
                      'Upcoming',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < upcoming.length; i++) ...[
                      _SessionTile(
                        batchId: batch.batchId,
                        session: upcoming[i],
                      ),
                      if (i != upcoming.length - 1) const Divider(height: 1),
                    ],
                  ],
                  if (upcoming.isNotEmpty && past.isNotEmpty)
                    const SizedBox(height: 14),
                  if (past.isNotEmpty) ...[
                    Text(
                      'Past & closed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < past.length; i++) ...[
                      _SessionTile(
                        batchId: batch.batchId,
                        session: past[i],
                      ),
                      if (i != past.length - 1) const Divider(height: 1),
                    ],
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

class _SessionTile extends ConsumerStatefulWidget {
  const _SessionTile({required this.batchId, required this.session});

  final String batchId;
  final TeacherBatchSessionModel session;

  @override
  ConsumerState<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends ConsumerState<_SessionTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;
    final when = DateFormat.yMMMd().add_jm().format(session.startsAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  TeacherBatchSessionStatus.label(session.status),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            when,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (session.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(session.notes, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => showTeacherBatchSessionEditor(
                          context,
                          batchId: widget.batchId,
                          session: session,
                        ),
                child: const Text('Edit'),
              ),
              if (session.isScheduled) ...[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _setStatus(TeacherBatchSessionStatus.completed),
                  child: const Text('Mark completed'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _setStatus(TeacherBatchSessionStatus.cancelled),
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    final success = await ref
        .read(teacherBatchOpsProvider.notifier)
        .updateSessionStatus(
          batchId: widget.batchId,
          sessionId: widget.session.sessionId,
          status: status,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Session marked ${TeacherBatchSessionStatus.label(status).toLowerCase()}.'
              : 'Unable to update session.',
        ),
      ),
    );
  }
}

class _SessionEditorDialog extends ConsumerStatefulWidget {
  const _SessionEditorDialog({required this.batchId, this.session});

  final String batchId;
  final TeacherBatchSessionModel? session;

  @override
  ConsumerState<_SessionEditorDialog> createState() =>
      _SessionEditorDialogState();
}

class _SessionEditorDialogState extends ConsumerState<_SessionEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _startsAt;
  DateTime? _endsAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _titleController = TextEditingController(text: session?.title ?? '');
    _notesController = TextEditingController(text: session?.notes ?? '');
    final now = DateTime.now();
    _startsAt = session?.startsAt ??
        DateTime(now.year, now.month, now.day, now.hour + 1);
    _endsAt = session?.endsAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.session == null ? 'Add session' : 'Edit session'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                enabled: !_saving,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
                enabled: !_saving,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Starts'),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(_startsAt)),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: _saving ? null : _pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ends (optional)'),
                subtitle: Text(
                  _endsAt == null
                      ? 'Not set'
                      : DateFormat.yMMMd().add_jm().format(_endsAt!),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_endsAt != null)
                      IconButton(
                        tooltip: 'Clear end',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _endsAt = null),
                        icon: const Icon(Icons.clear_rounded),
                      ),
                    const Icon(Icons.schedule_rounded),
                  ],
                ),
                onTap: _saving ? null : _pickEnd,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
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

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickEnd() async {
    final base = _endsAt ?? _startsAt.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(() {
      _endsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
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
    final success = await ref.read(teacherBatchOpsProvider.notifier).saveSession(
          batchId: widget.batchId,
          sessionId: widget.session?.sessionId,
          title: title,
          notes: _notesController.text,
          startsAt: _startsAt,
          endsAt: _endsAt,
          status: widget.session?.status ?? TeacherBatchSessionStatus.scheduled,
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Unable to save session.';
    });
  }
}
