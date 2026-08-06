import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router/route_names.dart';
import '../core/errors/app_exceptions.dart';
import '../core/notifications/notification_events.dart';
import '../models/resolution_case_model.dart';
import '../models/resolution_settlement_request_model.dart';
import '../models/user_model.dart';
import '../repositories/resolution_settlement_request_repository.dart';
import '../repositories/resolution_v2_repository.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'notification_provider.dart';
import 'repository_providers.dart';
import 'user_provider.dart';

final resolutionV2RepositoryProvider = Provider<ResolutionV2Repository>((ref) {
  return ResolutionV2Repository(ref.watch(firestoreProvider));
});

final resolutionSettlementRequestRepositoryProvider =
    Provider<ResolutionSettlementRequestRepository>((ref) {
      return ResolutionSettlementRequestRepository(
        ref.watch(firestoreProvider),
      );
    });

final resolutionSettlementRequestProvider =
    StreamProvider.family<ResolutionSettlementRequestModel?, String>((
      ref,
      requestId,
    ) {
      return ref
          .watch(resolutionSettlementRequestRepositoryProvider)
          .watchRequest(requestId);
    });

final adminResolutionCasesProvider = StreamProvider<List<ResolutionCaseModel>>((
  ref,
) {
  return ref.watch(resolutionV2RepositoryProvider).watchCasesForAdmin();
});

final customerResolutionCasesProvider =
    StreamProvider<List<ResolutionCaseModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <ResolutionCaseModel>[]);
      return ref
          .watch(resolutionV2RepositoryProvider)
          .watchCasesForClient(user.uid);
    });

final freelancerResolutionCasesProvider =
    StreamProvider<List<ResolutionCaseModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <ResolutionCaseModel>[]);
      return ref
          .watch(resolutionV2RepositoryProvider)
          .watchCasesForFreelancer(user.uid);
    });

final orderResolutionCasesProvider =
    StreamProvider.family<List<ResolutionCaseModel>, String>((ref, orderId) {
      final user = ref.watch(currentUserProvider).value;
      if (user == null || orderId.trim().isEmpty) {
        return Stream.value(const <ResolutionCaseModel>[]);
      }
      return ref
          .watch(resolutionV2RepositoryProvider)
          .watchCasesForOrder(orderId);
    });

final resolutionCaseEventsProvider =
    StreamProvider.family<List<ResolutionCaseEventModel>, String>((
      ref,
      caseId,
    ) {
      if (caseId.trim().isEmpty) {
        return Stream.value(const <ResolutionCaseEventModel>[]);
      }
      return ref.watch(resolutionV2RepositoryProvider).watchCaseEvents(caseId);
    });

final resolutionCaseEvidenceProvider =
    StreamProvider.family<List<ResolutionCaseEvidenceModel>, String>((
      ref,
      caseId,
    ) {
      if (caseId.trim().isEmpty) {
        return Stream.value(const <ResolutionCaseEvidenceModel>[]);
      }
      return ref
          .watch(resolutionV2RepositoryProvider)
          .watchCaseEvidence(caseId);
    });

final resolutionV2ActionProvider =
    AsyncNotifierProvider<ResolutionV2ActionNotifier, void>(
      ResolutionV2ActionNotifier.new,
    );

