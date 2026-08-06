import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_service_model.dart';
import '../../../models/freelancer_service_review_model.dart';
import '../../../providers/freelancer_service_provider.dart';
import '../../../providers/freelancer_service_review_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/customer_app_bar.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'service_request_form_dialog.dart';

enum _ServiceSort { newest, priceLow, priceHigh, trust, inquiries }

class FreelancerServicesMarketplaceScreen extends ConsumerStatefulWidget {
  const FreelancerServicesMarketplaceScreen({super.key});

  @override
  ConsumerState<FreelancerServicesMarketplaceScreen> createState() =>
      _FreelancerServicesMarketplaceScreenState();
}

class _FreelancerServicesMarketplaceScreenState
    extends ConsumerState<FreelancerServicesMarketplaceScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';
  String _pricingType = 'All';
  String _skill = 'All';
  RangeValues _priceRange = const RangeValues(0, 5000);
  _ServiceSort _sort = _ServiceSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(publishedFreelancerServicesProvider);
    final reviewSummaries = ref.watch(allReviewSummariesProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final isFreelancer =
        currentUser?.primaryRole?.trim().toLowerCase() == 'freelancer';
    final isCustomer = currentUser?.isCustomerAccount == true;

    return Scaffold(
      appBar: isCustomer ? const CustomerAppBar() : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: servicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _MarketplaceMessage(
            icon: Icons.error_outline_rounded,
            title: 'Services unavailable',
            message: error.toString(),
          ),
          data: (services) {
            final published = services
                .where((service) => service.isLive)
                .toList();
            final filtered = _filterServices(published);
            final categories = _uniqueValues(
              published.map((item) => item.category),
            );
            final skills = _uniqueValues(
              published.expand((item) => [...item.linkedSkills, ...item.tags]),
            );

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _MarketplaceHero(
                    totalServices: published.length,
                    visibleServices: filtered.length,
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.goNamed(RouteNames.home),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TrendingCategories(
                    categories: categories,
                    selectedCategory: _category,
                    onCategoryChanged: (value) =>
                        setState(() => _category = value),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _MarketplaceFilters(
                    searchController: _searchController,
                    query: _query,
                    pricingType: _pricingType,
                    skills: skills,
                    selectedSkill: _skill,
                    priceRange: _priceRange,
                    sort: _sort,
                    onSearchChanged: (value) => setState(() => _query = value),
                    onPricingTypeChanged: (value) =>
                        setState(() => _pricingType = value),
                    onSkillChanged: (value) => setState(() => _skill = value),
                    onPriceRangeChanged: (value) =>
                        setState(() => _priceRange = value),
                    onSortChanged: (value) => setState(() => _sort = value),
                    onClear: _clearFilters,
                  ),
                ),
                if (published.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MarketplaceMessage(
                      icon: Icons.design_services_rounded,
                      title: 'No published services yet',
                      message:
                          'SkillForge freelancers will appear here after they publish service offers.',
                      primaryLabel: 'Browse Freelancers',
                      onPrimary: () =>
                          context.goNamed(RouteNames.freelancerDirectory),
                      secondaryLabel: isFreelancer ? 'Create Service' : null,
                      onSecondary: isFreelancer
                          ? () => context.goNamed(RouteNames.freelancerServices)
                          : null,
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MarketplaceMessage(
                      icon: Icons.search_off_rounded,
                      title: 'No services match these filters',
                      message:
                          'Try a broader search, different skill, or wider price range.',
                      primaryLabel: 'Clear Filters',
                      onPrimary: _clearFilters,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                    sliver: SliverToBoxAdapter(
                      child: ResponsiveGrid(
                        minChildWidth: 310,
                        children: filtered
                            .map(
                              (service) => _ServiceMarketplaceCard(
                                service: service,
                                reviewSummary:
                                    reviewSummaries[service.serviceId] ??
                                    ReviewSummary.empty,
                                onView: () => context.pushNamed(
                                  RouteNames.publicServiceDetail,
                                  pathParameters: {
                                    'serviceId': service.serviceId,
                                  },
                                ),
                                onRequest: () => showServiceRequestFormDialog(
                                  context,
                                  service,
                                ),
                              ),
                            )
                            .toList(),
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

  List<FreelancerServiceModel> _filterServices(
    List<FreelancerServiceModel> services,
  ) {
    final query = _query.trim().toLowerCase();
    final filtered = services.where((service) {
      final terms = [
        service.title,
        service.shortDescription,
        service.fullDescription,
        service.category,
        service.freelancerName,
        ...service.tags,
        ...service.linkedSkills,
      ].join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || terms.contains(query);
      final matchesCategory =
          _category == 'All' || service.category == _category;
      final matchesPricing =
          _pricingType == 'All' || service.pricingType == _pricingType;
      final matchesSkill =
          _skill == 'All' ||
          service.tags.contains(_skill) ||
          service.linkedSkills.contains(_skill);
      final matchesPrice =
          service.startingPrice >= _priceRange.start &&
          service.startingPrice <= _priceRange.end;
      return service.isLive &&
          matchesSearch &&
          matchesCategory &&
          matchesPricing &&
          matchesSkill &&
          matchesPrice;
    }).toList();

    filtered.sort((a, b) {
      return switch (_sort) {
        _ServiceSort.priceLow => a.startingPrice.compareTo(b.startingPrice),
        _ServiceSort.priceHigh => b.startingPrice.compareTo(a.startingPrice),
        _ServiceSort.trust => _trustScore(b).compareTo(_trustScore(a)),
        _ServiceSort.inquiries => b.inquiryCount.compareTo(a.inquiryCount),
        _ServiceSort.newest => (b.publishedAt ?? b.updatedAt).compareTo(
          a.publishedAt ?? a.updatedAt,
        ),
      };
    });

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _category = 'All';
      _pricingType = 'All';
      _skill = 'All';
      _priceRange = const RangeValues(0, 5000);
      _sort = _ServiceSort.newest;
    });
  }
}

class _MarketplaceHero extends StatelessWidget {
  const _MarketplaceHero({
    required this.totalServices,
    required this.visibleServices,
    required this.onBack,
  });

  final int totalServices;
  final int visibleServices;
  final VoidCallback onBack;

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
              final isMobile = constraints.maxWidth < 720;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SkillForge Marketplace',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Discover top-tier freelance services backed by verified portfolios and certificates.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
              final badges = Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _TrustBadge(
                    label: '$totalServices Active Services',
                    icon: Icons.work_outline_rounded,
                  ),
                  const _TrustBadge(
                    label: 'Verified Portfolios',
                    icon: Icons.verified_user_rounded,
                  ),
                  const _TrustBadge(
                    label: 'Secure Escrow',
                    icon: Icons.security_rounded,
                  ),
                ],
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, const SizedBox(height: 24), badges],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 40),
                  Flexible(child: badges),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrendingCategories extends StatelessWidget {
  const _TrendingCategories({
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trending Categories',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Categories'),
                  selected: selectedCategory == 'All',
                  onSelected: (val) => onCategoryChanged('All'),
                  showCheckmark: false,
                ),
                const SizedBox(width: 8),
                ...categories
                    .take(12)
                    .map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: selectedCategory == cat,
                          onSelected: (val) =>
                              onCategoryChanged(val ? cat : 'All'),
                          showCheckmark: false,
                        ),
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

class _MarketplaceFilters extends StatelessWidget {
  const _MarketplaceFilters({
    required this.searchController,
    required this.query,
    required this.pricingType,
    required this.skills,
    required this.selectedSkill,
    required this.priceRange,
    required this.sort,
    required this.onSearchChanged,
    required this.onPricingTypeChanged,
    required this.onSkillChanged,
    required this.onPriceRangeChanged,
    required this.onSortChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String query;
  final String pricingType;
  final List<String> skills;
  final String selectedSkill;
  final RangeValues priceRange;
  final _ServiceSort sort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onPricingTypeChanged;
  final ValueChanged<String> onSkillChanged;
  final ValueChanged<RangeValues> onPriceRangeChanged;
  final ValueChanged<_ServiceSort> onSortChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.clear_rounded),
                    ),
              hintText: 'Search services, tags, or freelancer name...',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MenuFilter(
                label: 'Pricing',
                value: pricingType,
                values: const [
                  'All',
                  FreelancerServicePricingType.fixed,
                  FreelancerServicePricingType.hourly,
                ],
                onChanged: onPricingTypeChanged,
              ),
              _MenuFilter(
                label: 'Skill',
                value: selectedSkill,
                values: ['All', ...skills],
                onChanged: onSkillChanged,
              ),
              _MenuFilter<_ServiceSort>(
                label: 'Sort',
                value: sort,
                values: _ServiceSort.values,
                labelBuilder: _sortLabel,
                onChanged: onSortChanged,
              ),
              if (query.isNotEmpty ||
                  pricingType != 'All' ||
                  selectedSkill != 'All' ||
                  sort != _ServiceSort.newest)
                ActionChip(
                  onPressed: onClear,
                  avatar: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Clear Filters'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Price Range',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: RangeSlider(
                  values: priceRange,
                  min: 0,
                  max: 5000,
                  divisions: 20,
                  labels: RangeLabels(
                    '\$${priceRange.start.round()}',
                    '\$${priceRange.end.round()}',
                  ),
                  onChanged: onPriceRangeChanged,
                ),
              ),
              Text(
                '\$${priceRange.start.round()} - \$${priceRange.end.round()}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceMarketplaceCard extends StatelessWidget {
  const _ServiceMarketplaceCard({
    required this.service,
    required this.reviewSummary,
    required this.onView,
    required this.onRequest,
  });

  final FreelancerServiceModel service;
  final ReviewSummary reviewSummary;
  final VoidCallback onView;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ServiceCover(service: service),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (service.verifiedBadge)
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  service.shortDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _FreelancerLine(service: service),
                const SizedBox(height: 10),
                _RatingLine(summary: reviewSummary),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (service.category.trim().isNotEmpty)
                      _ServiceChip(label: service.category),
                    _ServiceChip(
                      label:
                          '${service.currency} ${service.startingPrice.toStringAsFixed(0)} ${service.pricingType}',
                    ),
                    if (service.estimatedDelivery.trim().isNotEmpty)
                      _ServiceChip(label: service.estimatedDelivery),
                    ...service.linkedSkills
                        .take(2)
                        .map((skill) => _ServiceChip(label: skill)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onView,
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        label: const Text('View Service'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onRequest,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Request'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCover extends StatelessWidget {
  const _ServiceCover({required this.service});

  final FreelancerServiceModel service;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.coverImageUrl.trim();
    if (imageUrl.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _CoverFallback(),
        ),
      );
    }
    return const AspectRatio(aspectRatio: 16 / 9, child: _CoverFallback());
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
          color: AppColors.freelancerPrimary,
          size: 42,
        ),
      ),
    );
  }
}

class _FreelancerLine extends StatelessWidget {
  const _FreelancerLine({required this.service});

  final FreelancerServiceModel service;

  @override
  Widget build(BuildContext context) {
    final avatar = service.freelancerAvatarUrl.trim();
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.freelancerPrimary.withValues(alpha: 0.12),
          backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
          child: avatar.isEmpty
              ? Text(
                  _initials(service.freelancerName),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            service.freelancerName.trim().isEmpty
                ? 'SkillForge Freelancer'
                : service.freelancerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = summary.hasReviews
        ? '${summary.averageRating.toStringAsFixed(1)} (${summary.reviewCount} review${summary.reviewCount == 1 ? '' : 's'})'
        : 'No reviews yet';
    return Row(
      children: [
        Icon(
          summary.hasReviews ? Icons.star_rounded : Icons.star_border_rounded,
          color: AppColors.warning,
          size: 18,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.freelancerPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.freelancerPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.freelancerPrimary),
            const SizedBox(width: 8),
          ],
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

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.freelancerPrimary.withValues(alpha: 0.10),
      side: BorderSide(
        color: AppColors.freelancerPrimary.withValues(alpha: 0.16),
      ),
    );
  }
}

class _MenuFilter<T> extends StatelessWidget {
  const _MenuFilter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.labelBuilder,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final String Function(T value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        borderRadius: BorderRadius.circular(16),
        items: values
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text('$label: ${labelBuilder?.call(item) ?? item}'),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _MarketplaceMessage extends StatelessWidget {
  const _MarketplaceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.freelancerPrimary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (primaryLabel != null && onPrimary != null) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel!),
                  ),
                  if (secondaryLabel != null && onSecondary != null)
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<String> _uniqueValues(Iterable<String> values) {
  final unique = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  unique.sort();
  return unique;
}

int _trustScore(FreelancerServiceModel service) {
  var score = 0;
  if (service.verifiedBadge) score += 25;
  if (service.linkedSkills.isNotEmpty) score += 20;
  if (service.linkedCertificateIds.isNotEmpty) score += 20;
  if (service.portfolioLinks.isNotEmpty) score += 15;
  if (service.skillScore > 0) score += service.skillScore.round().clamp(0, 20);
  return score;
}

String _sortLabel(_ServiceSort value) {
  return switch (value) {
    _ServiceSort.newest => 'Newest',
    _ServiceSort.priceLow => 'Price low',
    _ServiceSort.priceHigh => 'Price high',
    _ServiceSort.trust => 'Trust',
    _ServiceSort.inquiries => 'Interest',
  };
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'SF';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
