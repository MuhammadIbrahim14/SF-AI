import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ai_usage_models.dart';

class AiUsageGuardResult {
  const AiUsageGuardResult({
    required this.allowed,
    required this.cost,
    required this.reason,
    required this.settings,
    required this.roleQuota,
    required this.featureCost,
    required this.userCredits,
    this.heavyConfirmationRequired = false,
  });

  final bool allowed;
  final int cost;
  final String reason;
  final AiSettingsModel settings;
  final AiRoleQuotaModel roleQuota;
  final AiFeatureCostModel featureCost;
  final AiUserCreditsModel userCredits;
  final bool heavyConfirmationRequired;
}

class AiUsageRepository {
  AiUsageRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection('aiSettings').doc('main');

  Future<AiSettingsModel> getSettings() async {
    final doc = await _settingsDoc.get();
    return AiSettingsModel.fromMap(doc.data());
  }

  Future<AiSettingsModel> _getSettingsOrDefault() async {
    try {
      return await getSettings();
    } catch (_) {
      return AiSettingsModel.defaults();
    }
  }

  Stream<AiSettingsModel> watchSettings() {
    return _settingsDoc.snapshots().map((doc) {
      return AiSettingsModel.fromMap(doc.data());
    });
  }

  Future<void> updateSettings(AiSettingsModel settings, String adminId) {
    return _settingsDoc.set(
      settings.toMap(updatedBy: adminId),
      SetOptions(merge: true),
    );
  }

  Future<AiRoleQuotaModel> getRoleQuota(String role) async {
    final normalized = normalizeRole(role);
    final doc = await _firestore
        .collection('aiRoleQuotas')
        .doc(normalized)
        .get();
    return AiRoleQuotaModel.fromMap(normalized, doc.data());
  }

  Future<AiRoleQuotaModel> _getRoleQuotaOrDefault(String role) async {
    try {
      return await getRoleQuota(role);
    } catch (_) {
      return AiRoleQuotaModel.defaults(role);
    }
  }

