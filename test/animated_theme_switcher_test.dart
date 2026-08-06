import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillforge_ai/shared/widgets/animated_theme_switcher.dart';

const Duration _kSequence = Duration(milliseconds: 1100);

/// Mirrors the real `app.dart` wiring: the switcher lives inside
/// `MaterialApp.builder`, below `AnimatedTheme`, above the router content.
Widget _harness({
  required bool isDark,
  required VoidCallback onBuild,
  bool enabled = true,
}) {
  return MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationDuration: const Duration(milliseconds: 420),
    builder: (context, child) {
      onBuild();
      return AnimatedThemeSwitcher(
        isDark: isDark,
        enabled: enabled,
        duration: _kSequence,
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: const Scaffold(body: Center(child: Text('content'))),
  );
}

Matrix4 _panelMatrix(WidgetTester tester) {
  // The panel slide is the only Transform that carries a perspective entry.
  return tester
      .widgetList<Transform>(find.byType(Transform))
      .map((t) => t.transform)
      .firstWhere((m) => m.entry(3, 2) != 0);
}

double _panelDx(WidgetTester tester) => _panelMatrix(tester).getTranslation().x;

double _containerScale(WidgetTester tester) {
  final scaled = tester
      .widgetList<Transform>(find.byType(Transform))
      .map((t) => t.transform)
      .firstWhere((m) => m.entry(3, 2) == 0);
  return scaled.getTranslation().x == 0
      ? scaled.entry(0, 0)
      : scaled.entry(0, 0);
}

Brightness _contentBrightness(WidgetTester tester) {
  return Theme.of(tester.element(find.text('content'))).brightness;
}

void main() {
  testWidgets('plays the full sequence when the theme flips', (tester) async {
    var isDark = true;
    var builds = 0;

    Future<void> pumpWith(bool dark) =>
        tester.pumpWidget(_harness(isDark: dark, onBuild: () => builds++));

    await pumpWith(isDark);
    expect(builds, greaterThan(0));
    expect(_panelDx(tester), 0, reason: 'idle panel must not be displaced');

    isDark = false;
    await pumpWith(isDark);
    await tester.pump(const Duration(milliseconds: 180));

    // RECEDE: the frame has pulled backwards.
    expect(_containerScale(tester), lessThan(0.95));

    // EXIT: the panel has left the frame to the RIGHT.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_panelDx(tester), greaterThan(0));

    // ENTER: it comes back from the LEFT.
    await tester.pump(const Duration(milliseconds: 120));
    expect(_panelDx(tester), lessThan(0));

    // SETTLE: everything returns to a clean pass-through.
    await tester.pumpAndSettle();
    expect(_panelDx(tester), 0);
    expect(_containerScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('outgoing panel keeps the old palette until it is off screen', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(isDark: true, onBuild: () {}));
    expect(_contentBrightness(tester), Brightness.dark);

    await tester.pumpWidget(_harness(isDark: false, onBuild: () {}));

    // Mid-exit the panel is still on its way out and must still look dark.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_panelDx(tester), greaterThan(0));
    expect(_contentBrightness(tester), Brightness.dark);

    // Once it is outside the frame the palette has swapped.
    await tester.pump(const Duration(milliseconds: 230));
    expect(_contentBrightness(tester), Brightness.light);

    await tester.pumpAndSettle();
    expect(_contentBrightness(tester), Brightness.light);
  });

  testWidgets('platform reduced-motion does not compress the sequence', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(_harness(isDark: true, onBuild: () {}));
    await tester.pumpWidget(_harness(isDark: false, onBuild: () {}));

    // With AnimationBehavior.normal this would already be finished (the
    // framework compresses such controllers to 5% of their duration ≈ 55ms).
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      _panelDx(tester),
      isNot(0),
      reason: 'sequence must still be mid-flight, not collapsed to a frame',
    );

    await tester.pumpAndSettle();
    expect(_panelDx(tester), 0);
  });

  testWidgets('respects the app motion setting when disabled', (tester) async {
    await tester.pumpWidget(
      _harness(isDark: true, onBuild: () {}, enabled: false),
    );
    await tester.pumpWidget(
      _harness(isDark: false, onBuild: () {}, enabled: false),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(_panelDx(tester), 0);
    expect(_containerScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));

    await tester.pumpAndSettle();
    expect(_contentBrightness(tester), Brightness.light);
  });
}
