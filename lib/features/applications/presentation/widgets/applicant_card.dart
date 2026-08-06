import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/application_model.dart';
import '../../../../models/job_match_model.dart';
import '../../../../models/user_model.dart';

class ApplicantCard extends StatelessWidget {
  const ApplicantCard({
    super.key,
    required this.application,
    required this.applicant,
    required this.onUpdateStatus,
    this.match,
    this.onScheduleInterview,
    this.onViewInterview,
    this.onEvaluateInterview,
    this.onViewIntelligence,
  });

  final ApplicationModel application;
  final UserModel applicant;
  final Function(String) onUpdateStatus;
  final JobMatchModel? match;
  final VoidCallback? onScheduleInterview;
  final VoidCallback? onViewInterview;
  final VoidCallback? onEvaluateInterview;
  final VoidCallback? onViewIntelligence;

  Color _statusColor(BuildContext context, String status) {
    return switch (normalizeApplicationStatus(status)) {
      'selected' => AppColors.success,
      'rejected' => AppColors.error,
      'interview_scheduled' || 'interview_completed' => AppColors.secondary,
      'on_hold' => AppColors.warning,
      _ => AppColors.companyPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = application.normalizedStatus;
    final actionStage = _actionStage(normalizedStatus, application.interviewId);
    final statusColor = _statusColor(context, application.status);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final matchScore = match?.matchScore ?? 0.0;
    final isHighMatch = matchScore >= 75.0;
    final recommendation = _candidateRecommendation(match, normalizedStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.elevatedSurface
            : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighMatch
              ? AppColors.companyPrimary.withValues(alpha: 0.3)
              : (isDark ? AppColors.divider : AppColors.lightDivider),
          width: isHighMatch ? 1.5 : 1,
        ),
        boxShadow: [
          if (isHighMatch)
            BoxShadow(
              color: AppColors.companyPrimary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Candidate Name, Status, and Match Score Badge
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isHighMatch
                        ? AppColors.companyPrimary.withValues(alpha: 0.08)
                        : (isDark
                              ? AppColors.cardLight
                              : AppColors.lightCardLight),
                    isDark ? AppColors.card : AppColors.lightCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.companyPrimary.withValues(
                      alpha: 0.15,
                    ),
                    backgroundImage:
                        applicant.photoUrl?.trim().isNotEmpty == true
                        ? NetworkImage(applicant.photoUrl!)
                        : null,
                    child: applicant.photoUrl?.trim().isNotEmpty == true
                        ? null
                        : Text(
                            applicant.fullName.isNotEmpty
                                ? applicant.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 22,
                              color: AppColors.companyPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),

                  // Name & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          applicant.fullName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                applicant.email,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Status Badge
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SignalBadge(
                              label: applicationStatusLabel(
                                application.status,
                              ).toUpperCase(),
                              color: statusColor,
                            ),
                            _SignalBadge(
                              label: recommendation.label,
                              color: recommendation.color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Match Score Badge
                  if (match != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isHighMatch
                              ? AppColors.companyPrimary.withValues(alpha: 0.5)
                              : (isDark
                                    ? AppColors.divider
                                    : AppColors.lightDivider),
                        ),
                        boxShadow: isHighMatch
                            ? [
                                BoxShadow(
                                  color: AppColors.companyPrimary.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${matchScore.toStringAsFixed(0)}%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: isHighMatch
                                  ? AppColors.companyPrimary
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'MATCH',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Metrics Grid
            if (match != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.divider
                          : AppColors.lightDivider,
                    ),
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.divider
                          : AppColors.lightDivider,
                    ),
                  ),
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.02),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CompactMetric(
                      label: 'SKILL SCORE',
                      value: '${match!.skillScoreAverage.toStringAsFixed(0)}%',
                      icon: Icons.psychology_rounded,
                      color: AppColors.info,
                    ),
                    _CompactMetric(
                      label: 'RESUME',
                      value: match!.resumeScore > 0
                          ? '${match!.resumeScore.toStringAsFixed(0)}%'
                          : 'Missing',
                      icon: Icons.description_rounded,
                      color: AppColors.secondary,
                    ),
                    _CompactMetric(
                      label: 'CERTIFICATES',
                      value: match!.certificateScore > 0
                          ? '${match!.certificateScore.toStringAsFixed(0)}%'
                          : 'None',
                      icon: Icons.workspace_premium_rounded,
                      color: AppColors.warning,
                    ),
                    _CompactMetric(
                      label: 'PROJECTS',
                      value: match!.projectScore > 0
                          ? '${match!.projectScore.toStringAsFixed(0)}%'
                          : 'None',
                      icon: Icons.code_rounded,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (match != null) ...[
                    _CandidateEvidencePanel(match: match!),
                    const SizedBox(height: 24),
                  ],

                  // Verified Skills Section
                  if (match != null && match!.matchedSkills.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.companyPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Top Skills & Strengths',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: match!.matchedSkills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.companyPrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.companyPrimary.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Text(
                            skill,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isDark
                                  ? AppColors.companyPrimary
                                  : AppColors.companySecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (match != null && match!.missingSkills.isNotEmpty) ...[
                    _MissingSkillsPanel(skills: match!.missingSkills),
                    const SizedBox(height: 24),
                  ],

                  if (match != null) ...[
                    _RecruiterDecisionSupport(
                      match: match!,
                      recommendation: recommendation,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Pipeline Tracker
                  _PipelineGuide(
                    status: normalizedStatus,
                    hasInterview: application.interviewId != null,
                  ),

                  const SizedBox(height: 24),

                  if (onViewIntelligence != null) ...[
                    _ActionSection(
                      title: 'Candidate Intelligence',
                      message:
                          'Open AI-powered ATS profile with Interview Lab evidence.',
                      children: [
                        _PrimaryActionButton(
                          label: 'Open Intelligence',
                          icon: Icons.psychology_alt_rounded,
                          color: AppColors.companyPrimary,
                          onTap: onViewIntelligence,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Stage Logic
                  if (actionStage == _ApplicantActionStage.review)
                    _ActionSection(
                      title: 'Review Stage',
                      message:
                          'Evaluate match metrics and proceed to shortlist or interview.',
                      children: [
                        _PrimaryActionButton(
                          label: 'Shortlist',
                          icon: Icons.how_to_reg_rounded,
                          color: AppColors.companyPrimary,
                          onTap: () => onUpdateStatus('shortlisted'),
                        ),
                        _SecondaryActionButton(
                          label: 'Schedule',
                          icon: Icons.event_rounded,
                          color: AppColors.info,
                          onTap: onScheduleInterview,
                        ),
                        _GhostActionButton(
                          label: 'Reject',
                          color: AppColors.error,
                          onTap: () => onUpdateStatus('rejected'),
                        ),
                      ],
                    ),
                  if (actionStage == _ApplicantActionStage.interview)
                    _ActionSection(
                      title: 'Interview Stage',
                      message:
                          'Manage the candidate interview process and record evaluation.',
                      children: [
                        if (application.interviewId == null)
                          _PrimaryActionButton(
                            label: 'Schedule Interview',
                            icon: Icons.event_available_rounded,
                            color: AppColors.info,
                            onTap: onScheduleInterview,
                          ),
                        if (application.interviewId != null)
                          _SecondaryActionButton(
                            label: 'Details',
                            icon: Icons.calendar_today_rounded,
                            color: AppColors.secondary,
                            onTap: onViewInterview,
                          ),
                        if (application.interviewId != null)
                          _PrimaryActionButton(
                            label: 'Evaluate',
                            icon: Icons.fact_check_rounded,
                            color: AppColors.companyPrimary,
                            onTap: onEvaluateInterview,
                          ),
                      ],
                    ),
                  if (actionStage == _ApplicantActionStage.decision)
                    _ActionSection(
                      title: 'Final Decision Stage',
                      message:
                          'Review interview evaluation and make a hiring decision.',
                      children: [
                        if (application.interviewId != null)
                          _SecondaryActionButton(
                            label: 'Evaluation',
                            icon: Icons.assessment_rounded,
                            color: AppColors.info,
                            onTap: onEvaluateInterview,
                          ),
                        _PrimaryActionButton(
                          label: 'Hire Candidate',
                          icon: Icons.workspace_premium_rounded,
                          color: AppColors.companyPrimary,
                          onTap: () => onUpdateStatus('selected'),
                        ),
                        _GhostActionButton(
                          label: 'Reject',
                          color: AppColors.error,
                          onTap: () => onUpdateStatus('rejected'),
                        ),
                      ],
                    ),
                  if (actionStage == _ApplicantActionStage.closed)
                    _ActionSection(
                      title: 'Pipeline Closed',
                      message: 'This application has reached a final status.',
                      children: [
                        _SecondaryActionButton(
                          label: 'Reopen Pipeline',
                          icon: Icons.restore_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                          onTap: () => onUpdateStatus('shortlisted'),
                        ),
                        if (application.interviewId != null)
                          _SecondaryActionButton(
                            label: 'View Interview',
                            icon: Icons.visibility_rounded,
                            color: AppColors.info,
                            onTap: onViewInterview,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
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
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateEvidencePanel extends StatelessWidget {
  const _CandidateEvidencePanel({required this.match});

  final JobMatchModel match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resumeAvailable = match.resumeScore > 0;
    final certificatesAvailable = match.certificateScore > 0;
    final portfolioAvailable = match.projectScore > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _softPanelDecoration(context, AppColors.companyPrimary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Candidate Breakdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SignalBadge(
                label: resumeAvailable ? 'Resume Available' : 'No Resume',
                color: resumeAvailable ? AppColors.success : AppColors.warning,
              ),
              _SignalBadge(
                label: certificatesAvailable ? 'Certified' : 'No Certificates',
                color: certificatesAvailable
                    ? AppColors.success
                    : AppColors.warning,
              ),
              _SignalBadge(
                label: portfolioAvailable
                    ? 'Portfolio / Projects'
                    : 'No Portfolio Signal',
                color: portfolioAvailable ? AppColors.success : AppColors.info,
              ),
              _SignalBadge(
                label: match.careerGoalMatch
                    ? 'Career Aligned'
                    : 'Career Alignment Unknown',
                color: match.careerGoalMatch
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const _SignalBadge(
                label: 'Grand Test: Not Available',
                color: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MissingSkillsPanel extends StatelessWidget {
  const _MissingSkillsPanel({required this.skills});

  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _softPanelDecoration(context, AppColors.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_problem_outlined,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Weaknesses / Missing Skills',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in skills.take(8))
                _SignalBadge(label: skill, color: AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecruiterDecisionSupport extends StatelessWidget {
  const _RecruiterDecisionSupport({
    required this.match,
    required this.recommendation,
  });

  final JobMatchModel match;
  final _CandidateRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = _decisionNotes(match);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _softPanelDecoration(context, recommendation.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(recommendation.icon, color: recommendation.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SignalBadge(
                label: recommendation.label,
                color: recommendation.color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            match.recommendationReason.isNotEmpty
                ? match.recommendationReason
                : recommendation.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: recommendation.color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalBadge extends StatelessWidget {
  const _SignalBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CandidateRecommendation {
  const _CandidateRecommendation({
    required this.label,
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String label;
  final String title;
  final String message;
  final Color color;
  final IconData icon;
}

_CandidateRecommendation _candidateRecommendation(
  JobMatchModel? match,
  String normalizedStatus,
) {
  if (match == null) {
    return const _CandidateRecommendation(
      label: 'Review',
      title: 'Candidate Needs Review',
      message: 'Matching evidence is not available yet for this candidate.',
      color: AppColors.warning,
      icon: Icons.manage_search_rounded,
    );
  }
  if (normalizedStatus == 'interview_scheduled' ||
      normalizedStatus == 'interview_completed') {
    return const _CandidateRecommendation(
      label: 'Interview Active',
      title: 'Interview In Progress',
      message: 'Use interview evaluation before making the final decision.',
      color: AppColors.info,
      icon: Icons.event_available_rounded,
    );
  }
  if (match.matchScore >= 80 && match.missingSkills.isEmpty) {
    return const _CandidateRecommendation(
      label: 'Excellent',
      title: 'Excellent Candidate',
      message: 'Strong match with complete required skill coverage.',
      color: AppColors.success,
      icon: Icons.workspace_premium_rounded,
    );
  }
  if (match.matchScore >= 65) {
    return const _CandidateRecommendation(
      label: 'Needs Interview',
      title: 'Interview Recommended',
      message: 'Candidate has enough evidence to move into interview review.',
      color: AppColors.companyPrimary,
      icon: Icons.forum_rounded,
    );
  }
  if (match.skillScoreAverage >= 70 && match.matchScore < 65) {
    return const _CandidateRecommendation(
      label: 'Skill Strong',
      title: 'High Skill Score, Check Gaps',
      message: 'Skill evidence is strong, but role requirements need review.',
      color: AppColors.warning,
      icon: Icons.psychology_rounded,
    );
  }
  return const _CandidateRecommendation(
    label: 'Developing',
    title: 'Not Ready Yet',
    message: 'Candidate needs stronger evidence before moving forward.',
    color: AppColors.error,
    icon: Icons.trending_up_rounded,
  );
}

List<String> _decisionNotes(JobMatchModel match) {
  final notes = <String>[];
  if (match.resumeScore <= 0) {
    notes.add(
      'No resume signal is available. Ask for resume evidence before final hiring.',
    );
  }
  if (match.certificateScore <= 0) {
    notes.add('No active certificate signal is available.');
  }
  if (match.projectScore > 0) {
    notes.add('Project or portfolio evidence is available for deeper review.');
  }
  if (match.missingSkills.isNotEmpty) {
    notes.add(
      'Missing ${match.missingSkills.take(3).join(', ')} from the job requirements.',
    );
  }
  if (match.matchedSkills.isNotEmpty) {
    notes.add('Strengths include ${match.matchedSkills.take(3).join(', ')}.');
  }
  return notes.take(4).toList();
}

BoxDecoration _softPanelDecoration(BuildContext context, Color color) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? AppColors.surface.withValues(alpha: 0.62)
        : AppColors.lightSurface.withValues(alpha: 0.78),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: color.withValues(alpha: 0.18)),
  );
}

enum _ApplicantActionStage { review, interview, decision, closed }

_ApplicantActionStage _actionStage(
  String normalizedStatus,
  String? interviewId,
) {
  if (normalizedStatus == 'selected' ||
      normalizedStatus == 'rejected' ||
      normalizedStatus == 'withdrawn') {
    return _ApplicantActionStage.closed;
  }
  if (normalizedStatus == 'interview_completed' ||
      normalizedStatus == 'evaluated' ||
      normalizedStatus == 'evaluation_complete') {
    return _ApplicantActionStage.decision;
  }
  if (interviewId != null || normalizedStatus == 'interview_scheduled') {
    return _ApplicantActionStage.interview;
  }
  if (normalizedStatus == 'shortlisted') {
    return _ApplicantActionStage.interview;
  }
  return _ApplicantActionStage.review;
}

class _PipelineGuide extends StatelessWidget {
  const _PipelineGuide({required this.status, required this.hasInterview});

  final String status;
  final bool hasInterview;

  @override
  Widget build(BuildContext context) {
    final currentStep = switch (status) {
      'selected' || 'rejected' || 'withdrawn' => 4,
      'interview_completed' || 'evaluated' || 'evaluation_complete' => 3,
      'interview_scheduled' => 2,
      'shortlisted' => 1,
      _ => 0,
    };

    final steps = [
      ('Applied', currentStep >= 0),
      ('Shortlist', currentStep >= 1),
      ('Interview', currentStep >= 2 || hasInterview),
      ('Evaluated', currentStep >= 3),
      ('Decision', currentStep >= 4),
    ];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: (steps[index ~/ 2].$2 && steps[(index ~/ 2) + 1].$2)
                    ? AppColors.companyPrimary.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final step = steps[stepIndex];
          final active = step.$2;
          final isCurrent = currentStep == stepIndex;

          return Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.companyPrimary.withValues(
                          alpha: isCurrent ? 1.0 : 0.2,
                        )
                      : theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: active
                        ? AppColors.companyPrimary
                        : theme.colorScheme.outlineVariant,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: active && !isCurrent
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.companyPrimary,
                      )
                    : (isCurrent
                          ? Icon(
                              Icons.circle,
                              size: 8,
                              color: isDark
                                  ? AppColors.background
                                  : AppColors.lightBackground,
                            )
                          : const SizedBox()),
              ),
              const SizedBox(height: 6),
              Text(
                step.$1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: active
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.title,
    required this.message,
    required this.children,
  });

  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: children),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  const _GhostActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
