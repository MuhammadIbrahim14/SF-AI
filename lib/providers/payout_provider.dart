import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router/route_names.dart';
import '../core/errors/app_exceptions.dart';
import '../core/notifications/notification_events.dart';
import '../models/payout_model.dart';
import '../repositories/payout_repository.dart';
import '../repositories/payout_repository_impl.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'notification_provider.dart';
import 'repository_providers.dart';

final payoutRepositoryProvider = Provider<PayoutRepository>((ref) {
  return PayoutRepositoryImpl(ref.watch(firestoreProvider));
});

final myPayoutsProvider = StreamProvider<List<PayoutModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <PayoutModel>[]);
  return ref.watch(payoutRepositoryProvider).watchFreelancerPayouts(user.uid);
});

final adminPayoutsProvider = StreamProvider<List<PayoutModel>>((ref) {
  return ref.watch(payoutRepositoryProvider).watchAdminPayouts();
});

final payoutActionProvider = AsyncNotifierProvider<PayoutActionNotifier, void>(
  PayoutActionNotifier.new,
);

class PayoutActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> requestPayout({
    required double amount,
    required String destinationType,
    required String destinationName,
    required String destinationMasked,
    required String notes,
  }) async {
    state = const AsyncLoading();
    String? freelancerId;
    double? requestedAmount;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      freelancerId = user.uid;
      requestedAmount = amount;
      await ref
          .read(payoutRepositoryProvider)
          .requestPayout(
            freelancerId: user.uid,
            amount: amount,
            destinationType: destinationType,
            destinationName: destinationName,
            destinationMasked: destinationMasked,
            notes: notes,
          );
    });
    if (!state.hasError && freelancerId != null) {
      try {
        final adminIds = await ref
            .read(adminRepositoryProvider)
            .listAdminRecipientIds();
        if (adminIds.isNotEmpty) {
          final amountLabel =
              (requestedAmount ?? amount).toStringAsFixed(2);
          await ref.read(notificationServiceProvider).notifyMany(
            recipientIds: adminIds,
            title: 'Payout requested',
            body: 'A freelancer requested a payout of $amountLabel.',
            category: NotificationCategories.admin,
            event: NotificationEvents.adminPayoutRequested,
            actorId: freelancerId,
            actorRole: 'freelancer',
            relatedPath: 'payouts',
            routeName: RouteNames.adminPayouts,
            priority: 'high',
            meta: {
              'freelancerId': freelancerId,
              'amount': requestedAmount ?? amount,
            },
          );
        }
      } catch (_) {
        // Never fail the primary payout request because of notify.
      }
    }
    return !state.hasError;
  }

  Future<bool> approvePayout(String payoutId) {
    return _adminAction(
      (adminId) => ref
          .read(payoutRepositoryProvider)
          .approvePayout(payoutId: payoutId, adminId: adminId),
      payoutId: payoutId,
      decisionLabel: 'approved',
    );
  }

  Future<bool> rejectPayout(String payoutId, String notes) {
    return _adminAction(
      (adminId) => ref
          .read(payoutRepositoryProvider)
          .rejectPayout(payoutId: payoutId, adminId: adminId, notes: notes),
      payoutId: payoutId,
      decisionLabel: 'rejected',
    );
  }

  Future<bool> cancelPayout(String payoutId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      await ref
          .read(payoutRepositoryProvider)
          .cancelPayout(payoutId: payoutId, freelancerId: user.uid);
    });
    return !state.hasError;
  }

  Future<bool> processPayout(String payoutId) {
    return _adminAction(
      (adminId) => ref
          .read(payoutRepositoryProvider)
          .processPayout(payoutId: payoutId, adminId: adminId),
      payoutId: payoutId,
      decisionLabel: 'processing',
      notify: false,
    );
  }

  Future<bool> markPayoutPaid(String payoutId) {
    return _adminAction(
      (adminId) => ref
          .read(payoutRepositoryProvider)
          .markPayoutPaid(payoutId: payoutId, adminId: adminId),
      payoutId: payoutId,
      decisionLabel: 'paid',
    );
  }

  Future<bool> _adminAction(
    Future<void> Function(String adminId) action, {
    required String payoutId,
    required String decisionLabel,
    bool notify = true,
  }) async {
    state = const AsyncLoading();
    PayoutModel? payout;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      payout = await ref.read(payoutRepositoryProvider).getPayout(payoutId);
      await action(user.uid);

      if (notify) {
        final recipientId = (payout?.freelancerId ?? '').trim();
        if (recipientId.isNotEmpty) {
          final amount = payout?.amount;
          final amountLabel = amount == null
              ? ''
              : ' (${amount.toStringAsFixed(2)} ${payout?.currency ?? 'USD'})';
          await ref.read(notificationServiceProvider).notifyOne(
            recipientId: recipientId,
            title: 'Payout $decisionLabel',
            body: 'Your payout request was $decisionLabel$amountLabel.',
            category: NotificationCategories.admin,
            event: NotificationEvents.adminPayoutDecided,
            actorId: user.uid,
            actorRole: 'admin',
            relatedPath: 'payouts/$payoutId',
            routeName: RouteNames.freelancerPayouts,
            priority: decisionLabel == 'rejected' || decisionLabel == 'paid'
                ? 'high'
                : 'normal',
            meta: {
              'payoutId': payoutId,
              'status': decisionLabel,
            },
          );
        }
      }
    });
    return !state.hasError;
  }

  String? get errorMessage {
    final error = state.error;
    if (error is AppException) return error.message;
    return error?.toString();
  }
}
