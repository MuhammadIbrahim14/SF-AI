class StudentAiSafetyService {
  const StudentAiSafetyService();

  String safeInstructionForMode(String mode) {
    final normalized = mode.toLowerCase();
    if (normalized.contains('assignment')) {
      return 'Give hints, concepts, checklist, and step-by-step guidance. Do not write a final submission for the student.';
    }
    if (normalized.contains('activeassessment') ||
        normalized.contains('activequiz') ||
        normalized.contains('activetest')) {
      return 'This may be an active graded assessment. Do not reveal answer keys or direct answers. Give conceptual help only.';
    }
    if (normalized.contains('review')) {
      return 'The student is reviewing submitted work. Explain mistakes and correct concepts without changing scores.';
    }
    return 'Help the student learn. Encourage them to try first and explain reasoning clearly.';
  }

  bool shouldHideAnswerKey(String mode) {
    final normalized = mode.toLowerCase();
    return normalized.contains('activeassessment') ||
        normalized.contains('activequiz') ||
        normalized.contains('activetest');
  }
}
