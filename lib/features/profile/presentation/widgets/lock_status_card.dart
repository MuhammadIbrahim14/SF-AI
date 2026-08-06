import 'package:flutter/material.dart';

class LockStatusCard extends StatefulWidget {
  const LockStatusCard({
    super.key,
    required this.isAppLockEnabled,
    required this.isPinConfigured,
    required this.isBiometricEnabled,
  });

  final bool isAppLockEnabled;
  final bool isPinConfigured;
  final bool isBiometricEnabled;

  @override
  State<LockStatusCard> createState() => _LockStatusCardState();
}

class _LockStatusCardState extends State<LockStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isAppLockEnabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LockStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAppLockEnabled && !oldWidget.isAppLockEnabled) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isAppLockEnabled && oldWidget.isAppLockEnabled) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = widget.isAppLockEnabled
        ? const Color(0xFF16A36A)
        : colorScheme.error;

    final statusLabel = widget.isAppLockEnabled ? 'Secure' : 'Unprotected';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3 + (pulseValue * 0.2)),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: statusColor.withValues(
                          alpha: 0.2 + (pulseValue * 0.15),
                        ),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(
                            alpha: 0.2 + (pulseValue * 0.1),
                          ),
                          blurRadius: 16 + (pulseValue * 8),
                          spreadRadius: -4 + (pulseValue * 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.isAppLockEnabled
                          ? Icons.verified_user_rounded
                          : Icons.gpp_maybe_rounded,
                      color: statusColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vault Status',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isAppLockEnabled
                              ? 'Your identity and data are safely encrypted on this device.'
                              : 'App lock is currently off. Your data is exposed.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusBadge(
                    label: statusLabel,
                    color: statusColor,
                    pulseValue: pulseValue,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatusDetail(
                    icon: Icons.pin_outlined,
                    label: widget.isPinConfigured ? 'PIN Verified' : 'No PIN',
                    isActive: widget.isPinConfigured,
                  ),
                  _StatusDetail(
                    icon: Icons.fingerprint_rounded,
                    label: widget.isBiometricEnabled
                        ? 'Biometrics Active'
                        : 'Biometrics Off',
                    isActive: widget.isBiometricEnabled,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.pulseValue,
  });

  final String label;
  final Color color;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.3 + (pulseValue * 0.2)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color,
                  blurRadius: 4 + (pulseValue * 4),
                  spreadRadius: 1 + (pulseValue * 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDetail extends StatelessWidget {
  const _StatusDetail({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = isActive
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
