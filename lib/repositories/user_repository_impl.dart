import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/services/firestore_permission_logger.dart';
import '../models/user_model.dart';
import 'user_repository.dart';

/// SkillForge AI — Firestore User Repository Implementation
/// Manages user documents in the `users` collection.
class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  /// Reference to the users collection.
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(AppConstants.usersCollection);

  @override
  Future<void> createUser(UserModel user) async {
    try {
      await _usersRef.doc(user.uid).set(user.toJson());
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create user: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to fetch user: ${e.toString()}');
    }
  }

  @override
  Stream<UserModel?> userStream(String uid) {
    return _usersRef
        .doc(uid)
        .snapshots()
        .where((doc) {
          // Ignore optimistic local snapshots created by `updateUser(merge: true)`
          // (e.g. during signIn) that only contain `lastLogin` and lack core fields.
          final data = doc.data();
          if (data != null &&
              doc.metadata.hasPendingWrites &&
              !data.containsKey('email')) {
            return false;
          }
          return true;
        })
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return UserModel.fromFirestore(doc);
        });
  }

  @override
  Future<void> updateUserRole({
    required String uid,
    required List<String> roles,
    required String primaryRole,
  }) async {
    try {
      await _usersRef.doc(uid).set({
        'roles': roles,
        'primaryRole': primaryRole,
        'accountType': 'professional',
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update role: ${e.toString()}');
    }
  }

  @override
  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _usersRef.doc(uid).set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'User',
        repository: 'UserRepositoryImpl',
        operation: 'updateUser',
        path: 'users/$uid',
        action: 'update',
        uid: uid,
      );
    } catch (e) {
      throw FirestoreException('Failed to update user: ${e.toString()}');
    }
  }
}
