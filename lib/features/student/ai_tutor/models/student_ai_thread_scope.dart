enum StudentAiThreadScope {
  course,
  lesson,
  assignment,
  quiz,
  project,
  general;

  static StudentAiThreadScope fromValue(Object? value) {
    final raw = value?.toString().trim();
    return StudentAiThreadScope.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => StudentAiThreadScope.general,
    );
  }
}
