import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/project_assignment_model.dart';
import '../providers/assignment_provider.dart';
import 'course_premium_widgets.dart';

class ProjectSubmissionScreen extends ConsumerWidget {
  const ProjectSubmissionScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
  });

  final String courseId;
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(
      projectAssignmentDetailProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );
    final submissionAsync = ref.watch(
      studentProjectSubmissionProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Project Deployment',
      subtitle: 'Submit your project description, repository, and demo links.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.studentCourseLearn,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: CoursePremiumBackground(
        child: assignmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load project',
            message: error.toString(),
          ),
          data: (assignment) {
            if (assignment == null || !assignment.isPublished) {
              return const CoursePremiumMessage(
                icon: Icons.lock_outline_rounded,
                title: 'Project Unavailable',
                message: 'This project is not currently accepting submissions.',
              );
            }
            return submissionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (submission) => _SubmissionForm(
                courseId: courseId,
                assignment: assignment,
                existingDescription: submission?.projectDescription ?? '',
                existingGithub: submission?.githubLink ?? '',
                existingDemo: submission?.liveDemoLink ?? '',
                existingNotes: submission?.additionalNotes ?? '',
                isUpdate: submission != null,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AssignmentInfoBlock extends StatelessWidget {
  const _AssignmentInfoBlock({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item, style: const TextStyle(height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmissionForm extends ConsumerStatefulWidget {
  const _SubmissionForm({
    required this.courseId,
    required this.assignment,
    required this.existingDescription,
    required this.existingGithub,
    required this.existingDemo,
    required this.existingNotes,
    required this.isUpdate,
  });

  final String courseId;
  final ProjectAssignmentModel assignment;
  final String existingDescription;
  final String existingGithub;
  final String existingDemo;
  final String existingNotes;
  final bool isUpdate;

  @override
  ConsumerState<_SubmissionForm> createState() => _SubmissionFormState();
}

class _SubmissionFormState extends ConsumerState<_SubmissionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _githubController;
  late final TextEditingController _demoController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.existingDescription,
    );
    _githubController = TextEditingController(text: widget.existingGithub);
    _demoController = TextEditingController(text: widget.existingDemo);
    _notesController = TextEditingController(text: widget.existingNotes);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _githubController.dispose();
    _demoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(assignmentActionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return CoursePremiumListView(
      maxWidth: 800,
      children: [
        CourseHeroHeader(
          icon: Icons.rocket_launch_rounded,
          title: widget.isUpdate ? 'Update Submission' : 'Deploy Project',
          subtitle: 'Submit your code and live demo links for review.',
        ),
        const SizedBox(height: 32),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Assignment Details Block (Notion style)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    left: const BorderSide(color: AppColors.accent, width: 4),
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    right: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.assignment.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.assignment.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (widget.assignment.projectGoal.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Project goal',
                        items: [widget.assignment.projectGoal],
                      ),
                    ],
                    if (widget.assignment.realWorldScenario
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Real-world scenario',
                        items: [widget.assignment.realWorldScenario],
                      ),
                    ],
                    if (widget.assignment.learningObjectives.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Learning objectives',
                        items: widget.assignment.learningObjectives,
                      ),
                    ],
                    if (widget.assignment.deliverables.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Deliverables',
                        items: widget.assignment.deliverables,
                      ),
                    ],
                    if (widget.assignment.milestones.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Milestones',
                        items: widget.assignment.milestones,
                      ),
                    ],
                    if (widget.assignment.requirements.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Requirements Checklist',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.assignment.requirements.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_box_outline_blank_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (widget.assignment.acceptanceCriteria.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Acceptance criteria',
                        items: widget.assignment.acceptanceCriteria,
                      ),
                    ],
                    if (widget.assignment.submissionChecklist.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Submission checklist',
                        items: widget.assignment.submissionChecklist,
                      ),
                    ],
                    if (widget.assignment.rubricCriteria.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Rubric',
                        items: widget.assignment.rubricCriteria,
                      ),
                    ],
                    if (widget.assignment.starterGuidance.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Starter guidance',
                        items: widget.assignment.starterGuidance,
                      ),
                    ],
                    if (widget.assignment.resources.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AssignmentInfoBlock(
                        title: 'Resources',
                        items: widget.assignment.resources,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Developer Portal Form Section
              Text(
                'Submission Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161616) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.05,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFormLabel(
                      context,
                      'Project Overview',
                      required: true,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _buildInputDecoration(
                        isDark,
                        'Describe your approach, stack, and challenges...',
                      ),
                      minLines: 4,
                      maxLines: 8,
                      validator: _required,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 24),

                    _buildFormLabel(
                      context,
                      'Repository Link',
                      required: false,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _githubController,
                      decoration: _buildInputDecoration(
                        isDark,
                        'https://github.com/username/repo',
                        icon: Icons.code_rounded,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildFormLabel(context, 'Live Demo Link', required: false),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _demoController,
                      decoration: _buildInputDecoration(
                        isDark,
                        'https://your-project.vercel.app',
                        icon: Icons.public_rounded,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildFormLabel(
                      context,
                      'Additional Notes',
                      required: false,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: _buildInputDecoration(
                        isDark,
                        'Any instructions for the reviewer?',
                      ),
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 15),
                    ),

                    const SizedBox(height: 40),

                    FilledButton.icon(
                      onPressed: actionState.isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      icon: actionState.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              widget.isUpdate
                                  ? Icons.update_rounded
                                  : Icons.rocket_launch_rounded,
                            ),
                      label: Text(
                        actionState.isLoading
                            ? 'Deploying...'
                            : widget.isUpdate
                            ? 'Update Deployment'
                            : 'Deploy Project',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormLabel(
    BuildContext context,
    String text, {
    bool required = false,
  }) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _buildInputDecoration(
    bool isDark,
    String hint, {
    IconData? icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.02),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_githubController.text.trim().isEmpty &&
        _demoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide a GitHub or live demo link.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }
    final success = await ref
        .read(assignmentActionProvider.notifier)
        .submitProject(
          courseId: widget.courseId,
          assignmentId: widget.assignment.assignmentId,
          projectDescription: _descriptionController.text,
          githubLink: _githubController.text,
          liveDemoLink: _demoController.text,
          additionalNotes: _notesController.text,
        );
    if (!mounted) return;
    final message = success
        ? 'Project successfully deployed.'
        : ref.read(assignmentActionProvider.notifier).errorMessage ??
              'Unable to deploy project.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (success) {
      context.goNamed(
        RouteNames.studentProjectStatus,
        pathParameters: {
          'courseId': widget.courseId,
          'assignmentId': widget.assignment.assignmentId,
        },
      );
    }
  }
}
