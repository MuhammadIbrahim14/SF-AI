import 'package:skillforge_sie/src/sie_calibration/models/sie_calibration_enums.dart';
import 'package:skillforge_sie/src/sie_calibration/models/sie_sensitivity_parameters.dart';
import 'package:skillforge_sie/src/sie_confidence/models/sie_confidence_policy.dart';
import 'package:skillforge_sie/src/sie_cursor/models/sie_cursor_config.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_enums.dart';
import 'package:skillforge_sie/src/sie_gesture/models/sie_gesture_policy.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_configuration_bundle.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_enums.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';

/// Named profile overlays (composable via ordered application).
abstract final class CpmfProfileCatalog {
  /// Overlay for a single profile id (null = identity / no change).
  static CpmfConfigurationBundle? overlayFor(CpmfProfileId id) {
    final base = CpmfConfigurationBundle.builtInDefaults;
    return switch (id) {
      CpmfProfileId.standard => null,
      CpmfProfileId.reducedMotion => base.copyWith(
          version: '1.0.0-reduced-motion',
          cursor: SieCursorMotionConfig.accessibility,
          accessibility: const SieAccessibilityState(reducedMotion: true),
          changeHistory: const ['profile:reducedMotion'],
        ),
      CpmfProfileId.highContrast => base.copyWith(
          version: '1.0.0-high-contrast',
          accessibility: const SieAccessibilityState(highContrast: true),
          changeHistory: const ['profile:highContrast'],
        ),
      CpmfProfileId.largeCursor => base.copyWith(
          version: '1.0.0-large-cursor',
          accessibility: const SieAccessibilityState(largeCursor: true),
          cursor: SieCursorMotionConfig.accessibility,
          changeHistory: const ['profile:largeCursor'],
        ),
      CpmfProfileId.tremorSupport => base.copyWith(
          version: '1.0.0-tremor',
          sensitivity: SieSensitivityParameters.forProfile(
            SieSensitivityProfileId.tremorTolerant,
          ),
          cursor: SieCursorMotionConfig.accessibility,
          gesturePolicyId: SieGesturePolicyId.accessibility,
          gestures: SieGestureThresholds.accessibility,
          changeHistory: const ['profile:tremorSupport'],
        ),
      CpmfProfileId.dwellMode => base.copyWith(
          version: '1.0.0-dwell',
          dwellSelectEnabled: true,
          gesturePolicyId: SieGesturePolicyId.accessibility,
          gestures: SieGestureThresholds.accessibility,
          accessibility: const SieAccessibilityState(dwellMode: true),
          changeHistory: const ['profile:dwellMode'],
        ),
      CpmfProfileId.leftHanded => base.copyWith(
          version: '1.0.0-left',
          handedness: SieCalibratedHandedness.left,
          changeHistory: const ['profile:leftHanded'],
        ),
      CpmfProfileId.seatedMode => base.copyWith(
          version: '1.0.0-seated',
          sensitivity: SieSensitivityParameters.forProfile(
            SieSensitivityProfileId.precision,
          ),
          changeHistory: const ['profile:seatedMode'],
        ),
      CpmfProfileId.developer => base.copyWith(
          version: '1.0.0-developer',
          diagnostics: CpmfDiagnosticsDomain.development,
          gesturePolicyId: SieGesturePolicyId.debug,
          gestures: SieGestureThresholds.debug,
          confidence: SieConfidenceThresholds.debug,
          changeHistory: const ['profile:developer'],
        ),
      CpmfProfileId.qa => base.copyWith(
          version: '1.0.0-qa-profile',
          diagnostics: CpmfDiagnosticsDomain.development,
          changeHistory: const ['profile:qa'],
        ),
      CpmfProfileId.betaTester => base.copyWith(
          version: '1.0.0-beta',
          swipeNavigationEnabled: true,
          changeHistory: const ['profile:betaTester'],
        ),
      CpmfProfileId.enterpriseCustomer => base.copyWith(
          version: '1.0.0-ent-user',
          changeHistory: const ['profile:enterpriseCustomer'],
        ),
      CpmfProfileId.administrator => base.copyWith(
          version: '1.0.0-admin',
          changeHistory: const ['profile:administrator'],
        ),
      CpmfProfileId.accessibility => base.copyWith(
          version: '1.0.0-a11y',
          dwellSelectEnabled: true,
          gesturePolicyId: SieGesturePolicyId.accessibility,
          gestures: SieGestureThresholds.accessibility,
          cursor: SieCursorMotionConfig.accessibility,
          confidence: SieConfidenceThresholds.accessibility,
          sensitivity: SieSensitivityParameters.forProfile(
            SieSensitivityProfileId.accessibility,
          ),
          accessibility: const SieAccessibilityState(
            reducedMotion: true,
            largeCursor: true,
            dwellMode: true,
          ),
          changeHistory: const ['profile:accessibility'],
        ),
    };
  }

  /// Compose profiles in order (later overrides earlier).
  static CpmfConfigurationBundle compose(
    CpmfConfigurationBundle base,
    List<CpmfProfileId> profiles,
  ) {
    var result = base;
    for (final id in profiles) {
      final overlay = overlayFor(id);
      if (overlay != null) {
        result = result.overlay(overlay);
      }
    }
    return result;
  }
}
