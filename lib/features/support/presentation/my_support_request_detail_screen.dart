import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/contact_message_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/contact_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class MySupportRequestDetailScreen extends ConsumerWidget {
  const MySupportRequestDetailScreen({super.key, required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final role = UserRole.fromString(user?.primaryRole) ?? UserRole.student;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('You must be logged in to view support requests.'),
        ),
      );
    }

    final requestsAsync = ref.watch(userContactMessagesProvider(user.uid));

    return RoleFixedHeaderPage(
      role: role,
      title: 'Ticket Details',
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/support/my-requests');
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: requestsAsync.when(
              data: (requests) {
                final ticket = requests
                    .where((r) => r.messageId == messageId)
                    .firstOrNull;
                if (ticket == null) {
                  return const Center(
                    child: Text(
                      'Ticket not found or you do not have permission.',
                    ),
                  );
                }
                return _buildDetailView(context, ticket);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(BuildContext context, ContactMessage ticket) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('MMM d, yyyy • h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ticket.subject,
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _StatusChip(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ticket.category,
                      style: AppTypography.bodyMedium.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Icon(
                      Icons.flag_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Priority: ${ticket.priority.toUpperCase()}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: ticket.priority == 'high'
                            ? AppColors.error
                            : colorScheme.onSurfaceVariant,
                        fontWeight: ticket.priority == 'high'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Timeline
        Text(
          'Timeline',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _TimelineItem(
          icon: Icons.send_rounded,
          title: 'Submitted',
          subtitle: formatter.format(ticket.createdAt),
          isActive: true,
          color: colorScheme.primary,
        ),
        _TimelineItem(
          icon: Icons.visibility_rounded,
          title: 'Viewed by Support',
          subtitle: ticket.status != 'new'
              ? 'Support has viewed your request'
              : 'Waiting for review',
          isActive: ticket.status != 'new',
          color: colorScheme.primary,
        ),
        _TimelineItem(
          icon: Icons.work_history_rounded,
          title: 'In Progress',
          subtitle:
              [
                'inProgress',
                'responded',
                'resolved',
                'closed',
              ].contains(ticket.status)
              ? 'Support is working on it'
              : 'Pending',
          isActive: [
            'inProgress',
            'responded',
            'resolved',
            'closed',
          ].contains(ticket.status),
          color: colorScheme.primary,
        ),
        _TimelineItem(
          icon: Icons.check_circle_rounded,
          title: 'Resolved',
          subtitle: ticket.resolvedAt != null
              ? formatter.format(ticket.resolvedAt!)
              : 'Pending resolution',
          isActive: ['resolved', 'closed'].contains(ticket.status),
          color: AppColors.success,
          isLast: true,
        ),

        const SizedBox(height: 32),

        // Original Message
        Text(
          'Your Message',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Text(ticket.message, style: AppTypography.bodyLarge),
        ),

        // Admin Response
        if (ticket.adminResponse != null &&
            ticket.adminResponse!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Support Response',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SkillForge Support',
                      style: AppTypography.titleSmall.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (ticket.respondedAt != null)
                      Text(
                        formatter.format(ticket.respondedAt!),
                        style: AppTypography.labelSmall.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(ticket.adminResponse!, style: AppTypography.bodyLarge),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'new':
        color = AppColors.error;
        label = 'Submitted';
        break;
      case 'read':
        color = AppColors.warning;
        label = 'Viewed';
        break;
      case 'inProgress':
        color = AppColors.primary;
        label = 'In Progress';
        break;
      case 'responded':
        color = AppColors.info;
        label = 'Response Received';
        break;
      case 'resolved':
        color = AppColors.success;
        label = 'Resolved';
        break;
      case 'closed':
        color = Colors.grey;
        label = 'Closed';
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.color,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemColor = isActive ? color : colorScheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? itemColor.withValues(alpha: 0.15)
                        : colorScheme.surface,
                    border: Border.all(
                      color: isActive ? itemColor : colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isActive ? itemColor : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isActive
                          ? itemColor.withValues(alpha: 0.5)
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
