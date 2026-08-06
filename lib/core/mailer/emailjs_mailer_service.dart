import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'email_event_logger.dart';
import 'email_template_model.dart';
import 'emailjs_config.dart';

class EmailJsMailerService {
  EmailJsMailerService({
    required FirebaseFirestore firestore,
    http.Client? client,
  }) : _firestore = firestore,
       _client = client ?? http.Client(),
       _logger = EmailEventLogger(firestore);

  final FirebaseFirestore _firestore;
  final http.Client _client;
  final EmailEventLogger _logger;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('appPublicConfig').doc('emailjs');

  Stream<EmailJsConfig> watchConfig() {
    return _configRef.snapshots().map((doc) {
      return EmailJsConfig.fromMap(doc.data());
    });
  }

  Future<EmailJsConfig> loadConfig() async {
    final doc = await _configRef.get();
    return EmailJsConfig.fromMap(doc.data());
  }

  Future<void> saveConfig(EmailJsConfig config) {
    return _configRef.set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<EmailSendResult> send(
    SkillForgeEmailTemplate template, {
    required String triggeredBy,
    EmailJsConfig? config,
  }) async {
    final resolvedConfig = config ?? await loadConfig();
    if (!resolvedConfig.isConfigured || template.toEmail.trim().isEmpty) {
      await _logger.log(
        template: template,
        status: 'skipped',
        triggeredBy: triggeredBy,
        errorMessage: resolvedConfig.isConfigured
            ? 'Recipient email missing.'
            : 'EmailJS not configured.',
      );
      return const EmailSendResult.skipped('EmailJS not configured.');
    }

    if (await _logger.hasSent(template.dedupeKey, triggeredBy: triggeredBy)) {
      return const EmailSendResult.skipped('Duplicate email skipped.');
    }

    try {
      final response = await _client.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': resolvedConfig.serviceId,
          'template_id': resolvedConfig.templateId,
          'user_id': resolvedConfig.publicKey,
          'template_params': template.toEmailJsParams(
            appName: 'SkillForge AI',
            fromName: resolvedConfig.fromName,
            replyTo: resolvedConfig.replyTo,
          ),
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _logger.log(
          template: template,
          status: 'sent',
          triggeredBy: triggeredBy,
        );
        return const EmailSendResult.sent();
      }
      final message = 'EmailJS HTTP ${response.statusCode}';
      await _logger.log(
        template: template,
        status: 'failed',
        triggeredBy: triggeredBy,
        errorMessage: message,
      );
      return EmailSendResult.failed(message);
    } catch (error) {
      final message = error.toString();
      await _logger.log(
        template: template,
        status: 'failed',
        triggeredBy: triggeredBy,
        errorMessage: message,
      );
      return EmailSendResult.failed(message);
    }
  }
}

class EmailSendResult {
  const EmailSendResult._(this.status, this.message);

  const EmailSendResult.sent() : this._('sent', '');
  const EmailSendResult.skipped(String message) : this._('skipped', message);
  const EmailSendResult.failed(String message) : this._('failed', message);

  final String status;
  final String message;

  bool get isSent => status == 'sent';
}
