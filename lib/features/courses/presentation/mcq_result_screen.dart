import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/assignment_provider.dart';

class McqResultScreen extends ConsumerWidget {
  const McqResultScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
  });

  final String courseId;
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(
      assignmentDetailProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );
    final attemptAsync = ref.watch(
      studentAssignmentAttemptProvider((
        courseId: courseId,
        assignmentId: assignmentId,
      )),
    );

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'MCQ Result',
      subtitle: 'Review your score, warnings, and answer breakdown.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.studentAssignments,
              pathParameters: {'courseId': courseId},
            ),
      scrollable: false,
      child: assignmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (assignment) {
          if (assignment == null) {
            return const Center(child: Text('Assignment not found.'));
          }
          return attemptAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (attempt) {
              if (attempt == null || !attempt.isSubmitted) {
                return const Center(child: Text('No submitted result yet.'));
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            attempt.passed
                                ? Icons.verified_rounded
                                : Icons.info_outline_rounded,
                            size: 56,
                            color: attempt.passed
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            attempt.passed ? 'Passed' : 'Needs Practice',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${attempt.score}/${attempt.totalMarks} marks | '
                            '${attempt.percentage.toStringAsFixed(0)}%',
                          ),
                          const SizedBox(height: 8),
                          Text('Warnings: ${attempt.warningsCount}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Review',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...assignment.questions.map((question) {
                    final selected = attempt.answers[question.questionId];
                    final isCorrect =
                        selected?.trim().toLowerCase() ==
                        question.correctAnswer.trim().toLowerCase();
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          isCorrect
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                        title: Text(question.question),
                        subtitle: Text(
                          'Your answer: ${selected ?? 'Not answered'}\n'
                          'Correct answer: ${question.correctAnswer}'
                          '${question.explanation.trim().isEmpty ? '' : '\nExplanation: ${question.explanation}'}',
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.goNamed(
                      RouteNames.studentAssignments,
                      pathParameters: {'courseId': courseId},
                    ),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Back to Assignments'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
