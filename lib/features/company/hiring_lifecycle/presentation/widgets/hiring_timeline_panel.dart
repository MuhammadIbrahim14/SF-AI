import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../models/hiring_lifecycle_models.dart';
import '../../providers/hiring_lifecycle_providers.dart';

class HiringTimelinePanel extends ConsumerWidget {
  const HiringTimelinePanel({
    super.key,
    required this.applicationId,
    this.candidateView = false,
  });

  final String applicationId;
  final bool candidateView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(applicationTimelineProvider(applicationId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        final msg = e.toString();
        final permissionDenied = msg.contains('permission-denied') ||
            msg.contains('PERMISSION_DENIED');
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            permissionDenied
                ? (candidateView
                    ? 'Timeline is temporarily unavailable. Your application status above is still up to date.'
                    : 'Unable to load timeline (permission denied). Deploy latest Firestore rules if this persists.')
                : 'Unable to load timeline: $e',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: permissionDenied
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
        );
      },
      data: (events) {
        final visible = candidateView
            ? events.where((e) => e.visibleToCandidate).toList()
            : events;
        if (visible.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: const Text('No timeline events yet.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hiring Timeline',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...visible.map((event) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title.isEmpty
                                ? lifecycleStageLabel(event.stage)
                                : event.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (event.description.isNotEmpty)
                            Text(
                              event.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            DateFormat.yMMMd().add_jm().format(event.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
