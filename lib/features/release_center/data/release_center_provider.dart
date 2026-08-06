import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final releaseCenterProvider = StreamProvider<ReleaseCenterConfig?>((ref) {
  return FirebaseFirestore.instance
      .collection('appPublicConfig')
      .doc('releaseCenter')
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return null;
        return ReleaseCenterConfig.fromMap(data);
      });
});

final releaseCenterRepositoryProvider = Provider<ReleaseCenterRepository>((
  ref,
) {
  return ReleaseCenterRepository(FirebaseFirestore.instance);
});

class ReleaseCenterRepository {
  const ReleaseCenterRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('appPublicConfig').doc('releaseCenter');

  Future<void> save(ReleaseCenterConfig config) {
    return _doc.set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> savePortfolioSettings({
    required String portfolioBaseUrl,
    required bool isPortfolioEnabled,
  }) {
    return _firestore
        .collection('appPublicConfig')
        .doc('portfolioSettings')
        .set({
          'portfolioBaseUrl': portfolioBaseUrl.trim().replaceAll(
            RegExp(r'/+$'),
            '',
          ),
          'isPortfolioEnabled': isPortfolioEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}

class ReleaseCenterConfig {
  const ReleaseCenterConfig({
    this.androidApkUrl = '',
    this.androidVersion = '',
    this.androidBuildNumber = '',
    this.androidFileSize = '',
    this.androidReleaseNotes = '',
    this.windowsExeUrl = '',
    this.windowsZipUrl = '',
    this.windowsVersion = '',
    this.windowsBuildNumber = '',
    this.windowsFileSize = '',
    this.windowsReleaseNotes = '',
    this.latestVersion = '',
    this.githubReleaseUrl = '',
    this.isAndroidEnabled = false,
    this.isWindowsEnabled = false,
    this.updatedAt,
  });

  final String androidApkUrl;
  final String androidVersion;
  final String androidBuildNumber;
  final String androidFileSize;
  final String androidReleaseNotes;
  final String windowsExeUrl;
  final String windowsZipUrl;
  final String windowsVersion;
  final String windowsBuildNumber;
  final String windowsFileSize;
  final String windowsReleaseNotes;
  final String latestVersion;
  final String githubReleaseUrl;
  final bool isAndroidEnabled;
  final bool isWindowsEnabled;
  final DateTime? updatedAt;

  factory ReleaseCenterConfig.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    String readString(String key) => (data[key] ?? '').toString();

    return ReleaseCenterConfig(
      androidApkUrl: readString('androidApkUrl'),
      androidVersion: readString('androidVersion'),
      androidBuildNumber: readString('androidBuildNumber'),
      androidFileSize: readString('androidFileSize'),
      androidReleaseNotes: readString('androidReleaseNotes'),
      windowsExeUrl: readString('windowsExeUrl'),
      windowsZipUrl: readString('windowsZipUrl'),
      windowsVersion: readString('windowsVersion'),
      windowsBuildNumber: readString('windowsBuildNumber'),
      windowsFileSize: readString('windowsFileSize'),
      windowsReleaseNotes: readString('windowsReleaseNotes'),
      latestVersion: readString('latestVersion'),
      githubReleaseUrl: readString('githubReleaseUrl'),
      isAndroidEnabled: data['isAndroidEnabled'] == true,
      isWindowsEnabled: data['isWindowsEnabled'] == true,
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'androidApkUrl': androidApkUrl.trim(),
      'androidVersion': androidVersion.trim(),
      'androidBuildNumber': androidBuildNumber.trim(),
      'androidFileSize': androidFileSize.trim(),
      'androidReleaseNotes': androidReleaseNotes.trim(),
      'windowsExeUrl': windowsExeUrl.trim(),
      'windowsZipUrl': windowsZipUrl.trim(),
      'windowsVersion': windowsVersion.trim(),
      'windowsBuildNumber': windowsBuildNumber.trim(),
      'windowsFileSize': windowsFileSize.trim(),
      'windowsReleaseNotes': windowsReleaseNotes.trim(),
      'latestVersion': latestVersion.trim(),
      'githubReleaseUrl': githubReleaseUrl.trim(),
      'isAndroidEnabled': isAndroidEnabled,
      'isWindowsEnabled': isWindowsEnabled,
    };
  }

  ReleaseCenterConfig copyWith({
    String? androidApkUrl,
    String? androidVersion,
    String? androidBuildNumber,
    String? androidFileSize,
    String? androidReleaseNotes,
    String? windowsExeUrl,
    String? windowsZipUrl,
    String? windowsVersion,
    String? windowsBuildNumber,
    String? windowsFileSize,
    String? windowsReleaseNotes,
    String? latestVersion,
    String? githubReleaseUrl,
    bool? isAndroidEnabled,
    bool? isWindowsEnabled,
    DateTime? updatedAt,
  }) {
    return ReleaseCenterConfig(
      androidApkUrl: androidApkUrl ?? this.androidApkUrl,
      androidVersion: androidVersion ?? this.androidVersion,
      androidBuildNumber: androidBuildNumber ?? this.androidBuildNumber,
      androidFileSize: androidFileSize ?? this.androidFileSize,
      androidReleaseNotes: androidReleaseNotes ?? this.androidReleaseNotes,
      windowsExeUrl: windowsExeUrl ?? this.windowsExeUrl,
      windowsZipUrl: windowsZipUrl ?? this.windowsZipUrl,
      windowsVersion: windowsVersion ?? this.windowsVersion,
      windowsBuildNumber: windowsBuildNumber ?? this.windowsBuildNumber,
      windowsFileSize: windowsFileSize ?? this.windowsFileSize,
      windowsReleaseNotes: windowsReleaseNotes ?? this.windowsReleaseNotes,
      latestVersion: latestVersion ?? this.latestVersion,
      githubReleaseUrl: githubReleaseUrl ?? this.githubReleaseUrl,
      isAndroidEnabled: isAndroidEnabled ?? this.isAndroidEnabled,
      isWindowsEnabled: isWindowsEnabled ?? this.isWindowsEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
