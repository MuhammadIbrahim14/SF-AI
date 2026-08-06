/// AI Interview Lab enums & constants.
/// Separate from hiring [InterviewModel] / Firestore `interviews`.
library;

class InterviewLabDifficulty {
  const InterviewLabDifficulty._();

  static const easy = 'easy';
  static const medium = 'medium';
  static const hard = 'hard';

  static const all = <String>[easy, medium, hard];

  static bool isValid(String value) => all.contains(value);

  static String bumpUp(String value) {
    if (value == easy) return medium;
    if (value == medium) return hard;
    return hard;
  }

  static String bumpDown(String value) {
    if (value == hard) return medium;
    if (value == medium) return easy;
    return easy;
  }
}

class InterviewLabSessionStatus {
  const InterviewLabSessionStatus._();

  static const draft = 'draft';
  static const ready = 'ready';
  static const inProgress = 'in_progress';
  static const paused = 'paused';
  static const completed = 'completed';
  static const abandoned = 'abandoned';
  static const failed = 'failed';

  static const all = <String>[
    draft,
    ready,
    inProgress,
    paused,
    completed,
    abandoned,
    failed,
  ];

  static bool isValid(String value) => all.contains(value);
  static bool isTerminal(String value) =>
      value == completed || value == abandoned || value == failed;
}

class InterviewLabRoleTrack {
  const InterviewLabRoleTrack._();

  static const flutter = 'flutter';
  static const backend = 'backend';
  static const frontend = 'frontend';
  static const uiUx = 'ui_ux';
  static const ai = 'ai';
  static const cyberSecurity = 'cyber_security';
  static const dataScience = 'data_science';
  static const mobile = 'mobile';
  static const devops = 'devops';
  static const qa = 'qa';
  static const general = 'general';

  static const all = <String>[
    flutter,
    backend,
    frontend,
    uiUx,
    ai,
    cyberSecurity,
    dataScience,
    mobile,
    devops,
    qa,
    general,
  ];

  static bool isValid(String value) => all.contains(value);

  /// Accepts built-in tracks and admin-defined slugs (e.g. `mern`).
  static bool isUsable(String value) => slugify(value).isNotEmpty;

  static String slugify(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug;
  }

  static String displayLabel(String value) {
    final key = slugify(value);
    return switch (key) {
      flutter => 'Flutter Developer',
      backend => 'Backend Developer',
      frontend => 'Frontend Developer',
      uiUx => 'UI / UX Designer',
      ai => 'AI Engineer',
      cyberSecurity => 'Cyber Security',
      dataScience => 'Data Analyst',
      mobile => 'Mobile Developer',
      devops => 'DevOps Engineer',
      qa => 'QA Engineer',
      general => 'Generalist',
      _ => _humanize(key.isEmpty ? value : key),
    };
  }

  static String _humanize(String value) {
    final parts = value
        .split(RegExp(r'[_\s-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .toList();
    return parts.isEmpty ? 'Generalist' : parts.join(' ');
  }
}

class InterviewLabInterviewLevel {
  const InterviewLabInterviewLevel._();

  static const beginner = 'Beginner';
  static const junior = 'Junior';
  static const intermediate = 'Intermediate';
  static const advanced = 'Advanced';
  static const seniorReady = 'Senior Ready';

  static String fromScore(double overall) {
    if (overall >= 90) return seniorReady;
    if (overall >= 78) return advanced;
    if (overall >= 62) return intermediate;
    if (overall >= 45) return junior;
    return beginner;
  }
}

class InterviewLabQuestionCategory {
  const InterviewLabQuestionCategory._();

  static const concept = 'concept';
  static const scenario = 'scenario';
  static const debugging = 'debugging';
  static const architecture = 'architecture';
  static const bestPractices = 'best_practices';
  static const optimization = 'optimization';
  static const behavioral = 'behavioral';
  static const communication = 'communication';
  static const realWorld = 'real_world';
  static const technical = 'technical';
  static const problemSolving = 'problem_solving';
  static const shortAnswer = 'short_answer';

  static const all = <String>[
    concept,
    scenario,
    debugging,
    architecture,
    bestPractices,
    optimization,
    behavioral,
    communication,
    realWorld,
    technical,
    problemSolving,
    shortAnswer,
  ];
}

class InterviewLabEvaluationStrictness {
  const InterviewLabEvaluationStrictness._();

  static const lenient = 'lenient';
  static const balanced = 'balanced';
  static const strict = 'strict';

  static const all = <String>[lenient, balanced, strict];

  static bool isValid(String value) => all.contains(value);
}

class InterviewLabAiTaskType {
  const InterviewLabAiTaskType._();

  static const questionBank = 'interviewLabQuestionBank';
  static const answerCritique = 'interviewLabAnswerCritique';
  static const followUp = 'interviewLabFollowUp';
  static const debrief = 'interviewLabDebrief';

  static const all = <String>[
    questionBank,
    answerCritique,
    followUp,
    debrief,
  ];
}

class InterviewLabCollections {
  const InterviewLabCollections._();

  static const templates = 'interview_templates';
  static const sessions = 'interview_sessions';
  static const questions = 'interview_questions';
  static const reports = 'interview_reports';
  static const results = 'interview_results';
  static const history = 'interview_history';
  static const badges = 'interview_badges';
  static const progress = 'interview_progress';

  /// Admin config doc under existing `settings` collection.
  static const configDocPath = 'settings/interviewLab';
}

class InterviewLabBadgeIds {
  const InterviewLabBadgeIds._();

  static const flutterExpert = 'flutter_expert';
  static const problemSolver = 'problem_solver';
  static const communicationStar = 'communication_star';
  static const backendReady = 'backend_ready';
  static const frontendReady = 'frontend_ready';
  static const jobReady = 'job_ready';
  static const architectureThinker = 'architecture_thinker';
  static const adaptiveResilient = 'adaptive_resilient';
}
