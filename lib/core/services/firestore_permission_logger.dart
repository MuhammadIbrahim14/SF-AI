import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exceptions.dart';

class FirestorePermissionLogger {
  const FirestorePermissionLogger._();

  static FirestoreException toFirestoreException(
    FirebaseException exception, {
    required String feature,
    required String repository,
    required String operation,
    required String path,
    required String action,
    String? uid,
    String? role,
    String? accountType,
  }) {
    logIfPermissionDenied(
      exception,
      feature: feature,
      repository: repository,
      operation: operation,
      path: path,
      action: action,
      uid: uid,
      role: role,
      accountType: accountType,
    );
    return FirestoreException.fromCode(exception.code);
  }

  static void logIfPermissionDenied(
    FirebaseException exception, {
    required String feature,
    required String repository,
    required String operation,
    required String path,
    required String action,
    String? uid,
    String? role,
    String? accountType,
  }) {
    if (!kDebugMode || exception.code != 'permission-denied') return;

    debugPrint(
      '[FirestorePermissionDenied] '
      'feature=$feature '
      'repository=$repository '
      'operation=$operation '
      'path=$path '
      'action=$action '
      'uid=${_safe(uid)} '
      'role=${_safe(role)} '
      'accountType=${_safe(accountType)} '
      'code=${exception.code} '
      'message=${exception.message ?? ''}',
    );
  }

  static String _safe(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? 'unknown' : trimmed;
  }
}
