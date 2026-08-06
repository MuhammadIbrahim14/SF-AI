import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/models/legal_policy.dart';
import '../providers/legal_provider.dart';

/// Shared public viewer for CMS-backed legal documents.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fallbackSections,
    required this.selectSections,
    this.accent = AppColors.primary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<LegalSection> fallbackSections;
  final List<LegalSection> Function(LegalPolicies policies) selectSections;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final policiesAsync = ref.watch(legalPoliciesProvider);

    var sections = fallbackSections;
    var lastUpdated = 'Last updated: July 17, 2026';
    var version = '1.0.0';

    final policies = policiesAsync.value;
    if (policies != null) {
      final cms = selectSections(policies);
      if (cms.isNotEmpty) sections = cms;
      version = policies.version;
      lastUpdated =
          'Updated ${DateFormat.yMMMMd().format(policies.updatedAt)} · v$version';
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: isDark ? AppColors.background : AppColors.lightBackground,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.home);
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _LegalHeroBanner(
                title: title,
                subtitle: subtitle,
                icon: icon,
                accent: accent,
                isDark: isDark,
                lastUpdated: lastUpdated,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: Icons.verified_user_outlined,
                    label: 'Public policy',
                    color: accent,
                  ),
                  _MetaChip(
                    icon: Icons.auto_stories_outlined,
                    label: '${sections.length} sections',
                    color: AppColors.secondary,
                  ),
                  _MetaChip(
                    icon: Icons.history_rounded,
                    label: 'v$version',
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            sliver: SliverList.separated(
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _LegalSectionCard(
                  index: index,
                  section: sections[index],
                  accent: accent,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalHeroBanner extends StatelessWidget {
  const _LegalHeroBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.isDark,
    required this.lastUpdated,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool isDark;
  final String lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  accent.withValues(alpha: 0.45),
                  AppColors.background,
                  AppColors.secondary.withValues(alpha: 0.18),
                ]
              : [
                  accent.withValues(alpha: 0.22),
                  Colors.white,
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.55),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(icon, color: accent, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  lastUpdated,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionCard extends StatefulWidget {
  const _LegalSectionCard({
    required this.index,
    required this.section,
    required this.accent,
    required this.isDark,
  });

  final int index;
  final LegalSection section;
  final Color accent;
  final bool isDark;

  @override
  State<_LegalSectionCard> createState() => _LegalSectionCardState();
}

class _LegalSectionCardState extends State<_LegalSectionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 320 + (widget.index * 40).clamp(0, 240)),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: widget.isDark ? AppColors.elevatedSurface : Colors.white,
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(
                  alpha: widget.isDark ? 0.12 : 0.06,
                ),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      widget.accent,
                      widget.accent.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.section.body,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.75,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReturnRefundPolicyScreen extends ConsumerWidget {
  const ReturnRefundPolicyScreen({super.key});

  static const fallback = [
    LegalSection(
      title: 'Scope',
      body:
          'This Return & Refund Policy applies to digital purchases on SkillForge AI, including teacher plans, AI credit packs, paid courses, wallet top-ups, and freelancer service orders paid through our payment partners (including PayFast Pakistan).',
    ),
    LegalSection(
      title: 'Digital nature of products',
      body:
          'SkillForge AI primarily sells digital products and services. There is no physical merchandise to return. Access to courses, credits, subscriptions, and delivered freelance work is considered a digital service delivery.',
    ),
    LegalSection(
      title: 'Eligible refunds',
      body:
          'Refunds may be considered when: (1) a payment was charged twice for the same order, (2) a technical failure prevented delivery of a paid plan, credits, or course access after successful payment, or (3) a freelancer service order was cancelled before work started and escrow/payment rules allow a refund. Fraudulent or unauthorized transactions reported promptly may also be reviewed.',
    ),
    LegalSection(
      title: 'Non-refundable cases',
      body:
          'Unless required by applicable law, refunds are generally not available after digital access has been granted and used (for example consumed AI credits, started course content, or completed freelance milestones), for change-of-mind after successful delivery, or for violations of the Terms of Service that lead to account suspension.',
    ),
    LegalSection(
      title: 'How to request a refund',
      body:
          'Submit a request via Contact Support in the app, or email the platform support channel listed on the Contact page. Include your account email, payment/transaction reference, purchase date, and reason. We aim to acknowledge requests within 3–5 business days.',
    ),
    LegalSection(
      title: 'Refund processing',
      body:
          'Approved refunds are returned through the original payment method via our payment gateway where supported. Bank/wallet timelines may take additional business days after PayFast (or the relevant provider) processes the reversal. Platform fees already settled with third parties may affect the refundable amount as disclosed at checkout.',
    ),
    LegalSection(
      title: 'Subscriptions',
      body:
          'Teacher or other recurring plans cancelled mid-cycle keep access until the end of the paid period when cancel-at-period-end applies. Unused time after cancellation is typically non-refundable unless a billing error is confirmed.',
    ),
    LegalSection(
      title: 'Contact',
      body:
          'For refund questions use Contact Support in SkillForge AI, or the local contact details published on our Contact / Support page.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LegalDocumentScreen(
      title: 'Return & Refund Policy',
      subtitle: 'How SkillForge AI handles digital purchase refunds.',
      icon: Icons.replay_circle_filled_rounded,
      accent: AppColors.warning,
      fallbackSections: fallback,
      selectSections: (p) => p.returnRefundPolicy,
    );
  }
}

class ShippingServicePolicyScreen extends ConsumerWidget {
  const ShippingServicePolicyScreen({super.key});

  static const fallback = [
    LegalSection(
      title: 'Digital delivery (no physical shipping)',
      body:
          'SkillForge AI is a digital platform. We do not ship physical goods. “Shipping / Service delivery” means how digital access and freelance services are provided after payment.',
    ),
    LegalSection(
      title: 'Courses and learning content',
      body:
          'After a successful paid course purchase, enrollment and course access are activated in the student account. Delivery is online through the SkillForge AI app/web experience.',
    ),
    LegalSection(
      title: 'Plans and AI credit packs',
      body:
          'Teacher plans and credit packs are activated on the account shortly after payment confirmation from our payment gateway. Credits and plan entitlements appear in billing / AI usage areas of the app.',
    ),
    LegalSection(
      title: 'Wallet top-ups',
      body:
          'Customer or freelancer wallet balances are credited after successful payment confirmation. Use of wallet funds follows marketplace / commerce rules inside the app.',
    ),
    LegalSection(
      title: 'Freelancer services',
      body:
          'Service orders are delivered digitally (files, links, revisions, or agreed online work). Delivery timelines are those agreed in the service request, packages, or order milestones between client and freelancer. Escrow release follows platform commerce rules after delivery acceptance or the configured hold period.',
    ),
    LegalSection(
      title: 'Delays and failures',
      body:
          'If payment succeeds but access is not granted due to a technical issue, contact Support with your transaction reference. We will restore access or process a refund per the Return & Refund Policy.',
    ),
    LegalSection(
      title: 'Service area',
      body:
          'SkillForge AI is available online. Users may access digital services from Pakistan and other regions where the app is offered, subject to account verification and applicable law.',
    ),
    LegalSection(
      title: 'Contact & local support',
      body:
          'For delivery issues, use Contact Support in the app. Local office address and phone number (when published for your deployment) appear on the Contact / Support page and home footer links.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LegalDocumentScreen(
      title: 'Shipping & Service Policy',
      subtitle: 'How SkillForge AI delivers digital products and services.',
      icon: Icons.local_shipping_outlined,
      accent: AppColors.accent,
      fallbackSections: fallback,
      selectSections: (p) => p.shippingServicePolicy,
    );
  }
}
