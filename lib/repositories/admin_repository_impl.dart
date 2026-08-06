import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../core/services/firestore_permission_logger.dart';
import '../models/admin_model.dart';
import '../models/audit_log.dart';
import '../models/platform_settings.dart';
import '../models/platform_stats.dart';
import '../models/user_model.dart';
import '../models/verification_request.dart';
import 'admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _adminsRef =>
      _firestore.collection('admins');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      _firestore.collection('logs');

  DocumentReference<Map<String, dynamic>> get _platformSettingsRef =>
      _firestore.collection('settings').doc('platform');

  @override
  Future<AdminModel?> getAdminProfile(String userId) async {
    try {
      final doc = await _adminsRef.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AdminModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'Admin',
        repository: 'AdminRepositoryImpl',
        operation: 'getAdminProfile',
        path: 'admins/$userId',
        action: 'read',
        uid: userId,
      );
    } catch (e) {
      throw FirestoreException(
        'Failed to fetch admin profile: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> updateAdminProfile(AdminModel admin) async {
    try {
      await _adminsRef
          .doc(admin.userId)
          .set(admin.toJson(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'Admin',
        repository: 'AdminRepositoryImpl',
        operation: 'updateAdminProfile',
        path: 'admins/${admin.userId}',
        action: 'write',
        uid: admin.userId,
      );
    } catch (e) {
      throw FirestoreException(
        'Failed to update admin profile: ${e.toString()}',
      );
    }
  }

  @override
  Stream<List<UserModel>> streamAllUsers() {
    return _usersRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        )
        .handleError((Object error, StackTrace stackTrace) {
          _logStreamPermissionDenied(
            error,
            operation: 'streamAllUsers',
            path: 'users',
            action: 'list',
          );
          throw error;
        });
  }

  @override
  Stream<List<UserModel>> streamAdminUsers() {
    return _usersRef
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .where((user) => user.isAdmin || user.isSystemOwner)
              .toList();
          users.sort((a, b) {
            final roleOrder = (a.isSystemOwner || a.isSuperAdmin)
                ? -1
                : (b.isSystemOwner || b.isSuperAdmin)
                ? 1
                : 0;
            if (roleOrder != 0) return roleOrder;
            return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          });
          return users;
        })
        .handleError((Object error, StackTrace stackTrace) {
          _logStreamPermissionDenied(
            error,
            operation: 'streamAdminUsers',
            path: 'users',
            action: 'list',
          );
          throw error;
        });
  }

  @override
  Future<List<String>> listAdminRecipientIds({int limit = 50}) async {
    try {
      final capped = limit < 1 ? 50 : (limit > 100 ? 100 : limit);
      final snapshot = await _adminsRef.limit(capped).get();
      return snapshot.docs
          .map((doc) => doc.id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'Admin',
        repository: 'AdminRepositoryImpl',
        operation: 'listAdminRecipientIds',
        path: 'admins',
        action: 'list',
      );
    } catch (e) {
      throw FirestoreException(
        'Failed to list admin recipients: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> updateUserStatus(
    String userId,
    String status, {
    required String adminId,
  }) async {
    if (!const {'active', 'banned', 'suspended'}.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported account status');
    }
    try {
      final targetDoc = await _usersRef.doc(userId).get();
      final targetData = targetDoc.data();
      final targetRole = targetData?['primaryRole']?.toString();
      final operatorHasCriticalAccess = await _hasCriticalAdminAccess(adminId);

      if (adminId == userId) {
        throw StateError('Administrators cannot change their own status.');
      }
      if (_isSystemOwnerData(targetData)) {
        throw StateError('The system owner cannot be banned or suspended.');
      }
      if (_isSuperAdminRole(targetRole) && status != 'active') {
        throw StateError('Super administrators cannot be banned or suspended.');
      }
      if (_isAdminRole(targetRole) && !operatorHasCriticalAccess) {
        throw StateError(
          'Only a super administrator or system owner can manage administrator status.',
        );
      }

      final batch = _firestore.batch();
      batch.update(_usersRef.doc(userId), {
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': adminId,
      });
      _addAuditLog(
        batch,
        adminId: adminId,
        action: switch (status) {
          'banned' => 'user_banned',
          'suspended' => 'user_suspended',
          _ => 'user_restored',
        },
        targetId: userId,
        targetType: 'user',
        description: 'User account status changed to $status.',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'Admin',
        repository: 'AdminRepositoryImpl',
        operation: 'getPlatformStats',
        path: 'users/jobs/applications/teachers/companies',
        action: 'aggregate',
      );
    } catch (e) {
      throw FirestoreException('Failed to update user status: ${e.toString()}');
    }
  }

  @override
  Future<void> promoteUserToAdmin(
    String identifier, {
    required String adminId,
  }) async {
    final lookup = identifier.trim();
    if (lookup.isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'User lookup is empty',
      );
    }

    try {
      await _ensureCriticalAdmin(adminId);
      final target = await _findUserByUidOrEmail(lookup);
      if (target == null) {
        throw StateError('No user found for $lookup.');
      }
      if (target.uid == adminId) {
        throw StateError('Super administrators cannot promote themselves.');
      }
      if (target.isSystemOwner) {
        throw StateError('The system owner cannot be modified.');
      }
      if (_isSuperAdminRole(target.primaryRole)) {
        throw StateError('Cannot modify another super administrator.');
      }

      final batch = _firestore.batch();
      batch.set(_usersRef.doc(target.uid), {
        'roles': ['admin'],
        'primaryRole': 'admin',
        'status': 'active',
        'onboardingCompleted': true,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdatedBy': adminId,
      }, SetOptions(merge: true));
      batch.set(_adminsRef.doc(target.uid), {
        'accessLevel': 'admin',
        'assignedRegion': 'global',
        'lastActive': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminId,
      }, SetOptions(merge: true));
      _addAuditLog(
        batch,
        adminId: adminId,
        action: 'user_promoted_to_admin',
        targetId: target.uid,
        targetType: 'admin',
        description: '${target.email} was promoted to administrator.',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create admin: ${e.toString()}');
    }
  }

  @override
  Future<void> promoteAdminToSuperAdmin(
    String userId, {
    required String adminId,
  }) async {
    try {
      await _ensureCriticalAdmin(adminId);
      final target = await _usersRef.doc(userId).get();
      final targetData = target.data();
      final targetEmail = targetData?['email']?.toString() ?? userId;
      final targetRole = targetData?['primaryRole']?.toString();

      if (adminId == userId) {
        throw StateError('Administrators cannot promote themselves.');
      }
      if (_isSystemOwnerData(targetData)) {
        throw StateError('The system owner cannot be modified.');
      }
      if (_isSuperAdminRole(targetRole)) {
        throw StateError('Target user is already a super administrator.');
      }
      if (!_isAdminRole(targetRole)) {
        throw StateError('Target user must be an administrator first.');
      }

      final batch = _firestore.batch();
      batch.set(_usersRef.doc(userId), {
        'roles': ['super_admin'],
        'primaryRole': 'super_admin',
        'status': 'active',
        'onboardingCompleted': true,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdatedBy': adminId,
      }, SetOptions(merge: true));
      batch.set(_adminsRef.doc(userId), {
        'accessLevel': 'super_admin',
        'isSuperAdmin': true,
        'lastActive': FieldValue.serverTimestamp(),
        'promotedAt': FieldValue.serverTimestamp(),
        'promotedBy': adminId,
      }, SetOptions(merge: true));
      _addAuditLog(
        batch,
        adminId: adminId,
        action: 'user_promoted_to_super_admin',
        targetId: userId,
        targetType: 'admin',
        description: '$targetEmail was promoted to super administrator.',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to promote super admin: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> demoteAdmin(String userId, {required String adminId}) async {
    try {
      await _ensureCriticalAdmin(adminId);
      final target = await _usersRef.doc(userId).get();
      final targetData = target.data();
      final targetRole = targetData?['primaryRole']?.toString();
      final targetEmail = targetData?['email']?.toString() ?? userId;

      if (adminId == userId) {
        throw StateError('Super administrators cannot remove themselves.');
      }
      if (_isSystemOwnerData(targetData)) {
        throw StateError('The system owner cannot be modified.');
      }
      if (_isSuperAdminRole(targetRole)) {
        final remaining = await _activeSuperAdminCount(excludingUserId: userId);
        if (remaining <= 0) {
          throw StateError('Cannot remove the last super administrator.');
        }
      }
      if (!_isAdminRole(targetRole)) {
        throw StateError('Target user is not an administrator.');
      }

      if (await _isMaintenanceModeEnabled()) {
        final actorIsLastSuperAdmin =
            await _isSuperAdminUser(adminId) &&
            await _activeSuperAdminCount(excludingUserId: adminId) <= 0;
        if (actorIsLastSuperAdmin) {
          throw StateError(
            'The last super administrator cannot remove admins during maintenance.',
          );
        }
      }

      final batch = _firestore.batch();
      batch.set(_usersRef.doc(userId), {
        'roles': ['student'],
        'primaryRole': 'student',
        'onboardingCompleted': false,
        'profileCompleted': 0,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdatedBy': adminId,
      }, SetOptions(merge: true));
      batch.delete(_adminsRef.doc(userId));
      _addAuditLog(
        batch,
        adminId: adminId,
        action: 'admin_removed',
        targetId: userId,
        targetType: 'admin',
        description: '$targetEmail was removed from administrator access.',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to remove admin: ${e.toString()}');
    }
  }

  @override
  Future<void> updateUserRole(
    String userId,
    String role, {
    required String adminId,
  }) async {
    const adminRoles = {'admin', 'superAdmin', 'super_admin'};
    const validRoles = {
      'student',
      'teacher',
      'freelancer',
      'company',
      ...adminRoles,
    };
    if (!validRoles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unsupported user role');
    }

    try {
      final targetDoc = await _usersRef.doc(userId).get();
      final targetData = targetDoc.data();
      final oldRole = targetData?['primaryRole']?.toString();
      final hasCriticalAccess = await _hasCriticalAdminAccess(adminId);

      if (adminId == userId) {
        throw StateError('Administrators cannot change their own role.');
      }
      if (_isSystemOwnerData(targetData)) {
        throw StateError('The system owner cannot be modified.');
      }
      if (_isSuperAdminRole(oldRole) ||
          role == 'superAdmin' ||
          role == 'super_admin') {
        throw StateError(
          'Super administrator roles must be managed outside this action.',
        );
      }
      if (!hasCriticalAccess &&
          (adminRoles.contains(oldRole) || adminRoles.contains(role))) {
        throw StateError(
          'Only a super administrator or system owner can manage administrator roles.',
        );
      }

      final skipsOnboarding = adminRoles.contains(role);
      final batch = _firestore.batch();
      batch.update(_usersRef.doc(userId), {
        'roles': [role],
        'primaryRole': role,
        'onboardingCompleted': skipsOnboarding,
        if (!skipsOnboarding) 'profileCompleted': 0,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdatedBy': adminId,
      });
      _addAuditLog(
        batch,
        adminId: adminId,
        action: 'user_role_changed',
        targetId: userId,
        targetType: 'user',
        description:
            'User role changed from ${oldRole ?? 'unassigned'} to $role.',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update user role: ${e.toString()}');
    }
  }

  @override
  Future<void> revokeFreelancerUnlock(
    String userId, {
    required String adminId,
  }) async {
    try {
      final targetDoc = await _usersRef.doc(userId).get();
      final targetData = targetDoc.data();
      if (targetData == null) {
        throw StateError('User not found.');
      }
      if (adminId == userId) {
        throw StateError('Administrators cannot revoke their own unlock.');
      }
      if (_isSystemOwnerData(targetData)) {
        throw StateError('The system owner cannot be modified.');
      }
      if (targetData['freelancerUnlocked'] != true) {
        throw StateError('This user does not have a Freelancer Bridge unlock.');
      }

      final roles = (targetData['roles'] is Iterable)
          ? (targetData['roles'] as Iterable)
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList()
          : <String>[];
      final nextRoles = roles
          .where((role) => role.toLowerCase() != 'freelancer')
          .toList();
      if (!nextRoles.map((r) => r.toLowerCase()).contains('student')) {
        nextRoles.add('student');
      }

      final batch = _firestore.batch();
      batch.update(_usersRef.doc(userId), {
        'roles': nextRoles,
        'primaryRole': 'student',
        'freelancerUnlocked': false,
        'freelancerUnlockedAt': FieldValue.delete(),
        'freelancerRevokedAt': FieldValue.serverTimestamp(),
        'freelancerRevokedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _addAuditLog(
        batch,
        adminId: adminId,
        action: 'freelancer_bridge_unlock_revoked',
        targetId: userId,
        targetType: 'user',
        description:
            'Freelancer Bridge unlock revoked. Student role and LMS data retained.',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to revoke freelancer unlock: ${e.toString()}',
      );
    }
  }

  @override
  Future<PlatformStats> getPlatformStats() async {
    try {
      final counts = await Future.wait([
        _usersRef.count().get(),
        _usersRef.where('primaryRole', isEqualTo: 'student').count().get(),
        _usersRef.where('primaryRole', isEqualTo: 'teacher').count().get(),
        _usersRef.where('primaryRole', isEqualTo: 'freelancer').count().get(),
        _usersRef.where('primaryRole', isEqualTo: 'company').count().get(),
        _firestore.collection('jobs').count().get(),
        _firestore.collection('applications').count().get(),
        _usersRef.where('status', isEqualTo: 'banned').count().get(),
        _firestore.collection('teachers').count().get(),
        _firestore
            .collection('teachers')
            .where('verificationStatus', isEqualTo: 'approved')
            .count()
            .get(),
        _firestore
            .collection('teachers')
            .where('verificationStatus', isEqualTo: 'verified')
            .count()
            .get(),
        _firestore
            .collection('teachers')
            .where('verificationStatus', isEqualTo: 'rejected')
            .count()
            .get(),
        _firestore.collection('companies').count().get(),
        _firestore
            .collection('companies')
            .where('verificationStatus', isEqualTo: 'approved')
            .count()
            .get(),
        _firestore
            .collection('companies')
            .where('verificationStatus', isEqualTo: 'verified')
            .count()
            .get(),
        _firestore
            .collection('companies')
            .where('verificationStatus', isEqualTo: 'rejected')
            .count()
            .get(),
      ]);

      return PlatformStats(
        totalUsers: counts[0].count ?? 0,
        students: counts[1].count ?? 0,
        teachers: counts[2].count ?? 0,
        freelancers: counts[3].count ?? 0,
        companies: counts[4].count ?? 0,
        jobs: counts[5].count ?? 0,
        applications: counts[6].count ?? 0,
        bannedUsers: counts[7].count ?? 0,
        pendingVerifications:
            _pendingCount(
              total: counts[8].count ?? 0,
              approved: counts[9].count ?? 0,
              legacyVerified: counts[10].count ?? 0,
              rejected: counts[11].count ?? 0,
            ) +
            _pendingCount(
              total: counts[12].count ?? 0,
              approved: counts[13].count ?? 0,
              legacyVerified: counts[14].count ?? 0,
              rejected: counts[15].count ?? 0,
            ),
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to fetch platform stats: ${e.toString()}',
      );
    }
  }

  @override
  Stream<List<VerificationRequest>> streamTeacherVerifications() {
    return _verificationStream('teachers', 'teacher');
  }

  @override
  Stream<List<VerificationRequest>> streamCompanyVerifications() {
    return _verificationStream('companies', 'company');
  }

  Stream<List<VerificationRequest>> _verificationStream(
    String collection,
    String role,
  ) {
    return _firestore
        .collection(collection)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(
                (document) =>
                    VerificationRequest.fromFirestore(document, role: role),
              )
              .toList();
          requests.sort((a, b) {
            final statusOrder = _verificationStatusOrder(
              a.status,
            ).compareTo(_verificationStatusOrder(b.status));
            if (statusOrder != 0) return statusOrder;
            return (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                );
          });
          return requests;
        })
        .handleError((Object error, StackTrace stackTrace) {
          _logStreamPermissionDenied(
            error,
            operation:
                'stream${role[0].toUpperCase()}${role.substring(1)}Verifications',
            path: collection,
            action: 'list',
          );
          throw error;
        });
  }

  @override
  Future<void> updateVerificationStatus(
    VerificationRequest request,
    String status, {
    required String adminId,
  }) async {
    if (!const {'pending', 'approved', 'rejected'}.contains(status)) {
      throw ArgumentError.value(
        status,
        'status',
        'Unsupported verification status',
      );
    }
    final collection = request.role == 'company' ? 'companies' : 'teachers';
    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(collection).doc(request.userId),
        {
          'verificationStatus': status,
          'verificationUpdatedAt': FieldValue.serverTimestamp(),
          'verificationUpdatedBy': adminId,
        },
        SetOptions(merge: true),
      );
      _addAuditLog(
        batch,
        adminId: adminId,
        action: '${request.role}_verification_$status',
        targetId: request.userId,
        targetType: request.role,
        description:
            '${request.role} verification changed to $status for ${request.displayName}.',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to update verification: ${e.toString()}',
      );
    }
  }

  @override
  Stream<PlatformSettings> streamPlatformSettings() {
    return _platformSettingsRef
        .snapshots()
        .map(
          (document) => PlatformSettings.fromJson(
            document.data() ?? const <String, dynamic>{},
          ),
        )
        .handleError((Object error, StackTrace stackTrace) {
          _logStreamPermissionDenied(
            error,
            operation: 'streamPlatformSettings',
            path: 'settings/platform',
            action: 'read',
          );
          throw error;
        });
  }

  @override
  Future<void> updatePlatformSettings(
    PlatformSettings settings, {
    required String adminId,
  }) async {
    try {
      await _ensureCriticalAdmin(adminId);
      final previousSettings = await _platformSettingsRef.get();
      final previousMaintenance =
          previousSettings.data()?['maintenanceMode'] == true;
      final batch = _firestore.batch();
      batch.set(_platformSettingsRef, {
        ...settings.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      }, SetOptions(merge: true));
      _addAuditLog(
        batch,
        adminId: adminId,
        action: 'platform_settings_updated',
        targetId: 'platform',
        targetType: 'settings',
        description: 'Platform configuration was updated.',
      );
      if (previousMaintenance != settings.maintenanceMode) {
        _addAuditLog(
          batch,
          adminId: adminId,
          action: settings.maintenanceMode
              ? 'maintenance_enabled'
              : 'maintenance_disabled',
          targetId: 'platform',
          targetType: 'settings',
          description: settings.maintenanceMode
              ? 'Maintenance mode was enabled.'
              : 'Maintenance mode was disabled.',
        );
      }
      final previousSie =
          previousSettings.data()?['sieGloballyEnabled'] != false;
      if (previousSie != settings.sieGloballyEnabled) {
        _addAuditLog(
          batch,
          adminId: adminId,
          action: settings.sieGloballyEnabled
              ? 'sie_globally_enabled'
              : 'sie_globally_disabled',
          targetId: 'sie',
          targetType: 'settings',
          description: settings.sieGloballyEnabled
              ? 'Spatial Interaction Engine was enabled globally.'
              : 'Spatial Interaction Engine was disabled globally (kill switch).',
        );
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to update platform settings: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> setMaintenanceMode(
    bool enabled, {
    required String adminId,
  }) async {
    try {
      await _ensureCriticalAdmin(adminId);
      final currentDoc = await _platformSettingsRef.get();
      final currentSettings = PlatformSettings.fromJson(
        currentDoc.data() ?? const <String, dynamic>{},
      );
      await updatePlatformSettings(
        currentSettings.copyWith(maintenanceMode: enabled),
        adminId: adminId,
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to update maintenance mode: ${e.toString()}',
      );
    }
  }

  @override
  Stream<List<AuditLog>> streamAuditLogs({int limit = 100}) {
    return _logsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AuditLog.fromFirestore).toList())
        .handleError((Object error, StackTrace stackTrace) {
          _logStreamPermissionDenied(
            error,
            operation: 'streamAuditLogs',
            path: 'logs',
            action: 'list',
          );
          throw error;
        });
  }

  void _logStreamPermissionDenied(
    Object error, {
    required String operation,
    required String path,
    required String action,
  }) {
    if (error is! FirebaseException) return;
    FirestorePermissionLogger.logIfPermissionDenied(
      error,
      feature: 'Admin',
      repository: 'AdminRepositoryImpl',
      operation: operation,
      path: path,
      action: action,
    );
  }

  void _addAuditLog(
    WriteBatch batch, {
    required String adminId,
    required String action,
    required String targetId,
    required String targetType,
    required String description,
  }) {
    batch.set(_logsRef.doc(), {
      'adminId': adminId,
      'action': action,
      'targetId': targetId,
      'targetType': targetType,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureCriticalAdmin(String adminId) async {
    if (!await _hasCriticalAdminAccess(adminId)) {
      throw StateError(
        'Only a super administrator or system owner can perform this action.',
      );
    }
  }

  Future<bool> _hasCriticalAdminAccess(String userId) async {
    return await _isSystemOwnerUser(userId) || await _isSuperAdminUser(userId);
  }

  Future<bool> _isSystemOwnerUser(String userId) async {
    final results = await Future.wait([
      _usersRef.doc(userId).get(),
      _adminsRef.doc(userId).get(),
    ]);
    return _isSystemOwnerData(results[0].data()) ||
        _isSystemOwnerData(results[1].data());
  }

  Future<bool> _isSuperAdminUser(String userId) async {
    final results = await Future.wait([
      _usersRef.doc(userId).get(),
      _adminsRef.doc(userId).get(),
    ]);

    final userData = results[0].data();
    if (_dataHasSuperAdminRole(userData)) return true;

    final adminData = results[1].data();
    final accessLevel = adminData?['accessLevel']?.toString();
    final role = adminData?['role']?.toString();
    final permissionLevel = adminData?['permissionLevel']?.toString();
    final isSuperAdmin = adminData?['isSuperAdmin'] == true;

    return isSuperAdmin ||
        _isSuperAdminRole(accessLevel) ||
        _isSuperAdminRole(role) ||
        _isSuperAdminRole(permissionLevel);
  }

  bool _dataHasSuperAdminRole(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (_isSuperAdminRole(data['primaryRole']?.toString())) return true;
    if (_isSuperAdminRole(data['role']?.toString())) return true;
    if (data['isSuperAdmin'] == true) return true;

    final roles = data['roles'];
    if (roles is String) return _isSuperAdminRole(roles);
    if (roles is Iterable) {
      return roles.any((role) => _isSuperAdminRole(role?.toString()));
    }
    return false;
  }

  bool _isSystemOwnerData(Map<String, dynamic>? data) {
    return data?['isSystemOwner'] == true;
  }

  Future<int> _activeSuperAdminCount({String? excludingUserId}) async {
    final snapshot = await _usersRef.get();
    return snapshot.docs.where((doc) {
      if (excludingUserId != null && doc.id == excludingUserId) return false;
      final data = doc.data();
      final status = data['status']?.toString().toLowerCase() ?? 'active';
      if (status == 'banned' || status == 'suspended') return false;
      return _dataHasSuperAdminRole(data);
    }).length;
  }

  Future<bool> _isMaintenanceModeEnabled() async {
    final doc = await _platformSettingsRef.get();
    return doc.data()?['maintenanceMode'] == true;
  }

  Future<UserModel?> _findUserByUidOrEmail(String lookup) async {
    final byId = await _usersRef.doc(lookup).get();
    if (byId.exists && byId.data() != null) {
      return UserModel.fromFirestore(byId);
    }

    var byEmail = await _usersRef
        .where('email', isEqualTo: lookup)
        .limit(1)
        .get();
    if (byEmail.docs.isEmpty && lookup.toLowerCase() != lookup) {
      byEmail = await _usersRef
          .where('email', isEqualTo: lookup.toLowerCase())
          .limit(1)
          .get();
    }
    if (byEmail.docs.isEmpty) return null;
    return UserModel.fromFirestore(byEmail.docs.first);
  }
}

bool _isAdminRole(String? role) {
  final normalized = _normalizeRole(role);
  return normalized == 'admin' || normalized == 'superadmin';
}

bool _isSuperAdminRole(String? role) {
  return _normalizeRole(role) == 'superadmin';
}

String _normalizeRole(String? role) {
  return (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

int _verificationStatusOrder(String status) {
  return switch (status) {
    'pending' => 0,
    'rejected' => 1,
    'approved' || 'verified' => 2,
    _ => 3,
  };
}

int _pendingCount({
  required int total,
  required int approved,
  required int legacyVerified,
  required int rejected,
}) {
  final pending = total - approved - legacyVerified - rejected;
  return pending < 0 ? 0 : pending;
}
