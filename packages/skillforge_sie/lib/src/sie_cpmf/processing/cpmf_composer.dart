import 'package:skillforge_sie/src/sie_core/platform_kind.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_configuration_bundle.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_enums.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_policy_context.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_profile_catalog.dart';
import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_snapshot.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';
import 'package:skillforge_sie/src/sie_rollout/models/prf_config.dart';

/// Deterministic policy evaluation (no I/O).
abstract final class CpmfPolicyEngine {
  /// Answer a policy question.
  static bool evaluate(
    CpmfPolicyQuestion question,
    CpmfPolicyContext context,
  ) {
    final security = context.securityLevel;
    final bundle = context.bundle;
    final routeAllows = PrfRouteCatalog.allowsSie(context.routeId) ||
        _catalogAllows(context.routeId);

    return switch (question) {
      CpmfPolicyQuestion.sieOperableOnRoute =>
        routeAllows &&
            !(bundle.security.disableSieAtL4 &&
                security == SieSecurityLevel.l4Irreversible),
      CpmfPolicyQuestion.pinchActivateAllowed =>
        routeAllows &&
            !(bundle.security.disableSelectAtL3 &&
                (security == SieSecurityLevel.l3Sensitive ||
                    security == SieSecurityLevel.l4Irreversible)),
      CpmfPolicyQuestion.snappingEnabled =>
        bundle.cursor.snapEnabled &&
            !(bundle.security.disableSnapAtL3 &&
                security.index >= SieSecurityLevel.l3Sensitive.index),
      CpmfPolicyQuestion.predictionReduced =>
        bundle.accessibility.reducedMotion ||
            !bundle.cursor.predictionEnabled ||
            security.index >= SieSecurityLevel.l2Elevated.index,
      CpmfPolicyQuestion.animationsDisabled =>
        bundle.accessibility.reducedMotion || bundle.cursor.reducedMotion,
      CpmfPolicyQuestion.dwellSelectAllowed =>
        bundle.dwellSelectEnabled || bundle.accessibility.dwellMode,
      CpmfPolicyQuestion.dragAllowed =>
        routeAllows &&
            security.index < SieSecurityLevel.l3Sensitive.index &&
            _dragAllowedOnRoute(context.routeId),
    };
  }

  static bool _catalogAllows(String routeId) {
    for (final p in SieSkillForgeRouteCatalog.defaults) {
      if (p.routeId == routeId) return p.allowsSie;
    }
    return false;
  }

  static bool _dragAllowedOnRoute(String routeId) {
    for (final p in SieSkillForgeRouteCatalog.defaults) {
      if (p.routeId == routeId) return p.capability.allowDrag;
    }
    return true;
  }
}

/// Configuration composition + validation.
abstract final class CpmfComposer {
  /// Resolve with explicit precedence:
  /// builtIn → localFile → environment → profiles → platform → build → runtime → remote.
  static CpmfConfigurationSnapshot resolve({
    required DateTime timestamp,
    required CpmfEnvironment environment,
    required SiePlatformKind platform,
    List<CpmfProfileId> profiles = const [CpmfProfileId.standard],
    CpmfConfigurationBundle? buildTime,
    CpmfConfigurationBundle? runtime,
    CpmfConfigurationBundle? remote,
    CpmfConfigurationBundle? localFile,
  }) {
    var bundle = CpmfConfigurationBundle.builtInDefaults;
    var source = CpmfConfigSource.builtIn;

    if (localFile != null) {
      bundle = bundle.overlay(localFile);
      source = CpmfConfigSource.localFile;
    }

    bundle =
        bundle.overlay(CpmfEnvironmentOverlays.forEnvironment(environment));
    source = CpmfConfigSource.environment;

    bundle = CpmfProfileCatalog.compose(bundle, profiles);

    final platformOverlay = CpmfPlatformOverlays.forPlatform(platform);
    if (platformOverlay != null) {
      // Platform tuning is isolated — do not clobber profile/env domains.
      bundle = bundle.copyWith(
        camera: platformOverlay.camera,
        vision: platformOverlay.vision,
        performance: platformOverlay.performance,
        changeHistory: [
          ...bundle.changeHistory,
          ...platformOverlay.changeHistory,
        ],
      );
    }

    if (buildTime != null) {
      bundle = bundle.overlay(buildTime);
      source = CpmfConfigSource.buildTime;
    }
    if (runtime != null) {
      bundle = bundle.overlay(runtime);
      source = CpmfConfigSource.runtime;
    }
    if (remote != null) {
      bundle = bundle.overlay(remote);
      source = CpmfConfigSource.remote;
    }

    final issues = CpmfValidator.validate(bundle, platform: platform);
    final hasError =
        issues.any((i) => i.severity == CpmfValidationSeverity.error);
    if (hasError) {
      bundle = CpmfConfigurationBundle.builtInDefaults.overlay(
        CpmfEnvironmentOverlays.forEnvironment(environment),
      );
      bundle = bundle.copyWith(
        changeHistory: [
          ...bundle.changeHistory,
          'validation_fallback',
        ],
      );
    }

    return CpmfConfigurationSnapshot(
      timestamp: timestamp,
      environment: environment,
      platform: platform,
      profiles: List.unmodifiable(profiles),
      bundle: bundle,
      source: source,
      healthy: !hasError,
      validationIssues: issues,
    );
  }
}

