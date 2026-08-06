import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mailer/email_template_model.dart';
import '../../../core/mailer/email_template_type.dart';
import '../../../core/mailer/emailjs_provider.dart';
import '../../../providers/repository_providers.dart';
import '../providers/course_provider.dart';
import '../providers/enrollment_provider.dart';

class CourseUpdateMailer {
  const CourseUpdateMailer(this.ref);

  final Ref ref;

  Future<void> sendCourseUpdate({
    required String courseId,
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String teacherId,
    String dueDateLabel = '',
  }) async {
    try {
      final config = await ref.read(emailJsMailerServiceProvider).loadConfig();
      if (!config.sendCourseUpdateEmails) return;

      final course = await ref
          .read(courseRepositoryProvider)
          .getCourse(courseId);
      if (course == null || !course.isPublished) return;

      final enrollments = await ref
          .read(enrollmentRepositoryProvider)
          .getCourseEnrollments(courseId);
      if (enrollments.isEmpty) return;

      final mailer = ref.read(emailJsMailerServiceProvider);
      for (final enrollment in enrollments) {
        final student = await ref
            .read(userRepositoryProvider)
            .getUser(enrollment.studentId);
        final email = student?.email.trim() ?? '';
        if (email.isEmpty) continue;
        final subject = _subject(
          itemType: itemType,
          itemTitle: itemTitle,
          courseTitle: course.title,
        );
        final dueLine = dueDateLabel.trim().isEmpty
            ? ''
            : '\nDue date: ${dueDateLabel.trim()}.';
        await mailer.send(
          SkillForgeEmailTemplate(
            type: EmailTemplateType.courseUpdate,
            toEmail: email,
            toName: student?.fullName ?? 'Student',
            subject: subject,
            preheader: subject,
            headline: 'New $itemType added',
            body:
                'Your teacher added "$itemTitle" in ${course.title}.$dueLine Open the course to continue learning.',
            actionText: 'Open Course',
            actionUrl: '',
            footerNote:
                'You are receiving this because you are enrolled in this course.',
            dedupeKey:
                'course_update_${courseId}_${itemType}_${itemId}_${enrollment.studentId}',
            relatedDocPath: 'courses/$courseId',
          ),
          triggeredBy: teacherId,
          config: config,
        );
      }
    } catch (_) {
      // Course emails are non-blocking.
    }
  }

  String _subject({
    required String itemType,
    required String itemTitle,
    required String courseTitle,
  }) {
    return switch (itemType) {
      'lesson' => 'New lesson added: $itemTitle',
      'assignment' => 'New assignment added in $courseTitle',
      'project' => 'New project assignment added in $courseTitle',
      'grand test' => 'Grand test is now available in $courseTitle',
      _ => 'New course update in $courseTitle',
    };
  }
}
