import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/profile_image_provider.dart';
import '../../../shared/widgets/lms_ui/lms_status_badge.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../payment/providers/payment_providers.dart';
import '../data/models/course_model.dart';
import '../providers/course_provider.dart';
import '../providers/purchase_provider.dart';
import 'course_premium_widgets.dart';
import 'pricing_setup_widgets.dart';

class TeacherCourseScreen extends ConsumerWidget {
  const TeacherCourseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(teacherCoursesProvider);
    final actionState = ref.watch(courseActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: 'Courses',
      subtitle: 'Manage your course library and publishing workflow.',
      showBackButton: true,
      onBack: () => _goBackToDashboard(context),
      scrollable: false,
      actions: [
        IconButton.filledTonal(
          tooltip: 'Refresh courses',
          onPressed: () => ref.invalidate(teacherCoursesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
        FilledButton.icon(
          onPressed: actionState.isLoading
              ? null
              : () => context.pushNamed(RouteNames.teacherCourseCreate),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Course'),
        ),
        FilledButton.tonalIcon(
          onPressed: actionState.isLoading
              ? null
              : () => context.pushNamed(RouteNames.teacherAiCourseBuilder),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('AI Builder'),
        ),
      ],
      child: CoursePremiumBackground(
        child: coursesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load courses',
            message: error.toString(),
          ),
          data: (courses) {
            if (courses.isEmpty) {
              return CoursePremiumMessage(
                icon: Icons.auto_awesome_rounded,
                title: 'Create your first course',
                message:
                    'Start manually or let SkillForge AI draft a course blueprint you can review before saving.',
                actionLabel: 'Create Course with AI',
                onAction: () =>
                    context.pushNamed(RouteNames.teacherAiCourseBuilder),
              );
            }

            return CoursePremiumListView(
              bottomPadding: 96,
              children: [
                CourseHeroHeader(
                  icon: Icons.video_library_rounded,
                  title: 'Course Management',
                  subtitle:
                      'Create, publish, archive, and manage lessons, assignments, and grand tests.',
                  trailing: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 500;
                      return isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: actionState.isLoading
                                      ? null
                                      : () => context.pushNamed(
                                          RouteNames.teacherAiCourseBuilder,
                                        ),
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: const Text('AI Builder'),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: actionState.isLoading
                                      ? null
                                      : () => context.pushNamed(
                                          RouteNames.teacherCourseCreate,
                                        ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Create Course'),
                                ),
                              ],
                            )
                          : Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: actionState.isLoading
                                      ? null
                                      : () => context.pushNamed(
                                          RouteNames.teacherAiCourseBuilder,
                                        ),
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: const Text('AI Builder'),
                                ),
                                FilledButton.icon(
                                  onPressed: actionState.isLoading
                                      ? null
                                      : () => context.pushNamed(
                                          RouteNames.teacherCourseCreate,
                                        ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Create Course'),
                                ),
                              ],
                            );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _CourseAnalyticsGrid(courses: courses),
                const SizedBox(height: 32),
                const CourseSectionTitle(
                  title: 'Your Library',
                  subtitle: 'Manage all the courses you have authored',
                ),
                const SizedBox(height: 16),
                ...courses.map(
                  (course) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _CourseCard(
                      course: course,
                      busy: actionState.isLoading,
                      onEdit: () => context.pushNamed(
                        RouteNames.teacherCourseEdit,
                        pathParameters: {'courseId': course.id},
                      ),
                      onLessons: () => context.pushNamed(
                        RouteNames.teacherCourseLessons,
                        pathParameters: {'courseId': course.id},
                      ),
                      onGrandTests: () => context.pushNamed(
                        RouteNames.teacherGrandTests,
                        pathParameters: {'courseId': course.id},
                      ),
                      onPublish: course.isPublished
                          ? null
                          : () => _publishCourse(context, ref, course),
                      onArchive: course.isArchived
                          ? null
                          : () => _archiveCourse(context, ref, course),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _publishCourse(
    BuildContext context,
    WidgetRef ref,
    CourseModel course,
  ) async {
    final success = await ref
        .read(courseActionProvider.notifier)
        .publishCourse(course.id);
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success: success,
      successMessage: 'Course published.',
      fallbackError: 'Unable to publish course.',
    );
  }

  Future<void> _archiveCourse(
    BuildContext context,
    WidgetRef ref,
    CourseModel course,
  ) async {
    final success = await ref
        .read(courseActionProvider.notifier)
        .archiveCourse(course.id);
    if (!context.mounted) return;
    _showResult(
      context,
      ref,
      success: success,
      successMessage: 'Course archived.',
      fallbackError: 'Unable to archive course.',
    );
  }

  Future<void> _showResult(
    BuildContext context,
    WidgetRef ref, {
    required bool success,
    required String successMessage,
    required String fallbackError,
  }) async {
    final message = success
        ? successMessage
        : ref.read(courseActionProvider.notifier).errorMessage ?? fallbackError;
    if (!success && message.toLowerCase().contains('upgrade')) {
      await showTeacherUpgradeDialog(
        context: context,
        ref: ref,
        message: message,
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class CourseEditorScreen extends ConsumerWidget {
  const CourseEditorScreen({super.key, this.courseId});

  final String? courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = courseId;
    if (id == null || id.isEmpty) {
      return const _CourseEditorScaffold();
    }

    final courseAsync = ref.watch(courseDetailProvider(id));
    return courseAsync.when(
      loading: () => const RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit Course',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => RoleFixedHeaderPage(
        role: UserRole.teacher,
        title: 'Edit Course',
        showBackButton: true,
        onBack: () => _goBackToCourses(context),
        child: _CourseMessage(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load course',
          message: error.toString(),
        ),
      ),
      data: (course) {
        if (course == null) {
          return const RoleFixedHeaderPage(
            role: UserRole.teacher,
            title: 'Course unavailable',
            showBackButton: true,
            child: _CourseMessage(
              icon: Icons.search_off_rounded,
              title: 'Course not found',
              message: 'This course may have been removed or archived.',
            ),
          );
        }
        return _CourseEditorScaffold(course: course);
      },
    );
  }
}

class _CourseEditorScaffold extends ConsumerWidget {
  const _CourseEditorScaffold({this.course});

  final CourseModel? course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = course != null;
    final actionState = ref.watch(courseActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.teacher,
      title: isEditing ? 'Edit Course' : 'Create Course',
      subtitle: 'Configure course details, cover image, skills, and outcomes.',
      showBackButton: true,
      onBack: () => _goBackToCourses(context),
      scrollable: false,
      child: CoursePremiumBackground(
        child: _CourseForm(
          course: course,
          isSubmitting: actionState.isLoading,
          onSubmit: (data) => _save(context, ref, data),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    _CourseFormData data,
  ) async {
    final notifier = ref.read(courseActionProvider.notifier);
    final currentCourse = course;
    final success = currentCourse == null
        ? await notifier.createCourse(
            title: data.title,
            subtitle: data.subtitle,
            description: data.description,
            category: data.category,
            level: data.level,
            language: data.language,
            thumbnailUrl: data.thumbnailUrl,
            skillsCovered: data.skillsCovered,
            tags: data.tags,
            prerequisites: data.prerequisites,
            learningOutcomes: data.learningOutcomes,
            targetAudience: data.targetAudience,
            durationMinutes: data.durationMinutes,
          )
        : await notifier.updateCourse(
            currentCourse.copyWith(
              title: data.title,
              subtitle: data.subtitle,
              description: data.description,
              category: data.category,
              level: data.level,
              language: data.language,
              thumbnailUrl: data.thumbnailUrl,
              clearThumbnailUrl: data.thumbnailUrl == null,
              skillsCovered: data.skillsCovered,
              tags: data.tags,
              prerequisites: data.prerequisites,
              learningOutcomes: data.learningOutcomes,
              targetAudience: data.targetAudience,
              durationMinutes: data.durationMinutes,
            ),
          );

    if (!context.mounted) return;

    final message = success
        ? currentCourse == null
              ? 'Course created.'
              : 'Course updated.'
        : notifier.errorMessage ??
              (currentCourse == null
                  ? 'Unable to create course.'
                  : 'Unable to update course.');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (success) {
      context.goNamed(RouteNames.teacherCourses);
    }
  }
}

void _goBackToDashboard(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.goNamed(RouteNames.teacherDashboard);
}

void _goBackToCourses(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.goNamed(RouteNames.teacherCourses);
}

class _CourseAnalyticsGrid extends StatelessWidget {
  const _CourseAnalyticsGrid({required this.courses});

  final List<CourseModel> courses;

  @override
  Widget build(BuildContext context) {
    final total = courses.length;
    final draft = courses.where((course) => course.isDraft).length;
    final published = courses.where((course) => course.isPublished).length;
    final archived = courses.where((course) => course.isArchived).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final cards = [
          _CourseMetricCard(
            title: 'Total Courses',
            value: total.toString(),
            icon: Icons.menu_book_rounded,
          ),
          _CourseMetricCard(
            title: 'Draft Courses',
            value: draft.toString(),
            icon: Icons.edit_note_rounded,
          ),
          _CourseMetricCard(
            title: 'Published',
            value: published.toString(),
            icon: Icons.published_with_changes_rounded,
            highlightColor: AppColors.success,
          ),
          _CourseMetricCard(
            title: 'Archived',
            value: archived.toString(),
            icon: Icons.archive_rounded,
            highlightColor: AppColors.error,
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(width: 16),
                Expanded(child: cards[index]),
              ],
            ],
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: cards,
        );
      },
    );
  }
}

class _CourseMetricCard extends StatelessWidget {
  const _CourseMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.highlightColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = highlightColor ?? theme.colorScheme.primary;

    return CourseGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.6), size: 20),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.busy,
    required this.onEdit,
    required this.onLessons,
    required this.onGrandTests,
    required this.onPublish,
    required this.onArchive,
  });

  final CourseModel course;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onLessons;
  final VoidCallback onGrandTests;
  final VoidCallback? onPublish;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final createdDate = DateFormat('MMM d, yyyy').format(course.createdAt);

    return CourseGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? AppColors.divider
                          : AppColors.lightDivider,
                    ),
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: course.thumbnailUrl == null
                        ? Icon(
                            Icons.menu_book_rounded,
                            size: 32,
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : Image.network(
                            course.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.broken_image_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              course.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StatusChip(status: course.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Created $createdDate',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(
                            icon: Icons.category_rounded,
                            label: course.category,
                          ),
                          _MetaChip(
                            icon: Icons.signal_cellular_alt_rounded,
                            label: course.level,
                          ),
                          _MetaChip(
                            icon: Icons.schedule_rounded,
                            label: '${course.durationMinutes} min',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.02),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.divider : AppColors.lightDivider,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final actionButtons = [
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onLessons,
                    icon: const Icon(Icons.video_library_rounded),
                    label: const Text('Studio'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit Course'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onGrandTests,
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: const Text('Grand Tests'),
                  ),
                  if (course.isDraft)
                    TextButton.icon(
                      onPressed: busy ? null : onPublish,
                      icon: const Icon(Icons.publish_rounded),
                      label: const Text('Publish'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.success,
                      ),
                    ),
                  if (course.isPublished)
                    TextButton.icon(
                      onPressed: busy ? null : onArchive,
                      icon: const Icon(Icons.archive_rounded),
                      label: const Text('Archive'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                ];
                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: actionButtons
                            .map((button) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: button,
                                ))
                            .toList(),
                      )
                    : Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: actionButtons,
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseForm extends ConsumerStatefulWidget {
  const _CourseForm({this.course, this.onSubmit, this.isSubmitting = false});

  final CourseModel? course;
  final ValueChanged<_CourseFormData>? onSubmit;
  final bool isSubmitting;

  @override
  ConsumerState<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends ConsumerState<_CourseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _levelController;
  late final TextEditingController _languageController;
  late final TextEditingController _skillsController;
  late final TextEditingController _tagsController;
  late final TextEditingController _prerequisitesController;
  late final TextEditingController _outcomesController;
  late final TextEditingController _audienceController;
  late final TextEditingController _durationController;
  String? _thumbnailUrl;
  String? _uploadError;
  bool _isUploadingCover = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _titleController = TextEditingController(text: course?.title ?? '');
    _subtitleController = TextEditingController(text: course?.subtitle ?? '');
    _descriptionController = TextEditingController(
      text: course?.description ?? '',
    );
    _categoryController = TextEditingController(text: course?.category ?? '');
    _levelController = TextEditingController(text: course?.level ?? 'Beginner');
    _languageController = TextEditingController(
      text: course?.language ?? 'English',
    );
    _skillsController = TextEditingController(
      text: course?.skillsCovered.join(', ') ?? '',
    );
    _tagsController = TextEditingController(
      text: course?.tags.join(', ') ?? '',
    );
    _prerequisitesController = TextEditingController(
      text: course?.prerequisites.join(', ') ?? '',
    );
    _outcomesController = TextEditingController(
      text: course?.learningOutcomes.join('\n') ?? '',
    );
    _audienceController = TextEditingController(
      text: course?.targetAudience.join('\n') ?? '',
    );
    _durationController = TextEditingController(
      text: course == null || course.durationMinutes == 0
          ? ''
          : course.durationMinutes.toString(),
    );
    _thumbnailUrl = course?.thumbnailUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _levelController.dispose();
    _languageController.dispose();
    _skillsController.dispose();
    _tagsController.dispose();
    _prerequisitesController.dispose();
    _outcomesController.dispose();
    _audienceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    return UnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges && !widget.isSubmitting,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
        child: Form(
          key: _formKey,
          onChanged: _markDirty,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.course == null ? 'Create Course' : 'Edit Course',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 24),
                _CourseFormSection(
                  title: 'Section 1',
                  subtitle: 'Course essentials',
                  children: [
                    CoursePremiumTextField(
                      controller: _titleController,
                      label: 'Course Title',
                      hintText: 'e.g. Master Flutter UI Design',
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    CoursePremiumTextField(
                      controller: _subtitleController,
                      label: 'Subtitle',
                      hintText: 'A catchy one-liner describing the course',
                    ),
                    const SizedBox(height: 16),
                    CoursePremiumTextField(
                      controller: _descriptionController,
                      label: 'Detailed Description',
                      hintText: 'What will students learn in this course?',
                      minLines: 4,
                      maxLines: 8,
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 500;
                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(
                                child: CoursePremiumTextField(
                                  controller: _categoryController,
                                  label: 'Category',
                                  hintText: 'e.g. Mobile Dev',
                                  validator: _required,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CoursePremiumTextField(
                                  controller: _levelController,
                                  label: 'Difficulty Level',
                                  hintText: 'Beginner, Intermediate...',
                                  validator: _required,
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            CoursePremiumTextField(
                              controller: _categoryController,
                              label: 'Category',
                              hintText: 'e.g. Mobile Dev',
                              validator: _required,
                            ),
                            const SizedBox(height: 16),
                            CoursePremiumTextField(
                              controller: _levelController,
                              label: 'Difficulty Level',
                              hintText: 'Beginner, Intermediate...',
                              validator: _required,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 500;
                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(
                                child: CoursePremiumTextField(
                                  controller: _languageController,
                                  label: 'Language',
                                  validator: _required,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CoursePremiumTextField(
                                  controller: _durationController,
                                  label: 'Duration (minutes)',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) return 'Required';
                                    final minutes = int.tryParse(text);
                                    if (minutes == null || minutes < 0) {
                                      return 'Invalid duration';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            CoursePremiumTextField(
                              controller: _languageController,
                              label: 'Language',
                              validator: _required,
                            ),
                            const SizedBox(height: 16),
                            CoursePremiumTextField(
                              controller: _durationController,
                              label: 'Duration (minutes)',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) return 'Required';
                                final minutes = int.tryParse(text);
                                if (minutes == null || minutes < 0) {
                                  return 'Invalid duration';
                                }
                                return null;
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _CourseFormSection(
                  title: 'Section 2',
                  subtitle: 'Course cover image',
                  children: [
                    _CoverImagePicker(
                      imageUrl: _thumbnailUrl,
                      isUploading: _isUploadingCover,
                      errorMessage: _uploadError,
                      onUpload: _pickAndUploadCover,
                      onRemove: _thumbnailUrl == null
                          ? null
                          : () => setState(() => _thumbnailUrl = null),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _CourseFormSection(
                  title: 'Section 3',
                  subtitle: 'Skills, tags, and prerequisites',
                  children: [
                    CoursePremiumTextField(
                      controller: _skillsController,
                      label: 'Skills Covered',
                      hintText:
                          'Comma separated e.g. Flutter, Firebase, UI Design',
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    CoursePremiumTextField(
                      controller: _tagsController,
                      label: 'Search Tags',
                      hintText:
                          'Comma separated e.g. mobile, beginner, portfolio',
                    ),
                    const SizedBox(height: 16),
                    CoursePremiumTextField(
                      controller: _prerequisitesController,
                      label: 'Prerequisites',
                      hintText: 'Comma separated e.g. Basic Dart, Mac or PC',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _CourseFormSection(
                  title: 'Section 4',
                  subtitle: 'Outcomes and audience',
                  children: [
                    CoursePremiumTextField(
                      controller: _outcomesController,
                      label: 'Learning Outcomes',
                      hintText: 'Write each outcome on a new line',
                      minLines: 4,
                      maxLines: 6,
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    CoursePremiumTextField(
                      controller: _audienceController,
                      label: 'Target Audience',
                      hintText: 'Write each audience type on a new line',
                      minLines: 3,
                      maxLines: 6,
                      validator: _required,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _CourseFormSection(
                  title: 'Section 5',
                  subtitle: 'Status workflow',
                  children: [
                    Text(
                      'Courses are saved as drafts first. Use Publish from your course list when students should see it, or Archive when it should be hidden from students.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _StatusChip(status: CourseStatus.draft),
                        _StatusChip(status: CourseStatus.published),
                        _StatusChip(status: CourseStatus.archived),
                      ],
                    ),
                  ],
                ),
                if (widget.course != null) ...[
                  const SizedBox(height: 24),
                  _CourseFormSection(
                    title: 'Section 6',
                    subtitle: 'Marketplace pricing',
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final teacherId = widget.course!.teacherId;
                          final accessAsync = ref.watch(
                            teacherSubscriptionAccessProvider(teacherId),
                          );
                          final isPremium =
                              accessAsync.value?.allowPaidCourses ?? false;
                          return TeacherPricingCard(
                            courseId: widget.course!.id,
                            isPremiumTeacher: isPremium,
                            onEditPressed: () {
                              if (!isPremium) {
                                showTeacherUpgradeDialog(
                                  context: context,
                                  ref: ref,
                                  title: 'Unlock paid courses',
                                  message:
                                      'Paid course pricing requires a Pro teaching plan.',
                                );
                                return;
                              }
                              final config =
                                  ref.read(paidCourseConfigProvider(widget.course!.id)).value;
                              showDialog(
                                context: context,
                                builder: (_) => PricingSetupDialog(
                                  courseId: widget.course!.id,
                                  currentConfig: config,
                                  teacherId: teacherId,
                                  onSuccess: () {
                                    ref.invalidate(
                                      paidCourseConfigProvider(widget.course!.id),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: widget.isSubmitting || _isUploadingCover
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  icon: widget.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    widget.isSubmitting
                        ? 'Saving changes...'
                        : widget.course == null
                        ? 'Create Course'
                        : 'Save Changes',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _markDirty() {
    if (_hasUnsavedChanges) return;
    setState(() => _hasUnsavedChanges = true);
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  List<String> _commaList(TextEditingController controller) {
    return controller.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _lineList(TextEditingController controller) {
    return controller.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _pickAndUploadCover() async {
    if (_isUploadingCover) return;
    setState(() {
      _isUploadingCover = true;
      _uploadError = null;
    });

    try {
      final service = ref.read(cloudinaryServiceProvider);
      final image = await service.pickImageFromGallery();
      if (!mounted) return;
      if (image == null) {
        setState(() => _isUploadingCover = false);
        return;
      }

      final url = await service.uploadProfileImage(image);
      if (!mounted) return;
      setState(() {
        _thumbnailUrl = url;
        _isUploadingCover = false;
        _hasUnsavedChanges = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadError = error.toString();
        _isUploadingCover = false;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _hasUnsavedChanges = false);
    final data = _CourseFormData(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categoryController.text.trim(),
      level: _levelController.text.trim(),
      language: _languageController.text.trim(),
      thumbnailUrl: _thumbnailUrl,
      skillsCovered: _commaList(_skillsController),
      tags: _commaList(_tagsController),
      prerequisites: _commaList(_prerequisitesController),
      learningOutcomes: _lineList(_outcomesController),
      targetAudience: _lineList(_audienceController),
      durationMinutes: int.parse(_durationController.text.trim()),
    );
    final onSubmit = widget.onSubmit;
    if (onSubmit != null) {
      onSubmit(data);
      return;
    }
    Navigator.of(context).pop(data);
  }
}

class _CourseFormData {
  const _CourseFormData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.level,
    required this.language,
    required this.thumbnailUrl,
    required this.skillsCovered,
    required this.tags,
    required this.prerequisites,
    required this.learningOutcomes,
    required this.targetAudience,
    required this.durationMinutes,
  });

  final String title;
  final String subtitle;
  final String description;
  final String category;
  final String level;
  final String language;
  final String? thumbnailUrl;
  final List<String> skillsCovered;
  final List<String> tags;
  final List<String> prerequisites;
  final List<String> learningOutcomes;
  final List<String> targetAudience;
  final int durationMinutes;
}

class _CourseFormSection extends StatelessWidget {
  const _CourseFormSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourseGlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _CoverImagePicker extends StatelessWidget {
  const _CoverImagePicker({
    required this.imageUrl,
    required this.isUploading,
    required this.errorMessage,
    required this.onUpload,
    required this.onRemove,
  });

  final String? imageUrl;
  final bool isUploading;
  final String? errorMessage;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.divider : AppColors.lightDivider,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: hasImage
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _CoverPlaceholder(isUploading: isUploading),
                    )
                  : _CoverPlaceholder(isUploading: isUploading),
            ),
          ),
        ),
        if (errorMessage != null && errorMessage!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: isUploading ? null : onUpload,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: isUploading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  isUploading ? 'Uploading cover...' : 'Upload Cover Image',
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: isUploading ? null : onRemove,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.isUploading});

  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUploading)
            const CircularProgressIndicator()
          else
            Icon(
              Icons.add_photo_alternate_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          const SizedBox(height: 12),
          Text(
            isUploading
                ? 'Uploading securely to cloud...'
                : 'No cover image selected',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final lmsStatus = switch (status) {
      CourseStatus.published => LmsStatus.completed,
      CourseStatus.archived => LmsStatus.failed,
      _ => LmsStatus.pending,
    };
    return LmsStatusBadge(status: lmsStatus, text: status);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label.isEmpty ? 'Not set' : label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseMessage extends StatelessWidget {
  const _CourseMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
