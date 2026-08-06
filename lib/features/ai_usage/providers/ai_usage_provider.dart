import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_events.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../data/ai_usage_repository.dart';
import '../models/ai_usage_models.dart';
import '../services/ai_usage_guard_service.dart';

final aiUsageRepositoryProvider = Provider<AiUsageRepository>((ref) {
  return AiUsageRepository(ref.watch(firestoreProvider));
});

final aiUsageGuardServiceProvider = Provider<AiUsageGuardService>((ref) {
  return AiUsageGuardService(ref.watch(aiUsageRepositoryProvider));
});

final aiSettingsProvider = StreamProvider<AiSettingsModel>((ref) {
  return ref.watch(aiUsageRepositoryProvider).watchSettings();
});

final aiRoleQuotasProvider = StreamProvider<List<AiRoleQuotaModel>>((ref) {
  return ref.watch(aiUsageRepositoryProvider).watchRoleQuotas();
});

final aiFeatureCostsProvider = StreamProvider<List<AiFeatureCostModel>>((ref) {
  return ref.watch(aiUsageRepositoryProvider).watchFeatureCosts();
});

final aiCreditRequestsProvider = StreamProvider<List<AiCreditRequestModel>>((
  ref,
) {
  return ref.watch(aiUsageRepositoryProvider).watchCreditRequests();
});

final aiUsageLogsProvider = StreamProvider<List<AiUsageLogModel>>((ref) {
  return ref.watch(aiUsageRepositoryProvider).watchUsageLogs();
});

final aiAllUserCreditsProvider = StreamProvider<List<AiUserCreditsModel>>((
  ref,
) {
  return ref.watch(aiUsageRepositoryProvider).watchAllUserCredits();
});

final currentAiUserCreditsProvider = StreamProvider<AiUserCreditsModel>((ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  final profile = ref.watch(currentUserProvider).value;
  if (user == null) {
    return const Stream.empty();
  }
  return ref
      .watch(aiUsageRepositoryProvider)
      .watchUserCredits(userId: user.uid, role: profile?.primaryRole ?? 'user');
});

final aiUsageAdminActionProvider =
    AsyncNotifierProvider<AiUsageAdminActionNotifier, void>(
      AiUsageAdminActionNotifier.new,
    );

class AiUsageAdminActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AiUsageRepository get _repo => ref.read(aiUsageRepositoryProvider);

  String get _adminId =>
      ref.read(authRepositoryProvider).currentUser?.uid ?? 'admin';

  Future<void> updateSettings(AiSettingsModel settings) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.updateSettings(settings, _adminId),
    );
  }

  Future<void> updateRoleQuota(AiRoleQuotaModel quota) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.updateRoleQuota(quota, _adminId),
    );
  }

  Future<void> updateFeatureCost(AiFeatureCostModel feature) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.updateFeatureCost(feature, _adminId),
    );
  }

  Future<void> seedDefaultConfiguration() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.seedDefaultConfiguration(_adminId),
    );
  }

  Future<void> adjustUserCredits({
    required String userId,
    required String role,
    required int delta,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.adjustUserBonusCredits(
        userId: userId,
        role: role,
        delta: delta,
        adminId: _adminId,
      ),
    );
  }

  Future<void> reviewRequest({
    required AiCreditRequestModel request,
    required String status,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.reviewCreditRequest(
        request: request,
        status: status,
        adminId: _adminId,
        note: note,
      ),
    );
    if (!state.hasError) {
      final normalized = status.trim().toLowerCase();
      if (normalized == 'approved' || normalized == 'rejected') {
        try {
          final credits = request.requestedCredits;
          await ref.read(notificationServiceProvider).notifyOne(
            recipientId: request.userId,
            title: 'AI credit request $normalized',
            body: normalized == 'approved'
                ? 'Your request for $credits AI credits was approved.'
                : 'Your request for $credits AI credits was rejected.',
            category: NotificationCategories.admin,
            event: NotificationEvents.adminAiCreditDecided,
            actorId: _adminId,
            actorRole: 'admin',
            relatedPath: 'aiCreditRequests/${request.requestId}',
            priority: 'high',
            meta: {
              'requestId': request.requestId,
              'status': normalized,
              'requestedCredits': credits,
            },
          );
        } catch (_) {
          // Never fail the primary credit decision because of notify.
        }
      }
    }
  }
}

final aiCreditRequestActionProvider =
    AsyncNotifierProvider<AiCreditRequestActionNotifier, void>(
      AiCreditRequestActionNotifier.new,
    );

class AiCreditRequestActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> requestMoreCredits({
    required int requestedCredits,
    required String reason,
  }) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final profile = ref.read(currentUserProvider).value;
    if (user == null) throw StateError('Please sign in first.');
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(aiUsageRepositoryProvider)
          .requestCredits(
            userId: user.uid,
            role: profile?.primaryRole ?? 'user',
            requestedCredits: requestedCredits,
            reason: reason,
          ),
    );
  }
}
