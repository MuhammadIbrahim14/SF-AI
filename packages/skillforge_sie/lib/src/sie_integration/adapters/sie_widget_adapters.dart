import 'package:flutter/material.dart';

/// Marks a descendant as an SIE interactive target (no MediaPipe coupling).
final class SieInteractive extends StatelessWidget {
  /// Creates wrapper.
  const SieInteractive({
    required this.child,
    this.targetId,
    this.button = false,
    this.textField = false,
    this.slider = false,
    this.scrollable = false,
    super.key,
  });

  /// Child.
  final Widget child;

  /// Stable target id for hover / select.
  final String? targetId;

  /// Button semantics.
  final bool button;

  /// Text field semantics.
  final bool textField;

  /// Slider semantics.
  final bool slider;

  /// Scrollable semantics.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: targetId,
      button: button,
      textField: textField,
      slider: slider,
      excludeSemantics: false,
      child: child,
    );
  }
}

/// SIE-aware button adapter (ElevatedButton API surface preserved).
final class SieButton extends StatelessWidget {
  /// Creates button.
  const SieButton({
    required this.onPressed,
    required this.child,
    this.sieTargetId,
    this.style,
    super.key,
  });

  /// Press callback.
  final VoidCallback? onPressed;

  /// Child.
  final Widget child;

  /// Optional SIE target id.
  final String? sieTargetId;

  /// Style.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      button: true,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    );
  }
}

/// SIE-aware text field adapter.
final class SieTextField extends StatelessWidget {
  /// Creates text field.
  const SieTextField({
    this.controller,
    this.onChanged,
    this.decoration,
    this.sieTargetId,
    this.obscureText = false,
    super.key,
  });

  /// Controller.
  final TextEditingController? controller;

  /// Change callback.
  final ValueChanged<String>? onChanged;

  /// Decoration.
  final InputDecoration? decoration;

  /// Target id.
  final String? sieTargetId;

  /// Obscure.
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      textField: true,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: decoration,
        obscureText: obscureText,
      ),
    );
  }
}

/// SIE-aware card adapter.
final class SieCard extends StatelessWidget {
  /// Creates card.
  const SieCard({
    required this.child,
    this.sieTargetId,
    this.onTap,
    this.margin,
    this.elevation,
    super.key,
  });

  /// Child.
  final Widget child;

  /// Target id.
  final String? sieTargetId;

  /// Tap.
  final VoidCallback? onTap;

  /// Margin.
  final EdgeInsetsGeometry? margin;

  /// Elevation.
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: margin,
      elevation: elevation,
      child: child,
    );
    return SieInteractive(
      targetId: sieTargetId,
      button: onTap != null,
      child: onTap == null
          ? card
          : InkWell(
              onTap: onTap,
              child: card,
            ),
    );
  }
}

/// SIE-aware scroll view.
final class SieScrollView extends StatelessWidget {
  /// Creates scroll view.
  const SieScrollView({
    required this.child,
    this.controller,
    this.sieTargetId,
    this.padding,
    super.key,
  });

  /// Child.
  final Widget child;

  /// Controller.
  final ScrollController? controller;

  /// Target id.
  final String? sieTargetId;

  /// Padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      scrollable: true,
      child: SingleChildScrollView(
        controller: controller,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// SIE-aware list view.
final class SieListView extends StatelessWidget {
  /// Creates list.
  const SieListView({
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.sieTargetId,
    this.padding,
    super.key,
  });

  /// Count.
  final int itemCount;

  /// Builder.
  final IndexedWidgetBuilder itemBuilder;

  /// Controller.
  final ScrollController? controller;

  /// Target id.
  final String? sieTargetId;

  /// Padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      scrollable: true,
      child: ListView.builder(
        controller: controller,
        itemCount: itemCount,
        padding: padding,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// SIE-aware dialog wrapper (content only — show via [showSieDialog]).
final class SieDialog extends StatelessWidget {
  /// Creates dialog.
  const SieDialog({
    required this.child,
    this.sieTargetId,
    this.title,
    this.actions,
    super.key,
  });

  /// Body.
  final Widget child;

  /// Target id.
  final String? sieTargetId;

  /// Title.
  final Widget? title;

  /// Actions.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      child: AlertDialog(
        title: title,
        content: child,
        actions: actions,
      ),
    );
  }
}

/// Shows a [SieDialog] (host helper).
Future<T?> showSieDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}

/// SIE-aware popup menu button.
final class SieMenu<T> extends StatelessWidget {
  /// Creates menu.
  const SieMenu({
    required this.itemBuilder,
    required this.onSelected,
    this.sieTargetId,
    this.child,
    this.icon,
    super.key,
  });

  /// Items.
  final PopupMenuItemBuilder<T> itemBuilder;

  /// Selection.
  final ValueChanged<T>? onSelected;

  /// Target id.
  final String? sieTargetId;

  /// Child.
  final Widget? child;

  /// Icon.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      button: true,
      child: icon != null
          ? PopupMenuButton<T>(
              itemBuilder: itemBuilder,
              onSelected: onSelected,
              icon: icon,
            )
          : PopupMenuButton<T>(
              itemBuilder: itemBuilder,
              onSelected: onSelected,
              child: child ?? const Icon(Icons.more_vert),
            ),
    );
  }
}

/// SIE-aware dropdown.
final class SieDropdown<T> extends StatelessWidget {
  /// Creates dropdown.
  const SieDropdown({
    required this.items,
    required this.onChanged,
    this.value,
    this.sieTargetId,
    this.hint,
    super.key,
  });

  /// Items.
  final List<DropdownMenuItem<T>> items;

  /// Change.
  final ValueChanged<T?>? onChanged;

  /// Value.
  final T? value;

  /// Target id.
  final String? sieTargetId;

  /// Hint.
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      button: true,
      child: DropdownButton<T>(
        items: items,
        onChanged: onChanged,
        value: value,
        hint: hint,
      ),
    );
  }
}

/// SIE-aware slider.
final class SieSlider extends StatelessWidget {
  /// Creates slider.
  const SieSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.sieTargetId,
    super.key,
  });

  /// Value.
  final double value;

  /// Change.
  final ValueChanged<double>? onChanged;

  /// Min.
  final double min;

  /// Max.
  final double max;

  /// Target id.
  final String? sieTargetId;

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      slider: true,
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
      ),
    );
  }
}

/// SIE-aware tab bar.
final class SieTabBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates tab bar.
  const SieTabBar({
    required this.tabs,
    this.controller,
    this.sieTargetId,
    this.isScrollable = false,
    super.key,
  });

  /// Tabs.
  final List<Widget> tabs;

  /// Controller.
  final TabController? controller;

  /// Target id.
  final String? sieTargetId;

  /// Scrollable.
  final bool isScrollable;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SieInteractive(
      targetId: sieTargetId,
      child: TabBar(
        tabs: tabs,
        controller: controller,
        isScrollable: isScrollable,
      ),
    );
  }
}
