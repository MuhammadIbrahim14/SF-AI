import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_profile_view.dart';
import '../../profile/presentation/widgets/profile_section_scaffold.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const profileView = RoleProfileView(
      role: UserRole.student,
      editRouteName: RouteNames.studentEditProfile,
    );

    return Stack(
      children: [
        profileView,
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _PremiumGlassHintsPanel(
              isMobile: MediaQuery.of(context).size.width < 1200,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumGlassHintsPanel extends StatefulWidget {
  const _PremiumGlassHintsPanel({required this.isMobile});

  final bool isMobile;

  @override
  State<_PremiumGlassHintsPanel> createState() =>
      _PremiumGlassHintsPanelState();
}

class _PremiumGlassHintsPanelState extends State<_PremiumGlassHintsPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = AppColors.studentPrimary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _isExpanded
            ? colorScheme.surfaceContainerLowest.withValues(alpha: 0.85)
            : primaryColor,
        borderRadius: BorderRadius.circular(_isExpanded ? 28 : 32),
        border: Border.all(
          color: _isExpanded
              ? primaryColor.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: _isExpanded ? 0.15 : 0.4),
            blurRadius: _isExpanded ? 40 : 20,
            spreadRadius: _isExpanded ? 8 : 4,
            offset: _isExpanded ? const Offset(0, 12) : const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_isExpanded ? 28 : 32),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _isExpanded ? 24 : 0.001,
            sigmaY: _isExpanded ? 24 : 0.001,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomRight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _isExpanded
                  ? SizedBox(
                      key: const ValueKey('expanded'),
                      width: widget.isMobile
                          ? MediaQuery.of(context).size.width - 48
                          : 380,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height - 100,
                        ),
                        child: _buildExpandedContent(
                          context,
                          theme,
                          colorScheme,
                          primaryColor,
                        ),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('collapsed'),
                      width: 64,
                      height: 64,
                      child: _buildCollapsedContent(
                        context,
                        theme,
                        colorScheme,
                        primaryColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    Color primaryColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = true),
        borderRadius: BorderRadius.circular(32),
        child: const Center(
          child: Icon(Icons.school_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    Color primaryColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Learning Identity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _isExpanded = false),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.onSurface.withValues(
                      alpha: 0.05,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Unlock your potential by completing your profile and showcasing your skills.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ProfileInfoCard(
              title: 'Skill Readiness',
              icon: Icons.trending_up_rounded,
              accentColor: primaryColor,
              children: [
                const ProfileLinkTile(
                  label: 'Complete Portfolio',
                  icon: Icons.work_outline_rounded,
                  value: 'Add projects to stand out',
                ),
                const ProfileLinkTile(
                  label: 'Certifications',
                  icon: Icons.verified_user_outlined,
                  value: 'Earn badges for your skills',
                ),
                const ProfileLinkTile(
                  label: 'Smart Resume',
                  icon: Icons.description_outlined,
                  value: 'Generate ATS-friendly resume',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Improve Readiness'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ProfileInfoCard(
              title: 'Job Match Potential',
              icon: Icons.radar_rounded,
              accentColor: primaryColor,
              children: [
                Text(
                  'Students with completed portfolios get 40% more interview requests from verified companies.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
