import 'email_template_type.dart';

class SkillForgeEmailTemplate {
  const SkillForgeEmailTemplate({
    required this.type,
    required this.toEmail,
    required this.toName,
    required this.subject,
    required this.preheader,
    required this.headline,
    required this.body,
    required this.actionText,
    required this.actionUrl,
    required this.footerNote,
    required this.dedupeKey,
    required this.relatedDocPath,
  });

  final EmailTemplateType type;
  final String toEmail;
  final String toName;
  final String subject;
  final String preheader;
  final String headline;
  final String body;
  final String actionText;
  final String actionUrl;
  final String footerNote;
  final String dedupeKey;
  final String relatedDocPath;

  Map<String, dynamic> toEmailJsParams({
    required String appName,
    required String fromName,
    required String replyTo,
  }) {
    return {
      'to_email': toEmail,
      'to_name': toName,
      'subject': subject,
      'preheader': preheader,
      'headline': headline,
      'body': body,
      'action_text': actionText,
      'action_url': actionUrl,
      'footer_note': footerNote,
      'app_name': appName,
      'from_name': fromName,
      'reply_to': replyTo,
    };
  }
}
