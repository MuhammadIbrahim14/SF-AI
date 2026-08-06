import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_attendance_model.dart';
import '../../../models/teacher_batch_model.dart';
import '../providers/teacher_batch_ops_provider.dart';
import '../providers/teacher_batch_provider.dart';

class TeacherBatchAttendanceSection extends ConsumerStatefulWidget {
  const TeacherBatchAttendanceSection({super.key, required this.batch});

  final TeacherBatchModel batch;

  @override
  ConsumerState<TeacherBatchAttendanceSection> createState() =>
      _TeacherBatchAttendanceSectionState();
}

class _TeacherBatchAttendanceSectionState
    extends ConsumerState<TeacherBatchAttendanceSection> {
  late DateTime _selectedDate;
  Map<String, String> _draft = {};
  bool _draftReady = false;
  bool _saving = false;
  String? _loadedDateId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateId = teacherBatchAttendanceDateId(_selectedDate);
    final roster = ref.watch(teacherBatchRosterProvider(widget.batch));
    final attendanceArgs = (
      batchId: widget.batch.batchId,
      dateId: dateId,
    );
    final attendanceAsync = ref.watch(
      teacherBatchAttendanceProvider(attendanceArgs),
    );

    ref.listen(teacherBatchAttendanceProvider(attendanceArgs), (previous, next) {
      next.whenData((session) {
        if (!mounted) return;
        if (_loadedDateId == dateId && _draftReady) return;
        _hydrateDraft(roster, session, dateId);
      });
    });

    if (attendanceAsync.hasValue &&
        (_loadedDateId != dateId || !_draftReady)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_loadedDateId == dateId && _draftReady) return;
        _hydrateDraft(roster, attendanceAsync.value, dateId);
      });
    } else if (_draftReady &&
        _loadedDateId == dateId &&
        roster.any((entry) => !_draft.containsKey(entry.studentId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _loadedDateId != dateId) return;
        setState(() {
          for (final entry in roster) {
            _draft.putIfAbsent(
              entry.studentId,
              () => TeacherBatchAttendanceStatus.present,
            );
          }
        });
      });
    }

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
                  'Attendance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(DateFormat.yMMMd().format(_selectedDate)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mark roster for $dateId. Saved privately for you.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (roster.isEmpty)
            Text(
              'Add students to the roster before taking attendance.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _saving || !_draftReady
                      ? null
                      : () => _markAll(TeacherBatchAttendanceStatus.present),
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Mark all present'),
                ),
                FilledButton.icon(
                  onPressed: _saving || !_draftReady ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save attendance'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teacherPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            attendanceAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Unable to load attendance: $error',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
              ),
              data: (_) {
                if (!_draftReady) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < roster.length; i++) ...[
                      _AttendanceRow(
                        name: roster[i].studentName,
                        email: roster[i].studentEmail,
                        status:
                            _draft[roster[i].studentId] ??
                            TeacherBatchAttendanceStatus.present,
                        onChanged: (status) {
                          setState(() {
                            _draft[roster[i].studentId] = status;
                          });
                        },
                      ),
                      if (i != roster.length - 1) const Divider(height: 1),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _hydrateDraft(
    List<TeacherBatchRosterEntry> roster,
    TeacherBatchAttendanceModel? session,
    String dateId,
  ) {
    final next = <String, String>{};
    for (final entry in roster) {
      next[entry.studentId] =
          session?.statusFor(entry.studentId) ??
          TeacherBatchAttendanceStatus.present;
    }
    setState(() {
      _draft = next;
      _draftReady = true;
      _loadedDateId = dateId;
    });
  }

  void _markAll(String status) {
    setState(() {
      for (final key in _draft.keys.toList()) {
        _draft[key] = TeacherBatchAttendanceStatus.normalize(status);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _draftReady = false;
      _loadedDateId = null;
      _draft = {};
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dateId = teacherBatchAttendanceDateId(_selectedDate);
    final success = await ref
        .read(teacherBatchOpsProvider.notifier)
        .saveAttendance(
          batchId: widget.batch.batchId,
          dateId: dateId,
          records: Map<String, String>.from(_draft),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Attendance saved for $dateId.'
              : 'Unable to save attendance.',
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.name,
    required this.email,
    required this.status,
    required this.onChanged,
  });

  final String name;
  final String email;
  final String status;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
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
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: TeacherBatchAttendanceStatus.normalize(status),
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final value in TeacherBatchAttendanceStatus.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(TeacherBatchAttendanceStatus.label(value)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
