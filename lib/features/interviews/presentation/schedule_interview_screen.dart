import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/interview_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/company_permission_provider.dart';
import '../../../providers/interview_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class ScheduleInterviewScreen extends ConsumerStatefulWidget {
  const ScheduleInterviewScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<ScheduleInterviewScreen> createState() =>
      _ScheduleInterviewScreenState();
}

class _ScheduleInterviewScreenState
    extends ConsumerState<ScheduleInterviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController(text: '30');
  final _meetingLinkController = TextEditingController();
  final _locationController = TextEditingController();
  final _agendaController = TextEditingController();
  final _questionsController = TextEditingController();
  final _timezoneController = TextEditingController(text: 'Asia/Karachi');
  final _companyInstructionsController = TextEditingController();
  final _candidateInstructionsController = TextEditingController();

  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  String _mode = 'online';
  String _meetingPlatform = 'google_meet';

  @override
  void dispose() {
    _durationController.dispose();
    _meetingLinkController.dispose();
    _locationController.dispose();
    _agendaController.dispose();
    _questionsController.dispose();
    _timezoneController.dispose();
    _companyInstructionsController.dispose();
    _candidateInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _schedule() async {
    final permission = await ref.read(companyPermissionProvider.future);
    if (!permission.canScheduleInterview) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(permission.restrictionMessage)));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    final application = ref
        .read(applicationDetailProvider(widget.applicationId))
        .value;
    if (application == null) return;

    final now = DateTime.now();
    final interview = InterviewModel(
      interviewId: application.interviewId ?? '',
      jobId: application.jobId,
      applicationId: application.id,
      companyId: application.companyId,
      candidateId: application.applicantId,
      candidateRole: application.role,
      scheduledAt: _scheduledAt,
      durationMinutes: int.tryParse(_durationController.text.trim()) ?? 30,
      interviewMode: _mode,
      meetingLink: _meetingLinkController.text.trim(),
      location: _locationController.text.trim(),
      agenda: _agendaController.text.trim(),
      questions: _questionsController.text
          .split(RegExp(r'[\n,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      status: application.interviewId == null ? 'scheduled' : 'rescheduled',
      result: 'pending',
      interviewerNotes: '',
      candidateFeedback: '',
      technicalScore: 0,
      communicationScore: 0,
      confidenceScore: 0,
      finalScore: 0,
      createdAt: now,
      updatedAt: now,
      meetingPlatform: _mode == 'online' ? _meetingPlatform : 'none',
      timezone: _timezoneController.text.trim().isEmpty
          ? 'UTC'
          : _timezoneController.text.trim(),
      companyInstructions: _companyInstructionsController.text.trim(),
      candidateInstructions: _candidateInstructionsController.text.trim(),
    );

    final success = await ref
        .read(interviewActionProvider.notifier)
        .scheduleInterview(interview);
    if (!mounted) return;

    if (success) {
      ref.invalidate(applicationDetailProvider(widget.applicationId));
      ref.invalidate(applicationInterviewProvider(widget.applicationId));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interview scheduled successfully.')),
      );
    } else {
      final error = ref.read(interviewActionProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to schedule interview: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicationAsync = ref.watch(
      applicationDetailProvider(widget.applicationId),
    );
    final permissionAsync = ref.watch(companyPermissionProvider);
    final permission = permissionAsync.value;
    final canSchedule = permission?.canScheduleInterview ?? false;
    final isSaving = ref.watch(interviewActionProvider).isLoading;

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Schedule Interview',
      subtitle: 'Set interview timing, mode, agenda, and preparation topics.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.hiringPipeline),
      scrollable: false,
      child: applicationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (application) {
          if (application == null) {
            return const Center(child: Text('Application not found.'));
          }
          if (permissionAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!canSchedule) {
            return _CompanyPermissionBlocked(
              message:
                  permission?.restrictionMessage ??
                  'Company verification is required before scheduling interviews.',
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_rounded),
                    title: Text(
                      DateFormat.yMMMd().add_jm().format(_scheduledAt),
                    ),
                    subtitle: const Text('Interview date and time'),
                    trailing: TextButton(
                      onPressed: _pickDateTime,
                      child: const Text('Change'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _mode,
                    decoration: const InputDecoration(labelText: 'Interview Type'),
                    items: const [
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                      DropdownMenuItem(
                        value: 'in_person',
                        child: Text('Physical'),
                      ),
                      DropdownMenuItem(value: 'phone', child: Text('Phone')),
                    ],
                    onChanged: (value) =>
                        setState(() => _mode = value ?? _mode),
                  ),
                  if (_mode == 'online') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _meetingPlatform,
                      decoration:
                          const InputDecoration(labelText: 'Meeting Platform'),
                      items: const [
                        DropdownMenuItem(
                          value: 'google_meet',
                          child: Text('Google Meet'),
                        ),
                        DropdownMenuItem(value: 'zoom', child: Text('Zoom')),
                        DropdownMenuItem(
                          value: 'microsoft_teams',
                          child: Text('Microsoft Teams'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom URL'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _meetingPlatform = value ?? _meetingPlatform,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _durationController,
                    label: 'Duration Minutes',
                    hint: '30',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _timezoneController,
                    label: 'Timezone',
                    hint: 'Asia/Karachi',
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _meetingLinkController,
                    label: 'Meeting Link',
                    hint: 'https://meet.google.com/...',
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _locationController,
                    label: 'Location',
                    hint: 'Office address or phone number',
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _agendaController,
                    label: 'Agenda / Notes',
                    hint: 'Technical discussion, portfolio review...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _companyInstructionsController,
                    label: 'Company Instructions',
                    hint: 'Internal interviewer prep notes',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _candidateInstructionsController,
                    label: 'Candidate Instructions',
                    hint: 'What the candidate should prepare',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _questionsController,
                    label: 'Questions',
                    hint: 'One question per line',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    text: application.interviewId == null
                        ? 'Schedule Interview'
                        : 'Reschedule Interview',
                    isLoading: isSaving,
                    onPressed: canSchedule ? _schedule : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompanyPermissionBlocked extends StatelessWidget {
  const _CompanyPermissionBlocked({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_clock_rounded,
                color: AppColors.warning,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                'Interview scheduling locked',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