/// Validates threshold ranges and integrity.
abstract final class CpmfValidator {
  /// Validate bundle.
  static List<CpmfValidationIssue> validate(
    CpmfConfigurationBundle bundle, {
    required SiePlatformKind platform,
  }) {
    final issues = <CpmfValidationIssue>[];

    if (bundle.schemaVersion > kCpmfSchemaVersion) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message:
              'Configuration schema newer than runtime (version mismatch)',
        ),
      );
    }
    if (bundle.compatibilityVersion > kCpmfSchemaVersion) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message: 'Incompatible configuration compatibility version',
        ),
      );
    }

    if (!bundle.gestures.isValid) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message: 'Invalid gesture threshold hysteresis bands',
          domain: CpmfDomainId.gestures,
        ),
      );
    }
    if (bundle.gestures.dwellMs < 100 || bundle.gestures.dwellMs > 5000) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.warning,
          message: 'Dwell duration outside recommended range',
          domain: CpmfDomainId.gestures,
        ),
      );
    }
    if (bundle.cursor.smoothingAlpha <= 0 ||
        bundle.cursor.smoothingAlpha > 1) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message: 'Cursor smoothingAlpha out of range (0,1]',
          domain: CpmfDomainId.cursor,
        ),
      );
    }
    if (bundle.cursor.snapRadius < 0) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message: 'Snap radius must be non-negative',
          domain: CpmfDomainId.cursor,
        ),
      );
    }
    if (bundle.camera.targetFps < 1 || bundle.camera.targetFps > 120) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message: 'Camera target FPS out of range',
          domain: CpmfDomainId.camera,
        ),
      );
    }
    if (bundle.vision.maxHands < 1) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message: 'Vision maxHands must be >= 1',
          domain: CpmfDomainId.vision,
        ),
      );
    }
    if (bundle.sensitivity.gain <= 0) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message: 'Sensitivity gain must be positive',
          domain: CpmfDomainId.calibration,
        ),
      );
    }
    if (platform == SiePlatformKind.unsupported) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.warning,
          message: 'Unsupported platform — using safe defaults',
          domain: CpmfDomainId.performance,
        ),
      );
    }

    final c = bundle.confidence;
    if (c.trackEnter <= c.trackExit || c.stableEnter <= c.stableExit) {
      issues.add(
        const CpmfValidationIssue(
          severity: CpmfValidationSeverity.error,
          message: 'Invalid confidence hysteresis ordering',
          domain: CpmfDomainId.confidence,
        ),
      );
    }

    return issues;
  }
}

/// Schema migration (forward-compatible).
abstract final class CpmfMigrator {
  /// Migrate versioned bundle to current schema.
  static CpmfConfigurationBundle migrate(CpmfConfigurationBundle input) {
    if (input.schemaVersion == kCpmfSchemaVersion) return input;
    if (input.schemaVersion < 1) {
      return input.copyWith(
        schemaVersion: kCpmfSchemaVersion,
        compatibilityVersion: kCpmfSchemaVersion,
        changeHistory: [...input.changeHistory, 'migrated:v1'],
      );
    }
    return CpmfConfigurationBundle.builtInDefaults.copyWith(
      changeHistory: const ['migration_rejected_future_schema'],
    );
  }
}
