import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../profile/providers/public_profile_provider.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';
import '../data/release_center_provider.dart';

class AdminReleaseCenterConfigScreen extends ConsumerStatefulWidget {
  const AdminReleaseCenterConfigScreen({super.key});

  @override
  ConsumerState<AdminReleaseCenterConfigScreen> createState() =>
      _AdminReleaseCenterConfigScreenState();
}

class _AdminReleaseCenterConfigScreenState
    extends ConsumerState<AdminReleaseCenterConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _seeded = false;
  bool _portfolioSeeded = false;
  bool _saving = false;
  bool _androidEnabled = false;
  bool _windowsEnabled = false;
  bool _portfolioEnabled = false;

  late final _latestVersion = TextEditingController();
  late final _githubReleaseUrl = TextEditingController();
  late final _androidApkUrl = TextEditingController();
  late final _androidVersion = TextEditingController();
  late final _androidBuildNumber = TextEditingController();
  late final _androidFileSize = TextEditingController();
  late final _androidReleaseNotes = TextEditingController();
  late final _windowsExeUrl = TextEditingController();
  late final _windowsZipUrl = TextEditingController();
  late final _windowsVersion = TextEditingController();
  late final _windowsBuildNumber = TextEditingController();
  late final _windowsFileSize = TextEditingController();
  late final _windowsReleaseNotes = TextEditingController();
  late final _portfolioBaseUrl = TextEditingController();

  @override
  void dispose() {
    _latestVersion.dispose();
    _githubReleaseUrl.dispose();
    _androidApkUrl.dispose();
    _androidVersion.dispose();
    _androidBuildNumber.dispose();
    _androidFileSize.dispose();
    _androidReleaseNotes.dispose();
    _windowsExeUrl.dispose();
    _windowsZipUrl.dispose();
    _windowsVersion.dispose();
    _windowsBuildNumber.dispose();
    _windowsFileSize.dispose();
    _windowsReleaseNotes.dispose();
    _portfolioBaseUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(releaseCenterProvider);
    final portfolioSettings = ref
        .watch(portfolioSettingsProvider)
        .asData
        ?.value;
    return AdminControlScaffold(
      title: 'Release Center Config',
      subtitle: 'Publish GitHub download links for Android and Windows builds.',
      currentPath: RoutePaths.adminReleaseCenter,
      actions: [
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (config) {
          if (!_seeded) {
            _seed(config ?? const ReleaseCenterConfig());
          }
          if (!_portfolioSeeded && portfolioSettings != null) {
            _portfolioBaseUrl.text = portfolioSettings.portfolioBaseUrl;
            _portfolioEnabled = portfolioSettings.isPortfolioEnabled;
            _portfolioSeeded = true;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              children: [
                AdminPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global Release',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        controller: _latestVersion,
                        label: 'Latest Version',
                        hint: 'e.g. 1.0.0',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _githubReleaseUrl,
                        label: 'GitHub Release URL',
                        hint: 'https://github.com/.../releases/tag/v1.0.0',
                        validator: _optionalHttps,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _PlatformCard(
                  title: 'Android APK',
                  enabled: _androidEnabled,
                  onEnabledChanged: (value) =>
                      setState(() => _androidEnabled = value),
                  fields: [
                    _Field(
                      controller: _androidApkUrl,
                      label: 'APK URL',
                      hint: 'https://github.com/.../app-release.apk',
                      validator: _requiredHttpsWhenAndroidEnabled,
                    ),
                    _Field(controller: _androidVersion, label: 'Version'),
                    _Field(controller: _androidBuildNumber, label: 'Build'),
                    _Field(controller: _androidFileSize, label: 'File Size'),
                    _Field(
                      controller: _androidReleaseNotes,
                      label: 'Release Notes',
                      maxLines: 5,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PlatformCard(
                  title: 'Windows Build',
                  enabled: _windowsEnabled,
                  onEnabledChanged: (value) =>
                      setState(() => _windowsEnabled = value),
                  fields: [
                    _Field(
                      controller: _windowsExeUrl,
                      label: 'EXE URL',
                      hint: 'https://github.com/.../SkillForgeAI.exe',
                      validator: _optionalHttps,
                    ),
                    _Field(
                      controller: _windowsZipUrl,
                      label: 'ZIP URL',
                      hint: 'https://github.com/.../SkillForgeAI.zip',
                      validator: _windowsUrlValidator,
                    ),
                    _Field(controller: _windowsVersion, label: 'Version'),
                    _Field(controller: _windowsBuildNumber, label: 'Build'),
                    _Field(controller: _windowsFileSize, label: 'File Size'),
                    _Field(
                      controller: _windowsReleaseNotes,
                      label: 'Release Notes',
                      maxLines: 5,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AdminPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portfolio Website',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _portfolioEnabled,
                        onChanged: (value) =>
                            setState(() => _portfolioEnabled = value),
                        title: const Text('Enable public portfolio links'),
                        subtitle: const Text(
                          'One deployed portfolio_web site serves every /p/{slug} profile.',
                        ),
                      ),
                      _Field(
                        controller: _portfolioBaseUrl,
                        label: 'Portfolio Base URL',
                        hint: 'https://skillforge-portfolios.netlify.app',
                        validator: _portfolioUrlValidator,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _seed(ReleaseCenterConfig config) {
    _latestVersion.text = config.latestVersion;
    _githubReleaseUrl.text = config.githubReleaseUrl;
    _androidApkUrl.text = config.androidApkUrl;
    _androidVersion.text = config.androidVersion;
    _androidBuildNumber.text = config.androidBuildNumber;
    _androidFileSize.text = config.androidFileSize;
    _androidReleaseNotes.text = config.androidReleaseNotes;
    _windowsExeUrl.text = config.windowsExeUrl;
    _windowsZipUrl.text = config.windowsZipUrl;
    _windowsVersion.text = config.windowsVersion;
    _windowsBuildNumber.text = config.windowsBuildNumber;
    _windowsFileSize.text = config.windowsFileSize;
    _windowsReleaseNotes.text = config.windowsReleaseNotes;
    _androidEnabled = config.isAndroidEnabled;
    _windowsEnabled = config.isWindowsEnabled;
    _seeded = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(releaseCenterRepositoryProvider)
          .save(
            ReleaseCenterConfig(
              latestVersion: _latestVersion.text,
              githubReleaseUrl: _githubReleaseUrl.text,
              androidApkUrl: _androidApkUrl.text,
              androidVersion: _androidVersion.text,
              androidBuildNumber: _androidBuildNumber.text,
              androidFileSize: _androidFileSize.text,
              androidReleaseNotes: _androidReleaseNotes.text,
              windowsExeUrl: _windowsExeUrl.text,
              windowsZipUrl: _windowsZipUrl.text,
              windowsVersion: _windowsVersion.text,
              windowsBuildNumber: _windowsBuildNumber.text,
              windowsFileSize: _windowsFileSize.text,
              windowsReleaseNotes: _windowsReleaseNotes.text,
              isAndroidEnabled: _androidEnabled,
              isWindowsEnabled: _windowsEnabled,
            ),
          );
      await ref
          .read(releaseCenterRepositoryProvider)
          .savePortfolioSettings(
            portfolioBaseUrl: _portfolioBaseUrl.text,
            isPortfolioEnabled: _portfolioEnabled,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Release Center updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save release config: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredHttpsWhenAndroidEnabled(String? value) {
    if (!_androidEnabled) return _optionalHttps(value);
    if ((value ?? '').trim().isEmpty) return 'Required when enabled';
    return _optionalHttps(value);
  }

  String? _windowsUrlValidator(String? value) {
    final exe = _windowsExeUrl.text.trim();
    final zip = (value ?? '').trim();
    if (_windowsEnabled && exe.isEmpty && zip.isEmpty) {
      return 'Add EXE or ZIP URL when enabled';
    }
    return _optionalHttps(value);
  }

  String? _portfolioUrlValidator(String? value) {
    if (!_portfolioEnabled) return _optionalHttps(value);
    if ((value ?? '').trim().isEmpty) return 'Required when enabled';
    return _optionalHttps(value);
  }

  String? _optionalHttps(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'Use a valid https URL';
    }
    return null;
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.title,
    required this.enabled,
    required this.onEnabledChanged,
    required this.fields,
  });

  final String title;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: onEnabledChanged,
            title: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              enabled ? 'Public download enabled' : 'Public download disabled',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              if (!wide) {
                return Column(
                  children: [
                    for (final field in fields) ...[
                      field,
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final field in fields)
                    SizedBox(
                      width: field is _Field && field.maxLines > 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2,
                      child: field,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
