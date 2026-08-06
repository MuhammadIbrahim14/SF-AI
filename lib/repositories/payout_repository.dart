import '../models/payout_model.dart';

abstract class PayoutRepository {
  Stream<List<PayoutModel>> watchFreelancerPayouts(String freelancerId);

  Stream<List<PayoutModel>> watchAdminPayouts();

  Future<PayoutModel?> getPayout(String payoutId);

  Future<void> requestPayout({
    required String freelancerId,
    required double amount,
    required String destinationType,
    required String destinationName,
    required String destinationMasked,
    required String notes,
  });

  Future<void> approvePayout({
    required String payoutId,
    required String adminId,
  });

  Future<void> rejectPayout({
    required String payoutId,
    required String adminId,
    required String notes,
  });

  Future<void> cancelPayout({
    required String payoutId,
    required String freelancerId,
  });

  Future<void> processPayout({
    required String payoutId,
    required String adminId,
  });

  Future<void> markPayoutPaid({
    required String payoutId,
    required String adminId,
  });
}
