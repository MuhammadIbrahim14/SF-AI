import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../data/release_center_provider.dart';

class ReleaseCenterScreen extends ConsumerWidget {
  const ReleaseCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releaseAsync = ref.watch(releaseCenterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Release Center'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Go back',
        ),
      ),
      body: SafeArea(
        child: releaseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ReleaseMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to load downloads',
            message: 'Please retry in a moment.',
            details: error.toString(),
          ),
          data: (config) {
            final hasAndroid =
                config?.isAndroidEnabled == true &&
                (config?.androidApkUrl.trim().isNotEmpty ?? false);
            final hasWindows =
                config?.isWindowsEnabled == true &&
                ((config?.windowsExeUrl.trim().isNotEmpty ?? false) ||
                    (config?.windowsZipUrl.trim().isNotEmpty ?? false));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Hero(config: config),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 760;
                            final cards = [
                              _DownloadCard(
                                icon: Icons.android_rounded,
                                title: 'Android APK',
                                version: config?.androidVersion ?? '',
                                buildNumber: config?.androidBuildNumber ?? '',
                                fileSize: config?.androidFileSize ?? '',
                                notes: config?.androidReleaseNotes ?? '',
                                enabled: hasAndroid,
                                url: config?.androidApkUrl ?? '',
                                buttonLabel: 'Download APK',
                              ),
                              _DownloadCard(
                                icon: Icons.desktop_windows_rounded,
                                title: 'Windows App',
                                version: config?.windowsVersion ?? '',
                                buildNumber: config?.windowsBuildNumber ?? '',
                                fileSize: config?.windowsFileSize ?? '',
                                notes: config?.windowsReleaseNotes ?? '',
                                enabled: hasWindows,
                                url: (config?.windowsExeUrl.isNotEmpty ?? false)
                                    ? config!.windowsExeUrl
                                    : config?.windowsZipUrl ?? '',
                                secondaryUrl: config?.windowsZipUrl,
                                buttonLabel: 'Download Windows',
                              ),
                            ];

                            if (!isWide) {
                              return Column(
                                children: [
                                  for (final card in cards) ...[
                                    card,
                                    const SizedBox(height: 16),
                                  ],
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 16),
                                Expanded(child: cards[1]),
                              ],
                            );
                          },
                        ),
                        if (config?.githubReleaseUrl.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openUrl(context, config!.githubReleaseUrl),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('View GitHub Release'),
                          ),
                        ],
                        if (!hasAndroid && !hasWindows) ...[
                          const SizedBox(height: 24),
                          _ReleaseMessage(
                            icon: Icons.upcoming_rounded,
                            title: 'No public download published yet',
                            message:
                                'The app owner has not published release links yet.',
                            details: null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.config});

  final ReleaseCenterConfig? config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updatedAt = config?.updatedAt == null
        ? null
        : DateFormat.yMMMd().add_jm().format(config!.updatedAt!);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.secondary.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.download_for_offline_rounded, size: 42),
          const SizedBox(height: 16),
          Text(
            'SkillForge AI Downloads',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get the latest stable SkillForge AI build for your platform.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if ((config?.latestVersion ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Latest version: ${config!.latestVersion}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (updatedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Updated $updatedAt',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.icon,
    required this.title,
    required this.version,
    required this.buildNumber,
    required this.fileSize,
    required this.notes,
    required this.enabled,
    required this.url,
    required this.buttonLabel,
    this.secondaryUrl,
  });

  final IconData icon;
  final String title;
  final String version;
  final String buildNumber;
  final String fileSize;
  final String notes;
  final bool enabled;
  final String url;
  final String buttonLabel;
  final String? secondaryUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _Status(enabled: enabled),
            ],
          ),
          const SizedBox(height: 18),
          _Meta(label: 'Version', value: version),
          _Meta(label: 'Build', value: buildNumber),
          _Meta(label: 'Size', value: fileSize),
          const SizedBox(height: 12),
          Text(
            notes.trim().isEmpty ? 'Release notes will appear here.' : notes,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: enabled ? () => _openUrl(context, url) : null,
            icon: const Icon(Icons.download_rounded),
            label: Text(enabled ? buttonLabel : 'Not available'),
          ),
          if (enabled &&
              secondaryUrl != null &&
              secondaryUrl!.trim().isNotEmpty &&
              secondaryUrl!.trim() != url.trim()) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openUrl(context, secondaryUrl!),
              icon: const Icon(Icons.folder_zip_rounded),
              label: const Text('Download ZIP'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled ? 'LIVE' : 'SOON',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }
}

class _ReleaseMessage extends StatelessWidget {
  const _ReleaseMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.details,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _openUrl(BuildContext context, String rawUrl) async {
  final url = rawUrl.trim();
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download link is not configured safely.')),
    );
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted || launched) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Unable to open this download link.')),
  );
}
