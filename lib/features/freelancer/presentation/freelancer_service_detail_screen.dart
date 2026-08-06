import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_service_model.dart';
import '../../../models/freelancer_service_review_model.dart';
import '../../../providers/freelancer_service_provider.dart';
import '../../../providers/freelancer_service_review_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/customer_app_bar.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import 'service_request_form_dialog.dart';

class FreelancerServiceDetailScreen extends ConsumerWidget {
  const FreelancerServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(freelancerServiceDetailProvider(serviceId));
    final reviewsAsync = ref.watch(serviceReviewsProvider(serviceId));
    final summary = ref.watch(serviceReviewSummaryProvider(serviceId));
    final user = ref.watch(currentUserProvider).value;
    final isCustomer = user?.isCustomerAccount == true;

    return Scaffold(
      appBar: isCustomer ? const CustomerAppBar() : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: serviceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Service unavailable',
            message: error.toString(),
          ),
          data: (service) {
            if (service == null || !service.isLive) {
              return DashboardEmptyState(
                icon: Icons.visibility_off_rounded,
                title: 'Service is not public',
                message:
                    'This service is unavailable, hidden, or still in draft.',
                actionLabel: 'Back',
                onAction: () {
                  if (context.canPop()) context.pop();
                },
              );
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _DetailHero(service: service)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 980;
                        final main = _DetailPanel(service: service);
                        final reviews =
                            reviewsAsync.value ??
                            const <FreelancerServiceReviewModel>[];
                        final trust = _TrustPanel(
                          service: service,
                          summary: summary,
                        );
                        final reviewsPanel = _ReviewsPanel(
                          reviews: reviews,
                          isLoading: reviewsAsync.isLoading,
                          summary: summary,
                        );
                        if (!isDesktop) {
                          return Column(
                            children: [
                              main,
                              const SizedBox(height: 18),
                              trust,
                              const SizedBox(height: 18),
                              reviewsPanel,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  main,
                                  const SizedBox(height: 18),
                                  reviewsPanel,
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(child: trust),
                          ],
                        );
                      },
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
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.service});

  final FreelancerServiceModel service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 760;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Back',
                    onPressed: () => context.canPop() ? context.pop() : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    service.title,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    service.shortDescription,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Pill(
                        label: service.category,
                        icon: Icons.category_rounded,
                      ),
                      _Pill(
                        label:
                            '${service.currency} ${service.startingPrice.toStringAsFixed(0)} ${service.pricingType}',
                        icon: Icons.payments_rounded,
                      ),
                      if (service.estimatedDelivery.trim().isNotEmpty)
                        _Pill(
                          label: service.estimatedDelivery,
                          icon: Icons.schedule_rounded,
                        ),
                      if (service.verifiedBadge)
                        const _Pill(
                          label: 'Verified proof',
                          icon: Icons.verified_rounded,
                        ),
                    ],
                  ),
                ],
              );

              final request = FilledButton.icon(
                onPressed: () => showServiceRequestFormDialog(context, service),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Request Service'),
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [copy, const SizedBox(height: 24), request],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 40),
                  request,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.service});

  final FreelancerServiceModel service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassSection(
      title: 'Service Details',
      icon: Icons.article_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cover(service: service),
          const SizedBox(height: 18),
          Text(
            service.fullDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _TagWrap(title: 'Tags', values: service.tags),
          const SizedBox(height: 18),
          _TagWrap(title: 'Linked Skills', values: service.linkedSkills),
          const SizedBox(height: 18),
          _LinksBlock(
            title: 'Portfolio Links',
            links: service.portfolioLinks,
            empty: 'No public portfolio links attached to this service.',
          ),
          const SizedBox(height: 18),
          _LinksBlock(
            title: 'Gallery URLs',
            links: service.galleryUrls,
            empty: 'No gallery URLs attached yet.',
          ),
        ],
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel({required this.service, required this.summary});

  final FreelancerServiceModel service;
  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return _GlassSection(
      title: 'Trust Panel',
      icon: Icons.verified_user_rounded,
      child: Column(
        children: [
          _TrustTile(
            label: 'Freelancer',
            value: service.freelancerName.trim().isEmpty
                ? 'SkillForge Freelancer'
                : service.freelancerName,
            icon: Icons.person_rounded,
          ),
          _TrustTile(
            label: 'Skill score',
            value: service.skillScore <= 0
                ? 'Pending'
                : '${service.skillScore.toStringAsFixed(0)}%',
            icon: Icons.psychology_rounded,
          ),
          _TrustTile(
            label: 'Linked certificates',
            value: '${service.linkedCertificateIds.length}',
            icon: Icons.workspace_premium_rounded,
          ),
          _TrustTile(
            label: 'Rating',
            value: summary.hasReviews
                ? '${summary.averageRating.toStringAsFixed(1)} • ${summary.reviewCount} review${summary.reviewCount == 1 ? '' : 's'}'
                : 'No reviews yet',
            icon: Icons.star_rounded,
          ),
          _TrustTile(
            label: 'Public interest',
            value: '${service.inquiryCount}',
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showServiceRequestFormDialog(context, service),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Request Service'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsPanel extends StatelessWidget {
  const _ReviewsPanel({
    required this.reviews,
    required this.isLoading,
    required this.summary,
  });

  final List<FreelancerServiceReviewModel> reviews;
  final bool isLoading;
  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassSection(
      title: 'Client Reviews',
      icon: Icons.reviews_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                summary.hasReviews
                    ? '${summary.averageRating.toStringAsFixed(1)} average'
                    : 'No reviews yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (summary.hasReviews) ...[
                const SizedBox(width: 8),
                Text(
                  '(${summary.reviewCount})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (reviews.isEmpty)
            Text(
              'No clients have reviewed this service yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...reviews.take(5).map((review) => _ReviewTile(review: review)),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final FreelancerServiceReviewModel review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _Stars(rating: review.rating),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                review.comment,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: AppColors.warning,
          size: 16,
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.freelancerPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.service});

  final FreelancerServiceModel service;

  @override
  Widget build(BuildContext context) {
    final url = service.coverImageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url.isEmpty
            ? const _CoverFallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _CoverFallback(),
              ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.freelancerPrimary.withValues(alpha: 0.12),
      child: const Center(
        child: Icon(
          Icons.design_services_rounded,
          size: 48,
          color: AppColors.freelancerPrimary,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.freelancerPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.freelancerPrimary.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.freelancerPrimary, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.freelancerPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => Chip(
                  label: Text(value),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _LinksBlock extends StatelessWidget {
  const _LinksBlock({
    required this.title,
    required this.links,
    required this.empty,
  });

  final String title;
  final List<String> links;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (links.isEmpty)
          Text(
            empty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          ...links.map(
            (link) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(
                link,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.freelancerPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrustTile extends StatelessWidget {
  const _TrustTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.freelancerPrimary.withValues(alpha: 0.12),
        child: Icon(icon, size: 20, color: AppColors.freelancerPrimary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.freelancerPrimary,
        ),
      ),
    );
  }
}
