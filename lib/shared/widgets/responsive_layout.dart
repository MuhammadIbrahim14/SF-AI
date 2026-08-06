import 'package:flutter/material.dart';

class AppBreakpoints {
  const AppBreakpoints._();

  static const double mobile = 700;
  static const double desktop = 1100;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;

  static EdgeInsets pagePadding(double width) {
    if (isMobile(width)) return const EdgeInsets.fromLTRB(16, 16, 16, 24);
    if (isTablet(width)) return const EdgeInsets.fromLTRB(20, 20, 20, 28);
    return const EdgeInsets.fromLTRB(24, 24, 24, 32);
  }

  static int gridColumns(
    double width, {
    int mobileColumns = 1,
    int tabletColumns = 2,
    int desktopColumns = 3,
    int wideColumns = 4,
  }) {
    if (width >= 1400) return wideColumns;
    if (isDesktop(width)) return desktopColumns;
    if (isTablet(width)) return tabletColumns;
    return mobileColumns;
  }
}

class ResponsivePageWrapper extends StatelessWidget {
  const ResponsivePageWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1240,
    this.scrollable = true,
    this.padding,
    this.controller,
  });

  final Widget child;
  final double maxWidth;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding =
            padding ?? AppBreakpoints.pagePadding(constraints.maxWidth);
        final content = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: resolvedPadding, child: child),
          ),
        );

        if (!scrollable) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: content,
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            controller: controller,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: content,
          ),
        );
      },
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.wideColumns = 4,
    this.spacing = 14,
    this.runSpacing = 14,
    this.minChildWidth = 260,
  });

  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int wideColumns;
  final double spacing;
  final double runSpacing;
  final double minChildWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final preferredColumns = AppBreakpoints.gridColumns(
          width,
          mobileColumns: mobileColumns,
          tabletColumns: tabletColumns,
          desktopColumns: desktopColumns,
          wideColumns: wideColumns,
        );
        final maxColumnsForWidth = (width / minChildWidth).floor().clamp(
          1,
          preferredColumns,
        );
        final columns = maxColumnsForWidth.toInt();
        final rawItemWidth = (width - (spacing * (columns - 1))) / columns;
        final itemWidth = columns == 1
            ? width
            : rawItemWidth.clamp(0, width).toDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: columns == 1 ? width : itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class ResponsiveFormLayout extends StatelessWidget {
  const ResponsiveFormLayout({
    super.key,
    required this.children,
    this.spacing = 16,
    this.maxFieldWidth = 520,
  });

  final List<Widget> children;
  final double spacing;
  final double maxFieldWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);
        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }

        final itemWidth = ((constraints.maxWidth - spacing) / 2).clamp(
          240,
          maxFieldWidth,
        );
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth.toDouble(), child: child),
          ],
        );
      },
    );
  }
}
