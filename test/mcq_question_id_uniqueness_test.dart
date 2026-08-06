import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_ai/features/courses/data/models/grand_test_model.dart';
import 'package:skillforge_ai/features/courses/data/models/mcq_assignment_model.dart';

void main() {
  group('createMcqQuestionId', () {
    test('mints unique ids even in a tight loop', () {
      final ids = List.generate(40, (_) => createMcqQuestionId());
      expect(ids.toSet().length, ids.length);
    });
  });

  group('uniquifyMcqQuestionIds', () {
    test('repairs duplicate and empty question ids', () {
      final questions = [
        const McqQuestionModel(
          questionId: 'dup',
          question: 'Q1',
          options: ['A', 'B'],
          correctAnswer: 'A',
          marksPerQuestion: 1,
        ),
        const McqQuestionModel(
          questionId: 'dup',
          question: 'Q2',
          options: ['A', 'B'],
          correctAnswer: 'B',
          marksPerQuestion: 1,
        ),
        const McqQuestionModel(
          questionId: '',
          question: 'Q3',
          options: ['A', 'B'],
          correctAnswer: 'A',
          marksPerQuestion: 1,
        ),
      ];

      final fixed = uniquifyMcqQuestionIds(questions);
      expect(fixed.map((q) => q.questionId).toSet().length, 3);
      expect(fixed[0].question, 'Q1');
      expect(fixed[1].question, 'Q2');
      expect(fixed[2].question, 'Q3');

      // Answer map must keep one selection per question.
      final answers = <String, String>{};
      answers[fixed[0].questionId] = 'A';
      answers[fixed[1].questionId] = 'B';
      answers[fixed[2].questionId] = 'A';
      expect(answers.length, 3);
      expect(answers[fixed[0].questionId], 'A');
      expect(answers[fixed[1].questionId], 'B');
    });
  });

  group('uniquifyGrandTestQuestionIds', () {
    test('repairs duplicate question ids', () {
      final questions = [
        const GrandTestQuestionModel(
          questionId: 'same',
          question: 'GT1',
          options: ['A', 'B'],
          correctAnswer: 'A',
          marks: 1,
          difficulty: 'Medium',
          skillTag: 'dart',
        ),
        const GrandTestQuestionModel(
          questionId: 'same',
          question: 'GT2',
          options: ['A', 'B'],
          correctAnswer: 'B',
          marks: 1,
          difficulty: 'Medium',
          skillTag: 'dart',
        ),
      ];

      final fixed = uniquifyGrandTestQuestionIds(questions);
      expect(fixed.map((q) => q.questionId).toSet().length, 2);
    });
  });
}
