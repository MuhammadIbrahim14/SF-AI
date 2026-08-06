import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/features/courses/data/models/enrollment_model.dart';
import 'package:skillforge_ai/features/courses/data/services/course_progress_service.dart';

CourseProgressSnapshot snapshot({
  required int lessons,
  required int completedLessons,
  int quizzes = 0,
  int completedQuizzes = 0,
  int projects = 0,
  int completedProjects = 0,
  int grandTests = 0,
  int passedGrandTests = 0,
}) {
  return CourseProgressSnapshot(
    lessons: CourseRequirementCount(
      total: lessons,
      completed: completedLessons,
    ),
    quizzes: CourseRequirementCount(
      total: quizzes,
      completed: completedQuizzes,
    ),
    projects: CourseRequirementCount(
      total: projects,
      completed: completedProjects,
    ),
    grandTest: CourseRequirementCount(
      total: grandTests,
      completed: passedGrandTests,
    ),
  );
}

void main() {
  test('finishing every lesson is not full course completion', () {
    final result = snapshot(
      lessons: 4,
      completedLessons: 4,
      quizzes: 2,
      grandTests: 1,
    );

    expect(result.lessonProgressPercent, 100);
    expect(result.totalRequirements, 7);
    expect(result.completedRequirements, 4);
    expect(result.progressPercent, closeTo(57.14, 0.01));
    expect(result.isCourseComplete, isFalse);
  });

  test('completing every required module reaches 100%', () {
    final result = snapshot(
      lessons: 4,
      completedLessons: 4,
      quizzes: 2,
      completedQuizzes: 2,
      projects: 1,
      completedProjects: 1,
      grandTests: 1,
      passedGrandTests: 1,
    );

    expect(result.progressPercent, 100);
    expect(result.isCourseComplete, isTrue);
  });

  test('modules the course does not use never block 100%', () {
    final result = snapshot(lessons: 3, completedLessons: 3);

    expect(result.progressPercent, 100);
    expect(result.isCourseComplete, isTrue);
  });

  test('publishing new content pulls progress back below 100%', () {
    final before = snapshot(lessons: 3, completedLessons: 3);
    final afterNewLesson = snapshot(lessons: 4, completedLessons: 3);

    expect(before.progressPercent, 100);
    expect(afterNewLesson.progressPercent, 75);
    expect(afterNewLesson.isCourseComplete, isFalse);
  });

  test('enrollment update carries lesson and overall progress separately', () {
    final update = snapshot(
      lessons: 2,
      completedLessons: 2,
      quizzes: 2,
      completedQuizzes: 1,
    ).toEnrollmentUpdate(status: EnrollmentStatus.active);

    expect(update['lessonProgressPercent'], 100);
    expect(update['progressPercent'], 75);
    expect(update['completedRequirements'], 3);
    expect(update['totalRequirements'], 4);
    expect(update['status'], EnrollmentStatus.active);
  });

  test('a course with no published content stays at 0%', () {
    final result = snapshot(lessons: 0, completedLessons: 0);

    expect(result.progressPercent, 0);
    expect(result.lessonProgressPercent, 0);
    expect(result.isCourseComplete, isFalse);
  });
}
