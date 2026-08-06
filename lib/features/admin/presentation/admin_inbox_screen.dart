import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/contact_message_model.dart';
import '../../../providers/contact_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminInboxScreen extends ConsumerWidget {
  const AdminInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(contactMessagesProvider);
    final filters = ref.watch(contactFiltersProvider);

    return AdminControlScaffold(
      title: 'Support Inbox',
      subtitle: 'Manage user inquiries and support tickets',
      currentPath: RoutePaths.adminInbox,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: filters.status == 'All',
                  onTap: () => ref
                      .read(contactFiltersProvider.notifier)
                      .updateState(filters.copyWith(status: 'All')),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'New',
                  isSelected: filters.status == 'new',
                  onTap: () => ref
                      .read(contactFiltersProvider.notifier)
                      .updateState(filters.copyWith(status: 'new')),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Read',
                  isSelected: filters.status == 'read',
                  onTap: () => ref
                      .read(contactFiltersProvider.notifier)
                      .updateState(filters.copyWith(status: 'read')),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Resolved',
                  isSelected: filters.status == 'resolved',
                  onTap: () => ref
                      .read(contactFiltersProvider.notifier)
                      .updateState(filters.copyWith(status: 'resolved')),
                ),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages found.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageCard(message: message);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error loading messages: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? colorScheme.primary : colorScheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onPressed: onTap,
    );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({required this.message});
  final ContactMessage message;

  void _showDetailsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _MessageDetailDialog(message: message),
    );

    // Mark as read if it's new
    if (message.status == 'new') {
      ref
          .read(contactRepositoryProvider)
          .updateMessageStatus(messageId: message.messageId, status: 'read');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNew = message.status == 'new';
    final formatter = DateFormat('MMM d, yyyy • h:mm a');

    return Card(
      elevation: isNew ? 4 : 0,
      color: isNew
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isNew
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
          width: isNew ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showDetailsDialog(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      message.subject,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: message.status == 'resolved'
                          ? AppColors.success.withValues(alpha: 0.2)
                          : message.status == 'new'
                          ? AppColors.error.withValues(alpha: 0.2)
                          : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message.status.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        color: message.status == 'resolved'
                            ? AppColors.success
                            : message.status == 'new'
                            ? AppColors.error
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.name,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.category_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.category,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message.message,
                style: AppTypography.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(message.createdAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageDetailDialog extends ConsumerStatefulWidget {
  const _MessageDetailDialog({required this.message});
  final ContactMessage message;

  @override
  ConsumerState<_MessageDetailDialog> createState() =>
      _MessageDetailDialogState();
}

class _MessageDetailDialogState extends ConsumerState<_MessageDetailDialog> {
  late TextEditingController _noteController;
  late TextEditingController _responseController;
  late String _selectedStatus;
  late String _selectedPriority;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.message.adminNote ?? '',
    );
    _responseController = TextEditingController(
      text: widget.message.adminResponse ?? '',
    );
    _selectedStatus = widget.message.status;
    _selectedPriority = widget.message.priority;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _updateTicket() async {
    setState(() => _isResolving = true);
    try {
      final user = ref.read(currentUserProvider).value;
      final responseText = _responseController.text.trim();
      final hadResponseBefore =
          (widget.message.adminResponse ?? '').trim().isNotEmpty;
      await ref
          .read(contactRepositoryProvider)
          .updateMessageStatus(
            messageId: widget.message.messageId,
            status: _selectedStatus,
            adminNote: _noteController.text.trim().isNotEmpty
                ? _noteController.text.trim()
                : null,
            adminResponse: responseText.isNotEmpty ? responseText : null,
            resolvedBy:
                (_selectedStatus == 'resolved' || _selectedStatus == 'closed')
                ? user?.uid
                : null,
            respondedBy:
                (_selectedStatus == 'responded' && responseText.isNotEmpty)
                ? user?.uid
                : null,
            priority: _selectedPriority,
          );

      final ticketOwnerId = (widget.message.userId ?? '').trim();
      final shouldNotifyOwner =
          ticketOwnerId.isNotEmpty &&
          responseText.isNotEmpty &&
          (!hadResponseBefore || _selectedStatus == 'responded');
      if (shouldNotifyOwner) {
        final subject = widget.message.subject.trim().isEmpty
            ? 'your support ticket'
            : '"${widget.message.subject.trim()}"';
        await ref.read(notificationServiceProvider).notifyOne(
          recipientId: ticketOwnerId,
          title: 'Support replied',
          body: 'An admin replied to $subject.',
          category: NotificationCategories.support,
          event: NotificationEvents.supportTicketReplied,
          actorId: user?.uid,
          actorName: user?.fullName,
          actorRole: user?.primaryRole ?? 'admin',
          relatedPath: 'contactMessages/${widget.message.messageId}',
          routeName: RouteNames.supportRequestDetail,
          routeParams: {'messageId': widget.message.messageId},
          meta: {'messageId': widget.message.messageId},
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('Message Details', style: AppTypography.titleLarge),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.message.subject,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.message.name),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.email,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.message.email),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Message',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(widget.message.message),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New')),
                        DropdownMenuItem(value: 'read', child: Text('Read')),
                        DropdownMenuItem(
                          value: 'inProgress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'responded',
                          child: Text('Responded'),
                        ),
                        DropdownMenuItem(
                          value: 'resolved',
                          child: Text('Resolved'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('Closed'),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedStatus = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPriority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedPriority = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Public Response (Visible to User)',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _responseController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type response to the user...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: colorScheme.primary.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Internal Admin Note (Private)',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a private note...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _isResolving ? null : _updateTicket,
                    child: _isResolving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Ticket'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
