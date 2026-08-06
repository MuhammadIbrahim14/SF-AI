import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../models/user_role.dart';
import '../../../models/verified_skill_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../../courses/data/models/skill_score_model.dart';
import '../../courses/providers/skill_score_provider.dart';
import '../services/freelancer_eligibility_service.dart';

final freelancerEligibilityServiceProvider =
    Provider<FreelancerEligibilityService>((ref) {
      return const FreelancerEligibilityService();
    });

final verifiedStudentSkillsProvider = FutureProvider<List<VerifiedSkillModel>>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const <VerifiedSkillModel>[];
  final firestore = ref.watch(firestoreProvider);
  final existing = await firestore
      .collection('userVerifiedSkills')
      .doc(user.uid)
      .collection('skills')
      .get()
      .timeout(const Duration(seconds: 6));
  if (existing.docs.isNotEmpty) {
    final skills = existing.docs
        .map((doc) => VerifiedSkillModel.fromFirestore(doc))
        .toList();
    skills.sort((a, b) => b.score.compareTo(a.score));
    return skills;
  }

  final scores = await ref.watch(studentSkillScoresProvider.future);
  return scores.where(_hasVerifiedEvidence).map(_fromSkillScore).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
});

/// Single eligibility + readiness source used by Bridge UI and Activate.
final freelancerReadinessProvider = FutureProvider<FreelancerReadinessModel>((
  ref,
) async {
  final skills = await ref.watch(verifiedStudentSkillsProvider.future);
  final scores =
      await ref.watch(studentSkillScoresProvider.future).catchError((_) {
        return const <SkillScoreModel>[];
      });
  final profile = ref.watch(profileDataProvider).value;
  final profileCompletion =
      profile?.completion.profileCompletionPercentage.toDouble() ?? 0;
  return ref
      .watch(freelancerEligibilityServiceProvider)
      .evaluate(
        verifiedSkills: skills,
        skillScores: scores,
        profileCompletion: profileCompletion,
      );
});

final freelancerShowcaseActionProvider =
    AsyncNotifierProvider<FreelancerShowcaseActionNotifier, void>(
      FreelancerShowcaseActionNotifier.new,
    );

class FreelancerShowcaseActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> syncVerifiedSkills(List<VerifiedSkillModel> skills) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) {
        throw const FirestoreException(
          'Student sign-in required.',
          'unauthenticated',
        );
      }
      try {
        final batch = ref.read(firestoreProvider).batch();
        final root = ref
            .read(firestoreProvider)
            .collection('userVerifiedSkills')
            .doc(user.uid)
            .collection('skills');
        for (final skill in skills) {
          batch.set(
            root.doc(skill.skillId),
            skill.toJson(),
            SetOptions(merge: true),
          );
        }
        await batch.commit();
        ref.invalidate(verifiedStudentSkillsProvider);
        ref.invalidate(freelancerReadinessProvider);
      } on FirebaseException catch (e) {
        throw FirestoreException.fromCode(e.code);
      }
    });
    return !state.hasError;
  }

  Future<bool> activateShowcase({
    required String headline,
    required String bio,
    required String serviceCategory,
    required List<VerifiedSkillModel> publicSkills,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authUser = ref.read(authStateProvider).value;
      final appUser = await ref.read(currentUserProvider.future);
      if (authUser == null) {
        throw const FirestoreException(
          'Student sign-in required.',
          'unauthenticated',
        );
      }

      final alreadyUnlocked = appUser?.freelancerUnlocked == true;
      if (!alreadyUnlocked) {
        final eligibility = await ref.read(freelancerReadinessProvider.future);
        if (!eligibility.isEligible) {
          throw const FirestoreException(
            'You are not Ready yet. Complete the Freelancer Bridge checklist first.',
            'failed-precondition',
          );
        }
      }

      final now = Timestamp.fromDate(DateTime.now());
      final firestore = ref.read(firestoreProvider);
      final publicSkillNames = publicSkills
          .map((skill) => skill.skillName)
          .toList();
      final slugSource =
          appUser?.fullName ?? authUser.displayName ?? authUser.email ?? '';
      final slug = slugSource
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final profileSlug = slug.isEmpty ? authUser.uid : slug;
      final displayName =
          appUser?.fullName ?? authUser.displayName ?? 'SkillForge Student';
      final photoUrl = appUser?.photoUrl ?? authUser.photoURL ?? '';

      // Phase 0: split payloads to match Firestore hasOnly allow-lists.
      final publicProfileData = <String, dynamic>{
        'slug': profileSlug,
        'userId': authUser.uid,
        'ownerId': authUser.uid,
        'roleType': 'student',
        'displayName': displayName,
        'avatarUrl': photoUrl,
        'photoUrl': photoUrl,
        'headline': headline.trim(),
        'bio': bio.trim(),
        'skills': publicSkillNames,
        'serviceCategory': serviceCategory.trim(),
        'verifiedSkills': publicSkillNames,
        'verifiedSkillCount': publicSkills.length,
        'publicVisible': true,
        'isPublic': true,
        'source': 'student_freelancer_bridge',
        'updatedAt': now,
        'createdAt': now,
      };

      final showcaseData = <String, dynamic>{
        'ownerId': authUser.uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'headline': headline.trim(),
        'bio': bio.trim(),
        'serviceCategory': serviceCategory.trim(),
        'verifiedSkills': publicSkillNames,
        'verifiedSkillCount': publicSkills.length,
        'isPublic': true,
        'source': 'student_freelancer_bridge',
        'updatedAt': now,
        'createdAt': now,
        'requestedFreelancerActivation': true,
        'status': 'active',
      };

      try {
        await firestore
            .collection('publicProfiles')
            .doc(profileSlug)
            .set(publicProfileData, SetOptions(merge: true));
        await firestore
            .collection('freelancerShowcases')
            .doc(authUser.uid)
            .set(showcaseData, SetOptions(merge: true));

        // Phase 2: additive unlock — keep student, add freelancer capability.
        final existingRoles = List<String>.from(appUser?.roles ?? const []);
        if (!existingRoles
            .map((role) => role.trim().toLowerCase())
            .contains('student')) {
          existingRoles.add('student');
        }
        if (!existingRoles
            .map((role) => role.trim().toLowerCase())
            .contains('freelancer')) {
          existingRoles.add('freelancer');
        }

        // Default stays student until the user toggles mode.
        final primaryRole =
            (appUser?.primaryRole?.trim().isNotEmpty == true)
            ? appUser!.primaryRole!
            : UserRole.student.name;

        await ref
            .read(userRepositoryProvider)
            .updateUser(
              uid: authUser.uid,
              data: {
                'roles': existingRoles,
                'primaryRole': primaryRole,
                'freelancerUnlocked': true,
                'freelancerUnlockedAt': now,
                'updatedAt': FieldValue.serverTimestamp(),
              },
            );

        final freelancerRepo = ref.read(freelancerRepositoryProvider);
        final existingFreelancer = await freelancerRepo.getFreelancer(
          authUser.uid,
        );
        if (existingFreelancer == null) {
          await freelancerRepo.updateFreelancer(
            userId: authUser.uid,
            data: {
              'professionalTitle': headline.trim().isEmpty
                  ? 'SkillForge Freelancer'
                  : headline.trim(),
              'category': serviceCategory.trim(),
              'bio': bio.trim(),
              'skills': publicSkillNames,
              'services': publicSkillNames,
              'source': 'student_freelancer_bridge',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }

        ref.invalidate(currentUserProvider);
        ref.invalidate(freelancerReadinessProvider);
      } on FirebaseException catch (e) {
        throw FirestoreException.fromCode(e.code);
      }
    });
    return !state.hasError;
  }

  String? get errorMessage {
    final error = state.error;
    if (error is AppException) return error.message;
    if (error is FirebaseException) {
      return FirestoreException.fromCode(error.code).message;
    }
    return error?.toString();
  }
}

bool _hasVerifiedEvidence(SkillScoreModel score) {
  return score.sourceAssignmentIds.isNotEmpty ||
      score.sourceGrandTestIds.isNotEmpty ||
      score.sourceCertificateIds.isNotEmpty ||
      score.projectAverage > 0 ||
      score.mcqAverage > 0 ||
      score.grandTestAverage > 0;
}

VerifiedSkillModel _fromSkillScore(SkillScoreModel score) {
  final evidenceTypes = <String>[
    if (score.projectAverage > 0) 'project',
    if (score.mcqAverage > 0) 'assignment',
    if (score.grandTestAverage > 0) 'grand_test',
    if (score.sourceCertificateIds.isNotEmpty) 'certificate',
  ];
  return VerifiedSkillModel(
    skillId: score.skillScoreId,
    skillName: score.skillName,
    sourceCourseIds: score.sourceCourseIds,
    sourceProjectIds: score.sourceAssignmentIds,
    evidenceType: evidenceTypes.isEmpty
        ? 'verified_assessment'
        : evidenceTypes.join('+'),
    verificationLevel: score.score >= 85
        ? 'advanced_verified'
        : score.score >= 70
        ? 'verified'
        : 'developing',
    completedAt: score.updatedAt,
    score: score.score,
    publicVisible: false,
  );
}
