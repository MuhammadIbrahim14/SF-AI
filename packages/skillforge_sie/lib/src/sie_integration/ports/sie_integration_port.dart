import 'package:skillforge_sie/src/sie_arbitration/models/sie_arbitration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_feature_registry.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_enums.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_integration_state.dart';
import 'package:skillforge_sie/src/sie_integration/models/sie_route_policy.dart';
import 'package:skillforge_sie/src/sie_integration/processing/sie_route_registry.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_context.dart';
import 'package:skillforge_sie/src/sie_orchestrator/models/sie_orchestrator_enums.dart';

/// Host-facing Integration Framework port — sole application entry to SIE.
///
/// Applications must not call Camera / Vision / Gesture / MediaPipe APIs.
abstract interface class SieIntegrationPort {
  /// Low-frequency status (Riverpod-safe).
  Stream<SieIntegrationStatus> get status;

  /// Immutable state stream (low-frequency policy / lifecycle changes).
  Stream<SieIntegrationState> get states;

  /// Current status.
  SieIntegrationStatus get currentStatus;

  /// Current state.
  SieIntegrationState get currentState;

  /// Route registry.
  SieRouteRegistry get routes;

  /// Feature registry.
  SieFeatureRegistry get features;

  /// Automatic registration (startup).
  Future<void> register();

  /// Initialize policies + capabilities after registration.
  Future<void> initialize({
    SieInteractionAvailability? availability,
    bool permissionGranted = true,
  });

  /// Enable SIE (subject to route / security / availability).
  Future<void> enable();

  /// Disable SIE (traditional input continues).
  Future<void> disable();

  /// Pause.
  Future<void> pause();

  /// Resume.
  Future<void> resume();

  /// Shutdown / dispose.
  Future<void> shutdown();

  /// Activate route by id (applies IDS security automatically).
  Future<SieRoutePolicy> activateRoute(String routeId);

  /// Register additional route (future modules — zero redesign).
  Future<void> registerRoute(SieRoutePolicy policy);

  /// Configure a configurable route (settings).
  Future<void> configureRoute(String routeId, {required bool sieEnabled});

  /// Set feature enablement.
  Future<void> setFeature(
    SieIntegrationFeatureId id, {
    required bool enabled,
  });

  /// Lifecycle change.
  Future<void> setLifecycle(SieAppLifecycleState lifecycle);

  /// Accessibility (application-wide).
  Future<void> setAccessibility(SieAccessibilityState accessibility);

  /// Capability / permission updates (graceful degradation).
  Future<void> notifyCapabilities({
    SieInteractionAvailability? availability,
    bool? permissionGranted,
  });

  /// Report current input owner (from arbitration probe / host).
  Future<void> notifyInputOwner(SieInputSource owner);

  /// Diagnostics summary for SIDF / engineering.
  Map<String, Object?> diagnosticsReport();

  /// Dispose resources.
  Future<void> dispose();
}
