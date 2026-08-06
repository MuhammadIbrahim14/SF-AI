import '../data/ai_usage_repository.dart';

class AiUsageBlockedException implements Exception {
  const AiUsageBlockedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiUsageGuardService {
  const AiUsageGuardService(this._repository);

  final AiUsageRepository _repository;

  Future<AiUsageGuardResult> check({
    required String userId,
    required String role,
    required String taskType,
    bool heavyCandidate = false,
  }) {
    return _repository.checkGuard(
      userId: userId,
      role: role,
      taskType: taskType,
      heavyCandidate: heavyCandidate,
    );
  }

  Future<void> logAndCharge({
    required String userId,
    required String role,
    required String taskType,
    required String feature,
    required String provider,
    required String status,
    required bool fallbackUsed,
    required Map<String, dynamic>? usage,
    required int requestedCost,
  }) {
    return _repository.logUsageAndCharge(
      userId: userId,
      role: role,
      taskType: taskType,
      feature: feature,
      provider: provider,
      status: status,
      fallbackUsed: fallbackUsed,
      usage: usage,
      requestedCost: requestedCost,
    );
  }
}
