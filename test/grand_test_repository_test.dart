import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/features/courses/data/repositories/grand_test_repository.dart';

void main() {
  group('grand test eligibility fallback', () {
    test('builds a safe fallback result when readiness cannot be calculated', () {
      final eligibility = buildGrandTestEligibilityFallback(
        courseId: 'course-1',
        grandTestId: 'test-1',
        studentId: 'student-1',
        reason: 'Unable to calculate readiness right now.',
      );

      expect(eligibility.courseId, 'course-1');
      expect(eligibility.grandTestId, 'test-1');
      expect(eligibility.studentId, 'student-1');
      expect(eligibility.isEligible, isFalse);
      expect(eligibility.readinessPercent, 0.0);
      expect(
        eligibility.reasons,
        contains('Unable to calculate readiness right now.'),
      );
      expect(
        eligibility.recommendations,
        contains(
          'Try again in a moment or contact your teacher if the issue continues.',
        ),
      );
    });
  });
}
