import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/lms_ui/lms_empty_state.dart';

class CourseBreakpoints {
  const CourseBreakpoints._();

  static const double mobile = 700;
  static const double desktop = 1100;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width <= desktop;
  static bool isDesktop(double width) => width > desktop;
}

class CoursePremiumBackground extends StatelessWidget {
  const CoursePremiumBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Stack(
        children: [
          // Ambient glows
          Positioned(
            top: -100,
            left: -100,
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.08 : 0.04,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -50,
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary.withValues(
                      alpha: isDark ? 0.05 : 0.03,
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class CourseResponsivePadding extends StatelessWidget {
  const CourseResponsivePadding({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.bottomPadding = 32,
  });

  final Widget child;
  final double maxWidth;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontal = CourseBreakpoints.isMobile(width)
            ? 16.0
            : CourseBreakpoints.isTablet(width)
            ? 24.0
            : 32.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                16,
                horizontal,
                bottomPadding,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class CoursePremiumListView extends StatelessWidget {
  const CoursePremiumListView({
    super.key,
    required this.children,
    this.maxWidth = 1180,
    this.bottomPadding = 32,
    this.controller,
    this.physics,
  }) : _itemBuilder = null,
       _itemCount = null;

  const CoursePremiumListView.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    required int itemCount,
    this.maxWidth = 1180,
    this.bottomPadding = 32,
    this.controller,
    this.physics,
  }) : children = const [],
       _itemBuilder = itemBuilder,
       _itemCount = itemCount;

  final List<Widget> children;
  final NullableIndexedWidgetBuilder? _itemBuilder;
  final int? _itemCount;
  final double maxWidth;
  final double bottomPadding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontal = CourseBreakpoints.isMobile(width)
            ? 16.0
            : CourseBreakpoints.isTablet(width)
            ? 24.0
            : 32.0;

        if (_itemBuilder != null) {
          return ListView.builder(
            controller: controller,
            physics: physics,
            padding: EdgeInsets.fromLTRB(
              horizontal,
              16,
              horizontal,
              bottomPadding,
            ),
            itemCount: _itemCount,
            itemBuilder: (context, index) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _itemBuilder(context, index),
                ),
              );
            },
          );
        }

        return ListView(
          controller: controller,
          physics: physics,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            16,
            horizontal,
            bottomPadding,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CourseGlassCard extends StatelessWidget {
  const CourseGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.onTap,
    this.highlightColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surface.withValues(alpha: 0.68)
                : AppColors.lightSurface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  highlightColor?.withValues(alpha: 0.5) ??
                  (isDark
                      ? AppColors.divider.withValues(alpha: 0.75)
                      : AppColors.lightDivider.withValues(alpha: 0.8)),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: (highlightColor ?? Colors.black).withValues(
                        alpha: highlightColor != null ? 0.1 : 0.04,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    final wrapped = margin == null
        ? card
        : Padding(padding: margin!, child: card);
    if (onTap == null) return wrapped;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: wrapped,
    );
  }
}

class CourseHeroHeader extends StatelessWidget {
  const CourseHeroHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < CourseBreakpoints.mobile;
        final iconSize = isMobile ? 52.0 : 64.0;
        final iconRadius = isMobile ? 18.0 : 22.0;
        final content = isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroIcon(icon: icon, size: iconSize, radius: iconRadius),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _HeroCopy(
                          title: title,
                          subtitle: subtitle,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 220),
                        child: trailing!,
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                children: [
                  _HeroIcon(icon: icon, size: iconSize, radius: iconRadius),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _HeroCopy(title: title, subtitle: subtitle),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 20),
                    Flexible(flex: 0, child: trailing!),
                  ],
                ],
              );

        return Container(
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.elevatedSurface
                : AppColors.lightElevatedSurface,
            borderRadius: BorderRadius.circular(isMobile ? 24 : 28),
            border: Border.all(
              color: isDark ? AppColors.divider : AppColors.lightDivider,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: content,
        );
      },
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({
    required this.icon,
    required this.size,
    required this.radius,
  });

  final IconData icon;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: AppColors.primary, size: size * 0.5),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style:
              (compact
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          maxLines: compact ? 4 : 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class CourseSectionTitle extends StatelessWidget {
  const CourseSectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CoursePremiumMessage extends StatelessWidget {
  const CoursePremiumMessage({
    super.key,
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
      child: CourseResponsivePadding(
        maxWidth: 560,
        child: LmsEmptyState(
          icon: icon,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}

Future<void> showTeacherUpgradeDialog({
  required BuildContext context,
  required WidgetRef ref,
  String? title,
  String? message,
}) async {
  if (!context.mounted) return;
  await context.pushNamed(RouteNames.teacherPlans);
}

class CoursePill extends StatelessWidget {
  const CoursePill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class CoursePremiumTextField extends StatelessWidget {
  const CoursePremiumTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.minLines,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final int? minLines;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<dynamic>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters?.cast(),
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.02),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppColors.divider : AppColors.lightDivider,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppColors.divider : AppColors.lightDivider,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
