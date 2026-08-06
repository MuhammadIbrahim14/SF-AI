import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../models/interview_lab_models.dart';
import '../providers/interview_lab_providers.dart';
import 'widgets/interview_lab_widgets.dart';

class InterviewLabHistoryScreen extends ConsumerStatefulWidget {
  const InterviewLabHistoryScreen({super.key});

  @override
  ConsumerState<InterviewLabHistoryScreen> createState() =>
      _InterviewLabHistoryScreenState();
}

class _InterviewLabHistoryScreenState
    extends ConsumerState<InterviewLabHistoryScreen> {
  String _query = '';
  String _statusFilter = 'all';
  String _sort = 'newest';

  UserRole _role() {
    final user = ref.read(currentUserProvider).value;
    if (user?.primaryRole == UserRole.freelancer) return UserRole.freelancer;
    return UserRole.student;
  }

  List<InterviewLabSessionModel> _filter(List<InterviewLabSessionModel> input) {
    var list = List<InterviewLabSessionModel>.from(input);
    if (_statusFilter != 'all') {
      list = list.where((s) => s.status == _statusFilter).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((s) {
        final label =
            InterviewLabRoleTrack.displayLabel(s.roleTrack).toLowerCase();
        return label.contains(q) ||
            s.difficulty.toLowerCase().contains(q) ||
            s.status.toLowerCase().contains(q);
      }).toList();
    }
    switch (_sort) {
      case 'score_high':
        list.sort((a, b) => b.overallScore.compareTo(a.overallScore));
      case 'score_low':
        list.sort((a, b) => a.overallScore.compareTo(b.overallScore));
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  Future<void> _delete(InterviewLabSessionModel session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete interview?'),
        content: const Text(
          'This removes the session, answers, report, and history for this practice interview.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(interviewLabActionProvider.notifier)
        .deleteSession(session.sessionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Interview deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(myInterviewLabSessionsProvider);

    return RoleFixedHeaderPage(
      role: _role(),
      title: 'Interview history',
      subtitle: 'Search, filter, and open practice reports.',
      child: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e'),
        ),
        data: (sessions) {
          final filtered = _filter(sessions);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search role, difficulty, status…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All statuses')),
                        DropdownMenuItem(
                          value: InterviewLabSessionStatus.completed,
                          child: Text('Completed'),
                        ),
                        DropdownMenuItem(
                          value: InterviewLabSessionStatus.inProgress,
                          child: Text('In progress'),
                        ),
                        DropdownMenuItem(
                          value: InterviewLabSessionStatus.paused,
                          child: Text('Paused'),
                        ),
                        DropdownMenuItem(
                          value: InterviewLabSessionStatus.abandoned,
                          child: Text('Abandoned'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _statusFilter = v ?? 'all'),
                    ),
                    DropdownButton<String>(
                      value: _sort,
                      items: const [
                        DropdownMenuItem(
                          value: 'newest',
                          child: Text('Newest'),
                        ),
                        DropdownMenuItem(
                          value: 'score_high',
                          child: Text('Score high → low'),
                        ),
                        DropdownMenuItem(
                          value: 'score_low',
                          child: Text('Score low → high'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _sort = v ?? 'newest'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Text(
                          sessions.isEmpty
                              ? 'No practice interviews yet.'
                              : 'No interviews match your filters.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              context.pushNamed(RouteNames.interviewLabStart),
                          child: const Text('Start practice'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final s in filtered)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.14),
                          child: Icon(
                            Icons.record_voice_over_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          InterviewLabRoleTrack.displayLabel(s.roleTrack),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${interviewLabStatusLabel(s.status)} · ${s.difficulty}'
                          '${s.isCompleted ? ' · ${s.overallScore.toStringAsFixed(0)}' : ''}\n'
                          '${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'open':
                                if (s.isCompleted) {
                                  context.pushNamed(
                                    RouteNames.interviewLabReport,
                                    pathParameters: {
                                      'sessionId': s.sessionId,
                                    },
                                  );
                                } else {
                                  context.pushNamed(
                                    RouteNames.interviewLabSession,
                                    pathParameters: {
                                      'sessionId': s.sessionId,
                                    },
                                  );
                                }
                              case 'delete':
                                await _delete(s);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'open',
                              child: Text(
                                s.isCompleted ? 'Open report' : 'Resume',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (s.isCompleted) {
                            context.pushNamed(
                              RouteNames.interviewLabReport,
                              pathParameters: {'sessionId': s.sessionId},
                            );
                          } else {
                            context.pushNamed(
                              RouteNames.interviewLabSession,
                              pathParameters: {'sessionId': s.sessionId},
                            );
                          }
                        },
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
