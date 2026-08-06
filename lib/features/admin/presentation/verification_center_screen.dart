import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../models/verification_request.dart';
import '../../../providers/admin_provider.dart';
import '../../../core/theme/role_theme.dart';
import '../../../models/user_role.dart';
import 'widgets/admin_control_scaffold.dart';

class VerificationCenterScreen extends ConsumerStatefulWidget {
  const VerificationCenterScreen({super.key});

  @override
  ConsumerState<VerificationCenterScreen> createState() =>
      _VerificationCenterScreenState();
}

class _VerificationCenterScreenState
    extends ConsumerState<VerificationCenterScreen> {
  String _role = 'all';
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    final teachers = ref.watch(teacherVerificationsProvider);
    final companies = ref.watch(companyVerificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminControlScaffold(
      title: 'Verification Center',
      subtitle: 'Review teacher expertise and company identity requests.',
      currentPath: RoutePaths.adminVerification,
      actions: [
        IconButton(
          tooltip: 'Refresh Queue',
          onPressed: () {
            ref.invalidate(teacherVerificationsProvider);
            ref.invalidate(companyVerificationsProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Filter(
                      label: 'Account Type',
                      value: _role,
                      values: const ['all', 'teacher', 'company'],
                      icon: Icons.group_outlined,
                      onChanged: (value) => setState(() => _role = value),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: _Filter(
                      label: 'Status Queue',
                      value: _status,
                      values: const ['all', 'pending', 'approved', 'rejected'],
                      icon: Icons.pending_actions_outlined,
                      onChanged: (value) => setState(() => _status = value),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildRequests(teachers, companies)),
        ],
      ),
    );
  }

  Widget _buildRequests(
    AsyncValue<List<VerificationRequest>> teachers,
    AsyncValue<List<VerificationRequest>> companies,
  ) {
    if (teachers.isLoading || companies.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (teachers.hasError || companies.hasError) {
      return _VerificationMessage(
        icon: Icons.error_outline_rounded,
        title: 'Queue Offline',
        message: '${teachers.error ?? companies.error}',
      );
    }

    final requests = [...?teachers.value, ...?companies.value].where((request) {
      final roleMatch = _role == 'all' || request.role == _role;
      final statusMatch = _status == 'all' || request.status == _status;
      return roleMatch && statusMatch;
    }).toList();

    if (requests.isEmpty) {
      return const _VerificationMessage(
        icon: Icons.verified_outlined,
        title: 'Queue is clear',
        message: 'No verification requests match the selected filters.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final request = requests[index];
        final isCompany = request.role == 'company';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161616) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;
              final roleTheme = getRoleTheme(
                isCompany ? UserRole.company : UserRole.teacher,
              );
              final information = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: roleTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompany ? Icons.business_rounded : Icons.school_rounded,
                      color: roleTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request.displayName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (compact) ...[
                              const SizedBox(width: 8),
                              _RoleBadge(isCompany: isCompany),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (request.updatedAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat.yMMMd().add_jm().format(
                                  request.updatedAt!,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 16),
                    _RoleBadge(isCompany: isCompany),
                    const SizedBox(width: 16),
                    _ModerationStatusBadge(status: request.status),
                  ] else ...[
                    _ModerationStatusBadge(status: request.status),
                  ],
                ],
              );

              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showDetails(request),
                    icon: const Icon(Icons.plagiarism_outlined, size: 18),
                    label: const Text('Review Data'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  if (request.status != 'rejected')
                    FilledButton.tonalIcon(
                      onPressed: () => _update(request, 'rejected'),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer.withValues(alpha: 0.5),
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (request.status != 'approved')
                    FilledButton.icon(
                      onPressed: () => _update(request, 'approved'),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              );

              return Padding(
                padding: const EdgeInsets.all(20),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          information,
                          const SizedBox(height: 20),
                          actions,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: information),
                          const SizedBox(width: 24),
                          actions,
                        ],
                      ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _update(VerificationRequest request, String status) async {
    final success = await ref
        .read(adminActionProvider.notifier)
        .updateVerification(request, status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${request.displayName} is now $status.'
              : ref.read(adminActionProvider.notifier).errorMessage ??
                    'Unable to update verification.',
        ),
      ),
    );
  }

  Future<void> _showDetails(VerificationRequest request) {
    final fields = request.role == 'company'
        ? const [
            'companyName',
            'industry',
            'companySize',
            'website',
            'officialEmail',
          ]
        : const [
            'professionalTitle',
            'industry',
            'experienceYears',
            'subjects',
            'certifications',
          ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: getRoleTheme(
                    request.role == 'company'
                        ? UserRole.company
                        : UserRole.teacher,
                  ).primary.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: getRoleTheme(
                          request.role == 'company'
                              ? UserRole.company
                              : UserRole.teacher,
                        ).primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        request.role == 'company'
                            ? Icons.business_rounded
                            : Icons.school_rounded,
                        color: getRoleTheme(
                          request.role == 'company'
                              ? UserRole.company
                              : UserRole.teacher,
                        ).primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review Identity',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.displayName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    _ModerationStatusBadge(status: request.status),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: fields.map((field) {
                      final title = field
                          .replaceAllMapped(
                            RegExp(r'([A-Z])'),
                            (match) => ' ${match.group(1)}',
                          )
                          .toUpperCase();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _display(request.details[field]),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close Review'),
                    ),
                    const SizedBox(width: 12),
                    if (request.status != 'rejected')
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _update(request, 'rejected');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer.withValues(alpha: 0.5),
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('Reject'),
                      ),
                    const SizedBox(width: 12),
                    if (request.status != 'approved')
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _update(request, 'approved');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Approve'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isCompany});
  final bool isCompany;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isCompany ? 'COMPANY' : 'TEACHER',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ModerationStatusBadge extends StatelessWidget {
  const _ModerationStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'approved' => Colors.green,
      'rejected' => Colors.redAccent,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            normalized == 'approved'
                ? Icons.check_circle_rounded
                : (normalized == 'rejected'
                      ? Icons.cancel_rounded
                      : Icons.pending_rounded),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            normalized.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.values,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        hint: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        selectedItemBuilder: (context) {
          return values.map((val) {
            return Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  val == 'all' ? label : val.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            );
          }).toList();
        },
        items: values
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(
                  value == 'all' ? 'All' : value.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }
}

class _VerificationMessage extends StatelessWidget {
  const _VerificationMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
              ).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
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

String _display(Object? value) {
  if (value is Iterable) {
    final items = value.map((item) => item.toString()).toList();
    return items.isEmpty ? 'Not provided' : items.join(', ');
  }
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? 'Not provided' : text;
}
