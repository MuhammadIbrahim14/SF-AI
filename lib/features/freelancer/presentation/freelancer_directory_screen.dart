import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/customer_app_bar.dart';
import '../providers/freelancer_directory_provider.dart';

enum _FreelancerSort {
  profileStrength,
  rating,
  completedGigs,
  hourlyRateLow,
  hourlyRateHigh,
}

class FreelancerDirectoryScreen extends ConsumerStatefulWidget {
  const FreelancerDirectoryScreen({super.key});

  @override
  ConsumerState<FreelancerDirectoryScreen> createState() =>
      _FreelancerDirectoryScreenState();
}

class _FreelancerDirectoryScreenState
    extends ConsumerState<FreelancerDirectoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';
  String _service = 'All';
  double _minRating = 0;
  RangeValues _hourlyRange = const RangeValues(0, 250);
  _FreelancerSort _sort = _FreelancerSort.profileStrength;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(freelancerDirectoryProvider);
    final user = ref.watch(currentUserProvider).value;
    final isCustomer = user?.isCustomerAccount == true;

    return Scaffold(
      appBar: isCustomer ? const CustomerAppBar() : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: directoryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _DirectoryMessage(
            icon: Icons.error_outline_rounded,
            title: 'Freelancer directory unavailable',
            message: error.toString(),
          ),
          data: (profiles) {
            final categories = _uniqueValues(
              profiles.map((profile) => profile.freelancer.category),
            );
            final services = _uniqueValues(
              profiles.expand((profile) => profile.freelancer.services),
            );
            final filtered = _filterProfiles(profiles);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _DirectoryHero(
                    totalFreelancers: profiles.length,
                    visibleFreelancers: filtered.length,
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.goNamed(RouteNames.home),
                    onBrowseServices: () =>
                        context.goNamed(RouteNames.servicesMarketplace),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TrendingServices(
                    services: services,
                    selectedService: _service,
                    onServiceChanged: (value) =>
                        setState(() => _service = value),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FilterPanel(
                    searchController: _searchController,
                    query: _query,
                    categories: categories,
                    selectedCategory: _category,
                    minRating: _minRating,
                    hourlyRange: _hourlyRange,
                    sort: _sort,
                    onSearchChanged: (value) => setState(() => _query = value),
                    onCategoryChanged: (value) =>
                        setState(() => _category = value),
                    onRatingChanged: (value) =>
                        setState(() => _minRating = value),
                    onHourlyRangeChanged: (value) =>
                        setState(() => _hourlyRange = value),
                    onSortChanged: (value) => setState(() => _sort = value),
                    onClear: _clearFilters,
                  ),
                ),
                if (profiles.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DirectoryMessage(
                      icon: Icons.groups_rounded,
                      title: 'No verified freelancers available yet',
                      message:
                          'Freelancers will appear here as they complete their SkillForge profiles.',
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DirectoryMessage(
                      icon: Icons.search_off_rounded,
                      title: 'No freelancers match these filters',
                      message:
                          'Try clearing filters or searching for a broader service category.',
                      actionLabel: 'Clear Filters',
                      onAction: _clearFilters,
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = _columnsForWidth(constraints.maxWidth);
                        final spacing = columns == 1 ? 14.0 : 18.0;
                        final availableWidth =
                            constraints.maxWidth -
                            40 -
                            (spacing * (columns - 1));
                        final cardWidth = columns == 1
                            ? constraints.maxWidth - 40
                            : availableWidth / columns;

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                          child: Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: filtered
                                .map(
                                  (profile) => SizedBox(
                                    width: cardWidth,
                                    child: _FreelancerCard(
                                      profile: profile,
                                      onViewProfile: () =>
                                          _showProfilePreview(context, profile),
                                      onRequest: () => context.goNamed(
                                        RouteNames.servicesMarketplace,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<FreelancerDirectoryProfile> _filterProfiles(
    List<FreelancerDirectoryProfile> profiles,
  ) {
    final filtered = profiles.where((profile) {
      final freelancer = profile.freelancer;
      final matchesCategory =
          _category == 'All' || freelancer.category == _category;
      final matchesService =
          _service == 'All' || freelancer.services.contains(_service);
      final matchesRating = freelancer.rating >= _minRating;
      final rate = freelancer.hourlyRate;
      final matchesRate =
          rate <= 0 || (rate >= _hourlyRange.start && rate <= _hourlyRange.end);
      return profile.matchesSearch(_query) &&
          matchesCategory &&
          matchesService &&
          matchesRating &&
          matchesRate;
    }).toList();

    filtered.sort((a, b) {
      return switch (_sort) {
        _FreelancerSort.rating => b.freelancer.rating.compareTo(
          a.freelancer.rating,
        ),
        _FreelancerSort.completedGigs => b.freelancer.completedGigs.compareTo(
          a.freelancer.completedGigs,
        ),
        _FreelancerSort.hourlyRateLow => a.freelancer.hourlyRate.compareTo(
          b.freelancer.hourlyRate,
        ),
        _FreelancerSort.hourlyRateHigh => b.freelancer.hourlyRate.compareTo(
          a.freelancer.hourlyRate,
        ),
        _FreelancerSort.profileStrength => b.profileStrength.compareTo(
          a.profileStrength,
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
      _service = 'All';
      _minRating = 0;
      _hourlyRange = const RangeValues(0, 250);
      _sort = _FreelancerSort.profileStrength;
    });
  }
}

class _DirectoryHero extends StatelessWidget {
  const _DirectoryHero({
    required this.totalFreelancers,
    required this.visibleFreelancers,
    required this.onBack,
    required this.onBrowseServices,
  });

  final int totalFreelancers;
  final int visibleFreelancers;
  final VoidCallback onBack;
  final VoidCallback onBrowseServices;

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
              final isMobile = constraints.maxWidth < 700;
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
                    'SkillForge Experts',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hire verified talent backed by real-world portfolios and platform certificates.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );

              final stats = Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HeroStat(
                    label: 'Available',
                    value: '$totalFreelancers',
                    icon: Icons.group_rounded,
                  ),
                  _HeroStat(
                    label: 'Matched',
                    value: '$visibleFreelancers',
                    icon: Icons.search_rounded,
                  ),
                ],
              );
              final browseButton = OutlinedButton.icon(
                onPressed: onBrowseServices,
                icon: const Icon(Icons.design_services_rounded, size: 18),
                label: const Text('Browse Services'),
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const SizedBox(height: 24),
                    stats,
                    const SizedBox(height: 24),
                    browseButton,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 40),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [stats, const SizedBox(height: 24), browseButton],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrendingServices extends StatelessWidget {
  const _TrendingServices({
    required this.services,
    required this.selectedService,
    required this.onServiceChanged,
  });

  final List<String> services;
  final String selectedService;
  final ValueChanged<String> onServiceChanged;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trending Services',
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
                  label: const Text('All Services'),
                  selected: selectedService == 'All',
                  onSelected: (val) => onServiceChanged('All'),
                  showCheckmark: false,
                ),
                const SizedBox(width: 8),
                ...services
                    .take(12)
                    .map(
                      (srv) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(srv),
                          selected: selectedService == srv,
                          onSelected: (val) =>
                              onServiceChanged(val ? srv : 'All'),
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.freelancerPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.freelancerPrimary.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.freelancerPrimary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.freelancerPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.query,
    required this.categories,
    required this.selectedCategory,
    required this.minRating,
    required this.hourlyRange,
    required this.sort,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onRatingChanged,
    required this.onHourlyRangeChanged,
    required this.onSortChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String query;
  final List<String> categories;
  final String selectedCategory;
  final double minRating;
  final RangeValues hourlyRange;
  final _FreelancerSort sort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<double> onRatingChanged;
  final ValueChanged<RangeValues> onHourlyRangeChanged;
  final ValueChanged<_FreelancerSort> onSortChanged;
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
              hintText: 'Search by name, service, skill, or category...',
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
                label: 'Category',
                value: selectedCategory,
                values: ['All', ...categories],
                onChanged: onCategoryChanged,
              ),
              _MenuFilter<_FreelancerSort>(
                label: 'Sort',
                value: sort,
                values: _FreelancerSort.values,
                labelBuilder: _sortLabel,
                onChanged: onSortChanged,
              ),
              FilterChip(
                selected: minRating >= 4,
                label: const Text('4+ Rating'),
                onSelected: (selected) => onRatingChanged(selected ? 4 : 0),
              ),
              if (query.isNotEmpty ||
                  selectedCategory != 'All' ||
                  sort != _FreelancerSort.profileStrength ||
                  minRating > 0)
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
                'Hourly rate',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: RangeSlider(
                  values: hourlyRange,
                  min: 0,
                  max: 250,
                  divisions: 10,
                  labels: RangeLabels(
                    '\$${hourlyRange.start.round()}',
                    '\$${hourlyRange.end.round()}',
                  ),
                  onChanged: onHourlyRangeChanged,
                ),
              ),
              Text(
                '\$${hourlyRange.start.round()} - \$${hourlyRange.end.round()}',
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

class _FreelancerCard extends StatelessWidget {
  const _FreelancerCard({
    required this.profile,
    required this.onViewProfile,
    required this.onRequest,
  });

  final FreelancerDirectoryProfile profile;
  final VoidCallback onViewProfile;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final freelancer = profile.freelancer;
    final colorScheme = Theme.of(context).colorScheme;
    final title = freelancer.professionalTitle.trim().isEmpty
        ? 'SkillForge Service Provider'
        : freelancer.professionalTitle.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final previewServices = freelancer.services.take(2).toList();
        final previewSkills = freelancer.skills.take(3).toList();
        final hiddenItems =
            (freelancer.services.length - previewServices.length).clamp(0, 99) +
            (freelancer.skills.length - previewSkills.length).clamp(0, 99);

        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.freelancerPrimary.withValues(
                        alpha: 0.14,
                      ),
                      backgroundImage: (profile.avatarUrl ?? '').trim().isEmpty
                          ? null
                          : NetworkImage(profile.avatarUrl!),
                      child: (profile.avatarUrl ?? '').trim().isEmpty
                          ? Text(
                              _initials(profile.displayName),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (freelancer.category.trim().isNotEmpty)
                      _Badge(
                        label: freelancer.category,
                        icon: Icons.category_rounded,
                      ),
                    if (freelancer.hourlyRate > 0)
                      _Badge(
                        label:
                            '\$${freelancer.hourlyRate.toStringAsFixed(0)}/hr',
                        icon: Icons.payments_rounded,
                      ),
                    if (freelancer.rating > 0)
                      _Badge(
                        label: freelancer.rating.toStringAsFixed(1),
                        icon: Icons.star_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _TrustBar(profile: profile, compact: true),
                const SizedBox(height: 12),
                if (previewServices.isNotEmpty || previewSkills.isNotEmpty) ...[
                  Text(
                    'Top signals',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...previewServices.map(_ServiceChip.new),
                      ...previewSkills.map(_SkillChip.new),
                      if (hiddenItems > 0)
                        _MoreChip(label: '+$hiddenItems more'),
                    ],
                  ),
                ] else
                  Text(
                    'View profile for full freelancer details.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 16),
                if (isNarrow)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onViewProfile,
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        label: const Text('View Profile'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: onRequest,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Request'),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onViewProfile,
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          label: const Text('View Profile'),
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
        );
      },
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.freelancerPrimary.withValues(alpha: 0.10),
    );
  }
}

class _TrustBar extends StatelessWidget {
  const _TrustBar({required this.profile, this.compact = false});

  final FreelancerDirectoryProfile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Badge(
          label: '${profile.profileStrength}% profile',
          icon: Icons.verified_user_rounded,
          color: AppColors.freelancerPrimary,
        ),
        if (!compact && profile.portfolioLinksCount > 0)
          _Badge(
            label: '${profile.portfolioLinksCount} portfolio links',
            icon: Icons.link_rounded,
            color: AppColors.freelancerSecondary,
          ),
        if (compact && profile.portfolioLinksCount > 0)
          _Badge(
            label: '${profile.portfolioLinksCount} links',
            icon: Icons.link_rounded,
            color: AppColors.freelancerSecondary,
          ),
        if (!compact && profile.freelancer.experienceYears > 0)
          _Badge(
            label: '${profile.freelancer.experienceYears}+ yrs',
            icon: Icons.timeline_rounded,
            color: AppColors.info,
          ),
        if (compact && profile.freelancer.completedGigs > 0)
          _Badge(
            label: '${profile.freelancer.completedGigs} gigs',
            icon: Icons.task_alt_rounded,
            color: AppColors.freelancerSecondary,
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    this.color = AppColors.freelancerPrimary,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      avatar: const Icon(Icons.handyman_rounded, size: 16),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

void _showProfilePreview(
  BuildContext context,
  FreelancerDirectoryProfile profile,
) {
  final freelancer = profile.freelancer;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(profile.displayName),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                freelancer.professionalTitle.trim().isEmpty
                    ? 'SkillForge Service Provider'
                    : freelancer.professionalTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (profile.location.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(profile.location),
              ],
              const SizedBox(height: 12),
              _TrustBar(profile: profile),
              const SizedBox(height: 14),
              Text(
                freelancer.bio.trim().isEmpty
                    ? 'This freelancer has not added a public bio yet.'
                    : freelancer.bio,
              ),
              const SizedBox(height: 14),
              if (freelancer.services.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: freelancer.services.map(_ServiceChip.new).toList(),
                ),
              const SizedBox(height: 14),
              if (freelancer.skills.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: freelancer.skills.map(_SkillChip.new).toList(),
                ),
              if (profile.portfolioLinksCount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Proof links are available on this freelancer profile. Use the links and social handles as read-only trust signals until project requests are enabled.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.goNamed(RouteNames.servicesMarketplace);
          },
          child: const Text('Request Project'),
        ),
      ],
    ),
  );
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

int _columnsForWidth(double width) {
  if (width >= 1280) return 4;
  if (width >= 920) return 3;
  if (width >= 620) return 2;
  return 1;
}

String _sortLabel(_FreelancerSort value) {
  return switch (value) {
    _FreelancerSort.profileStrength => 'Profile strength',
    _FreelancerSort.rating => 'Rating',
    _FreelancerSort.completedGigs => 'Completed gigs',
    _FreelancerSort.hourlyRateLow => 'Rate low',
    _FreelancerSort.hourlyRateHigh => 'Rate high',
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
