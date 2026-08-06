import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router/route_names.dart';
import '../core/notifications/notification_events.dart';
import '../models/service_request_model.dart';
import '../repositories/service_request_repository.dart';
import '../repositories/service_request_repository_impl.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'notification_provider.dart';
import 'repository_providers.dart';
import 'user_provider.dart';

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>((
  ref,
) {
  return ServiceRequestRepositoryImpl(ref.watch(firestoreProvider));
});

final myServiceRequestsProvider = StreamProvider<List<ServiceRequestModel>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <ServiceRequestModel>[]);
  return ref
      .watch(serviceRequestRepositoryProvider)
      .watchClientRequests(user.uid);
});

final freelancerServiceRequestsProvider =
    StreamProvider<List<ServiceRequestModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <ServiceRequestModel>[]);
      return ref
          .watch(serviceRequestRepositoryProvider)
          .watchFreelancerRequests(user.uid);
    });

final serviceRequestDetailProvider =
    StreamProvider.family<ServiceRequestModel?, String>((ref, requestId) {
      if (requestId.trim().isEmpty) return Stream.value(null);
      return ref
          .watch(serviceRequestRepositoryProvider)
          .watchRequest(requestId);
    });

final serviceRequestActionProvider =
    AsyncNotifierProvider<ServiceRequestActionNotifier, void>(
      ServiceRequestActionNotifier.new,
    );

class ServiceRequestActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> createRequest(ServiceRequestModel request) async {
    state = const AsyncLoading();
    String? requestId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in to request a service.');
      if (request.clientId != user.uid) {
        throw StateError('You can only create your own service requests.');
      }
      requestId = await ref
          .read(serviceRequestRepositoryProvider)
          .createRequest(request);
    });
    if (!state.hasError && requestId != null) {
      await _notifyServiceRequestCreated(
        request.copyWith(requestId: requestId!),
      );
    }
    return state.hasError ? null : requestId;
  }

  Future<bool> updateFreelancerStatus({
    required String requestId,
    required String status,
    String? freelancerNote,
  }) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in freelancer is required.');
      actorId = user.uid;
      await ref
          .read(serviceRequestRepositoryProvider)
          .updateFreelancerStatus(
            requestId: requestId,
            freelancerId: user.uid,
            status: status,
            freelancerNote: freelancerNote,
          );
    });
    if (!state.hasError && actorId != null) {
      await _notifyServiceRequestStatus(
        requestId: requestId,
        status: status,
        actorId: actorId!,
        actorRole: 'freelancer',
      );
    }
    return !state.hasError;
  }

  Future<bool> cancelClientRequest({
    required String requestId,
    String? clientNote,
  }) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      await ref
          .read(serviceRequestRepositoryProvider)
          .cancelClientRequest(
            requestId: requestId,
            clientId: user.uid,
            clientNote: clientNote,
          );
    });
    if (!state.hasError && actorId != null) {
      await _notifyServiceRequestStatus(
        requestId: requestId,
        status: ServiceRequestStatus.cancelled,
        actorId: actorId!,
        actorRole: 'client',
      );
    }
    return !state.hasError;
  }

  Future<bool> completeClientRequest({
    required String requestId,
    String? clientNote,
  }) async {
    state = const AsyncLoading();
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      await ref
          .read(serviceRequestRepositoryProvider)
          .completeClientRequest(
            requestId: requestId,
            clientId: user.uid,
            clientNote: clientNote,
          );
    });
    if (!state.hasError && actorId != null) {
      await _notifyServiceRequestStatus(
        requestId: requestId,
        status: ServiceRequestStatus.completed,
        actorId: actorId!,
        actorRole: 'client',
      );
    }
    return !state.hasError;
  }

  Future<void> _notifyServiceRequestCreated(ServiceRequestModel request) async {
    try {
      final freelancerId = request.freelancerId.trim();
      if (freelancerId.isEmpty) return;

      final clientLabel = request.clientName.trim().isNotEmpty
          ? request.clientName.trim()
          : 'A client';
      final projectLabel = request.projectTitle.trim().isNotEmpty
          ? request.projectTitle.trim()
          : (request.serviceTitle.trim().isNotEmpty
                ? request.serviceTitle.trim()
                : 'your service');
      final actorRole = (request.clientRole ?? '').trim().isNotEmpty
          ? request.clientRole!.trim()
          : 'client';

      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: freelancerId,
        title: 'New service request',
        body: '$clientLabel requested "$projectLabel".',
        category: NotificationCategories.commerce,
        event: NotificationEvents.commerceServiceRequestCreated,
        actorId: request.clientId,
        actorName: request.clientName.trim().isEmpty
            ? null
            : request.clientName.trim(),
        actorRole: actorRole,
        relatedPath: 'serviceRequests/${request.requestId}',
        routeName: RouteNames.serviceRequestDetail,
        routeParams: {'requestId': request.requestId},
        meta: {
          'serviceRequestId': request.requestId,
          'serviceTitle': request.serviceTitle,
          'projectTitle': request.projectTitle,
          'status': request.status,
        },
      );
    } catch (_) {
      // Never fail the primary create path because of notify.
    }
  }

  Future<void> _notifyServiceRequestStatus({
    required String requestId,
    required String status,
    required String actorId,
    required String actorRole,
  }) async {
    try {
      final request = await ref
          .read(serviceRequestRepositoryProvider)
          .getRequest(requestId);
      if (request == null) return;

      final clientId = (request.clientId ?? '').trim();
      final freelancerId = request.freelancerId.trim();
      final recipientId = actorRole == 'client' ? freelancerId : clientId;
      if (recipientId.isEmpty) return;

      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      final projectLabel = request.projectTitle.trim().isNotEmpty
          ? request.projectTitle.trim()
          : (request.serviceTitle.trim().isNotEmpty
                ? request.serviceTitle.trim()
                : 'your request');
      final statusLabel = _serviceRequestStatusLabel(status);
      final body = actorRole == 'client'
          ? 'Request "$projectLabel" was $statusLabel by the client.'
          : 'Your request "$projectLabel" was $statusLabel.';

      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: recipientId,
        title: 'Service request update',
        body: body,
        category: NotificationCategories.commerce,
        event: NotificationEvents.commerceServiceRequestStatus,
        actorId: actorId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: actorRole,
        relatedPath: 'serviceRequests/${request.requestId}',
        routeName: RouteNames.serviceRequestDetail,
        routeParams: {'requestId': request.requestId},
        meta: {
          'serviceRequestId': request.requestId,
          'serviceTitle': request.serviceTitle,
          'projectTitle': request.projectTitle,
          'status': ServiceRequestStatus.normalize(status),
        },
      );
    } catch (_) {
      // Never fail the primary status update because of notify.
    }
  }

  String? get errorMessage => state.error?.toString();
}

String _serviceRequestStatusLabel(String status) {
  return switch (ServiceRequestStatus.normalize(status)) {
    ServiceRequestStatus.accepted => 'accepted',
    ServiceRequestStatus.rejected => 'declined',
    ServiceRequestStatus.inProgress => 'marked in progress',
    ServiceRequestStatus.delivered => 'marked delivered',
    ServiceRequestStatus.completed => 'completed',
    ServiceRequestStatus.cancelled => 'cancelled',
    _ => 'updated',
  };
}
