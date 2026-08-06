import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_service_review_model.dart';
import '../../../models/service_request_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/freelancer_service_review_provider.dart';

Future<void> showServiceReviewDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ServiceRequestModel request,
  required UserModel user,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ServiceReviewDialog(request: request, user: user),
  );
}

class _ServiceReviewDialog extends ConsumerStatefulWidget {
  const _ServiceReviewDialog({required this.request, required this.user});

  final ServiceRequestModel request;
  final UserModel user;

  @override
  ConsumerState<_ServiceReviewDialog> createState() =>
      _ServiceReviewDialogState();
}

class _ServiceReviewDialogState extends ConsumerState<_ServiceReviewDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(freelancerServiceReviewActionProvider);
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Review this service'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.request.serviceTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  tooltip: '$value star${value == 1 ? '' : 's'}',
                  onPressed: actionState.isLoading
                      ? null
                      : () => setState(() => _rating = value),
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.warning,
                    size: 30,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              minLines: 3,
              maxLines: 5,
              enabled: !actionState.isLoading,
              decoration: const InputDecoration(
                labelText: 'Review comment',
                hintText:
                    'Share what went well and what future clients should know.',
                border: OutlineInputBorder(),
              ),
            ),
            if (actionState.hasError) ...[
              const SizedBox(height: 12),
              Text(
                actionState.error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: actionState.isLoading
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: actionState.isLoading ? null : _submit,
          icon: actionState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.rate_review_rounded, size: 18),
          label: const Text('Submit Review'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (comment.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a short review comment.')),
      );
      return;
    }

    final now = DateTime.now();
    final review = FreelancerServiceReviewModel(
      reviewId: widget.request.requestId,
      serviceRequestId: widget.request.requestId,
      serviceId: widget.request.serviceId,
      freelancerId: widget.request.freelancerId,
      clientId: widget.user.uid,
      clientName: widget.user.fullName.trim().isEmpty
          ? 'SkillForge Client'
          : widget.user.fullName,
      rating: _rating,
      comment: comment,
      createdAt: now,
      updatedAt: now,
      isVisible: true,
      serviceTitle: widget.request.serviceTitle,
    );
    final ok = await ref
        .read(freelancerServiceReviewActionProvider.notifier)
        .createReview(review);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review submitted.')));
    }
  }
}
