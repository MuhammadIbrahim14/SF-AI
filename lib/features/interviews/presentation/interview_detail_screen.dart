import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/interview_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/interview_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class InterviewDetailScreen extends ConsumerWidget {
  const InterviewDetailScreen({super.key, required this.interviewId});

  final String interviewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interviewAsync = ref.watch(interviewDetailProvider(interviewId));
    final role = ref.watch(currentUserProvider).value?.primaryRole ?? '';
    final isCompany = role.toLowerCase() == 'company';
    final headerRole = UserRole.fromString(role) ?? UserRole.freelancer;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RoleFixedHeaderPage(
      role: headerRole,
      title: 'Interview Overview',
      subtitle: 'Review logistics, preparation details, and evaluation status.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.myInterviews),
      scrollable: false,
      child: ColoredBox(
        color: Colors.transparent,
        child: interviewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (interview) {
            if (interview == null) {
              return const Center(child: Text('Interview not found.'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(interview: interview),
                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF161616)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logistics & Details',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 24),

                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _InfoBento(
                                  icon: Icons.event_rounded,
                                  title: 'Date & Time',
                                  value: DateFormat.yMMMd().add_jm().format(
                                    interview.scheduledAt,
                                  ),
                                ),
                                _InfoBento(
                                  icon: Icons.timer_rounded,
                                  title: 'Duration',
                                  value: '${interview.durationMinutes} minutes',
                                ),
                                _InfoBento(
                                  icon: Icons.videocam_rounded,
                                  title: 'Mode',
                                  value: _label(interview.interviewMode),
                                ),
                              ],
                            ),

                            if (interview.meetingLink.isNotEmpty ||
                                interview.location.isNotEmpty ||
                                interview.timezone.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 24),

                              _ActionListTile(
                                icon: Icons.public_rounded,
                                title: 'Platform / Timezone',
                                value:
                                    '${interview.platformLabel} · ${interview.timezone}',
                                color: theme.colorScheme.onSurface,
                              ),
                              const SizedBox(height: 12),
                              if (interview.meetingLink.isNotEmpty)
                                _ActionListTile(
                                  icon: Icons.link_rounded,
                                  title: 'Meeting Link',
                                  value: interview.meetingLink,
                                  color: AppColors.primary,
                                ),
                              if (interview.meetingLink.isNotEmpty &&
                                  interview.location.isNotEmpty)
                                const SizedBox(height: 12),
                              if (interview.location.isNotEmpty)
                                _ActionListTile(
                                  icon: Icons.place_rounded,
                                  title: 'Location',
                                  value: interview.location,
                                  color: theme.colorScheme.onSurface,
                                ),
                              if (interview.candidateInstructions.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _ActionListTile(
                                  icon: Icons.info_outline_rounded,
                                  title: 'Candidate Instructions',
                                  value: interview.candidateInstructions,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ],
                              if (interview.companyInstructions.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _ActionListTile(
                                  icon: Icons.lock_outline_rounded,
                                  title: 'Company Instructions',
                                  value: interview.companyInstructions,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),

                      if (interview.agenda.isNotEmpty ||
                          interview.questions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF161616)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preparation',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),

                              if (interview.agenda.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Agenda',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  interview.agenda,
                                  style: const TextStyle(height: 1.5),
                                ),
                              ],

                              if (interview.questions.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Expected Topics',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...interview.questions.map(
                                  (q) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            q,
                                            style: const TextStyle(height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (interview.isCompleted) ...[
                        const SizedBox(height: 24),
                        _ScoreCard(interview: interview),
                      ],

                      if (isCompany) ...[
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () => context.pushNamed(
                            RouteNames.evaluateInterview,
                            pathParameters: {
                              'interviewId': interview.interviewId,
                            },
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            backgroundColor: AppColors.companyPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.fact_check_rounded),
                          label: Text(
                            interview.isCompleted
                                ? 'Update Evaluation'
                                : 'Complete Evaluation',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.interview});

  final InterviewModel interview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    IconData icon;

    if (interview.status == 'completed') {
      color = AppColors.success;
      icon = Icons.fact_check_rounded;
    } else if (interview.status == 'cancelled') {
      color = AppColors.error;
      icon = Icons.event_busy_rounded;
    } else {
      color = AppColors.primary;
      icon = Icons.event_available_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 24),
          Text(
            _label(interview.status),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (interview.result != 'pending') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _resultColor(interview.result).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _resultColor(interview.result).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Final Result: ${_label(interview.result)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _resultColor(interview.result),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _resultColor(String result) {
    if (result == 'selected' || result == 'passed') return AppColors.success;
    if (result == 'rejected' || result == 'failed') return AppColors.error;
    return AppColors.warning;
  }
}

class _InfoBento extends StatelessWidget {
  const _InfoBento({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 24),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13,
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.interview});

  final InterviewModel interview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? const Color(0xFF161616) : Colors.white,
            AppColors.success.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppColors.success),
              const SizedBox(width: 12),
              Text(
                'Evaluation Scorecard',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: _ScoreDial(
                  label: 'Technical',
                  value: interview.technicalScore,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _ScoreDial(
                  label: 'Communication',
                  value: interview.communicationScore,
                  color: Colors.purple,
                ),
              ),
              Expanded(
                child: _ScoreDial(
                  label: 'Confidence',
                  value: interview.confidenceScore,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Final Aggregate Score',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text(
                '${interview.finalScore.toStringAsFixed(1)} / 100',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: AppColors.success,
                ),
              ),
            ],
          ),

          if (interview.interviewerNotes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black26
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interviewer Notes',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    interview.interviewerNotes,
                    style: const TextStyle(
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreDial extends StatelessWidget {
  const _ScoreDial({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
              Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }
}

String _label(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
