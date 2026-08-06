import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/core/utils/profile_completion.dart';

void main() {
  group('ProfileCompletion', () {
    test('reports every missing common and student field', () {
      final result = ProfileCompletion.evaluate(
        userData: const {},
        role: 'student',
        roleData: const {},
      );

      expect(result.profileCompletionPercentage, 0);
      expect(result.completedFields, isEmpty);
      expect(result.missingFields, hasLength(result.totalFields));
      expect(result.missingFields, contains('Profile image'));
      expect(result.missingFields, contains('Education level'));
    });

    test('reaches 100 only when all required fields are complete', () {
      final result = ProfileCompletion.evaluate(
        userData: {
          'profileImage': 'https://example.com/avatar.jpg',
          'fullName': 'Student User',
          'email': 'student@example.com',
          'phone': '123456789',
          'gender': 'Prefer not to say',
          'dateOfBirth': DateTime(2000),
          'country': 'Pakistan',
          'city': 'Karachi',
          'bio': 'Learning Flutter.',
        },
        role: 'student',
        roleData: const {
          'educationLevel': 'Undergraduate',
          'institute': 'SkillForge University',
          'degree': 'BS',
          'fieldOfStudy': 'Computer Science',
          'graduationYear': 2027,
          'skills': ['Flutter'],
          'interestedSkills': ['AI'],
          'careerGoal': 'Become a mobile engineer',
        },
      );

      expect(result.profileCompletionPercentage, 100);
      expect(result.missingFields, isEmpty);
      expect(result.completedFields, hasLength(result.totalFields));
    });

    test('does not treat zero or empty collections as complete', () {
      final result = ProfileCompletion.evaluate(
        userData: const {
          'fullName': 'Freelancer User',
          'email': 'freelancer@example.com',
        },
        role: 'freelancer',
        roleData: const {
          'experienceYears': 0,
          'services': <String>[],
          'hourlyRate': 0,
        },
      );

      expect(result.missingFields, contains('Experience'));
      expect(result.missingFields, contains('Services'));
      expect(result.missingFields, contains('Hourly rate'));
      expect(result.profileCompletionPercentage, lessThan(100));
    });
  });
}
