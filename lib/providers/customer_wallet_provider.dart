import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router/route_names.dart';
import '../core/errors/app_exceptions.dart';
import '../core/notifications/notification_events.dart';
import '../core/utils/app_logger.dart';
import '../features/payment/providers/payment_providers.dart';
import '../features/payment/services/demo_payment_finalize_service.dart';
import '../models/customer_wallet_model.dart';
import '../models/service_order_model.dart';
import '../repositories/customer_wallet_repository.dart';
import '../repositories/customer_wallet_repository_impl.dart';
import 'auth_provider.dart';
import 'commerce_order_provider.dart';
import 'firebase_providers.dart';
import 'notification_provider.dart';
import 'repository_providers.dart';
import 'user_provider.dart';

final customerWalletRepositoryProvider = Provider<CustomerWalletRepository>((
  ref,
) {
  return CustomerWalletRepositoryImpl(ref.watch(firestoreProvider));
});

final myCustomerWalletProvider = StreamProvider<CustomerWalletModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(customerWalletRepositoryProvider).watchMyWallet(user.uid);
});

final myCustomerWalletTransactionsProvider =
    StreamProvider<List<WalletTransactionModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <WalletTransactionModel>[]);
      return ref
          .watch(customerWalletRepositoryProvider)
          .watchMyWalletTransactions(user.uid);
    });

final customerWalletActionProvider =
    AsyncNotifierProvider<CustomerWalletActionNotifier, void>(
      CustomerWalletActionNotifier.new,
    );

class CustomerWalletActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> getOrCreateMyWallet() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      await ref
          .read(customerWalletRepositoryProvider)
          .getOrCreateMyWallet(user.uid);
    });
    return !state.hasError;
  }

  Future<bool> addDemoBalance(double amount) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      if (amount <= 0) {
        throw const FirestoreException('Enter a top-up amount greater than 0.');
      }
      if (amount > 10000) {
        throw const FirestoreException(
          'Demo top-up limit is 10,000 per transaction.',
        );
      }

      // Credits must be granted by the demo gateway Admin SDK (not client mint).
      final demo = DemoPaymentFinalizeService();
      final session = await demo.createCheckout(
        type: 'wallet_topup',
        amount: amount,
        description: 'Demo wallet top-up',
        paymentMethod: 'card',
        role: 'customer',
        metadata: const {'walletRole': 'customer'},
      );
      await demo.confirm(
        intentId: session.intentId,
        outcome: 'success',
        cardLast4: '4242',
      );
      await ref
          .read(customerWalletRepositoryProvider)
          .getOrCreateMyWallet(user.uid);
    });
    if (!state.hasError && actorId != null) {
      try {
        await ref
            .read(demoPaymentNotificationHelperProvider)
            .notifyCheckoutOutcome(
              payerId: actorId!,
              type: 'wallet_topup',
              success: true,
              amount: amount,
              currency: 'PKR',
              description: 'Demo wallet top-up',
            );
      } catch (error) {
        AppLogger.warn('Wallet top-up notification could not be sent: $error');
      }
    }
    return !state.hasError;
  }

  Future<bool> payOrderFromWallet(String orderId) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      await ref
          .read(customerWalletRepositoryProvider)
          .payOrderFromWallet(customerId: user.uid, orderId: orderId);
    });
    if (!state.hasError && actorId != null) {
      await _notifyOrderCounterpart(
        orderId: orderId,
        actorId: actorId!,
        title: 'Escrow funded',
        bodyFor: (order) {
          final label = _orderLabel(order);
          return 'Escrow is held for "$label". You can start work.';
        },
        statusHint: ServiceOrderStatus.active,
        escrowHint: ServiceOrderEscrowStatus.held,
      );
      // Payer receipt (freelancer already notified above).
      try {
        final order = await ref
            .read(commerceOrderRepositoryProvider)
            .getOrder(orderId);
        if (order != null) {
          final label = _orderLabel(order);
          await ref
              .read(notificationServiceProvider)
              .notifyOne(
                recipientId: actorId!,
                title: 'Order funded',
                body: 'Payment confirmed. Escrow is held for "$label".',
                category: NotificationCategories.commerce,
                event: NotificationEvents.commerceOrderStatus,
                actorId: 'system',
                relatedPath: 'serviceOrders/${order.orderId}',
                routeName: RouteNames.serviceOrderDetail,
                routeParams: {'orderId': order.orderId},
                meta: {
                  'orderId': order.orderId,
                  'serviceRequestId': order.serviceRequestId,
                  'orderStatus': ServiceOrderStatus.active,
                  'escrowStatus': ServiceOrderEscrowStatus.held,
                  'serviceTitle': order.serviceTitle,
                },
              );
        }
      } catch (error) {
        AppLogger.warn(
          'Wallet payment receipt notification could not be sent: $error',
        );
      }
    }
    return !state.hasError;
  }

  Future<bool> completeOrderAndReleaseEscrow(String orderId) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      await ref
          .read(customerWalletRepositoryProvider)
          .completeOrderAndReleaseEscrow(
            customerId: user.uid,
            orderId: orderId,
          );
    });
    if (!state.hasError && actorId != null) {
      await _notifyOrderCounterpart(
        orderId: orderId,
        actorId: actorId!,
        title: 'Order completed',
        bodyFor: (order) {
          final label = _orderLabel(order);
          return 'Order "$label" was completed. Escrow was released.';
        },
        statusHint: ServiceOrderStatus.completed,
        escrowHint: ServiceOrderEscrowStatus.released,
      );
    }
    return !state.hasError;
  }

  Future<void> _notifyOrderCounterpart({
    required String orderId,
    required String actorId,
    required String title,
    required String Function(ServiceOrderModel order) bodyFor,
    String? statusHint,
    String? escrowHint,
  }) async {
    try {
      final order = await ref
          .read(commerceOrderRepositoryProvider)
          .getOrder(orderId);
      if (order == null) return;

      final freelancerId = order.freelancerId.trim();
      if (freelancerId.isEmpty) return;

      final actorName = (ref.read(currentUserProvider).value?.fullName ?? '')
          .trim();

      await ref
          .read(notificationServiceProvider)
          .notifyOne(
            recipientId: freelancerId,
            title: title,
            body: bodyFor(order),
            category: NotificationCategories.commerce,
            event: NotificationEvents.commerceOrderStatus,
            actorId: actorId,
            actorName: actorName.isEmpty ? null : actorName,
            actorRole: 'client',
            relatedPath: 'serviceOrders/${order.orderId}',
            routeName: RouteNames.serviceOrderDetail,
            routeParams: {'orderId': order.orderId},
            meta: {
              'orderId': order.orderId,
              'serviceRequestId': order.serviceRequestId,
              'orderStatus': statusHint ?? order.orderStatus,
              'escrowStatus': ?escrowHint,
              'serviceTitle': order.serviceTitle,
            },
          );
    } catch (_) {
      // Never fail the primary wallet action because of notify.
    }
  }

  String _orderLabel(ServiceOrderModel order) {
    final title = order.serviceTitle.trim();
    if (title.isNotEmpty) return title;
    final number = order.orderNumber.trim();
    if (number.isNotEmpty) return number;
    return 'your order';
  }

  String? get errorMessage {
    final error = state.error;
    if (error == null) return null;
    if (error is AppException) return error.message;
    if (error is DemoPaymentException) return error.message;
    final message = error.toString();
    if (message.contains('Dart exception thrown from converted Future')) {
      return 'Unable to complete wallet action. Please try again.';
    }
    return message;
  }
}
