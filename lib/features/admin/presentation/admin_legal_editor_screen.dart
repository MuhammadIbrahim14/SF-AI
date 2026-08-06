import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../legal/domain/models/legal_policy.dart';
import '../../legal/presentation/return_refund_policy_screen.dart';
import '../../legal/providers/legal_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminLegalEditorScreen extends ConsumerStatefulWidget {
  const AdminLegalEditorScreen({super.key});

  @override
  ConsumerState<AdminLegalEditorScreen> createState() =>
      _AdminLegalEditorScreenState();
}

class _AdminLegalEditorScreenState extends ConsumerState<AdminLegalEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LegalPolicies? _editedPolicies;
  bool _isDirty = false;

  static const _docs = [
    _LegalDocMeta(
      title: 'Privacy Policy',
      short: 'Privacy',
      icon: Icons.shield_outlined,
      accent: AppColors.primary,
      blurb: 'How SkillForge collects and protects user data.',
    ),
    _LegalDocMeta(
      title: 'Terms of Service',
      short: 'Terms',
      icon: Icons.gavel_rounded,
      accent: AppColors.secondary,
      blurb: 'Platform rules, roles, and acceptable use.',
    ),
    _LegalDocMeta(
      title: 'Account Deletion',
      short: 'Deletion',
      icon: Icons.person_remove_outlined,
      accent: AppColors.error,
      blurb: 'How account removal requests are handled.',
    ),
    _LegalDocMeta(
      title: 'Return & Refund',
      short: 'Refunds',
      icon: Icons.replay_circle_filled_outlined,
      accent: AppColors.warning,
      blurb: 'Digital purchase refunds and billing corrections.',
    ),
    _LegalDocMeta(
      title: 'Shipping & Service',
      short: 'Delivery',
      icon: Icons.local_shipping_outlined,
      accent: AppColors.accent,
      blurb: 'How digital products and services are delivered.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _docs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializePolicies(LegalPolicies? current) {
    if (_editedPolicies == null && !_isDirty) {
      var policies = current ?? LegalPolicies(updatedAt: DateTime.now());
      var seeded = false;
      if (policies.returnRefundPolicy.isEmpty) {
        policies = policies.copyWith(
          returnRefundPolicy: ReturnRefundPolicyScreen.fallback,
        );
        seeded = true;
      }
      if (policies.shippingServicePolicy.isEmpty) {
        policies = policies.copyWith(
          shippingServicePolicy: ShippingServicePolicyScreen.fallback,
        );
        seeded = true;
      }
      _editedPolicies = policies;
      if (seeded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isDirty = true);
        });
      }
    }
  }

  void _markDirty() => setState(() => _isDirty = true);

  Future<void> _savePolicies() async {
    if (_editedPolicies == null) return;
    final success = await ref
        .read(legalEditorProvider.notifier)
        .savePolicies(_editedPolicies!);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Legal policies published successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _isDirty = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(legalEditorProvider).error?.toString() ??
                'Failed to publish policies.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<LegalSection> _sectionsFor(int index) {
    final p = _editedPolicies!;
    switch (index) {
      case 0:
        return p.privacyPolicy;
      case 1:
        return p.termsOfService;
      case 2:
        return p.accountDeletion;
      case 3:
        return p.returnRefundPolicy;
      case 4:
        return p.shippingServicePolicy;
      default:
        return const [];
    }
  }

  void _setSections(int index, List<LegalSection> next) {
    switch (index) {
      case 0:
        _editedPolicies = _editedPolicies!.copyWith(privacyPolicy: next);
      case 1:
        _editedPolicies = _editedPolicies!.copyWith(termsOfService: next);
      case 2:
        _editedPolicies = _editedPolicies!.copyWith(accountDeletion: next);
      case 3:
        _editedPolicies = _editedPolicies!.copyWith(returnRefundPolicy: next);
      case 4:
        _editedPolicies =
            _editedPolicies!.copyWith(shippingServicePolicy: next);
    }
    _markDirty();
  }

  @override
  Widget build(BuildContext context) {
    final policiesAsync = ref.watch(legalPoliciesProvider);
    final isSaving = ref.watch(legalEditorProvider).isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LoadingOverlay(
      isLoading: isSaving,
      message: 'Publishing policies...',
      child: AdminControlScaffold(
        title: 'Legal & Governance',
        subtitle:
            'Craft public policies for Privacy, Terms, Refunds, and Delivery — then publish live.',
        currentPath: RoutePaths.adminLegalEditor,
        actions: [
          if (_isDirty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _savePolicies,
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: const Text('Publish'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
        ],
        body: policiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (policies) {
            _initializePolicies(policies);
            if (_editedPolicies == null) {
              return const Center(child: Text('Failed to initialize.'));
            }

            final active = _tabController.index.clamp(0, _docs.length - 1);
            final meta = _docs[active];
            final sections = _sectionsFor(active);

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GovernanceHero(
                          isDark: isDark,
                          isDirty: _isDirty,
                          version: _editedPolicies!.version,
                          updatedAt: _editedPolicies!.updatedAt,
                          sectionCount: sections.length,
                          activeTitle: meta.title,
                        ),
                        const SizedBox(height: 16),
                        _PolicyTabStrip(
                          controller: _tabController,
                          docs: _docs,
                          sectionCounts: List.generate(
                            _docs.length,
                            (i) => _sectionsFor(i).length,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PolicyWorkspace(
                          meta: meta,
                          sections: sections,
                          onChanged: (next) => _setSections(active, next),
                          onAdd: () {
                            final next = List<LegalSection>.from(sections)
                              ..add(
                                const LegalSection(
                                  title: 'New Section',
                                  body: 'Write clear policy language here…',
                                ),
                              );
                            _setSections(active, next);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LegalDocMeta {
  const _LegalDocMeta({
    required this.title,
    required this.short,
    required this.icon,
    required this.accent,
    required this.blurb,
  });

  final String title;
  final String short;
  final IconData icon;
  final Color accent;
  final String blurb;
}

class _GovernanceHero extends StatelessWidget {
  const _GovernanceHero({
    required this.isDark,
    required this.isDirty,
    required this.version,
    required this.updatedAt,
    required this.sectionCount,
    required this.activeTitle,
  });

  final bool isDark;
  final bool isDirty;
  final String version;
  final DateTime updatedAt;
  final int sectionCount;
  final String activeTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.28),
                  AppColors.secondary.withValues(alpha: 0.12),
                  AppColors.elevatedSurface,
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.14),
                  AppColors.secondary.withValues(alpha: 0.08),
                  Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 720;
          final stats = [
            _HeroStat(
              label: 'Document',
              value: activeTitle,
              icon: Icons.description_outlined,
            ),
            _HeroStat(
              label: 'Sections',
              value: '$sectionCount',
              icon: Icons.view_agenda_outlined,
            ),
            _HeroStat(
              label: 'Version',
              value: 'v$version',
              icon: Icons.tag_rounded,
            ),
            _HeroStat(
              label: 'Updated',
              value: DateFormat.MMMd().add_jm().format(updatedAt),
              icon: Icons.schedule_rounded,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Policy Command Center',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Edit once — published copy powers public legal pages for PayFast & trust.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDirty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Unpublished changes',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: stats
                    .map(
                      (s) => SizedBox(
                        width: wide ? (constraints.maxWidth - 50) / 4 : null,
                        child: s,
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
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

class _PolicyTabStrip extends StatelessWidget {
  const _PolicyTabStrip({
    required this.controller,
    required this.docs,
    required this.sectionCounts,
  });

  final TabController controller;
  final List<_LegalDocMeta> docs;
  final List<int> sectionCounts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final doc = docs[index];
          final selected = controller.index == index;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => controller.animateTo(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: selected
                      ? LinearGradient(
                          colors: [
                            doc.accent,
                            doc.accent.withValues(alpha: 0.75),
                          ],
                        )
                      : null,
                  color: selected
                      ? null
                      : Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                  border: Border.all(
                    color: selected
                        ? doc.accent
                        : Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.45),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: doc.accent.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      doc.icon,
                      size: 18,
                      color: selected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      doc.short,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.22)
                            : doc.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${sectionCounts[index]}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : doc.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PolicyWorkspace extends StatelessWidget {
  const _PolicyWorkspace({
    required this.meta,
    required this.sections,
    required this.onChanged,
    required this.onAdd,
  });

  final _LegalDocMeta meta;
  final List<LegalSection> sections;
  final ValueChanged<List<LegalSection>> onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: meta.accent.withValues(alpha: 0.08),
            border: Border.all(color: meta.accent.withValues(alpha: 0.25)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(meta.icon, color: meta.accent),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          meta.blurb,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              PrimaryButton(
                text: 'Add Section',
                onPressed: onAdd,
                width: 140,
                height: 40,
              ),
            ],
          ),
        ),
        if (sections.isEmpty)
          _EmptyPolicyState(accent: meta.accent, onAdd: onAdd)
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: true,
            itemCount: sections.length,
            onReorder: (oldIndex, newIndex) {
              final next = List<LegalSection>.from(sections);
              if (newIndex > oldIndex) newIndex -= 1;
              final item = next.removeAt(oldIndex);
              next.insert(newIndex, item);
              onChanged(next);
            },
            itemBuilder: (context, index) {
              final section = sections[index];
              return _SectionEditorCard(
                key: ValueKey('legal_section_${meta.short}_$index'),
                index: index,
                accent: meta.accent,
                section: section,
                onTitle: (val) {
                  final next = List<LegalSection>.from(sections);
                  next[index] = LegalSection(
                    title: val,
                    body: section.body,
                  );
                  onChanged(next);
                },
                onBody: (val) {
                  final next = List<LegalSection>.from(sections);
                  next[index] = LegalSection(
                    title: section.title,
                    body: val,
                  );
                  onChanged(next);
                },
                onDelete: () {
                  final next = List<LegalSection>.from(sections)
                    ..removeAt(index);
                  onChanged(next);
                },
              );
            },
          ),
      ],
    );
  }
}

class _EmptyPolicyState extends StatelessWidget {
  const _EmptyPolicyState({required this.accent, required this.onAdd});

  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          color: accent.withValues(alpha: 0.06),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_outlined, size: 42, color: accent),
            const SizedBox(height: 12),
            Text(
              'No sections yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first policy section to start publishing.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Section'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionEditorCard extends StatelessWidget {
  const _SectionEditorCard({
    super.key,
    required this.index,
    required this.accent,
    required this.section,
    required this.onTitle,
    required this.onBody,
    required this.onDelete,
  });

  final int index;
  final Color accent;
  final LegalSection section;
  final ValueChanged<String> onTitle;
  final ValueChanged<String> onBody;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.elevatedSurface : Colors.white,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: index == 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.7)],
              ),
            ),
            child: Text(
              '${index + 1}'.padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            section.title.isEmpty ? 'Untitled Section' : section.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            section.body.isEmpty
                ? 'Empty body'
                : section.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.drag_indicator_rounded),
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Section Title',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              initialValue: section.title,
              onChanged: onTitle,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Section Body',
                alignLabelWithHint: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              initialValue: section.body,
              maxLines: 8,
              onChanged: onBody,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Section'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
