import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/career_roadmap_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../courses/data/models/skill_score_model.dart';
import '../../courses/providers/skill_score_provider.dart';

const careerTargetSkills = <String, List<String>>{
  'Flutter Developer': [
    'Flutter',
    'Dart',
    'Firebase',
    'State Management',
    'UI/UX',
  ],
  'AI Agent Builder': [
    'AI',
    'Prompt Engineering',
    'API Integration',
    'Automation',
    'Firebase',
  ],
  'Frontend Developer': ['HTML', 'CSS', 'JavaScript', 'React', 'UI/UX'],
  'Firebase Developer': [
    'Firebase',
    'Firestore',
    'Authentication',
    'Security Rules',
    'Cloud Storage',
  ],
  'UI/UX Designer': [
    'UI/UX',
    'Wireframing',
    'Design Systems',
    'Prototyping',
    'Accessibility',
  ],
};

final studentCareerRoadmapProvider = FutureProvider<CareerRoadmapModel?>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final snapshot = await ref
      .watch(firestoreProvider)
      .collection('careerRoadmaps')
      .doc(user.uid)
      .collection('roadmaps')
      .orderBy('updatedAt', descending: true)
      .limit(1)
      .get()
      .timeout(const Duration(seconds: 6));
  if (snapshot.docs.isEmpty) return null;
  return CareerRoadmapModel.fromFirestore(user.uid, snapshot.docs.first);
});

final studentSkillGapProvider = FutureProvider<SkillGapAnalysisModel>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return const SkillGapAnalysisModel(
      targetRole: 'Flutter Developer',
      requiredSkills: <String>[],
      masteredSkills: <String>[],
      weakSkills: <String>[],
      missingSkills: <String>[],
      recommendedCourses: <String>[],
      recommendedProjects: <String>[],
      progressPercent: 0,
    );
  }
  final roadmap = await ref.watch(studentCareerRoadmapProvider.future);
  final targetRole = roadmap?.targetRole ?? 'Flutter Developer';
  final scores = await ref.watch(studentSkillScoresProvider.future);
  final firestore = ref.watch(firestoreProvider);
  return _buildSkillGap(
    studentId: user.uid,
    targetRole: targetRole,
    scores: scores,
    firestore: firestore,
  );
});

final careerRoadmapActionProvider =
    AsyncNotifierProvider<CareerRoadmapActionNotifier, void>(
      CareerRoadmapActionNotifier.new,
    );

class CareerRoadmapActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> saveTargetRole(String targetRole) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw StateError('Student sign-in required.');
      final firestore = ref.read(firestoreProvider);
      final scores = await ref.read(studentSkillScoresProvider.future);
      final analysis = await _buildSkillGap(
        studentId: user.uid,
        targetRole: targetRole,
        scores: scores,
        firestore: firestore,
      );
      final now = DateTime.now();
      final doc = firestore
          .collection('careerRoadmaps')
          .doc(user.uid)
          .collection('roadmaps')
          .doc(targetRole.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'));
      final existing = await doc.get();
      final model = CareerRoadmapModel(
        roadmapId: doc.id,
        studentId: user.uid,
        targetRole: targetRole,
        requiredSkills: analysis.requiredSkills,
        currentSkills: analysis.masteredSkills,
        missingSkills: analysis.missingSkills,
        recommendedCourses: analysis.recommendedCourses,
        recommendedProjects: analysis.recommendedProjects,
        progressPercent: analysis.progressPercent,
        createdAt: existing.exists
            ? CareerRoadmapModel.fromFirestore(user.uid, existing).createdAt
            : now,
        updatedAt: now,
      );
      await doc.set(model.toJson(), SetOptions(merge: true));
      ref.invalidate(studentCareerRoadmapProvider);
      ref.invalidate(studentSkillGapProvider);
    });
    return !state.hasError;
  }
}

Future<SkillGapAnalysisModel> _buildSkillGap({
  required String studentId,
  required String targetRole,
  required List<SkillScoreModel> scores,
  required FirebaseFirestore firestore,
}) async {
  final requiredSkills =
      careerTargetSkills[targetRole] ?? careerTargetSkills.values.first;
  final mastered = scores
      .where(_hasVerifiedEvidence)
      .where((score) => score.score >= 70)
      .map((score) => score.skillName)
      .toSet();
  final weak = scores
      .where(_hasVerifiedEvidence)
      .where((score) => score.score > 0 && score.score < 70)
      .map((score) => score.skillName)
      .toSet();
  final missing = requiredSkills
      .where((skill) => !mastered.any((item) => _sameSkill(item, skill)))
      .toList();
  final progress = requiredSkills.isEmpty
      ? 0.0
      : ((requiredSkills.length - missing.length) / requiredSkills.length * 100)
            .clamp(0, 100)
            .toDouble();

  final recommendedCourses = await _recommendedCourses(firestore, missing);
  final recommendedProjects = missing
      .take(3)
      .map((skill) => '$skill portfolio project')
      .toList();

  return SkillGapAnalysisModel(
    targetRole: targetRole,
    requiredSkills: requiredSkills,
    masteredSkills: mastered.toList()..sort(),
    weakSkills: weak.toList()..sort(),
    missingSkills: missing,
    recommendedCourses: recommendedCourses,
    recommendedProjects: recommendedProjects,
    progressPercent: progress,
  );
}

bool _hasVerifiedEvidence(SkillScoreModel score) {
  return score.sourceAssignmentIds.isNotEmpty ||
      score.sourceGrandTestIds.isNotEmpty ||
      score.sourceCertificateIds.isNotEmpty ||
      score.projectAverage > 0 ||
      score.mcqAverage > 0 ||
      score.grandTestAverage > 0;
}

bool _sameSkill(String a, String b) {
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

Future<List<String>> _recommendedCourses(
  FirebaseFirestore firestore,
  List<String> missingSkills,
) async {
  if (missingSkills.isEmpty) return const <String>[];
  try {
    final snapshot = await firestore
        .collection('courses')
        .where('status', isEqualTo: 'published')
        .limit(30)
        .get()
        .timeout(const Duration(seconds: 6));
    final matches = <String>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = data['title']?.toString().trim() ?? '';
      final skills = data['skillsCovered'];
      final courseSkills = skills is Iterable
          ? skills.map((item) => item.toString().toLowerCase()).toList()
          : <String>[];
      final matched = missingSkills.any(
        (skill) => courseSkills.contains(skill.toLowerCase()),
      );
      if (matched && title.isNotEmpty) matches.add(title);
    }
    return matches.take(4).toList();
  } catch (_) {
    return const <String>[];
  }
}