class ResolutionV2ActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createRevision(String orderId, String notes) {
    return _userAction(
      (userId, _) => ref
          .read(resolutionV2RepositoryProvider)
          .createRevisionCase(orderId: orderId, actorId: userId, notes: notes),
      afterSuccess: (userId, result) async {
        final caseId = result is String ? result.trim() : '';
        if (caseId.isEmpty) return;
        await _notifyCaseOpened(
          caseId: caseId,
          actorId: userId,
          title: 'Revision requested',
          bodyPrefix: 'A revision was requested on',
        );
      },
    );
  }

  Future<bool> createDispute(String orderId, String reason) {
    return _userAction(
      (userId, _) => ref
          .read(resolutionV2RepositoryProvider)
          .createDisputeCase(orderId: orderId, actorId: userId, reason: reason),
      afterSuccess: (userId, result) async {
        final caseId = result is String ? result.trim() : '';
        if (caseId.isEmpty) return;
        await _notifyDisputeOpened(caseId: caseId, actorId: userId);
      },
    );
  }

  Future<bool> createRefund(String orderId, String reason, {double? amount}) {
    return _userAction(
      (userId, _) => ref
          .read(resolutionV2RepositoryProvider)
          .createRefundCase(
            orderId: orderId,
            actorId: userId,
            reason: reason,
            amount: amount,
          ),
      afterSuccess: (userId, result) async {
        final caseId = result is String ? result.trim() : '';
        if (caseId.isEmpty) return;
        await _notifyCaseOpened(
          caseId: caseId,
          actorId: userId,
          title: 'Refund requested',
          bodyPrefix: 'A refund was requested on',
        );
      },
    );
  }

  Future<bool> acceptRevision(String caseId, String notes) {
    return _userAction(
      (userId, _) => ref
          .read(resolutionV2RepositoryProvider)
          .acceptRevision(caseId: caseId, freelancerId: userId, notes: notes),
      afterSuccess: (userId, _) => _notifyResolutionPeer(
        caseId: caseId,
        actorId: userId,
        title: 'Revision accepted',
        summary: 'The freelancer accepted the revision request',
      ),
    );
  }

  Future<bool> submitRevision(String caseId, String notes) {
    return _userAction(
      (userId, _) => ref
          .read(resolutionV2RepositoryProvider)
          .submitRevision(caseId: caseId, freelancerId: userId, notes: notes),
      afterSuccess: (userId, _) => _notifyResolutionPeer(
        caseId: caseId,
        actorId: userId,
        title: 'Revision submitted',
        summary: 'The freelancer submitted revision work',
      ),
    );
  }

  Future<bool> completeRevision(String caseId, String notes) {
    return _userAction(
      (userId, _) => ref
          .read(resolutionV2RepositoryProvider)
          .completeRevision(caseId: caseId, clientId: userId, notes: notes),
      afterSuccess: (userId, _) => _notifyResolutionPeer(
        caseId: caseId,
        actorId: userId,
        title: 'Revision completed',
        summary: 'The client marked the revision complete',
      ),
    );
  }

  Future<bool> addEvidence(String caseId, String notes) {
    return _userAction(
      (userId, role) => ref
          .read(resolutionV2RepositoryProvider)
          .addEvidence(
            caseId: caseId,
            actorId: userId,
            actorRole: _roleName(role),
            notes: notes,
          ),
      afterSuccess: (userId, _) => _notifyResolutionPeer(
        caseId: caseId,
        actorId: userId,
        title: 'Evidence added',
        summary: 'New evidence was added to the resolution case',
      ),
    );
  }

  Future<bool> markUnderReview(String caseId) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .markUnderReview(caseId: caseId, adminId: adminId),
    );
  }

  Future<bool> requestEvidence(
    String caseId,
    String message, {
    String targetRole = 'both',
  }) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .requestEvidence(
            caseId: caseId,
            adminId: adminId,
            message: message,
            targetRole: targetRole,
          ),
    );
  }

  Future<bool> generateLawRecommendation(String caseId) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .generateLawRecommendation(caseId: caseId, adminId: adminId),
    );
  }

  Future<bool> resolveRelease(String caseId, double amount, String adminNote) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .resolveReleaseToFreelancer(
            caseId: caseId,
            adminId: adminId,
            releaseAmount: amount,
            adminNote: adminNote,
          ),
      caseId: caseId,
      summary: 'Release to freelancer',
    );
  }

  Future<bool> resolveRefund(String caseId, double amount, String adminNote) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .resolveRefundToClient(
            caseId: caseId,
            adminId: adminId,
            refundAmount: amount,
            adminNote: adminNote,
          ),
      caseId: caseId,
      summary: 'Refund to client',
    );
  }

  Future<bool> resolveSplit(
    String caseId,
    double releaseAmount,
    double refundAmount,
    String adminNote,
  ) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .resolveSplit(
            caseId: caseId,
            adminId: adminId,
            releaseAmount: releaseAmount,
            refundAmount: refundAmount,
            adminNote: adminNote,
          ),
      caseId: caseId,
      summary: 'Split settlement',
    );
  }

  Future<bool> completeDemoSettlement({
    required String caseId,
    required String resolutionType,
    required double freelancerAmount,
    required double customerAmount,
    required String decisionNote,
  }) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .completeDemoSettlement(
            caseId: caseId,
            adminId: adminId,
            resolutionType: resolutionType,
            freelancerAmount: freelancerAmount,
            customerAmount: customerAmount,
            decisionNote: decisionNote,
          ),
      caseId: caseId,
      summary: 'Demo settlement ($resolutionType)',
    );
  }

  Future<ResolutionSettlementRequestModel?> createSettlementRequest({
    required ResolutionCaseModel item,
    required String decision,
    required double releaseAmount,
    required double refundAmount,
    required String adminNote,
  }) async {
    state = const AsyncLoading();
    ResolutionSettlementRequestModel? created;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      created = await ref
          .read(resolutionSettlementRequestRepositoryProvider)
          .createSettlementRequest(
            item: item,
            adminId: user.uid,
            decision: decision,
            releaseAmount: releaseAmount,
            refundAmount: refundAmount,
            adminNote: adminNote,
          );
    });
    return state.hasError ? null : created;
  }

  Future<bool> rejectCase(String caseId, String adminNote) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .rejectCase(caseId: caseId, adminId: adminId, adminNote: adminNote),
      caseId: caseId,
      summary: 'Case rejected',
    );
  }

  Future<bool> closeCase(String caseId) {
    return _adminAction(
      (adminId) => ref
          .read(resolutionV2RepositoryProvider)
          .closeCase(caseId: caseId, adminId: adminId),
      caseId: caseId,
      notify: false,
    );
  }

  Future<bool> _userAction(
    Future<Object?> Function(String userId, UserModel? profile) action, {
    Future<void> Function(String userId, Object? result)? afterSuccess,
  }) async {
    state = const AsyncLoading();
    Object? result;
    String? actorId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      actorId = user.uid;
      final profile = ref.read(currentUserProvider).value;
      result = await action(user.uid, profile);
    });
    if (!state.hasError && afterSuccess != null && actorId != null) {
      try {
        await afterSuccess(actorId!, result);
      } catch (_) {
        // Never fail the primary resolution action because of notify.
      }
    }
    return !state.hasError;
  }

  Future<bool> _adminAction(
    Future<void> Function(String adminId) action, {
    String? caseId,
    String? summary,
    bool notify = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      final resolvedCaseId = (caseId ?? '').trim();
      ResolutionCaseModel? before;
      if (notify && resolvedCaseId.isNotEmpty) {
        before = await ref
            .read(resolutionV2RepositoryProvider)
            .getCase(resolvedCaseId);
      }
      await action(user.uid);
      if (notify && before != null) {
        await _notifyResolutionParties(
          item: before,
          adminId: user.uid,
          summary: summary ?? 'Resolution updated',
        );
      }
    });
    return !state.hasError;
  }

  Future<void> _notifyResolutionParties({
    required ResolutionCaseModel item,
    required String adminId,
    required String summary,
  }) async {
    final recipients = <String>{
      if (item.clientId.trim().isNotEmpty) item.clientId.trim(),
      if (item.freelancerId.trim().isNotEmpty) item.freelancerId.trim(),
    };
    if (recipients.isEmpty) return;

    final titleLabel = item.serviceTitle.trim().isEmpty
        ? 'your order'
        : item.serviceTitle.trim();
    final notifications = ref.read(notificationServiceProvider);

    for (final recipientId in recipients) {
      final isClient = recipientId == item.clientId.trim();
      await notifications.notifyOne(
        recipientId: recipientId,
        title: 'Resolution update',
        body: '$summary for $titleLabel.',
        category: NotificationCategories.admin,
        event: NotificationEvents.adminResolutionUpdated,
        actorId: adminId,
        actorRole: 'admin',
        relatedPath: 'resolutionCases/${item.caseId}',
        routeName: isClient
            ? RouteNames.customerResolutions
            : RouteNames.freelancerResolutions,
        priority: 'high',
        meta: {
          'caseId': item.caseId,
          'orderId': item.orderId,
          'summary': summary,
        },
      );
    }
  }

  Future<void> _notifyDisputeOpened({
    required String caseId,
    required String actorId,
  }) async {
    final item = await ref
        .read(resolutionV2RepositoryProvider)
        .getCase(caseId);
    if (item == null) return;

    final titleLabel = item.serviceTitle.trim().isEmpty
        ? 'your order'
        : item.serviceTitle.trim();
    final counterpartyId = _counterpartyId(item, actorId);
    final notifications = ref.read(notificationServiceProvider);
    final meta = <String, dynamic>{
      'caseId': item.caseId,
      'orderId': item.orderId,
      'type': item.type,
    };

    // Peer notify via orderId → existing notifSoPeer gate (no new rules).
    if (counterpartyId.isNotEmpty) {
      final isClient = counterpartyId == item.clientId.trim();
      await notifications.notifyOne(
        recipientId: counterpartyId,
        title: 'Dispute opened',
        body: 'A dispute was opened on $titleLabel.',
        category: NotificationCategories.support,
        event: NotificationEvents.supportDisputeOpened,
        actorId: actorId,
        relatedPath: 'serviceOrders/${item.orderId}',
        routeName: isClient
            ? RouteNames.customerResolutions
            : RouteNames.freelancerResolutions,
        priority: 'high',
        meta: meta,
      );
    }

    // Admin fan-out (same pattern as support tickets).
    try {
      final adminIds = await ref
          .read(adminRepositoryProvider)
          .listAdminRecipientIds();
      if (adminIds.isNotEmpty) {
        await notifications.notifyMany(
          recipientIds: adminIds.where((id) => id.trim() != actorId),
          title: 'Dispute opened',
          body: 'A dispute was opened on $titleLabel.',
          category: NotificationCategories.support,
          event: NotificationEvents.supportDisputeOpened,
          actorId: actorId,
          relatedPath: 'resolutionCases/${item.caseId}',
          routeName: RouteNames.adminInbox,
          priority: 'high',
          meta: meta,
        );
      }
    } catch (_) {
      // Peer notify may still have succeeded; admin fan-out is best-effort.
    }
  }

  Future<void> _notifyCaseOpened({
    required String caseId,
    required String actorId,
    required String title,
    required String bodyPrefix,
  }) async {
    final item = await ref
        .read(resolutionV2RepositoryProvider)
        .getCase(caseId);
    if (item == null) return;
    final counterpartyId = _counterpartyId(item, actorId);
    if (counterpartyId.isEmpty) return;

    final titleLabel = item.serviceTitle.trim().isEmpty
        ? 'your order'
        : item.serviceTitle.trim();
    final isClient = counterpartyId == item.clientId.trim();
    await ref.read(notificationServiceProvider).notifyOne(
      recipientId: counterpartyId,
      title: title,
      body: '$bodyPrefix $titleLabel.',
      category: NotificationCategories.support,
      event: NotificationEvents.supportResolutionPeer,
      actorId: actorId,
      relatedPath: 'serviceOrders/${item.orderId}',
      routeName: isClient
          ? RouteNames.customerResolutions
          : RouteNames.freelancerResolutions,
      priority: 'high',
      meta: {
        'caseId': item.caseId,
        'orderId': item.orderId,
        'type': item.type,
      },
    );
  }

  Future<void> _notifyResolutionPeer({
    required String caseId,
    required String actorId,
    required String title,
    required String summary,
  }) async {
    final item = await ref
        .read(resolutionV2RepositoryProvider)
        .getCase(caseId.trim());
    if (item == null) return;
    final counterpartyId = _counterpartyId(item, actorId);
    if (counterpartyId.isEmpty) return;

    final titleLabel = item.serviceTitle.trim().isEmpty
        ? 'your order'
        : item.serviceTitle.trim();
    final isClient = counterpartyId == item.clientId.trim();
    await ref.read(notificationServiceProvider).notifyOne(
      recipientId: counterpartyId,
      title: title,
      body: '$summary for $titleLabel.',
      category: NotificationCategories.support,
      event: NotificationEvents.supportResolutionPeer,
      actorId: actorId,
      relatedPath: 'serviceOrders/${item.orderId}',
      routeName: isClient
          ? RouteNames.customerResolutions
          : RouteNames.freelancerResolutions,
      priority: 'normal',
      meta: {
        'caseId': item.caseId,
        'orderId': item.orderId,
        'type': item.type,
        'summary': summary,
      },
    );
  }

  String _counterpartyId(ResolutionCaseModel item, String actorId) {
    final clientId = item.clientId.trim();
    final freelancerId = item.freelancerId.trim();
    final actor = actorId.trim();
    if (actor == clientId) return freelancerId;
    if (actor == freelancerId) return clientId;
    final against = (item.againstUserId ?? '').trim();
    if (against.isNotEmpty && against != actor) return against;
    return '';
  }

  String _roleName(UserModel? user) {
    if (user?.primaryRole == 'freelancer' ||
        (user?.roles.contains('freelancer') ?? false)) {
      return 'freelancer';
    }
    if (user?.isAdmin == true || user?.isSystemOwner == true) return 'admin';
    return 'client';
  }

  String? get errorMessage {
    final error = state.error;
    if (error == null) return null;
    if (error is AppException) return error.message;
    final message = error.toString();
    if (message.contains('Dart exception thrown from converted Future')) {
      return 'Unable to complete resolution action. Please try again.';
    }
    return message;
  }
}
