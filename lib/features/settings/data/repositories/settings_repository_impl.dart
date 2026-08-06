import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../providers/firebase_providers.dart';
import '../models/language_settings_model.dart';
import '../models/motion_settings_model.dart';
import '../models/theme_settings_model.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final FirebaseFirestore _firestore;

  SettingsRepositoryImpl(this._firestore);

  @override
  Stream<ThemeSettingsModel?> watchThemeSettings() {
    return _firestore
        .collection(AppConstants.settingsCollection)
        .doc('theme')
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return ThemeSettingsModel.fromMap(doc.data()!);
        });
  }

  @override
  Future<void> updateThemeSettings(
    ThemeSettingsModel settings, {
    required String adminId,
  }) async {
    await _updateWithAudit(
      documentId: 'theme',
      data: settings.toMap(),
      adminId: adminId,
      action: 'theme_settings_updated',
      description: 'Global theme settings were updated.',
    );
  }

  @override
  Stream<MotionSettingsModel?> watchMotionSettings() {
    return _firestore
        .collection(AppConstants.settingsCollection)
        .doc('motion')
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return MotionSettingsModel.fromMap(doc.data()!);
        });
  }

  @override
  Future<void> updateMotionSettings(
    MotionSettingsModel settings, {
    required String adminId,
  }) async {
    await _updateWithAudit(
      documentId: 'motion',
      data: settings.toMap(),
      adminId: adminId,
      action: 'motion_settings_updated',
      description: 'Global motion settings were updated.',
    );
  }

  @override
  Stream<LanguageSettingsModel?> watchLanguageSettings() {
    return _firestore
        .collection(AppConstants.settingsCollection)
        .doc('language')
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return LanguageSettingsModel.fromMap(doc.data()!);
        });
  }

  @override
  Future<void> updateLanguageSettings(
    LanguageSettingsModel settings, {
    required String adminId,
  }) async {
    await _updateWithAudit(
      documentId: 'language',
      data: settings.toMap(),
      adminId: adminId,
      action: 'language_settings_updated',
      description: 'Global language settings were updated.',
    );
  }

  Future<void> _updateWithAudit({
    required String documentId,
    required Map<String, dynamic> data,
    required String adminId,
    required String action,
    required String description,
  }) async {
    final batch = _firestore.batch();
    final settingsReference = _firestore
        .collection(AppConstants.settingsCollection)
        .doc(documentId);
    batch.set(settingsReference, {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': adminId,
    }, SetOptions(merge: true));
    batch.set(_firestore.collection('logs').doc(), {
      'adminId': adminId,
      'action': action,
      'targetId': documentId,
      'targetType': 'settings',
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return SettingsRepositoryImpl(firestore);
});
