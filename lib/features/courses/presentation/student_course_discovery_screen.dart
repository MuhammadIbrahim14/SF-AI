import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../models/student_model.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/course_model.dart';
import '../providers/course_provider.dart';
import 'course_premium_widgets.dart';

class StudentCourseDiscoveryScreen extends ConsumerStatefulWidget {
  const StudentCourseDiscoveryScreen({super.key});

  @override
  ConsumerState<StudentCourseDiscoveryScreen> createState() =>
      _StudentCourseDiscoveryScreenState();
}

class _StudentCourseDiscoveryScreenState
    extends ConsumerState<StudentCourseDiscoveryScreen> {
  final _searchController = TextEditingController();
  String _categoryFilter = 'All';
  String _difficultyFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(publishedCoursesProvider);
    final student = ref.watch(studentProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Course Marketplace',
      subtitle: 'Discover published courses matched to your goals and skills.',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.goNamed(RouteNames.studentDashboard);
      },
      scrollable: false,
      child: CoursePremiumBackground(
        child: coursesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Marketplace offline',
            message: error.toString(),
            actionLabel: 'Retry connection',
            onAction: () => ref.invalidate(publishedCoursesProvider),
          ),
          data: (courses) {
            final categories = _filterValues(courses.map((c) => c.category));
            final difficulties = _filterValues(courses.map((c) => c.level));
            final filteredCourses = _filteredCourses(courses);
            final recommendedCourses = _recommendedCourses(
              filteredCourses,
              student,
            );

            final fullWidth = MediaQuery.sizeOf(context).width;
            final baseHorizontal = CourseBreakpoints.isMobile(fullWidth)
                ? 16.0
                : CourseBreakpoints.isTablet(fullWidth)
                ? 24.0
                : 32.0;
            final extraPadding = fullWidth > 1280
                ? (fullWidth - 1280) / 2
                : 0.0;
            final horizontalPadding = baseHorizontal + extraPadding;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(publishedCoursesProvider);
              },
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        CourseHeroHeader(
                          icon: Icons.storefront_rounded,
                          title: 'Course Marketplace',
                          subtitle:
                              'Discover premium content crafted to accelerate your career.',
                          trailing: FilledButton.tonalIcon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reset filters'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SaaS Style Search & Filter Bar
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.05,
                                ),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  hintText:
                                      'Search by title, skills, or keywords...',
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 640;
                                  final filters = [
                                    Expanded(
                                      child: _CourseFilterDropdown(
                                        label: 'Category',
                                        value: _categoryFilter,
                                        values: categories,
                                        icon: Icons.category_rounded,
                                        onChanged: (value) => setState(
                                          () => _categoryFilter = value,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _CourseFilterDropdown(
                                        label: 'Difficulty',
                                        value: _difficultyFilter,
                                        values: difficulties,
                                        icon: Icons.signal_cellular_alt_rounded,
                                        onChanged: (value) => setState(
                                          () => _difficultyFilter = value,
                                        ),
                                      ),
                                    ),
                                  ];

                                  if (isWide) {
                                    return Row(
                                      children: [
                                        filters.first,
                                        const SizedBox(width: 16),
                                        filters.last,
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      filters.first,
                                      const SizedBox(height: 12),
                                      filters.last,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (courses.isEmpty)
                          const CoursePremiumMessage(
                            icon: Icons.inventory_2_outlined,
                            title: 'Catalog is empty',
                            message:
                                'Instructors are currently preparing new courses.',
                          )
                        else if (filteredCourses.isEmpty)
                          CoursePremiumMessage(
                            icon: Icons.search_off_rounded,
                            title: 'No exact matches',
                            message:
                                'Try tweaking your search terms or expanding your filters.',
                            actionLabel: 'Clear all filters',
                            onAction: _clearFilters,
                          )
                        else ...[
                          if (recommendedCourses.isNotEmpty &&
                              _searchController.text.isEmpty) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppColors.accent,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Top Picks For You',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      Text(
                                        'Curated based on your goals and current skills.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ]),
                    ),
                  ),
                  if (courses.isNotEmpty &&
                      filteredCourses.isNotEmpty &&
                      recommendedCourses.isNotEmpty &&
                      _searchController.text.isEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: _CourseSliverGrid(
                        itemCount: recommendedCourses.length,
                        itemBuilder: (context, index) {
                          final match = recommendedCourses[index];
                          return _StudentCourseCard(
                            course: match.course,
                            recommendationReason: match.reason,
                          );
                        },
                      ),
                    ),
                  if (courses.isNotEmpty && filteredCourses.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (recommendedCourses.isNotEmpty &&
                              _searchController.text.isEmpty)
                            const SizedBox(height: 48),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.grid_view_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Explore Catalog',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    Text(
                                      'Browse all published courses to expand your knowledge.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ]),
                      ),
                    ),
                  if (courses.isNotEmpty && filteredCourses.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        96,
                      ),
                      sliver: _CourseSliverGrid(
                        itemCount: filteredCourses.length,
                        itemBuilder: (context, index) =>
                            _StudentCourseCard(course: filteredCourses[index]),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<CourseModel> _filteredCourses(List<CourseModel> courses) {
    final query = _searchController.text.trim().toLowerCase();
    return courses.where((course) {
      final matchesCategory =
          _categoryFilter == 'All' || course.category == _categoryFilter;
      final matchesDifficulty =
          _difficultyFilter == 'All' || course.level == _difficultyFilter;
      final matchesSearch =
          query.isEmpty ||
          course.title.toLowerCase().contains(query) ||
          course.skillsCovered.any(
            (skill) => skill.toLowerCase().contains(query),
          );
      return course.isPublished &&
          matchesCategory &&
          matchesDifficulty &&
          matchesSearch;
    }).toList();
  }

  List<_RecommendedCourse> _recommendedCourses(
    List<CourseModel> courses,
    StudentModel? student,
  ) {
    if (student == null) return const <_RecommendedCourse>[];

    final matches = <_RecommendedCourse>[];
    for (final course in courses) {
      final reason = _recommendationReason(course, student);
      if (reason != null) {
        matches.add(_RecommendedCourse(course: course, reason: reason));
      }
    }
    return matches;
  }

  String? _recommendationReason(CourseModel course, StudentModel student) {
    final courseSkills = course.skillsCovered.map(_normalize).toList();
    final searchableCourseText = [
      course.title,
      course.subtitle,
      course.description,
      course.category,
      course.level,
      ...course.tags,
      ...course.skillsCovered,
    ].map(_normalize).where((value) => value.isNotEmpty).join(' ');

    final interestedSkill = _firstMatchingTerm(
      student.interestedSkills,
      courseSkills,
    );
    if (interestedSkill != null) {
      return 'Matches your $interestedSkill interest';
    }

    final existingSkill = _firstMatchingTerm(student.skills, courseSkills);
    if (existingSkill != null) {
      return 'Builds on your $existingSkill skill';
    }

    final careerGoalKeyword = _firstTextKeywordMatch(
      student.careerGoal,
      searchableCourseText,
    );
    if (careerGoalKeyword != null) {
      return 'Supports your $careerGoalKeyword goal';
    }

    final fieldKeyword = _firstTextKeywordMatch(
      student.fieldOfStudy,
      searchableCourseText,
    );
    if (fieldKeyword != null) {
      return 'Fits your $fieldKeyword studies';
    }

    return null;
  }

  String? _firstMatchingTerm(
    List<String> studentTerms,
    List<String> courseTerms,
  ) {
    for (final rawTerm in studentTerms) {
      final term = _normalize(rawTerm);
      if (term.isEmpty) continue;
      final matched = courseTerms.any(
        (courseTerm) => courseTerm.contains(term) || term.contains(courseTerm),
      );
      if (matched) return rawTerm.trim();
    }
    return null;
  }

  String? _firstTextKeywordMatch(String text, String searchableCourseText) {
    final keywords = _keywords(text);
    for (final keyword in keywords) {
      if (searchableCourseText.contains(keyword)) return keyword;
    }
    return null;
  }

  List<String> _keywords(String value) {
    return _normalize(value)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 3)
        .toSet()
        .toList();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  List<String> _filterValues(Iterable<String> values) {
    final normalized =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...normalized];
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _categoryFilter = 'All';
      _difficultyFilter = 'All';
    });
  }
}

class _CourseSliverGrid extends StatelessWidget {
  const _CourseSliverGrid({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final crossAxisCount = width >= 1100
            ? 3
            : width >= 700
            ? 2
            : 1;

        final childAspectRatio = crossAxisCount == 1 ? 0.90 : 0.72;

        return SliverGrid.builder(
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 32,
            crossAxisSpacing: 32,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

class _StudentCourseCard extends StatefulWidget {
  const _StudentCourseCard({required this.course, this.recommendationReason});

  final CourseModel course;
  final String? recommendationReason;

  @override
  State<_StudentCourseCard> createState() => _StudentCourseCardState();
}

class _StudentCourseCardState extends State<_StudentCourseCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final course = widget.course;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
        child: GestureDetector(
          onTap: () => context.pushNamed(
            RouteNames.studentCourseDetail,
            pathParameters: {'courseId': course.id},
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161618) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: _isHovered ? 2 : 1,
              ),
              boxShadow: [
                if (_isHovered)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Premium Image Header
                  Expanded(
                    flex: 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        course.thumbnailUrl == null
                            ? ColoredBox(
                                color: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade100,
                                child: Icon(
                                  Icons.layers_rounded,
                                  size: 64,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.3),
                                ),
                              )
                            : AnimatedScale(
                                scale: _isHovered ? 1.05 : 1.0,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                child: Image.network(
                                  course.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => ColoredBox(
                                    color: isDark
                                        ? Colors.grey.shade900
                                        : Colors.grey.shade100,
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      size: 64,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                              ),
                        // Gradient Overlay for text visibility
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                        // Top Badges
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.signal_cellular_alt_rounded,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  course.level.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.recommendationReason != null &&
                            widget.recommendationReason!.trim().isNotEmpty)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: _RecommendationBadge(
                              label: widget.recommendationReason!,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Content Area
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  course.category.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            course.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              course.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isDark
                                    ? Colors.white10
                                    : Colors.black12,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Created by',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      course.teacherName.trim().isEmpty ||
                                              course.teacherName
                                                      .trim()
                                                      .toLowerCase() ==
                                                  'teacher'
                                          ? 'Verified Expert'
                                          : course.teacherName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _isHovered
                                      ? AppColors.primary
                                      : AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: _isHovered
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationBadge extends StatelessWidget {
  const _RecommendationBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseFilterDropdown extends StatelessWidget {
  const _CourseFilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : 'All',
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _RecommendedCourse {
  const _RecommendedCourse({required this.course, required this.reason});

  final CourseModel course;
  final String reason;
}
