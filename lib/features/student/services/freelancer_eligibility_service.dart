import '../../../models/verified_skill_model.dart';
import '../../courses/data/models/skill_score_model.dart';

/// Single source of truth for Freelancer Bridge readiness gates.
class FreelancerEligibilityService {
  const FreelancerEligibilityService();

  static const int minVerifiedSkills = 3;
  static const double minSkillScore = 70;
  static const double minProfileCompletion = 70;
  static const double minReadinessScore = 85;

  FreelancerReadinessModel evaluate({
    required List<VerifiedSkillModel> verifiedSkills,
    required List<SkillScoreModel> skillScores,
    required double profileCompletion,
  }) {
    final qualifyingSkills = verifiedSkills
        .where((skill) => skill.score >= minSkillScore)
        .toList();
    final hasVerifiedSkills = qualifyingSkills.length >= minVerifiedSkills;

    final hasGradedProject =
        verifiedSkills.any(_isGradedProjectEvidence) ||
        skillScores.any(
          (score) =>
              score.projectAverage > 0 || score.sourceAssignmentIds.isNotEmpty,
        );

    final hasCertOrGrandTest =
        verifiedSkills.any(_isCertOrGrandTestEvidence) ||
        skillScores.any(
          (score) =>
              score.sourceCertificateIds.isNotEmpty ||
              score.sourceGrandTestIds.isNotEmpty ||
              score.grandTestAverage > 0 ||
              score.certificateBonusApplied,
        );

    final profileReady = profileCompletion >= minProfileCompletion;
    final readinessScore = _readinessScore(
      qualifyingSkillCount: qualifyingSkills.length,
      hasGradedProject: hasGradedProject,
      hasCertOrGrandTest: hasCertOrGrandTest,
      profileCompletion: profileCompletion,
    );

    final checks = <FreelancerEligibilityCheckItem>[
      FreelancerEligibilityCheckItem(
        id: 'verified_skills',
        label:
            'At least $minVerifiedSkills verified skills (≥${minSkillScore.round()}%)',
        passed: hasVerifiedSkills,
        detail:
            '${qualifyingSkills.length}/$minVerifiedSkills skills at ${minSkillScore.round()}%+',
      ),
      FreelancerEligibilityCheckItem(
        id: 'graded_project',
        label: 'At least 1 graded project',
        passed: hasGradedProject,
        detail: hasGradedProject
            ? 'Project evidence found'
            : 'Complete a graded project for proof of work',
      ),
      FreelancerEligibilityCheckItem(
        id: 'cert_or_grand_test',
        label: 'Certificate or grand test',
        passed: hasCertOrGrandTest,
        detail: hasCertOrGrandTest
            ? 'Credential evidence found'
            : 'Earn a certificate or pass a grand test',
      ),
      FreelancerEligibilityCheckItem(
        id: 'profile',
        label: 'Profile ≥${minProfileCompletion.round()}%',
        passed: profileReady,
        detail: 'Profile ${profileCompletion.round()}%',
      ),
      FreelancerEligibilityCheckItem(
        id: 'readiness',
        label: 'Readiness ≥${minReadinessScore.round()}% (Ready threshold)',
        passed: readinessScore >= minReadinessScore,
        detail: 'Readiness ${readinessScore.round()}%',
      ),
    ];

    final isEligible = checks.every((check) => check.passed);
    final recommendations = checks
        .where((check) => !check.passed)
        .map((check) => check.detail)
        .toList();

    return FreelancerReadinessModel(
      score: readinessScore,
      verifiedSkillCount: qualifyingSkills.length,
      completedProjectCount: hasGradedProject ? 1 : 0,
      profileCompletion: profileCompletion,
      portfolioReady: hasVerifiedSkills && hasGradedProject,
      serviceReady: isEligible,
      recommendations: recommendations.isEmpty
          ? const ['You meet the Ready threshold. Activate your showcase.']
          : recommendations,
      isEligible: isEligible,
      checks: checks,
    );
  }

  double _readinessScore({
    required int qualifyingSkillCount,
    required bool hasGradedProject,
    required bool hasCertOrGrandTest,
    required double profileCompletion,
  }) {
    final skillsScore = (qualifyingSkillCount * (40 / minVerifiedSkills))
        .clamp(0, 40)
        .toDouble();
    final projectScore = hasGradedProject ? 20.0 : 0.0;
    final credentialScore = hasCertOrGrandTest ? 20.0 : 0.0;
    final profileScore = (profileCompletion.clamp(0, 100) * 0.2)
        .clamp(0, 20)
        .toDouble();
    return (skillsScore + projectScore + credentialScore + profileScore)
        .clamp(0, 100)
        .toDouble();
  }

  bool _isGradedProjectEvidence(VerifiedSkillModel skill) {
    final type = skill.evidenceType.toLowerCase();
    return type.contains('project') || skill.sourceProjectIds.isNotEmpty;
  }

  bool _isCertOrGrandTestEvidence(VerifiedSkillModel skill) {
    final type = skill.evidenceType.toLowerCase();
    return type.contains('certificate') ||
        type.contains('grand_test') ||
        type.contains('grand-test');
  }
}