  Stream<List<AiRoleQuotaModel>> watchRoleQuotas() {
    return _firestore.collection('aiRoleQuotas').snapshots().map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => AiRoleQuotaModel.fromMap(doc.id, doc.data()))
          .toList();
      final existing = docs.map((item) => item.role).toSet();
      final defaults = AiUsageDefaults.roleMonthlyCredits.keys
          .map(normalizeRole)
          .where((role) => !existing.contains(role))
          .map(AiRoleQuotaModel.defaults);
      return [...docs, ...defaults]..sort((a, b) => a.role.compareTo(b.role));
    });
  }

  Future<void> updateRoleQuota(AiRoleQuotaModel quota, String adminId) {
    return _firestore
        .collection('aiRoleQuotas')
        .doc(normalizeRole(quota.role))
        .set(quota.toMap(updatedBy: adminId), SetOptions(merge: true));
  }

  Future<AiFeatureCostModel> getFeatureCost(String taskType) async {
    final doc = await _firestore
        .collection('aiFeatureCosts')
        .doc(taskType)
        .get();
    return AiFeatureCostModel.fromMap(taskType, doc.data());
  }

  Future<AiFeatureCostModel> _getFeatureCostOrDefault(String taskType) async {
    try {
      return await getFeatureCost(taskType);
    } catch (_) {
      return AiFeatureCostModel.defaults(taskType);
    }
  }

  Stream<List<AiFeatureCostModel>> watchFeatureCosts() {
    return _firestore.collection('aiFeatureCosts').snapshots().map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => AiFeatureCostModel.fromMap(doc.id, doc.data()))
          .toList();
      final existing = docs.map((item) => item.taskType).toSet();
      final defaults = AiUsageDefaults.featureCosts.keys
          .where((task) => !existing.contains(task))
          .map(AiFeatureCostModel.defaults);
      return [...docs, ...defaults]
        ..sort((a, b) => a.taskType.compareTo(b.taskType));
    });
  }

  Future<void> updateFeatureCost(AiFeatureCostModel feature, String adminId) {
    return _firestore
        .collection('aiFeatureCosts')
        .doc(feature.taskType)
        .set(feature.toMap(updatedBy: adminId), SetOptions(merge: true));
  }

  Future<void> seedDefaultConfiguration(String adminId) async {
    final batch = _firestore.batch();

    final settingsDoc = await _settingsDoc.get();
    if (!settingsDoc.exists) {
      batch.set(
        _settingsDoc,
        AiSettingsModel.defaults().toMap(updatedBy: adminId),
      );
    }

    for (final role in AiUsageDefaults.roleMonthlyCredits.keys) {
      final normalized = normalizeRole(role);
      final ref = _firestore.collection('aiRoleQuotas').doc(normalized);
      final doc = await ref.get();
      if (!doc.exists) {
        batch.set(
          ref,
          AiRoleQuotaModel.defaults(normalized).toMap(updatedBy: adminId),
        );
      }
    }

    for (final taskType in AiUsageDefaults.featureCosts.keys) {
      final ref = _firestore.collection('aiFeatureCosts').doc(taskType);
      final doc = await ref.get();
      if (!doc.exists) {
        batch.set(
          ref,
          AiFeatureCostModel.defaults(taskType).toMap(updatedBy: adminId),
        );
      }
    }

    await batch.commit();
  }

  Future<AiUserCreditsModel> getUserCredits({
    required String userId,
    required String role,
    bool writeDefaultIfMissing = true,
  }) async {
    final doc = await _firestore.collection('aiUserCredits').doc(userId).get();
    final credits = AiUserCreditsModel.fromMap(
      userId: userId,
      role: role,
      map: doc.data(),
    );
    if (writeDefaultIfMissing &&
        (!doc.exists ||
            doc.data()?['currentMonthKey'] != credits.currentMonthKey)) {
      try {
        await _firestore
            .collection('aiUserCredits')
            .doc(userId)
            .set(credits.toMap(), SetOptions(merge: true));
      } catch (_) {
        // Best-effort only. Quota document setup must not block AI usage.
      }
    }
    return credits;
  }

  Future<AiUserCreditsModel> _getUserCreditsOrDefault({
    required String userId,
    required String role,
  }) async {
    try {
      return await getUserCredits(
        userId: userId,
        role: role,
        writeDefaultIfMissing: true,
      );
    } catch (_) {
      return AiUserCreditsModel.defaults(userId: userId, role: role);
    }
  }

  Stream<AiUserCreditsModel> watchUserCredits({
    required String userId,
    required String role,
  }) {
    return _firestore
        .collection('aiUserCredits')
        .doc(userId)
        .snapshots()
        .map(
          (doc) => AiUserCreditsModel.fromMap(
            userId: userId,
            role: role,
            map: doc.data(),
          ),
        );
  }

  Stream<List<AiUserCreditsModel>> watchAllUserCredits() {
    return _firestore
        .collection('aiUserCredits')
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AiUserCreditsModel.fromMap(
                  userId: doc.id,
                  role: doc.data()['role']?.toString() ?? 'user',
                  map: doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<AiUsageGuardResult> checkGuard({
    required String userId,
    required String role,
    required String taskType,
    bool heavyCandidate = false,
  }) async {
    final settings = await _getSettingsOrDefault();
    final roleQuota = await _getRoleQuotaOrDefault(role);
    final featureCost = await _getFeatureCostOrDefault(taskType);
    final userCredits = await _getUserCreditsOrDefault(
      userId: userId,
      role: role,
    );
    final cost = featureCost.creditCost;
    if (!settings.enabled) {
      return _blocked(
        'AI is currently disabled by admin.',
        cost,
        settings,
        roleQuota,
        featureCost,
        userCredits,
      );
    }
    if (!roleQuota.aiEnabled) {
      return _blocked(
        'AI is disabled for your role.',
        cost,
        settings,
        roleQuota,
        featureCost,
        userCredits,
      );
    }
    if (!roleQuota.allowsFeature(taskType)) {
      return _blocked(
        'This AI feature is not enabled for your role.',
        cost,
        settings,
        roleQuota,
        featureCost,
        userCredits,
      );
    }
    if (!featureCost.enabled) {
      return _blocked(
        'This AI feature is currently disabled.',
        cost,
        settings,
        roleQuota,
        featureCost,
        userCredits,
      );
    }
    if (userCredits.remainingCredits < cost) {
      return _blocked(
        'Not enough AI Credits remaining.',
        cost,
        settings,
        roleQuota,
        featureCost,
        userCredits,
      );
    }
    return AiUsageGuardResult(
      allowed: true,
      cost: cost,
      reason: 'Allowed',
      settings: settings,
      roleQuota: roleQuota,
      featureCost: featureCost,
      userCredits: userCredits,
      heavyConfirmationRequired: heavyCandidate || featureCost.isHeavy,
    );
  }

  AiUsageGuardResult _blocked(
    String reason,
    int cost,
    AiSettingsModel settings,
    AiRoleQuotaModel roleQuota,
    AiFeatureCostModel featureCost,
    AiUserCreditsModel userCredits,
  ) {
    return AiUsageGuardResult(
      allowed: false,
      cost: cost,
      reason: reason,
      settings: settings,
      roleQuota: roleQuota,
      featureCost: featureCost,
      userCredits: userCredits,
    );
  }

  Future<void> logUsageAndCharge({
    required String userId,
    required String role,
    required String taskType,
    required String feature,
    required String provider,
    required String status,
    required bool fallbackUsed,
    required Map<String, dynamic>? usage,
    required int requestedCost,
  }) async {
    final isRealProvider = provider == 'openai' || provider == 'gemini';
    final shouldCharge = status == 'success' && isRealProvider && !fallbackUsed;
    final creditsCharged = shouldCharge ? requestedCost : 0;
    final userRef = _firestore.collection('aiUserCredits').doc(userId);
    final logRef = _firestore.collection('aiUsageLogs').doc();
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(userRef);
      final credits = AiUserCreditsModel.fromMap(
        userId: userId,
        role: role,
        map: doc.data(),
      );
      final used = credits.usedCreditsThisMonth + creditsCharged;
      final remaining =
          (credits.monthlyFreeCredits + credits.bonusCredits - used).clamp(
            0,
            1000000,
          );
      transaction.set(userRef, {
        ...credits.toMap(),
        'usedCreditsThisMonth': used,
        'remainingCredits': remaining,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(logRef, {
        'userId': userId,
        'role': normalizeRole(role),
        'taskType': taskType,
        'feature': feature,
        'provider': provider == 'mock' ? 'template' : provider,
        'model': usage?['model']?.toString() ?? '',
        'status': status,
        'creditsCharged': creditsCharged,
        'promptTokens': _int(usage?['promptTokens']),
        'completionTokens': _int(usage?['completionTokens']),
        'totalTokens': _int(usage?['totalTokens']),
        'fallbackUsed': fallbackUsed,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> requestCredits({
    required String userId,
    required String role,
    required int requestedCredits,
    required String reason,
  }) {
    return _firestore.collection('aiCreditRequests').add({
      'userId': userId,
      'role': normalizeRole(role),
      'requestedCredits': requestedCredits,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AiCreditRequestModel>> watchCreditRequests() {
    return _firestore
        .collection('aiCreditRequests')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AiCreditRequestModel.fromDoc).toList(),
        );
  }

  Stream<List<AiUsageLogModel>> watchUsageLogs() {
    return _firestore
        .collection('aiUsageLogs')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AiUsageLogModel.fromDoc).toList());
  }

  Future<void> adjustUserBonusCredits({
    required String userId,
    required String role,
    required int delta,
    required String adminId,
  }) async {
    final ref = _firestore.collection('aiUserCredits').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      final credits = AiUserCreditsModel.fromMap(
        userId: userId,
        role: role,
        map: doc.data(),
      );
      final bonus = (credits.bonusCredits + delta).clamp(0, 1000000);
      final remaining =
          (credits.monthlyFreeCredits + bonus - credits.usedCreditsThisMonth)
              .clamp(0, 1000000);
      transaction.set(ref, {
        ...credits.toMap(adjustedBy: adminId),
        'bonusCredits': bonus,
        'remainingCredits': remaining,
      }, SetOptions(merge: true));
    });
  }

  Future<void> reviewCreditRequest({
    required AiCreditRequestModel request,
    required String status,
    required String adminId,
    String? note,
  }) async {
    if (status == 'approved') {
      await adjustUserBonusCredits(
        userId: request.userId,
        role: request.role,
        delta: request.requestedCredits,
        adminId: adminId,
      );
    }
    await _firestore.collection('aiCreditRequests').doc(request.requestId).set({
      'status': status,
      'adminNote': note ?? '',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminId,
    }, SetOptions(merge: true));
  }
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
