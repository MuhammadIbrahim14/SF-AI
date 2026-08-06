import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router/route_names.dart';
import '../core/errors/app_exceptions.dart';
import '../core/notifications/notification_events.dart';
import '../models/service_order_delivery_model.dart';
import '../models/service_order_model.dart';
import '../repositories/commerce_order_repository.dart';
import '../repositories/commerce_order_repository_impl.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'notification_provider.dart';
import 'repository_providers.dart';
import 'user_provider.dart';

final commerceOrderRepositoryProvider = Provider<CommerceOrderRepository>((
  ref,
) {
  return CommerceOrderRepositoryImpl(ref.watch(firestoreProvider));
});

final myServiceOrdersProvider = StreamProvider<List<ServiceOrderModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <ServiceOrderModel>[]);
  return ref.watch(commerceOrderRepositoryProvider).watchClientOrders(user.uid);
});

final freelancerServiceOrdersProvider = StreamProvider<List<ServiceOrderModel>>(
  (ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return Stream.value(const <ServiceOrderModel>[]);
    return ref
        .watch(commerceOrderRepositoryProvider)
        .watchFreelancerOrders(user.uid);
  },
);

final adminServiceOrdersProvider = StreamProvider<List<ServiceOrderModel>>((
  ref,
) {
  return ref.watch(commerceOrderRepositoryProvider).watchAdminOrders();
});

final serviceOrderProvider = StreamProvider.family<ServiceOrderModel?, String>((
  ref,
  orderId,
) {
  if (orderId.trim().isEmpty) return Stream.value(null);
  return ref.watch(commerceOrderRepositoryProvider).watchOrder(orderId);
});

final orderDeliveriesProvider =
    StreamProvider.family<List<ServiceOrderDeliveryModel>, String>((
      ref,
      orderId,
    ) {
      if (orderId.trim().isEmpty) {
        return Stream.value(const <ServiceOrderDeliveryModel>[]);
      }
      return ref
          .watch(commerceOrderRepositoryProvider)
          .watchOrderDeliveries(orderId);
    });

final orderByServiceRequestProvider =
    StreamProvider.family<ServiceOrderModel?, String>((ref, serviceRequestId) {
      if (serviceRequestId.trim().isEmpty) return Stream.value(null);
      return ref
          .watch(commerceOrderRepositoryProvider)
          .watchOrderByServiceRequestId(serviceRequestId);
    });

final commerceOrderActionProvider =
    AsyncNotifierProvider<CommerceOrderActionNotifier, void>(
      CommerceOrderActionNotifier.new,
    );

class CommerceOrderActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> createOrderFromServiceRequest(String serviceRequestId) async {
    state = const AsyncLoading();
    String? orderId;
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in to create an order.');
      actorId = user.uid;
      orderId = await ref
          .read(commerceOrderRepositoryProvider)
          .createOrderFromServiceRequest(
            serviceRequestId: serviceRequestId,
            clientId: user.uid,
          );
    });
    if (!state.hasError && orderId != null && actorId != null) {
      await _notifyOrderStatus(
        orderId: orderId!,
        actorId: actorId!,
        actorRole: 'client',
        title: 'New service order',
        bodyFor: (order) {
          final label = _orderLabel(order);
          return 'A client created an order for "$label".';
        },
        notifyClient: false,
        notifyFreelancer: true,
        statusHint: ServiceOrderStatus.pending,
        escrowHint: ServiceOrderEscrowStatus.notFunded,
      );
    }
    return state.hasError ? null : orderId;
  }

  Future<bool> cancelOrder(String orderId) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      await ref
          .read(commerceOrderRepositoryProvider)
          .cancelOrder(orderId: orderId, clientId: user.uid);
    });
    if (!state.hasError && actorId != null) {
      await _notifyOrderStatus(
        orderId: orderId,
        actorId: actorId!,
        actorRole: 'client',
        title: 'Order cancelled',
        bodyFor: (order) {
          final label = _orderLabel(order);
          return 'Order "$label" was cancelled.';
        },
        notifyClient: false,
        notifyFreelancer: true,
        statusHint: ServiceOrderStatus.cancelled,
      );
    }
    return !state.hasError;
  }

  Future<bool> confirmSandboxPayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      await ref
          .read(commerceOrderRepositoryProvider)
          .confirmSandboxPayment(
            orderId: orderId,
            clientId: user.uid,
            paymentMethod: paymentMethod,
          );
    });
    if (!state.hasError && actorId != null) {
      await _notifyOrderStatus(
        orderId: orderId,
        actorId: actorId!,
        actorRole: 'client',
        title: 'Escrow funded',
        bodyFor: (order) {
          final label = _orderLabel(order);
          return 'Escrow is held for "$label". You can start work.';
        },
        // Both parties: client confirmation + freelancer alert.
        notifyClient: true,
        notifyFreelancer: true,
        statusHint: ServiceOrderStatus.active,
        escrowHint: ServiceOrderEscrowStatus.held,
        clientBodyOverride: (order) {
          final label = _orderLabel(order);
          return 'Payment confirmed. Escrow is held for "$label".';
        },
      );
    }
    return !state.hasError;
  }

  Future<bool> startWork(String orderId) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      await ref
          .read(commerceOrderRepositoryProvider)
          .startWork(orderId: orderId, freelancerId: user.uid);
    });
    if (!state.hasError && actorId != null) {
      await _notifyOrderStatus(
        orderId: orderId,
        actorId: actorId!,
        actorRole: 'freelancer',
        title: 'Work started',
        bodyFor: (order) {
          final label = _orderLabel(order);
          return 'The freelancer started work on "$label".';
        },
        notifyClient: true,
        notifyFreelancer: false,
        statusHint: ServiceOrderStatus.inProgress,
      );
    }
    return !state.hasError;
  }

  Future<bool> submitDelivery({
    required String orderId,
    required String message,
    required List<String> attachmentUrls,
    List<Map<String, dynamic>> attachmentMetadata = const [],
  }) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      await ref
          .read(commerceOrderRepositoryProvider)
          .submitDelivery(
            orderId: orderId,
            freelancerId: user.uid,
            message: message,
            attachmentUrls: attachmentUrls,
            attachmentMetadata: attachmentMetadata,
          );
    });
    if (!state.hasError && actorId != null) {
      await _notifyOrderStatus(
        orderId: orderId,
        actorId: actorId!,
        actorRole: 'freelancer',
        title: 'Delivery submitted',
        bodyFor: (order) {
          final label = _orderLabel(order);
          return 'Delivery was submitted for "$label". Review it when ready.';
        },
        notifyClient: true,
        notifyFreelancer: false,
        statusHint: ServiceOrderStatus.delivered,
      );
    }
    return !state.hasError;
  }

  Future<void> _notifyOrderStatus({
    required String orderId,
    required String actorId,
    required String actorRole,
    required String title,
    required String Function(ServiceOrderModel order) bodyFor,
    required bool notifyClient,
    required bool notifyFreelancer,
    String? statusHint,
    String? escrowHint,
    String Function(ServiceOrderModel order)? clientBodyOverride,
  }) async {
    try {
      final order = await ref
          .read(commerceOrderRepositoryProvider)
          .getOrder(orderId);
      if (order == null) return;

      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      final relatedPath = 'serviceOrders/${order.orderId}';
      final routeParams = {'orderId': order.orderId};
      final meta = <String, dynamic>{
        'orderId': order.orderId,
        'serviceRequestId': order.serviceRequestId,
        'orderStatus': statusHint ?? order.orderStatus,
        'escrowStatus': ?escrowHint,
        'serviceTitle': order.serviceTitle,
      };

      final notifications = <Future<void>>[];
      if (notifyFreelancer) {
        final freelancerId = order.freelancerId.trim();
        if (freelancerId.isNotEmpty) {
          notifications.add(
            ref.read(notificationServiceProvider).notifyOne(
              recipientId: freelancerId,
              title: title,
              body: bodyFor(order),
              category: NotificationCategories.commerce,
              event: NotificationEvents.commerceOrderStatus,
              actorId: actorId,
              actorName: actorName.isEmpty ? null : actorName,
              actorRole: actorRole,
              relatedPath: relatedPath,
              routeName: RouteNames.serviceOrderDetail,
              routeParams: routeParams,
              meta: meta,
            ),
          );
        }
      }
      if (notifyClient) {
        final clientId = order.clientId.trim();
        if (clientId.isNotEmpty) {
          notifications.add(
            ref.read(notificationServiceProvider).notifyOne(
              recipientId: clientId,
              title: title,
              body: clientBodyOverride?.call(order) ?? bodyFor(order),
              category: NotificationCategories.commerce,
              event: NotificationEvents.commerceOrderStatus,
              actorId: actorId,
              actorName: actorName.isEmpty ? null : actorName,
              actorRole: actorRole,
              relatedPath: relatedPath,
              routeName: RouteNames.serviceOrderDetail,
              routeParams: routeParams,
              meta: meta,
            ),
          );
        }
      }
      if (notifications.isNotEmpty) {
        await Future.wait(notifications);
      }
    } catch (_) {
      // Never fail the primary order action because of notify.
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
    if (error is AppException) return error.message;
    return error?.toString();
  }
}
