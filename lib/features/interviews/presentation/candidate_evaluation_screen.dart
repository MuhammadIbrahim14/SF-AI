import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/application_model.dart';
import '../../../models/interview_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/company_permission_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/interview_provider.dart';
import '../../../providers/pdf_export_provider.dart';
import '../../company/hiring_lifecycle/providers/hiring_lifecycle_providers.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class CandidateEvaluationScreen extends ConsumerStatefulWidget {
  const CandidateEvaluationScreen({super.key, required this.interviewId});

  final String interviewId;

  @override
  ConsumerState<CandidateEvaluationScreen> createState() =>
      _CandidateEvaluationScreenState();
}

class _CandidateEvaluationScreenState
    extends ConsumerState<CandidateEvaluationScreen> {
  final _technicalController = TextEditingController();
  final _communicationController = TextEditingController();
  final _confidenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _feedbackController = TextEditingController();
  final _salaryController = TextEditingController();
  final _joiningDateController = TextEditingController();
  final _offerMessageController = TextEditingController();
  bool _hydrated = false;
  String _selectedCurrency = 'PKR';

  @override
  void dispose() {
    _technicalController.dispose();
    _communicationController.dispose();
    _confidenceController.dispose();
    _notesController.dispose();
    _feedbackController.dispose();
    _salaryController.dispose();
    _joiningDateController.dispose();
    _offerMessageController.dispose();
    super.dispose();
  }

  void _hydrate(InterviewModel interview) {
    if (_hydrated) return;
    _hydrated = true;
    _technicalController.text = interview.technicalScore.toStringAsFixed(0);
    _communicationController.text = interview.communicationScore
        .toStringAsFixed(0);
    _confidenceController.text = interview.confidenceScore.toStringAsFixed(0);
    _notesController.text = interview.interviewerNotes;
    _feedbackController.text = interview.candidateFeedback;
  }

  double _score(TextEditingController controller) {
    return (double.tryParse(controller.text.trim()) ?? 0)
        .clamp(0, 100)
        .toDouble();
  }

  Future<void> _saveEvaluation(InterviewModel interview) async {
    final permission = await ref.read(companyPermissionProvider.future);
    if (!permission.canEvaluateInterview) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(permission.restrictionMessage)));
      return;
    }

    final technical = _score(_technicalController);
    final communication = _score(_communicationController);
    final confidence = _score(_confidenceController);
    final finalScore = InterviewModel.calculateFinalScore(
      technicalScore: technical,
      communicationScore: communication,
      confidenceScore: confidence,
    );
    final result = InterviewModel.resultForScore(finalScore);
    final recommendedStage = switch (result) {
      'passed' => 'offer',
      'on_hold' => 'screening',
      _ => 'rejected',
    };
    final evaluationSummary = [
      'Technical: ${technical.toStringAsFixed(0)}%',
      'Communication: ${communication.toStringAsFixed(0)}%',
      'Confidence: ${confidence.toStringAsFixed(0)}%',
      if (_notesController.text.trim().isNotEmpty)
        'Notes: ${_notesController.text.trim()}',
    ].join('\n');

    final success = await ref
        .read(interviewActionProvider.notifier)
        .updateInterview(
          interview.copyWith(
            status: 'completed',
            result: result,
            technicalScore: technical,
            communicationScore: communication,
            confidenceScore: confidence,
            finalScore: finalScore,
            interviewerNotes: _notesController.text.trim(),
            candidateFeedback: _feedbackController.text.trim(),
            updatedAt: DateTime.now(),
          ),
          applicationStatus: 'interview_completed',
        );

    if (!mounted) return;
    if (success) {
      await ref
          .read(applicationActionProvider.notifier)
          .updateHiringData(
            applicationId: interview.applicationId,
            evaluationScore: finalScore,
            evaluationSummary: evaluationSummary,
            rankingScore: finalScore,
            rankingReason: 'Interview score saved by recruiter.',
            recommendedNextStep:
                'Recommended manual next step: ${pipelineStageLabel(recommendedStage)}.',
            evaluatedAt: DateTime.now(),
            lifecycleStage: 'interview_completed',
            applicationStatus: 'interview_completed',
            candidateVisibleStatus: 'interview_completed',
          );
      if (!mounted) return;
      ref.invalidate(interviewDetailProvider(interview.interviewId));
      ref.invalidate(applicationDetailProvider(interview.applicationId));
      ref.invalidate(applicationDetailStreamProvider(interview.applicationId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Evaluation saved. Suggested result: ${result.replaceAll('_', ' ')}. No status changed automatically.',
          ),
        ),
      );
    } else {
      final error = ref.read(interviewActionProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save evaluation: $error')),
      );
    }
  }

  Future<void> _markAsEvaluated(InterviewModel interview) async {
    final permission = await ref.read(companyPermissionProvider.future);
    if (!permission.canEvaluateInterview) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(permission.restrictionMessage)));
      return;
    }

    final success = await ref
        .read(applicationActionProvider.notifier)
        .markAsEvaluated(applicationId: interview.applicationId);
    if (!mounted) return;
    if (success) {
      ref.invalidate(applicationDetailStreamProvider(interview.applicationId));
      ref.invalidate(applicationDetailProvider(interview.applicationId));
      ref.invalidate(applicationTimelineProvider(interview.applicationId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evaluation marked complete. Ready for decision.'),
        ),
      );
    }
  }

  Future<void> _makeOffer(InterviewModel interview) async {
    final permission = await ref.read(companyPermissionProvider.future);
    if (!permission.canHire) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(permission.restrictionMessage)));
      return;
    }

    if (_salaryController.text.trim().isEmpty ||
        _joiningDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all offer fields')),
      );
      return;
    }

    final success = await ref
        .read(applicationActionProvider.notifier)
        .makeOffer(
          applicationId: interview.applicationId,
          salary: _salaryController.text.trim(),
          currency: _selectedCurrency,
          joiningDate: _joiningDateController.text.trim(),
          message: _offerMessageController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      ref.invalidate(applicationDetailStreamProvider(interview.applicationId));
      ref.invalidate(applicationDetailProvider(interview.applicationId));
      ref.invalidate(applicationTimelineProvider(interview.applicationId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offer sent. Candidate can view it under My Applications.',
          ),
        ),
      );
      _salaryController.clear();
      _joiningDateController.clear();
      _offerMessageController.clear();
    }
  }

  Future<void> _hireCandidate(InterviewModel interview) async {
    final permission = await ref.read(companyPermissionProvider.future);
    if (!permission.canHire) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(permission.restrictionMessage)));
      return;
    }

    final success = await ref
        .read(applicationActionProvider.notifier)
        .hireCandidate(applicationId: interview.applicationId);
    if (!mounted) return;
    if (success) {
      ref.invalidate(applicationDetailStreamProvider(interview.applicationId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidate hired!')),
      );
    } else {
      final error =
          ref.read(applicationActionProvider.notifier).lastErrorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Unable to hire candidate. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _exportOfferPdf(
    ApplicationModel app, {
    required String candidateName,
    required bool print,
  }) async {
    final company = ref.read(companyProvider).asData?.value;
    final companyName = (company?.companyName.trim().isNotEmpty == true)
        ? company!.companyName
        : 'Company';
    final ok = await ref.read(pdfExportActionProvider.notifier).exportOfferLetter(
          application: app,
          companyName: companyName,
          candidateName: candidateName,
          print: print,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (print
                  ? 'Offer letter opened for print.'
                  : 'Offer letter ready to share.')
              : (ref.read(pdfExportActionProvider.notifier).errorMessage ??
                  'Unable to export offer letter.'),
        ),
      ),
    );
  }

  Future<void> _rejectCandidate(InterviewModel interview) async {
    final permission = await ref.read(companyPermissionProvider.future);
    if (!permission.canReject) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(permission.restrictionMessage)));
      return;
    }

    final success = await ref
        .read(applicationActionProvider.notifier)
        .rejectCandidate(applicationId: interview.applicationId);
    if (!mounted) return;
    if (success) {
      ref.invalidate(applicationDetailStreamProvider(interview.applicationId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidate rejected.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final interviewAsync = ref.watch(
      interviewDetailStreamProvider(widget.interviewId),
    );
    final permissionAsync = ref.watch(companyPermissionProvider);
    final permission = permissionAsync.value;
    final canEvaluate = permission?.canEvaluateInterview ?? false;
    final isSaving = ref.watch(interviewActionProvider).isLoading;
    final isProcessing = ref.watch(applicationActionProvider).isLoading;

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Candidate Evaluation',
      subtitle: 'Score interview performance and update hiring status.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.hiringPipeline),
      scrollable: false,
      child: interviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (interview) {
          if (interview == null) {
            return const Center(child: Text('Interview not found.'));
          }
          if (permissionAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!canEvaluate) {
            return _CompanyPermissionBlocked(
              message:
                  permission?.restrictionMessage ??
                  'Company verification is required before evaluating candidates.',
            );
          }
          _hydrate(interview);

          final technical = _score(_technicalController);
          final communication = _score(_communicationController);
          final confidence = _score(_confidenceController);
          final finalScore = InterviewModel.calculateFinalScore(
            technicalScore: technical,
            communicationScore: communication,
            confidenceScore: confidence,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.analytics_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Final Score: ${finalScore.toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _technicalController,
                  label: 'Technical Score',
                  hint: '0-100',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _communicationController,
                  label: 'Communication Score',
                  hint: '0-100',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _confidenceController,
                  label: 'Confidence Score',
                  hint: '0-100',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _notesController,
                  label: 'Interviewer Notes',
                  hint: 'Technical strengths, concerns, next steps...',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _feedbackController,
                  label: 'Candidate Feedback',
                  hint: 'Optional feedback visible later to candidate.',
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Save Evaluation',
                  isLoading: isSaving,
                  onPressed: canEvaluate
                      ? () => _saveEvaluation(interview)
                      : null,
                ),
                const SizedBox(height: 18),
                if (interview.status == 'completed') ...[
                  FilledButton(
                    onPressed: isProcessing ? null : () => _markAsEvaluated(interview),
                    child: const Text('Mark as Evaluated & Move to Decision'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Make Job Offer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _salaryController,
                    label: 'Salary',
                    hint: 'e.g., 50000',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null && mounted) {
                              _joiningDateController.text = date.toIso8601String().split('T').first;
                            }
                          },
                          child: CustomTextField(
                            controller: _joiningDateController,
                            label: 'Joining Date',
                            hint: 'e.g., 2026-08-01',
                            enabled: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownMenu<String>(
                          initialSelection: _selectedCurrency,
                          onSelected: (value) {
                            if (value != null) {
                              setState(() => _selectedCurrency = value);
                            }
                          },
                          dropdownMenuEntries: const [
                            DropdownMenuEntry(value: 'PKR', label: 'PKR'),
                            DropdownMenuEntry(value: 'USD', label: 'USD'),
                            DropdownMenuEntry(value: 'EUR', label: 'EUR'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _offerMessageController,
                    label: 'Offer Message',
                    hint: 'Welcome message to the candidate (optional)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Send Job Offer',
                    isLoading: isProcessing,
                    onPressed: () => _makeOffer(interview),
                  ),
                  Builder(
                    builder: (context) {
                      final app = ref
                          .watch(
                            applicationDetailStreamProvider(
                              interview.applicationId,
                            ),
                          )
                          .asData
                          ?.value;
                      if (app == null || !app.hasStructuredOffer) {
                        return const SizedBox.shrink();
                      }
                      final candidateAsync = ref.watch(
                        hiringUserProvider(app.applicantId),
                      );
                      final candidateName =
                          candidateAsync.asData?.value?.fullName ??
                          candidateAsync.asData?.value?.email ??
                          'Candidate';
                      final pdfBusy =
                          ref.watch(pdfExportActionProvider).isLoading;
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: pdfBusy
                                  ? null
                                  : () => _exportOfferPdf(
                                        app,
                                        candidateName: candidateName,
                                        print: true,
                                      ),
                              icon: const Icon(Icons.print_rounded),
                              label: const Text('Preview / Print Offer'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: pdfBusy
                                  ? null
                                  : () => _exportOfferPdf(
                                        app,
                                        candidateName: candidateName,
                                        print: false,
                                      ),
                              icon: const Icon(Icons.ios_share_rounded),
                              label: const Text('Share Offer PDF'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Final Decision',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isProcessing ? null : () => _hireCandidate(interview),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Hire'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isProcessing ? null : () => _rejectCandidate(interview),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          icon: const Icon(Icons.cancel_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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
                Icons.lock_outline_rounded,
                color: AppColors.warning,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                'Candidate evaluation locked',
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
