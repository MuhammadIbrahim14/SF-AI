import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/public_profile_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/user_provider.dart';

final portfolioSettingsProvider = StreamProvider<PortfolioSettings>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('appPublicConfig')
      .doc('portfolioSettings')
      .snapshots()
      .map((snapshot) => PortfolioSettings.fromMap(snapshot.data()));
});

String buildPortfolioUrl(String slug, {String? baseUrl}) {
  return _buildPortfolioUrl(slug, baseUrl: baseUrl);
}

String _buildPortfolioUrl(String slug, {String? baseUrl}) {
  final base =
      (baseUrl?.trim().isNotEmpty == true
              ? baseUrl!.trim()
              : PortfolioSettings.defaultPortfolioBaseUrl)
          .replaceAll(RegExp(r'/+$'), '');
  return '$base/p/${publicProfileSlug(slug)}';
}

final myPublicProfileProvider = StreamProvider<PublicProfileModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('publicProfiles')
      .where('userId', isEqualTo: user.uid)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return PublicProfileModel.fromFirestore(snapshot.docs.first);
      });
});

final publicProfileDraftProvider = FutureProvider<PublicProfileModel>((
  ref,
) async {
  final authUser = ref.watch(authStateProvider).value;
  final appUser = await ref.watch(currentUserProvider.future);
  final profile = ref.watch(profileDataProvider).value;
  if (authUser == null || appUser == null) {
    throw StateError('A signed-in user is required.');
  }
  final roleType = (appUser.primaryRole ?? 'student').toString();
  final details = profile?.details ?? const <String, dynamic>{};
  final skills = _list(details['skills']);
  final socialLinks = [
    ..._list(details['socialLinks']),
    ..._list(details['portfolioLinks']),
  ];
  final firestore = ref.watch(firestoreProvider);
  final now = DateTime.now();

  final verifiedSkills = await _verifiedSkillNames(firestore, authUser.uid);
  final services = roleType == 'freelancer'
      ? await _publishedServices(firestore, authUser.uid)
      : const <String>[];
  final courses = roleType == 'teacher'
      ? await _teacherCourses(firestore, authUser.uid)
      : const <String>[];
  final certificates = await _certificates(firestore, authUser.uid);

  final baseSlug = publicProfileSlug(
    appUser.fullName.isNotEmpty
        ? appUser.fullName
        : authUser.email ?? authUser.uid,
  );
  return PublicProfileModel(
    slug: baseSlug,
    userId: authUser.uid,
    roleType: roleType,
    displayName: appUser.fullName.isNotEmpty
        ? appUser.fullName
        : authUser.displayName ?? 'SkillForge Member',
    headline: _string(details['professionalTitle'], '$roleType portfolio'),
    bio: _string(details['bio'], _string(details['about'])),
    avatarUrl: appUser.photoUrl ?? '',
    location: _string(details['location']),
    skills: skills,
    verifiedSkills: verifiedSkills,
    projects: _list(details['projects']),
    services: services,
    coursesCreated: courses,
    certificates: certificates,
    reviews: const <String>[],
    socialLinks: socialLinks,
    contactMode: 'platform',
    hireButtonEnabled: roleType == 'freelancer' || roleType == 'student',
    publicVisible: false,
    updatedAt: now,
  );
});

final publicProfileActionProvider =
    AsyncNotifierProvider<PublicProfileActionNotifier, void>(
      PublicProfileActionNotifier.new,
    );

class PublicProfileActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> saveProfile(PublicProfileModel profile) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null || user.uid != profile.userId) {
        throw StateError('You can only publish your own portfolio.');
      }
      final slug = publicProfileSlug(profile.slug);
      await ref
          .read(firestoreProvider)
          .collection('publicProfiles')
          .doc(slug)
          .set(
            PublicProfileModel(
              slug: slug,
              userId: profile.userId,
              roleType: profile.roleType,
              displayName: profile.displayName,
              headline: profile.headline,
              bio: profile.bio,
              avatarUrl: profile.avatarUrl,
              location: profile.location,
              skills: profile.skills,
              verifiedSkills: profile.verifiedSkills,
              projects: profile.projects,
              services: profile.services,
              coursesCreated: profile.coursesCreated,
              certificates: profile.certificates,
              reviews: profile.reviews,
              socialLinks: profile.socialLinks,
              contactMode: profile.contactMode,
              hireButtonEnabled: profile.hireButtonEnabled,
              publicVisible: profile.publicVisible,
              updatedAt: DateTime.now(),
            ).toJson(),
            SetOptions(merge: true),
          );
      ref.invalidate(myPublicProfileProvider);
    });
    return !state.hasError;
  }
}

