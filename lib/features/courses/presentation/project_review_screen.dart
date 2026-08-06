import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/project_submission_model.dart';
import '../providers/assignment_provider.dart';
import 'course_premium_widgets.dart';

class ProjectReviewScreen extends ConsumerStatefulWidget {
  const ProjectReviewScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.studentId,
  });

  final String courseId;
  final String assignmentId;
  final String studentId;

  @override
  ConsumerState<ProjectReviewScreen> createState() =>
      _ProjectReviewScreenState();
}

class _ProjectReviewScreenState extends ConsumerState<ProjectReviewScreen> {
  late final TextEditingController _marksController;
  late final TextEditingController _feedbackController;
  String _status = ProjectSubmissionStatus.graded;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _marksController = TextEditingController();
    _feedbackController = TextEditingController();
  }

  @override
  void dispose() {
    _marksController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignmentAsync = ref.watch(
      projectAssignmentDetailProvider((
        courseId: widget.courseId,
        assignmentId: widget.assignmentId,
      )),
    );
    final submissionAsync = ref.watch(
      projectSubmissionProviderForStudent((
        courseId: widget.courseId,
        assignmentId: widget.assignmentId,
        studentId: widget.studentId,
      )),
    );
    final actionState = ref.watch(assignmentActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Code Review',
      subtitle: 'Grade project submissions and provide actionable feedback.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.teacherProjectSubmissions,
              pathParameters: {
                'courseId': widget.courseId,
                'assignmentId': widget.assignmentId,
              },
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: assignmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (assignment) {
            if (assignment == null) {
              return const CoursePremiumMessage(
                icon: Icons.error_outline_rounded,
                title: 'Assignment not found',
                message: 'This assignment could not be loaded.',
              );
            }
            return submissionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (submission) {
                if (submission == null) {
                  return const CoursePremiumMessage(
                    icon: Icons.error_outline_rounded,
                    title: 'Submission not found',
                    message: 'This submission could not be loaded.',
                  );
                }
                _seedForm(submission);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;

                    final detailsPane = _buildDetailsPane(
                      context,
                      assignment.title,
                      submission,
                    );
                    final reviewPane = _buildReviewPane(
                      context,
                      assignment.maxMarks,
                      actionState.isLoading,
                    );

                    if (isWide) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: SingleChildScrollView(child: detailsPane),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: SingleChildScrollView(child: reviewPane),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          detailsPane,
                          const SizedBox(height: 24),
                          reviewPane,
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailsPane(
    BuildContext context,
    String projectTitle,
    ProjectSubmissionModel submission,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CourseHeroHeader(
          icon: Icons.rate_review_rounded,
          title: 'Student ${submission.studentId}',
          subtitle: projectTitle,
        ),
        const SizedBox(height: 24),
        CourseGlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LinkTile(
                icon: Icons.code_rounded,
                title: 'GitHub Repository',
                url: submission.githubLink,
                color: Colors.white,
                backgroundColor: const Color(0xFF24292E),
              ),
              const SizedBox(height: 16),
              _LinkTile(
                icon: Icons.open_in_browser_rounded,
                title: 'Live Demo Link',
                url: submission.liveDemoLink,
                color: Colors.white,
                backgroundColor: Colors.blue.shade600,
              ),
              const SizedBox(height: 32),
              _SectionLabel(
                title: 'Project Description',
                icon: Icons.description_rounded,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  submission.projectDescription.isEmpty
                      ? 'No description provided.'
                      : submission.projectDescription,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
              if (submission.additionalNotes.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionLabel(
                  title: 'Additional Notes',
                  icon: Icons.note_alt_rounded,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SelectableText(
                    submission.additionalNotes,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewPane(
    BuildContext context,
    int maxMarks,
    bool isSubmitting,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CourseGlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.grading_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                'Grading Panel',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.divider : AppColors.lightDivider,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _status,
                isExpanded: true,
                dropdownColor: theme.colorScheme.surface,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                items: [
                  DropdownMenuItem(
                    value: ProjectSubmissionStatus.graded,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Approved / Graded',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: ProjectSubmissionStatus.rejected,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Rejected',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: ProjectSubmissionStatus.changesRequested,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.rate_review_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Changes Requested',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          CoursePremiumTextField(
            controller: _marksController,
            label: 'Marks Awarded',
            hintText: 'Out of $maxMarks',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 24),
          CoursePremiumTextField(
            controller: _feedbackController,
            label: 'Detailed Feedback',
            hintText:
                'Explain what was done well and what needs improvement...',
            minLines: 4,
            maxLines: 8,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: isSubmitting ? null : () => _saveReview(maxMarks),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 24),
              backgroundColor: AppColors.primary,
            ),
            icon: isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(
              isSubmitting ? 'Saving Review...' : 'Submit Review',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _seedForm(ProjectSubmissionModel submission) {
    if (_seeded) return;
    _seeded = true;
    _marksController.text = submission.marks.toString();
    _feedbackController.text = submission.feedback;
    _status = submission.status == ProjectSubmissionStatus.submitted
        ? ProjectSubmissionStatus.graded
        : submission.status;
  }

  Future<void> _saveReview(int maxMarks) async {
    final marks = int.tryParse(_marksController.text.trim()) ?? 0;
    if (marks > maxMarks) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Marks cannot exceed $maxMarks.')));
      return;
    }
    final success = await ref
        .read(assignmentActionProvider.notifier)
        .reviewProjectSubmission(
          courseId: widget.courseId,
          assignmentId: widget.assignmentId,
          studentId: widget.studentId,
          status: _status,
          marks: marks,
          feedback: _feedbackController.text.trim(),
        );
    if (!mounted) return;
    final message = success
        ? 'Review successfully saved.'
        : ref.read(assignmentActionProvider.notifier).errorMessage ??
              'Unable to save review.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.url,
    required this.backgroundColor,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String url;
  final Color backgroundColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: backgroundColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  url,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
