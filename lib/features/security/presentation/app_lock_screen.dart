import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../providers/app_lock_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _biometricPrompted = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text;
    if (!AppLockService.isValidPin(pin) || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final unlocked = await ref.read(appLockProvider.notifier).verifyPin(pin);
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    if (unlocked) {
      _goToDashboard();
      return;
    }

    _pinController.clear();
    _pinFocusNode.requestFocus();
  }

  Future<void> _unlockWithBiometrics() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    final unlocked = await ref
        .read(appLockProvider.notifier)
        .unlockWithBiometrics();
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    if (unlocked) _goToDashboard();
  }

  void _goToDashboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(RoutePaths.dashboard);
    });
  }

  void _scheduleBiometricPrompt(AppLockState state) {
    if (_biometricPrompted ||
        !state.isEnabled ||
        !state.isBiometricEnabled ||
        !state.isBiometricAvailable) {
      return;
    }

    _biometricPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlockWithBiometrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockAsync = ref.watch(appLockProvider);
    final lockState = lockAsync.value ?? const AppLockState();
    _scheduleBiometricPrompt(lockState);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: lockAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontal = constraints.maxWidth < 600 ? 20.0 : 40.0;
                    final vertical = constraints.maxHeight < 620 ? 16.0 : 32.0;
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        vertical,
                        horizontal,
                        vertical,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - (vertical * 2))
                              .clamp(0.0, double.infinity),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: _LockPanel(
                              pinController: _pinController,
                              pinFocusNode: _pinFocusNode,
                              lockState: lockState,
                              isSubmitting: _isSubmitting,
                              onPinChanged: (_) => setState(() {}),
                              onPinSubmitted: (_) => _unlockWithPin(),
                              onUnlockWithPin: _unlockWithPin,
                              onUnlockWithBiometrics: _unlockWithBiometrics,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _LockPanel extends StatelessWidget {
  const _LockPanel({
    required this.pinController,
    required this.pinFocusNode,
    required this.lockState,
    required this.isSubmitting,
    required this.onPinChanged,
    required this.onPinSubmitted,
    required this.onUnlockWithPin,
    required this.onUnlockWithBiometrics,
  });

  final TextEditingController pinController;
  final FocusNode pinFocusNode;
  final AppLockState lockState;
  final bool isSubmitting;
  final ValueChanged<String> onPinChanged;
  final ValueChanged<String> onPinSubmitted;
  final VoidCallback onUnlockWithPin;
  final VoidCallback onUnlockWithBiometrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pinIsValid = AppLockService.isValidPin(pinController.text);

    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 360 ? 24 : 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 24,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: colorScheme.primary,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Identity Gateway',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify your identity to access SkillForge AI. Your session remains securely active.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          if (lockState.isBiometricEnabled &&
              lockState.isBiometricAvailable) ...[
            Center(
              child: _BiometricNode(
                isSubmitting: isSubmitting,
                onTap: onUnlockWithBiometrics,
                label: lockState.biometricLabel,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          TextField(
            controller: pinController,
            focusNode: pinFocusNode,
            autofocus: !lockState.isBiometricEnabled,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: onPinChanged,
            onSubmitted: onPinSubmitted,
            decoration: InputDecoration(
              labelText: 'App Lock PIN',
              hintText: '4 or 6 digits',
              prefixIcon: const Icon(Icons.pin_outlined),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (lockState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              lockState.errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (lockState.failedAttempts > 0) ...[
            const SizedBox(height: 5),
            Text(
              '${lockState.failedAttempts} failed '
              '${lockState.failedAttempts == 1 ? 'attempt' : 'attempts'}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Verify Identity',
            icon: Icons.shield_rounded,
            isLoading: isSubmitting,
            isEnabled: pinIsValid,
            onPressed: onUnlockWithPin,
          ),
        ],
      ),
    );
  }
}

class _BiometricNode extends StatefulWidget {
  const _BiometricNode({
    required this.isSubmitting,
    required this.onTap,
    required this.label,
  });

  final bool isSubmitting;
  final VoidCallback onTap;
  final String label;

  @override
  State<_BiometricNode> createState() => _BiometricNodeState();
}

class _BiometricNodeState extends State<_BiometricNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.isSubmitting ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isSubmitting
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(
                color: widget.isSubmitting
                    ? colorScheme.primary.withValues(alpha: 0.4)
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: widget.isSubmitting
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isSubmitting)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _controller.value * 2 * 3.14159,
                        child: CustomPaint(
                          painter: _ScanRingPainter(color: colorScheme.primary),
                          size: const Size(88, 88),
                        ),
                      );
                    },
                  ),
                Icon(
                  Icons.fingerprint_rounded,
                  size: 42,
                  color: widget.isSubmitting
                      ? colorScheme.primary
                      : colorScheme.primary.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.isSubmitting
                ? 'Verifying Neural Pattern...'
                : 'Scan ${widget.label}',
            key: ValueKey(widget.isSubmitting),
            style: theme.textTheme.labelLarge?.copyWith(
              color: widget.isSubmitting
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanRingPainter extends CustomPainter {
  final Color color;
  _ScanRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - 2,
      ),
      0,
      3.14159 * 0.7,
      false,
      paint,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - 2,
      ),
      3.14159,
      3.14159 * 0.7,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
