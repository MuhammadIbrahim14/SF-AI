import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/profile_provider.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';

typedef ProfileSectionBuilder =
    Widget Function(BuildContext context, ProfileData profile);

class ProfileSectionScaffold extends ConsumerWidget {
  const ProfileSectionScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final ProfileSectionBuilder builder;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _SectionMessage(
        icon: Icons.error_outline_rounded,
        message: error.toString(),
      ),
      data: (profile) {
        if (profile == null) {
          return const _SectionMessage(
            icon: Icons.person_off_outlined,
            message: 'Profile data is not available.',
          );
        }

        return RoleFixedHeaderPage(
          role: profile.role,
          title: title,
          subtitle: subtitle,
          showBackButton: true,
          actions: actions,
          scrollable: true,
          maxWidth: 900,
          child: builder(context, profile),
        );
      },
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    required this.accentColor,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...children.asMap().entries.map((entry) {
            final index = entry.key;
            final child = entry.value;
            final isLast = index == children.length - 1;

            return Column(
              children: [
                child,
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 32),
                    child: Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({super.key, required this.label, required this.value});

  final String label;
  final Object? value;

  IconData _getIconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('name')) return Icons.person_rounded;
    if (l.contains('email')) return Icons.email_rounded;
    if (l.contains('phone')) return Icons.phone_rounded;
    if (l.contains('gender')) return Icons.wc_rounded;
    if (l.contains('birth')) return Icons.cake_rounded;
    if (l.contains('country') || l.contains('city') || l.contains('location')) {
      return Icons.location_on_rounded;
    }
    if (l.contains('bio') || l.contains('description')) {
      return Icons.description_rounded;
    }
    if (l.contains('education') ||
        l.contains('degree') ||
        l.contains('institute') ||
        l.contains('study')) {
      return Icons.school_rounded;
    }
    if (l.contains('experience') || l.contains('year')) {
      return Icons.work_history_rounded;
    }
    if (l.contains('specialization') || l.contains('industry')) {
      return Icons.star_rounded;
    }
    if (l.contains('certification')) return Icons.workspace_premium_rounded;
    if (l.contains('service') || l.contains('skill')) {
      return Icons.build_rounded;
    }
    if (l.contains('rate')) return Icons.attach_money_rounded;
    if (l.contains('company')) return Icons.business_rounded;
    if (l.contains('size')) return Icons.groups_rounded;
    if (l.contains('website')) return Icons.language_rounded;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final text = profileDisplayValue(value);
    final isMissing = text == 'Not added';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForLabel(label),
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isMissing ? FontWeight.w500 : FontWeight.w700,
                    color: isMissing
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : colorScheme.onSurface,
                    height: 1.4,
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

class ProfileChipGroup extends StatelessWidget {
  const ProfileChipGroup({
    super.key,
    required this.values,
    this.emptyLabel = 'Nothing added yet',
  });

  final Iterable<Object?> values;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final items = values
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => Chip(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              label: Text(item),
            ),
          )
          .toList(),
    );
  }
}

class ProfileLinkTile extends StatelessWidget {
  const ProfileLinkTile({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = profileDisplayValue(value);
    final isMissing = displayValue == 'Not added';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isMissing
                          ? theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            )
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMissing)
              Icon(
                Icons.open_in_new_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

String profileDisplayValue(Object? value) {
  if (value == null) return 'Not added';
  if (value is num && value == 0) return 'Not added';
  final text = value.toString().trim();
  return text.isEmpty ? 'Not added' : text;
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
