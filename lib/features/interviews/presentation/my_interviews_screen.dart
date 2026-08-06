import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/interview_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/interview_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class MyInterviewsScreen extends ConsumerWidget {
  const MyInterviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.freelancer;
    final interviewsAsync = currentRole == UserRole.company
        ? ref.watch(companyInterviewsProvider)
        : ref.watch(myInterviewsProvider);

    return RoleFixedHeaderPage(
      role: currentRole,
      title: 'Interview Command Center',
      subtitle: currentRole == UserRole.company
          ? 'Track today, upcoming interviews, pending feedback, and hiring decisions.'
          : 'Track your interview schedule, results, and preparation timeline.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(_dashboardRouteFor(currentRole)),
      scrollable: false,
      child: ColoredBox(
        color: Colors.transparent,
        child: interviewsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (interviews) {
            final state = _InterviewCommandState.from(interviews);
            if (interviews.isEmpty) {
              return _InterviewEmptyState(role: currentRole);
            }

            return RefreshIndicator(
              onRefresh: () async {
                if (currentRole == UserRole.company) {
                  ref.invalidate(companyInterviewsProvider);
                } else {
                  ref.invalidate(myInterviewsProvider);
                }
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                children: [
                  if (currentRole != UserRole.company)
                    const _PendingOfferBanner(),
                  _InterviewHero(state: state, role: currentRole),
                  const SizedBox(height: 20),
                  _InterviewMetricsGrid(state: state, role: currentRole),
                  const SizedBox(height: 28),
                  if (state.today.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.today_rounded,
                      title: "Today's Interviews",
                      subtitle: 'Interviews scheduled for today.',
                      color: _accentFor(currentRole),
                    ),
                    const SizedBox(height: 14),
                    ...state.today.map(
                      (interview) => _CommandInterviewCard(
                        interview: interview,
                        role: currentRole,
                        priority: _InterviewPriority.today,
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                  _SectionTitle(
                    icon: Icons.warning_amber_rounded,
                    title: 'Pending Evaluations',
                    subtitle:
                        'Past interviews that still need recruiter feedback.',
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 14),
                  if (state.pendingEvaluations.isEmpty)
                    const _SoftEmptyPanel(
                      icon: Icons.fact_check_outlined,
                      title: 'No feedback pending',
                      message:
                          'Completed or overdue interviews needing evaluation will appear here.',
                    )
                  else
                    ...state.pendingEvaluations.map(
                      (interview) => _CommandInterviewCard(
                        interview: interview,
                        role: currentRole,
                        priority: _InterviewPriority.evaluation,
                      ),
                    ),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    icon: Icons.upcoming_rounded,
                    title: 'Upcoming Timeline',
                    subtitle: 'Future interviews beyond today.',
                    color: AppColors.info,
                  ),
                  const SizedBox(height: 14),
                  if (state.upcoming.isEmpty)
                    const _SoftEmptyPanel(
                      icon: Icons.event_available_outlined,
                      title: 'No upcoming interviews',
                      message:
                          'Scheduled interviews will appear in this queue.',
                    )
                  else
                    ...state.upcoming.map(
                      (interview) => _CommandInterviewCard(
                        interview: interview,
                        role: currentRole,
                        priority: _InterviewPriority.upcoming,
                      ),
                    ),
                  const SizedBox(height: 28),
                  _InterviewRecommendations(state: state, role: currentRole),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    icon: Icons.timeline_rounded,
                    title: 'Candidate Timeline',
                    subtitle:
                        'Scheduled, completed, cancelled, evaluation, and decision events.',
                    color: AppColors.companyPrimary,
                  ),
                  const SizedBox(height: 14),
                  _InterviewTimeline(state: state, role: currentRole),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    icon: Icons.history_rounded,
                    title: 'Completed & Cancelled',
                    subtitle: 'Historical interview outcomes.',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 14),
                  if (state.history.isEmpty)
                    const _SoftEmptyPanel(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'No interview history yet',
                      message:
                          'Completed and cancelled interviews will be archived here.',
                    )
                  else
                    ...state.history.map(
                      (interview) => _CommandInterviewCard(
                        interview: interview,
                        role: currentRole,
                        priority: _InterviewPriority.history,
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _dashboardRouteFor(UserRole role) {
  return switch (role) {
    UserRole.student => RouteNames.studentDashboard,
    UserRole.freelancer => RouteNames.freelancerDashboard,
    UserRole.company => RouteNames.companyDashboard,
    UserRole.teacher => RouteNames.teacherDashboard,
    UserRole.admin => RouteNames.adminDashboard,
    UserRole.superAdmin => RouteNames.superAdminDashboard,
  };
}

class _InterviewCommandState {
  const _InterviewCommandState({
    required this.all,
    required this.today,
    required this.upcoming,
    required this.pendingEvaluations,
    required this.completed,
    required this.cancelled,
    required this.history,
  });

  final List<InterviewModel> all;
  final List<InterviewModel> today;
  final List<InterviewModel> upcoming;
  final List<InterviewModel> pendingEvaluations;
  final List<InterviewModel> completed;
  final List<InterviewModel> cancelled;
  final List<InterviewModel> history;

  factory _InterviewCommandState.from(List<InterviewModel> interviews) {
    final now = DateTime.now();
    final today =
        interviews
            .where(
              (interview) =>
                  interview.isScheduled &&
                  _isSameDay(interview.scheduledAt, now),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final upcoming =
        interviews
            .where(
              (interview) =>
                  interview.isScheduled &&
                  interview.scheduledAt.isAfter(_endOfDay(now)),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final pendingEvaluations = interviews.where((interview) {
      if (interview.status == 'completed' && interview.result == 'pending') {
        return true;
      }
      return interview.isScheduled && interview.scheduledAt.isBefore(now);
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final completed =
        interviews
            .where((interview) => interview.status == 'completed')
            .toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    final cancelled =
        interviews
            .where((interview) => interview.status == 'cancelled')
            .toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    final history =
        interviews.where((interview) => !interview.isScheduled).toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    final all = [...interviews]
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return _InterviewCommandState(
      all: all,
      today: today,
      upcoming: upcoming,
      pendingEvaluations: pendingEvaluations,
      completed: completed,
      cancelled: cancelled,
      history: history,
    );
  }

  int get scheduled => all.where((interview) => interview.isScheduled).length;
}

class _InterviewHero extends StatelessWidget {
  const _InterviewHero({required this.state, required this.role});

  final _InterviewCommandState state;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(role);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(context, accent),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.video_camera_front_rounded,
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role == UserRole.company
                      ? 'Recruiter Interview Operations'
                      : 'Your Interview Workspace',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _heroMessage(state),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
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

class _InterviewMetricsGrid extends StatelessWidget {
  const _InterviewMetricsGrid({required this.state, required this.role});

  final _InterviewCommandState state;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      mobileColumns: 2,
      tabletColumns: 3,
      desktopColumns: 5,
      wideColumns: 5,
      minChildWidth: 160,
      children: [
        _MetricTile(
          label: 'Today',
          value: state.today.length.toString(),
          icon: Icons.today_rounded,
          color: _accentFor(role),
        ),
        _MetricTile(
          label: 'Upcoming',
          value: state.upcoming.length.toString(),
          icon: Icons.upcoming_rounded,
          color: AppColors.info,
        ),
        _MetricTile(
          label: 'Pending Eval',
          value: state.pendingEvaluations.length.toString(),
          icon: Icons.rate_review_rounded,
          color: AppColors.warning,
        ),
        _MetricTile(
          label: 'Completed',
          value: state.completed.length.toString(),
          icon: Icons.fact_check_rounded,
          color: AppColors.success,
        ),
        _MetricTile(
          label: 'Cancelled',
          value: state.cancelled.length.toString(),
          icon: Icons.event_busy_rounded,
          color: AppColors.error,
        ),
      ],
    );
  }
}

class _CommandInterviewCard extends StatelessWidget {
  const _CommandInterviewCard({
    required this.interview,
    required this.role,
    required this.priority,
  });

  final InterviewModel interview;
  final UserRole role;
  final _InterviewPriority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(interview);
    final isCompany = role == UserRole.company;
    final isEvaluationPending = _needsEvaluation(interview);
    final time = DateFormat.jm().format(interview.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _panelDecoration(context, statusColor),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushNamed(
            RouteNames.myInterviewDetail,
            pathParameters: {'interviewId': interview.interviewId},
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CalendarBlock(interview: interview, color: statusColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_label(interview.interviewMode)} Interview',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusPill(
                                label: _label(interview.status),
                                color: statusColor,
                              ),
                              _StatusPill(
                                label:
                                    '$time - ${interview.durationMinutes} min',
                                color: AppColors.info,
                              ),
                              if (isEvaluationPending)
                                const _StatusPill(
                                  label: 'Evaluation Pending',
                                  color: AppColors.warning,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InterviewMiniTimeline(interview: interview),
                if (interview.interviewerNotes.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _NotesPanel(text: interview.interviewerNotes),
                ],
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 500;
                    return isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => context.pushNamed(
                                  RouteNames.myInterviewDetail,
                                  pathParameters: {
                                    'interviewId': interview.interviewId,
                                  },
                                ),
                                icon: const Icon(Icons.visibility_rounded),
                                label: const Text('View Details'),
                              ),
                              if (isCompany &&
                                  (isEvaluationPending ||
                                      interview.isCompleted)) ...[
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  onPressed: () => context.pushNamed(
                                    RouteNames.evaluateInterview,
                                    pathParameters: {
                                      'interviewId': interview.interviewId,
                                    },
                                  ),
                                  icon: const Icon(Icons.fact_check_rounded),
                                  label: Text(
                                    interview.isCompleted
                                        ? 'Update Evaluation'
                                        : 'Evaluate',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        AppColors.companyPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => context.pushNamed(
                                  RouteNames.myInterviewDetail,
                                  pathParameters: {
                                    'interviewId': interview.interviewId,
                                  },
                                ),
                                icon: const Icon(Icons.visibility_rounded),
                                label: const Text('View Details'),
                              ),
                              if (isCompany &&
                                  (isEvaluationPending ||
                                      interview.isCompleted))
                                FilledButton.icon(
                                  onPressed: () => context.pushNamed(
                                    RouteNames.evaluateInterview,
                                    pathParameters: {
                                      'interviewId': interview.interviewId,
                                    },
                                  ),
                                  icon: const Icon(Icons.fact_check_rounded),
                                  label: Text(
                                    interview.isCompleted
                                        ? 'Update Evaluation'
                                        : 'Evaluate',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        AppColors.companyPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          );
                  },
                ),
                if (priority == _InterviewPriority.evaluation) ...[
                  const SizedBox(height: 12),
                  Text(
                    _evaluationRecommendation(interview),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InterviewRecommendations extends StatelessWidget {
  const _InterviewRecommendations({required this.state, required this.role});

  final _InterviewCommandState state;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final recommendations = _recommendations(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.psychology_alt_rounded,
          title: 'Recommendations',
          subtitle:
              'Rule-based interview guidance from existing interview data.',
          color: _accentFor(role),
        ),
        const SizedBox(height: 14),
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          wideColumns: 2,
          minChildWidth: 300,
          children: [
            for (final recommendation in recommendations)
              _RecommendationTile(
                text: recommendation,
                color: _accentFor(role),
              ),
          ],
        ),
      ],
    );
  }
}

class _InterviewTimeline extends StatelessWidget {
  const _InterviewTimeline({required this.state, required this.role});

  final _InterviewCommandState state;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final items = state.all.take(8).toList();
    if (items.isEmpty) {
      return const _SoftEmptyPanel(
        icon: Icons.timeline_rounded,
        title: 'No timeline yet',
        message: 'Interview activity appears here after scheduling starts.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context, _accentFor(role)),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++)
            _TimelineItem(
              interview: items[index],
              isLast: index == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.interview, required this.isLast});

  final InterviewModel interview;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(interview);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 58,
                color: color.withValues(alpha: 0.22),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_label(interview.status)} - ${_label(interview.interviewMode)} Interview',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMd().add_jm().format(interview.scheduledAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (interview.result != 'pending') ...[
                  const SizedBox(height: 6),
                  _StatusPill(
                    label: 'Decision: ${_label(interview.result)}',
                    color: _resultColor(interview.result),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InterviewMiniTimeline extends StatelessWidget {
  const _InterviewMiniTimeline({required this.interview});

  final InterviewModel interview;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        'Upcoming',
        interview.isScheduled && interview.scheduledAt.isAfter(DateTime.now()),
      ),
      ('Completed', interview.status == 'completed'),
      ('Cancelled', interview.status == 'cancelled'),
      ('Evaluation', interview.finalScore > 0 || interview.result != 'pending'),
      ('Decision', interview.result != 'pending'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final step in steps)
          _StatusPill(
            label: step.$1,
            color: step.$2
                ? AppColors.companyPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context, color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarBlock extends StatelessWidget {
  const _CalendarBlock({required this.interview, required this.color});

  final InterviewModel interview;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Text(
              DateFormat('MMM').format(interview.scheduledAt).toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 10,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              DateFormat('dd').format(interview.scheduledAt),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context, color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.companyPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.companyPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            color: AppColors.companyPrimary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftEmptyPanel extends StatelessWidget {
  const _SoftEmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(
        context,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterviewEmptyState extends StatelessWidget {
  const _InterviewEmptyState({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(role);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          decoration: _panelDecoration(context, accent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 54,
                  color: accent,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                role == UserRole.company
                    ? 'No interviews scheduled yet'
                    : 'No upcoming interviews',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                role == UserRole.company
                    ? 'Schedule interviews from shortlisted applicants to start building your interview command center.'
                    : 'When a company schedules an interview, it will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

enum _InterviewPriority { today, upcoming, evaluation, history }

List<String> _recommendations(_InterviewCommandState state) {
  final recommendations = <String>[];
  if (state.pendingEvaluations.isNotEmpty) {
    recommendations.add(
      '${state.pendingEvaluations.length} interview feedback ${state.pendingEvaluations.length == 1 ? 'is' : 'are'} pending.',
    );
  }
  if (state.today.isNotEmpty) {
    recommendations.add(
      '${state.today.length} interview ${state.today.length == 1 ? 'is' : 'are'} scheduled today. Prepare notes before the session.',
    );
  }
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final tomorrowCount = state.upcoming
      .where((interview) => _isSameDay(interview.scheduledAt, tomorrow))
      .length;
  if (tomorrowCount > 0) {
    recommendations.add(
      '$tomorrowCount interview ${tomorrowCount == 1 ? 'is' : 'are'} scheduled tomorrow.',
    );
  }
  final overdue = state.pendingEvaluations
      .where(
        (interview) =>
            DateTime.now().difference(interview.scheduledAt).inDays >= 1,
      )
      .length;
  if (overdue > 0) {
    recommendations.add(
      '$overdue evaluation ${overdue == 1 ? 'is' : 'are'} overdue. Complete feedback to keep hiring decisions fresh.',
    );
  }
  if (state.completed.isNotEmpty && state.pendingEvaluations.isEmpty) {
    recommendations.add(
      'Completed interviews are evaluated. Keep the hiring timeline moving.',
    );
  }
  if (recommendations.isEmpty) {
    recommendations.add('No urgent interview actions right now.');
  }
  return recommendations.take(5).toList();
}

String _heroMessage(_InterviewCommandState state) {
  if (state.pendingEvaluations.isNotEmpty) {
    return 'Feedback is pending for ${state.pendingEvaluations.length} interview${state.pendingEvaluations.length == 1 ? '' : 's'}.';
  }
  if (state.today.isNotEmpty) {
    return 'You have ${state.today.length} interview${state.today.length == 1 ? '' : 's'} scheduled today.';
  }
  if (state.upcoming.isNotEmpty) {
    return 'Next interview: ${DateFormat.yMMMd().add_jm().format(state.upcoming.first.scheduledAt)}.';
  }
  return 'Interview operations are calm right now.';
}

String _evaluationRecommendation(InterviewModel interview) {
  if (interview.scheduledAt.isBefore(DateTime.now())) {
    return 'Evaluation overdue. Record feedback and move the candidate to a decision stage.';
  }
  return 'Prepare evaluation criteria before the interview time.';
}

bool _needsEvaluation(InterviewModel interview) {
  if (interview.status == 'completed' && interview.result == 'pending') {
    return true;
  }
  return interview.isScheduled &&
      interview.scheduledAt.isBefore(DateTime.now());
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _endOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}

Color _statusColor(InterviewModel interview) {
  if (interview.status == 'completed') return AppColors.success;
  if (interview.status == 'cancelled') return AppColors.error;
  if (_needsEvaluation(interview)) return AppColors.warning;
  return AppColors.companyPrimary;
}

Color _resultColor(String result) {
  if (result == 'selected' || result == 'passed') return AppColors.success;
  if (result == 'rejected' || result == 'failed') return AppColors.error;
  return AppColors.warning;
}

Color _accentFor(UserRole role) {
  return switch (role) {
    UserRole.company => AppColors.companyPrimary,
    UserRole.student => AppColors.studentPrimary,
    UserRole.freelancer => AppColors.freelancerPrimary,
    UserRole.teacher => AppColors.teacherPrimary,
    UserRole.admin => AppColors.adminPrimary,
    UserRole.superAdmin => AppColors.superAdminPrimary,
  };
}

class _PendingOfferBanner extends ConsumerWidget {
  const _PendingOfferBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(myApplicationsProvider).value ?? const [];
    final pending = apps
        .where(
          (a) =>
              a.normalizedOfferStatus == 'sent' ||
              a.normalizedOfferStatus == 'clarification',
        )
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.pushNamed(RouteNames.myApplications),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_rounded, color: Colors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pending.length == 1
                            ? 'You have a job offer waiting'
                            : 'You have ${pending.length} job offers waiting',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Open My Applications to review and respond.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context, Color color) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? AppColors.elevatedSurface.withValues(alpha: 0.46)
        : AppColors.lightElevatedSurface.withValues(alpha: 0.72),
    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
    border: Border.all(color: color.withValues(alpha: 0.18)),
    boxShadow: isDark ? AppTheme.darkShadowSm : AppTheme.lightShadowSm,
  );
}

String _label(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