class PortfolioSettings {
  const PortfolioSettings({
    required this.portfolioBaseUrl,
    required this.isPortfolioEnabled,
  });

  static const String defaultPortfolioBaseUrl =
      'https://lively-griffin-4878ac.netlify.app/';

  final String portfolioBaseUrl;
  final bool isPortfolioEnabled;

  String get effectiveBaseUrl {
    final configured = portfolioBaseUrl.trim();
    final base = configured.isEmpty ? defaultPortfolioBaseUrl : configured;
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  bool get hasLiveBaseUrl {
    final uri = Uri.tryParse(effectiveBaseUrl);
    return isPortfolioEnabled &&
        uri != null &&
        uri.scheme.startsWith('http') &&
        uri.host.isNotEmpty;
  }

  String buildPortfolioUrl(String slug) => publicLinkFor(slug);

  String publicLinkFor(String slug) {
    return _buildPortfolioUrl(slug, baseUrl: effectiveBaseUrl);
  }

  factory PortfolioSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const PortfolioSettings(
        portfolioBaseUrl: defaultPortfolioBaseUrl,
        isPortfolioEnabled: true,
      );
    }
    final map = data;
    final configuredBaseUrl = (map['portfolioBaseUrl'] ?? '').toString().trim();
    return PortfolioSettings(
      portfolioBaseUrl: configuredBaseUrl.isEmpty
          ? defaultPortfolioBaseUrl
          : configuredBaseUrl,
      isPortfolioEnabled: map.containsKey('isPortfolioEnabled')
          ? map['isPortfolioEnabled'] != false
          : true,
    );
  }
}

Future<List<String>> _verifiedSkillNames(
  FirebaseFirestore firestore,
  String userId,
) async {
  try {
    final snapshot = await firestore
        .collection('userVerifiedSkills')
        .doc(userId)
        .collection('skills')
        .where('publicVisible', isEqualTo: true)
        .limit(20)
        .get()
        .timeout(const Duration(seconds: 5));
    return snapshot.docs
        .map((doc) => _string(doc.data()['skillName'], doc.id))
        .toList();
  } catch (_) {
    return const <String>[];
  }
}

Future<List<String>> _publishedServices(
  FirebaseFirestore firestore,
  String userId,
) async {
  try {
    final snapshot = await firestore
        .collection('freelancerServices')
        .where('freelancerId', isEqualTo: userId)
        .where('isPublished', isEqualTo: true)
        .limit(12)
        .get()
        .timeout(const Duration(seconds: 5));
    return snapshot.docs
        .map((doc) => _string(doc.data()['title']))
        .where((item) => item.isNotEmpty)
        .toList();
  } catch (_) {
    return const <String>[];
  }
}

Future<List<String>> _teacherCourses(
  FirebaseFirestore firestore,
  String userId,
) async {
  try {
    final snapshot = await firestore
        .collection('courses')
        .where('teacherId', isEqualTo: userId)
        .where('status', isEqualTo: 'published')
        .limit(12)
        .get()
        .timeout(const Duration(seconds: 5));
    return snapshot.docs
        .map((doc) => _string(doc.data()['title']))
        .where((item) => item.isNotEmpty)
        .toList();
  } catch (_) {
    return const <String>[];
  }
}

Future<List<String>> _certificates(
  FirebaseFirestore firestore,
  String userId,
) async {
  try {
    final snapshot = await firestore
        .collection('certificates')
        .where('studentId', isEqualTo: userId)
        .limit(12)
        .get()
        .timeout(const Duration(seconds: 5));
    return snapshot.docs
        .map((doc) => _string(doc.data()['courseTitle']))
        .where((item) => item.isNotEmpty)
        .toList();
  } catch (_) {
    return const <String>[];
  }
}

List<String> _list(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

String _string(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
