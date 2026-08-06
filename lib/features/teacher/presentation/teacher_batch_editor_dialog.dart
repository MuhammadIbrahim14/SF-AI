import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/teacher_batch_model.dart';
import '../../courses/data/models/course_model.dart';
import '../../courses/providers/course_provider.dart';
import '../data/models/teacher_student_progress_model.dart';
import '../providers/teacher_batch_provider.dart';
import '../providers/teacher_student_progress_provider.dart';

Future<bool?> showTeacherBatchEditorDialog(
  BuildContext context, {
  TeacherBatchModel? batch,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => TeacherBatchEditorDialog(batch: batch),
  );
}

class TeacherBatchEditorDialog extends ConsumerStatefulWidget {
  const TeacherBatchEditorDialog({super.key, this.batch});

  final TeacherBatchModel? batch;

  @override
  ConsumerState<TeacherBatchEditorDialog> createState() =>
      _TeacherBatchEditorDialogState();
}

class _TeacherBatchEditorDialogState
    extends ConsumerState<TeacherBatchEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _courseSearchController;
  late final TextEditingController _studentSearchController;

  late Set<String> _selectedCourseIds;
  late Set<String> _selectedStudentIds;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;
  bool _syncing = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    final batch = widget.batch;
    _titleController = TextEditingController(text: batch?.title ?? '');
    _descriptionController = TextEditingController(
      text: batch?.description ?? '',
    );
    _courseSearchController = TextEditingController();
    _studentSearchController = TextEditingController();
    _selectedCourseIds = {...?batch?.courseIds};
    _selectedStudentIds = {...?batch?.studentIds};
    _startDate = batch?.startDate;
    _endDate = batch?.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _courseSearchController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courses = ref.watch(teacherCoursesProvider).value ?? const [];
    final progress =
        ref.watch(teacherStudentProgressProvider).value ??
        const <TeacherStudentProgressModel>[];
    final enrollmentsAsync = ref.watch(
      teacherBatchActiveEnrollmentsProvider(
        teacherBatchCourseIdsKey(_selectedCourseIds),
      ),
    );
    final enrollments = enrollmentsAsync.value ?? const [];
    final enrolledStudentIds = enrollments
        .map((item) => item.studentId)
        .toSet();

    final nameByStudent = <String, String>{};
    final emailByStudent = <String, String>{};
    for (final record in progress) {
      if (!nameByStudent.containsKey(record.studentId) &&
          record.studentName.trim().isNotEmpty) {
        nameByStudent[record.studentId] = record.studentName.trim();
      }
      if (!emailByStudent.containsKey(record.studentId) &&
          record.studentEmail.trim().isNotEmpty) {
        emailByStudent[record.studentId] = record.studentEmail.trim();
      }
    }

    final courseQuery = _courseSearchController.text.trim().toLowerCase();
    final filteredCourses = courses.where((course) {
      if (courseQuery.isEmpty) return true;
      return course.title.toLowerCase().contains(courseQuery) ||
          course.id.toLowerCase().contains(courseQuery);
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final studentQuery = _studentSearchController.text.trim().toLowerCase();
    final candidateStudentIds = <String>{
      ...enrolledStudentIds,
      ..._selectedStudentIds,
    }.toList()
      ..sort((a, b) {
        final an = (nameByStudent[a] ?? a).toLowerCase();
        final bn = (nameByStudent[b] ?? b).toLowerCase();
        return an.compareTo(bn);
      });
    final filteredStudentIds = candidateStudentIds.where((id) {
      if (studentQuery.isEmpty) return true;
      final name = (nameByStudent[id] ?? '').toLowerCase();
      final email = (emailByStudent[id] ?? '').toLowerCase();
      return name.contains(studentQuery) ||
          email.contains(studentQuery) ||
          id.toLowerCase().contains(studentQuery);
    }).toList();

    return AlertDialog(
      title: Text(widget.batch == null ? 'Create Batch' : 'Edit Batch'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Batch title',
                  hintText: 'e.g. Morning Flutter Cohort',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional notes for this workspace',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Schedule',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DateChip(
                    label: 'Start',
                    value: _startDate,
                    onPick: () => _pickDate(isStart: true),
                    onClear: _startDate == null
                        ? null
                        : () => setState(() => _startDate = null),
                  ),
                  _DateChip(
                    label: 'End',
                    value: _endDate,
                    onPick: () => _pickDate(isStart: false),
                    onClear: _endDate == null
                        ? null
                        : () => setState(() => _endDate = null),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Courses',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select courses you own. Batch metrics filter by these courses.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _courseSearchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search courses',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (_selectedCourseIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final courseId in _selectedCourseIds)
                        InputChip(
                          label: Text(_courseTitle(courses, courseId)),
                          onDeleted: () => setState(() {
                            _selectedCourseIds.remove(courseId);
                          }),
                        ),
                    ],
                  ),
                ),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: courses.isEmpty
                    ? const ListTile(
                        dense: true,
                        title: Text('No courses found for this teacher.'),
                      )
                    : filteredCourses.isEmpty
                    ? const ListTile(
                        dense: true,
                        title: Text('No courses match your search.'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredCourses.length,
                        itemBuilder: (context, index) {
                          final course = filteredCourses[index];
                          final selected = _selectedCourseIds.contains(
                            course.id,
                          );
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            title: Text(course.title),
                            subtitle: Text(
                              course.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedCourseIds.add(course.id);
                                } else {
                                  _selectedCourseIds.remove(course.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Students',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selectedCourseIds.isEmpty || _syncing
                        ? null
                        : _syncFromEnrollments,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: const Text('Sync from enrollments'),
                  ),
                ],
              ),
              Text(
                'Replaces student list with currently enrolled students when you sync. '
                'You can still add or remove students after syncing.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedCourseIds.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.teacherPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Select at least one course to load enrolled students.',
                  ),
                )
              else ...[
                TextField(
                  controller: _studentSearchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search students by name or email',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (_selectedStudentIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final studentId in _selectedStudentIds)
                          InputChip(
                            label: Text(
                              nameByStudent[studentId] ??
                                  _shortId(studentId),
                            ),
                            onDeleted: () => setState(() {
                              _selectedStudentIds.remove(studentId);
                            }),
                          ),
                      ],
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: enrollmentsAsync.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : filteredStudentIds.isEmpty
                      ? const ListTile(
                          dense: true,
                          title: Text(
                            'No active enrollments for the selected courses.',
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredStudentIds.length,
                          itemBuilder: (context, index) {
                            final studentId = filteredStudentIds[index];
                            final selected = _selectedStudentIds.contains(
                              studentId,
                            );
                            final enrolled = enrolledStudentIds.contains(
                              studentId,
                            );
                            final name =
                                nameByStudent[studentId] ?? _shortId(studentId);
                            final email = emailByStudent[studentId] ?? '';
                            return CheckboxListTile(
                              dense: true,
                              value: selected,
                              title: Text(name),
                              subtitle: Text(
                                [
                                  if (email.isNotEmpty) email,
                                  if (!enrolled) 'Not in current enrollments',
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedStudentIds.add(studentId);
                                  } else {
                                    _selectedStudentIds.remove(studentId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
              if (_note != null) ...[
                const SizedBox(height: 12),
                Text(
                  _note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
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
          onPressed: _saving ? null : () => _save(courses, enrolledStudentIds),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Batch'),
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && picked.isBefore(_startDate!)) {
          _startDate = picked;
        }
      }
    });
  }

  Future<void> _syncFromEnrollments() async {
    setState(() {
      _syncing = true;
      _note = null;
    });
    try {
      final studentIds = await ref
          .read(teacherBatchActionProvider.notifier)
          .resolveActiveEnrollmentStudentIds(_selectedCourseIds.toList());
      if (!mounted) return;
      setState(() {
        _selectedStudentIds = studentIds.toSet();
        _note =
            'Student list replaced with currently enrolled students '
            '(${studentIds.length}).';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _note = 'Unable to sync roster: $error';
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _save(
    List<CourseModel> courses,
    Set<String> enrolledStudentIds,
  ) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _note = 'Batch title is required.');
      return;
    }

    final ownedIds = courses.map((course) => course.id).toSet();
    final validCourseIds = _selectedCourseIds
        .where(ownedIds.contains)
        .toList();
    final droppedCourses = _selectedCourseIds.length - validCourseIds.length;

    // Re-resolve enrollments for the validated course set.
    final liveEnrolled = await ref
        .read(teacherBatchActionProvider.notifier)
        .resolveActiveEnrollmentStudentIds(validCourseIds);
    final allowedStudents = liveEnrolled.toSet();
    final validStudentIds = _selectedStudentIds
        .where(allowedStudents.contains)
        .toList();
    final droppedStudents = _selectedStudentIds.length - validStudentIds.length;

    setState(() {
      _selectedCourseIds = validCourseIds.toSet();
      _selectedStudentIds = validStudentIds.toSet();
      _saving = true;
      _note = null;
    });

    final success = await ref
        .read(teacherBatchActionProvider.notifier)
        .saveBatch(
          batchId: widget.batch?.batchId,
          title: title,
          description: _descriptionController.text,
          courseIds: validCourseIds,
          studentIds: validStudentIds,
          startDate: _startDate,
          endDate: _endDate,
          status: widget.batch?.status ?? TeacherBatchStatus.active,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!success) {
      final error = ref.read(teacherBatchActionProvider).error;
      setState(() {
        _note = error?.toString() ?? 'Unable to save batch.';
      });
      return;
    }

    final notes = <String>[];
    if (droppedCourses > 0) {
      notes.add('Removed $droppedCourses course(s) you do not own.');
    }
    if (droppedStudents > 0) {
      notes.add(
        'Removed $droppedStudents student(s) not enrolled in the selected courses.',
      );
    }

    if (notes.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notes.join(' '))));
    }

    if (context.mounted) Navigator.of(context).pop(true);
  }

  String _courseTitle(List<CourseModel> courses, String courseId) {
    for (final course in courses) {
      if (course.id == courseId) return course.title;
    }
    return courseId;
  }

  String _shortId(String id) {
    final trimmed = id.trim();
    if (trimmed.length <= 8) return trimmed;
    return '${trimmed.substring(0, 6)}…';
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.yMMMd();
    return InputChip(
      avatar: const Icon(Icons.event_rounded, size: 18),
      label: Text(
        value == null ? '$label: Not set' : '$label: ${formatter.format(value!)}',
      ),
      onPressed: onPick,
      onDeleted: onClear,
      deleteIcon: onClear == null ? null : const Icon(Icons.close_rounded),
    );
  }
}
