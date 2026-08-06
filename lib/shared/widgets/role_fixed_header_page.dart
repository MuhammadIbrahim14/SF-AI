import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_role.dart';
import '../../providers/user_provider.dart';
import 'customer_workspace_shell.dart';
import 'github_style_navigation.dart';
import 'responsive_layout.dart';

/// Shared fixed-header wrapper for non-dashboard role pages.
///
/// This intentionally reuses [GitHubStyleNavigationFrame] so role menus,
/// route destinations, colors, profile actions, and logout behavior remain
/// identical to the dashboard shell for professional users.
///
/// If the current user is a customer, it automatically defaults to the
/// lightweight [CustomerWorkspaceShell] instead.
class RoleFixedHeaderPage extends ConsumerWidget {
  const RoleFixedHeaderPage({
    super.key,
    required this.role,
    required this.child,
    this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBack,
    this.actions,
    this.padding,
    this.scrollable = true,
    this.useSafeArea = true,
    this.showHeader = true,
    this.maxWidth = double.infinity,
  });

  final UserRole role;
  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final bool useSafeArea;
  final bool showHeader;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isCustomer = user?.isCustomerAccount ?? false;
    final pageBody = _RoleFixedHeaderPageBody(
      showBackButton: showBackButton && showHeader && !isCustomer,
      actions: actions,
      padding: padding,
      scrollable: scrollable,
      maxWidth: maxWidth,
      child: child,
    );

    if (isCustomer && showHeader) {
      return CustomerWorkspaceShell(
        child: useSafeArea ? SafeArea(child: pageBody) : pageBody,
      );
    }

    final framedBody = showHeader
        ? GitHubStyleNavigationFrame(
            role: role,
            showBackButton: showBackButton,
            onBack: onBack,
            child: pageBody,
          )
        : pageBody;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: useSafeArea ? SafeArea(child: framedBody) : framedBody,
    );
  }
}

class _RoleFixedHeaderPageBody extends StatelessWidget {
  const _RoleFixedHeaderPageBody({
    required this.child,
    required this.showBackButton,
    required this.scrollable,
    required this.maxWidth,
    this.actions,
    this.padding,
  });

  final Widget child;
  final bool showBackButton;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final double maxWidth;

  bool get _hasPageActions => actions != null && actions!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final resolvedPadding = padding ?? AppBreakpoints.pagePadding(width);
        final directionalPadding = resolvedPadding.resolve(
          Directionality.of(context),
        );
        final fixedBackInset = showBackButton ? 56.0 : 0.0;
        Widget constrainIfNeeded(Widget value) {
          if (!maxWidth.isFinite) {
            return SizedBox(width: double.infinity, child: value);
          }
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: value,
          );
        }

        final header = _hasPageActions
            ? Align(
                alignment: Alignment.topCenter,
                child: constrainIfNeeded(
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      directionalPadding.left,
                      directionalPadding.top,
                      directionalPadding.right,
                      0,
                    ),
                    child: _RoleFixedHeaderPageActions(actions: actions!),
                  ),
                ),
              )
            : null;

        final body = maxWidth.isFinite
            ? Align(
                alignment: Alignment.topCenter,
                child: constrainIfNeeded(child),
              )
            : SizedBox(width: double.infinity, child: child);

        final pageContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (fixedBackInset > 0) SizedBox(height: fixedBackInset),
            if (header != null) ...[header, const SizedBox(height: 8)],
            if (scrollable) body else Expanded(child: body),
          ],
        );

        final content = Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: double.infinity, child: pageContent),
        );

        if (!scrollable) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: content,
          );
        }

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: content,
        );
      },
    );
  }
}

class _RoleFixedHeaderPageActions extends StatelessWidget {
  const _RoleFixedHeaderPageActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
          ),
        ],
      ),
    );
  }
}
