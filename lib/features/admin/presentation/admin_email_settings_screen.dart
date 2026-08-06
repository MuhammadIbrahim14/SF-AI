import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/mailer/email_templates.dart';
import '../../../core/mailer/emailjs_config.dart';
import '../../../core/mailer/emailjs_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/dashboard_empty_state.dart';
import 'widgets/admin_control_scaffold.dart';

class AdminEmailSettingsScreen extends ConsumerStatefulWidget {
  const AdminEmailSettingsScreen({super.key});

  @override
  ConsumerState<AdminEmailSettingsScreen> createState() =>
      _AdminEmailSettingsScreenState();
}

class _AdminEmailSettingsScreenState
    extends ConsumerState<AdminEmailSettingsScreen> {
  final _serviceId = TextEditingController();
  final _publicKey = TextEditingController();
  final _templateId = TextEditingController();
  final _fromName = TextEditingController(text: 'SkillForge AI');
  final _replyTo = TextEditingController();
  bool _enabled = true;
  bool _loginEmails = false;
  bool _courseEmails = true;
  bool _hiringEmails = true;
  bool _marketplaceEmails = true;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _serviceId.dispose();
    _publicKey.dispose();
    _templateId.dispose();
    _fromName.dispose();
    _replyTo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(emailJsConfigProvider);
    return AdminControlScaffold(
      title: 'EmailJS Settings',
      subtitle: 'Professional transactional email without notifications.',
      currentPath: RoutePaths.adminEmailSettings,
      body: configAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => DashboardEmptyState(
          icon: Icons.mark_email_unread_outlined,
          title: 'Email settings unavailable',
          message: error.toString(),
        ),
        data: (config) {
          if (!_seeded) {
            _seed(config);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!config.isConfigured)
                      const _WarningCard(
                        message:
                            'EmailJS not configured. Actions will still save, but email sends will be skipped and logged.',
                      ),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile(
                              value: _enabled,
                              onChanged: (value) =>
                                  setState(() => _enabled = value),
                              title: const Text('Enable EmailJS mailer'),
                              subtitle: const Text(
                                'Uses public EmailJS service/template IDs only. No private secret is stored here.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            _field(_serviceId, 'Service ID'),
                            _field(_publicKey, 'Public Key'),
                            _field(_templateId, 'Template ID'),
                            _field(_fromName, 'From name'),
                            _field(_replyTo, 'Reply-to email'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _toggle(
                                  'Login emails',
                                  _loginEmails,
                                  (v) => _loginEmails = v,
                                ),
                                _toggle(
                                  'Course updates',
                                  _courseEmails,
                                  (v) => _courseEmails = v,
                                ),
                                _toggle(
                                  'Hiring emails',
                                  _hiringEmails,
                                  (v) => _hiringEmails = v,
                                ),
                                _toggle(
                                  'Marketplace emails',
                                  _marketplaceEmails,
                                  (v) => _marketplaceEmails = v,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: const Icon(Icons.save_rounded),
                                  label: Text(_saving ? 'Saving...' : 'Save'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _saving ? null : _sendTest,
                                  icon: const Icon(Icons.send_rounded),
                                  label: const Text('Send Test Email'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      selected: value,
      label: Text(label),
      onSelected: (next) => setState(() => onChanged(next)),
    );
  }

  void _seed(EmailJsConfig config) {
    _enabled = config.enabled;
    _serviceId.text = config.serviceId;
    _publicKey.text = config.publicKey;
    _templateId.text = config.templateId;
    _fromName.text = config.fromName;
    _replyTo.text = config.replyTo;
    _loginEmails = config.sendLoginEmails;
    _courseEmails = config.sendCourseUpdateEmails;
    _hiringEmails = config.sendHiringEmails;
    _marketplaceEmails = config.sendMarketplaceEmails;
    _seeded = true;
  }

  EmailJsConfig _config() {
    return EmailJsConfig(
      enabled: _enabled,
      serviceId: _serviceId.text,
      publicKey: _publicKey.text,
      templateId: _templateId.text,
      fromName: _fromName.text,
      replyTo: _replyTo.text,
      sendLoginEmails: _loginEmails,
      sendCourseUpdateEmails: _courseEmails,
      sendHiringEmails: _hiringEmails,
      sendMarketplaceEmails: _marketplaceEmails,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(emailJsMailerServiceProvider).saveConfig(_config());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('EmailJS settings saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save email settings: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendTest() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final email = user?.email ?? _replyTo.text;
    if (email.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a test email first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(emailJsMailerServiceProvider)
          .send(
            SkillForgeEmailTemplates.test(
              toEmail: email,
              toName: user?.displayName ?? 'Admin',
            ),
            triggeredBy: user?.uid ?? 'admin',
            config: _config(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSent
                ? 'Test email sent.'
                : 'Test email ${result.status}: ${result.message}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: .28),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
