import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../models/audit_log.dart';
import '../../../providers/admin_provider.dart';
import 'widgets/admin_control_scaffold.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isMobile = MediaQuery.of(context).size.width < 700;
    return AdminControlScaffold(
      title: isMobile ? 'Ledger' : 'Security Ledger',
      subtitle: isMobile
          ? 'Immutable history of all platform events.'
          : 'Immutable history of platform events, status changes, and administrator actions.',
      currentPath: RoutePaths.adminAuditLogs,
      actions: [
        IconButton(
          tooltip: 'Refresh Ledger',
          onPressed: () => ref.invalidate(auditLogsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: AdminPanelCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText:
                            'Search ledger by action, description, admin ID, or target ID...',
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                final visible = logs.where((log) {
                  if (_query.isEmpty) return true;
                  return log.action.toLowerCase().contains(_query) ||
                      log.description.toLowerCase().contains(_query) ||
                      log.adminId.toLowerCase().contains(_query) ||
                      log.targetId.toLowerCase().contains(_query);
                }).toList();

                if (visible.isEmpty) {
                  return _EmptyLedger(query: _query);
                }

                return Container(
                  margin: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF161616)
                        : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Continuous timeline line safely positioned behind the list
                        Positioned(
                          left: 35, // 72 width column / 2 = 36 - 1px line width
                          top: 40,
                          bottom: 40,
                          child: Container(
                            width: 2,
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final log = visible[index];
                            return _LedgerEntry(log: log);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: AdminPanelCard(
                  child: Text(
                    'Failed to load ledger: $error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntry extends StatelessWidget {
  const _LedgerEntry({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final severity = _determineSeverity(log.action);
    final color = _getSeverityColor(severity);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        SizedBox(
          width: 72,
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 24),
              width: 32,
              height: 32,
              // Solid background to hide the continuous line passing behind it
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161616)
                    : const Color(0xFFFAFAFA),
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(_getSeverityIcon(severity), size: 16, color: color),
              ),
            ),
          ),
        ),

        // Content column
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 24, top: 12, bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.05),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          log.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _ActionBadge(action: log.action, color: color),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 400;
                      final items = [
                        _DataPoint(
                          label: 'TIMESTAMP',
                          value: DateFormat(
                            'yyyy-MM-dd HH:mm:ss',
                          ).format(log.createdAt),
                        ),
                        _DataPoint(
                          label: 'ADMIN ID',
                          value: _short(log.adminId),
                        ),
                        _DataPoint(
                          label: 'TARGET ID',
                          value: _short(log.targetId),
                        ),
                      ];

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: items
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: item,
                                ),
                              )
                              .toList(),
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: items,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _short(String value) {
    if (value.length <= 12) return value;
    return '${value.substring(0, 12)}...';
  }

  _Severity _determineSeverity(String action) {
    final normalized = action.toLowerCase();
    if (normalized.contains('ban') ||
        normalized.contains('suspend') ||
        normalized.contains('reject') ||
        normalized.contains('delete') ||
        normalized.contains('remove')) {
      return _Severity.critical;
    }
    if (normalized.contains('approve') ||
        normalized.contains('verify') ||
        normalized.contains('create') ||
        normalized.contains('restore')) {
      return _Severity.success;
    }
    if (normalized.contains('update') ||
        normalized.contains('edit') ||
        normalized.contains('change') ||
        normalized.contains('maintenance')) {
      return _Severity.warning;
    }
    return _Severity.info;
  }

  Color _getSeverityColor(_Severity severity) {
    switch (severity) {
      case _Severity.critical:
        return Colors.redAccent;
      case _Severity.success:
        return Colors.green;
      case _Severity.warning:
        return Colors.orange;
      case _Severity.info:
        return Colors.blue;
    }
  }

  IconData _getSeverityIcon(_Severity severity) {
    switch (severity) {
      case _Severity.critical:
        return Icons.gavel_rounded;
      case _Severity.success:
        return Icons.check_circle_outline_rounded;
      case _Severity.warning:
        return Icons.build_circle_outlined;
      case _Severity.info:
        return Icons.info_outline_rounded;
    }
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action, required this.color});

  final String action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        action.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _DataPoint extends StatelessWidget {
  const _DataPoint({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              query.isEmpty ? Icons.shield_outlined : Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            query.isEmpty ? 'Ledger is Empty' : 'No Matching Records Found',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            query.isEmpty
                ? 'No security events have been recorded in the system yet.'
                : 'No ledger entries matched your search parameters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Severity { info, success, warning, critical }
