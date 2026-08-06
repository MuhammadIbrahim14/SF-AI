import 'package:skillforge_sie/src/sie_cpmf/models/cpmf_configuration_bundle.dart';
import 'package:skillforge_sie/src/sie_intent/models/sie_intent_enums.dart';

/// Context for policy questions.
final class CpmfPolicyContext {
  /// Creates context.
  const CpmfPolicyContext({
    required this.routeId,
    required this.securityLevel,
    required this.bundle,
  });

  /// Route id.
  final String routeId;

  /// Security level.
  final SieSecurityLevel securityLevel;

  /// Active bundle.
  final CpmfConfigurationBundle bundle;
}
