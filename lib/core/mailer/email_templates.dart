import 'email_template_model.dart';
import 'email_template_type.dart';

class SkillForgeEmailTemplates {
  const SkillForgeEmailTemplates._();

  static SkillForgeEmailTemplate accountCreated({
    required String uid,
    required String toEmail,
    required String toName,
    required String role,
    required String actionUrl,
  }) {
    return SkillForgeEmailTemplate(
      type: EmailTemplateType.accountCreated,
      toEmail: toEmail,
      toName: toName.isEmpty ? 'SkillForge member' : toName,
      subject: 'Welcome to SkillForge AI - your account is ready',
      preheader: 'Your SkillForge AI account has been created successfully.',
      headline: 'Welcome to SkillForge AI',
      body:
          'Your SkillForge AI account has been created successfully. ${_roleLine(role)}',
      actionText: 'Open Dashboard',
      actionUrl: actionUrl,
      footerNote: 'You are receiving this because your account was created.',
      dedupeKey: 'account_created_$uid',
      relatedDocPath: 'users/$uid',
    );
  }

  static SkillForgeEmailTemplate login({
    required String uid,
    required String toEmail,
    required String toName,
    required String dateKey,
    required String actionUrl,
  }) {
    return SkillForgeEmailTemplate(
      type: EmailTemplateType.login,
      toEmail: toEmail,
      toName: toName.isEmpty ? 'SkillForge member' : toName,
      subject: 'New login to your SkillForge AI account',
      preheader: 'A new login was recorded for your SkillForge AI account.',
      headline: 'New login detected',
      body:
          'A new login was recorded for your SkillForge AI account. If this was you, no action is needed.',
      actionText: 'Review Account',
      actionUrl: actionUrl,
      footerNote: 'Login emails can be disabled by the platform admin.',
      dedupeKey: 'login_${uid}_$dateKey',
      relatedDocPath: 'users/$uid',
    );
  }

  static SkillForgeEmailTemplate hiringStatus({
    required String applicationId,
    required String toEmail,
    required String toName,
    required String companyName,
    required String jobTitle,
    required String status,
    required String nextSteps,
    required String actionUrl,
  }) {
    final label = status.trim().isEmpty ? 'application update' : status;
    return SkillForgeEmailTemplate(
      type: EmailTemplateType.hiringStatus,
      toEmail: toEmail,
      toName: toName.isEmpty ? 'Candidate' : toName,
      subject: _hiringSubject(label, jobTitle, companyName),
      preheader: 'Your application status has been updated.',
      headline: 'Application update',
      body:
          '$companyName updated your application for $jobTitle. Status: ${_human(label)}. $nextSteps',
      actionText: 'View Application',
      actionUrl: actionUrl,
      footerNote: 'Private recruiter notes and internal scores are not shared.',
      dedupeKey: 'application_status_${applicationId}_$label',
      relatedDocPath: 'applications/$applicationId',
    );
  }

  static SkillForgeEmailTemplate marketplace({
    required String dedupeKey,
    required String relatedDocPath,
    required String toEmail,
    required String toName,
    required String subject,
    required String headline,
    required String body,
    required String actionUrl,
  }) {
    return SkillForgeEmailTemplate(
      type: EmailTemplateType.marketplace,
      toEmail: toEmail,
      toName: toName.isEmpty ? 'SkillForge member' : toName,
      subject: subject,
      preheader: headline,
      headline: headline,
      body: body,
      actionText: 'Open SkillForge',
      actionUrl: actionUrl,
      footerNote: 'Sandbox commerce emails do not contain payment secrets.',
      dedupeKey: dedupeKey,
      relatedDocPath: relatedDocPath,
    );
  }

  static SkillForgeEmailTemplate test({
    required String toEmail,
    required String toName,
  }) {
    return SkillForgeEmailTemplate(
      type: EmailTemplateType.test,
      toEmail: toEmail,
      toName: toName.isEmpty ? 'Admin' : toName,
      subject: 'SkillForge AI EmailJS test',
      preheader: 'EmailJS is configured for SkillForge AI.',
      headline: 'EmailJS test successful',
      body:
          'This is a test message from the SkillForge AI EmailJS mailer system.',
      actionText: 'Open SkillForge',
      actionUrl: '',
      footerNote: 'No private EmailJS secret was used.',
      dedupeKey: 'test_${DateTime.now().millisecondsSinceEpoch}',
      relatedDocPath: 'appPublicConfig/emailjs',
    );
  }
}

String _roleLine(String role) {
  return switch (role) {
    'student' => 'Start learning and building your career portfolio.',
    'teacher' => 'Create courses and guide learners.',
    'company' => 'Post jobs and evaluate verified candidates.',
    'freelancer' => 'Offer services and manage client work.',
    'customer' => 'Request services and hire freelancers safely.',
    _ => 'Access your role-based tools from your dashboard.',
  };
}

String _hiringSubject(String status, String jobTitle, String companyName) {
  return switch (status) {
    'applied' || 'pending' => 'Application received for $jobTitle',
    'shortlisted' => 'You have been shortlisted for $jobTitle',
    'evaluation' ||
    'evaluationRequested' => 'Evaluation requested for $jobTitle',
    'interview' ||
    'interviewScheduled' ||
    'interview_scheduled' ||
    'interview_invitation' => 'Interview invitation for $jobTitle',
    'interview_updated' => 'Interview updated for $jobTitle',
    'interview_cancelled' => 'Interview cancelled for $jobTitle',
    'offer' ||
    'offerSent' ||
    'offer_sent' => 'Offer letter from $companyName — $jobTitle',
    'offerAccepted' ||
    'offer_accepted' ||
    'accepted' ||
    'candidate_accepted' => 'Offer accepted confirmation — $jobTitle',
    'offer_rejected' ||
    'offerDeclined' ||
    'candidate_declined' => 'Offer response — $jobTitle',
    'offer_clarification' => 'Offer clarification requested — $jobTitle',
    'joining_reminder' => 'Joining reminder for $jobTitle',
    'selected' || 'hired' || 'joined' =>
      'Congratulations - you are selected for $jobTitle',
    'rejected' => 'Application update for $jobTitle',
    _ => 'Application update for $jobTitle',
  };
}

String _human(String value) {
  return value
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .trim();
}
