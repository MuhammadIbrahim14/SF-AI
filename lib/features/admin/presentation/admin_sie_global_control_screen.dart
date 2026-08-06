import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../models/platform_settings.dart';
import '../../../providers/admin_provider.dart';
import '../../student/sie/student_sie_providers.dart';
import 'widgets/admin_control_scaffold.dart';

/// Super-admin control panel for the Spatial Interaction Engine (SIE).
///
/// Global On/Off is persisted in Firestore `settings/platform.sieGloballyEnabled`
/// and enforced across all roles via the shared SIE host + PRF kill switch.
class AdminSieGlobalControlScreen extends ConsumerStatefulWidget {
  const AdminSieGlobalControlScreen({super.key});

  @override
  ConsumerState<AdminSieGlobalControlScreen> createState() =>
      _AdminSieGlobalControlScreenState();
}

class _AdminSieGlobalControlScreenState
    extends ConsumerState<AdminSieGlobalControlScreen> {
  PlatformSettings? _draft;
  bool _initialized = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(platformSettingsProvider);
    final availability = ref.watch(studentSieAvailabilityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return AdminControlScaffold(
      title: 'SIE Engine',
      subtitle:
          'Globally enable or disable Spatial Interaction Engine for every role.',
      currentPath: RoutePaths.adminSieControl,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            _initialized = false;
            ref.invalidate(platformSettingsProvider);
            ref.invalidate(studentSieBootstrapProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load SIE settings.\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
        data: (settings) {
          if (!_initialized) {
            _draft = settings;
            _initialized = true;
          }
          final draft = _draft ?? settings;
          final on = draft.sieGloballyEnabled;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (on ? Colors.teal : Colors.redAccent)
                      .withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (on ? Colors.teal : Colors.redAccent)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      on ? Icons.gesture_rounded : Icons.block_rounded,
                      size: 36,
                      color: on ? Colors.teal : Colors.redAccent,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            on ? 'SIE is ON' : 'SIE is OFF',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            on
                                ? 'Hand gestures / virtual cursor can run on allowed routes.'
                                : 'All roles: SIE host blocked + PRF kill switch armed.',
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.7),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: on,
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                                () => _draft =
                                    draft.copyWith(sieGloballyEnabled: value),
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _StatusCard(
                title: 'Live runtime status',
                rows: [
                  ('Host gate', availability.hostEnabled ? 'OPEN' : 'BLOCKED'),
                  (
                    'SRDCR available',
                    availability.available ? 'yes' : 'no',
                  ),
                  (
                    'PRF sieEnabled',
                    availability.sieEnabled ? 'true' : 'false',
                  ),
                  (
                    'Active route',
                    availability.activeRouteId ?? '—',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'What this controls',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Student, Teacher, Freelancer, Company, and Admin SIE hosts\n'
                '• Progressive rollout feature flag (enableSie)\n'
                '• Emergency kill switch (local + remote flags)\n'
                '• Camera / gesture pipeline will not bootstrap while OFF\n'
                '• Traditional mouse/touch input always keeps working',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(draft),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving…' : 'Save SIE global setting'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(PlatformSettings draft) async {
    setState(() => _saving = true);
    try {
      final success = await ref
          .read(adminActionProvider.notifier)
          .savePlatformSettings(draft);
      if (!mounted) return;
      if (success) {
        _initialized = false;
        ref.invalidate(platformSettingsProvider);
        ref.invalidate(studentSieBootstrapProvider);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (draft.sieGloballyEnabled
                    ? 'SIE enabled globally.'
                    : 'SIE disabled globally.')
                : ref.read(adminActionProvider.notifier).errorMessage ??
                    'Unable to save SIE setting.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 12),
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Text(
                  row.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
