import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../providers/app_lock_provider.dart';
import '../../../shared/widgets/primary_button.dart';

enum PinManagementMode { setup, change, disable }

class PinManagementScreen extends ConsumerStatefulWidget {
  const PinManagementScreen.setup({super.key}) : mode = PinManagementMode.setup;

  const PinManagementScreen.change({super.key})
    : mode = PinManagementMode.change;

  const PinManagementScreen.disable({super.key})
    : mode = PinManagementMode.disable;

  final PinManagementMode mode;

  @override
  ConsumerState<PinManagementScreen> createState() =>
      _PinManagementScreenState();
}

class _PinManagementScreenState extends ConsumerState<PinManagementScreen> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final validationError = _validate();
    if (validationError != null) {
      setState(() => _validationError = validationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    final notifier = ref.read(appLockProvider.notifier);
    final success = switch (widget.mode) {
      PinManagementMode.setup => await notifier.enableLock(
        _newPinController.text,
      ),
      PinManagementMode.change => await notifier.changePin(
        currentPin: _currentPinController.text,
        newPin: _newPinController.text,
      ),
      PinManagementMode.disable => await notifier.disableLockWithPin(
        _currentPinController.text,
      ),
    };
    if (!mounted) return;

    if (!success) {
      setState(() {
        _isSubmitting = false;
        _validationError =
            ref.read(appLockProvider).value?.errorMessage ??
            'Unable to update App Lock.';
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_successMessage),
        backgroundColor: const Color(0xFF087F5B),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.of(context);
      if (router.canPop()) {
        context.pop();
      } else {
        context.go(RoutePaths.securitySettings);
      }
    });
  }

  String? _validate() {
    if (widget.mode != PinManagementMode.setup &&
        !AppLockService.isValidPin(_currentPinController.text)) {
      return 'Current PIN must contain exactly 4 or 6 digits.';
    }
    if (widget.mode == PinManagementMode.disable) return null;
    if (!AppLockService.isValidPin(_newPinController.text)) {
      return 'New PIN must contain exactly 4 or 6 digits.';
    }
    if (_newPinController.text != _confirmPinController.text) {
      return 'PIN confirmation does not match.';
    }
    return null;
  }

  String get _title => switch (widget.mode) {
    PinManagementMode.setup => 'Enable App Lock',
    PinManagementMode.change => 'Change PIN',
    PinManagementMode.disable => 'Disable App Lock',
  };

  String get _description => switch (widget.mode) {
    PinManagementMode.setup =>
      'Create a 4 or 6 digit PIN. This session will remain unlocked.',
    PinManagementMode.change =>
      'Verify your current PIN, then choose a new secure PIN.',
    PinManagementMode.disable =>
      'Verify your PIN to remove App Lock from this device.',
  };

  String get _buttonLabel => switch (widget.mode) {
    PinManagementMode.setup => 'Enable App Lock',
    PinManagementMode.change => 'Change PIN',
    PinManagementMode.disable => 'Disable App Lock',
  };

  String get _successMessage => switch (widget.mode) {
    PinManagementMode.setup => 'App Lock enabled.',
    PinManagementMode.change => 'PIN changed successfully.',
    PinManagementMode.disable => 'App Lock disabled.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDestructive = widget.mode == PinManagementMode.disable;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth < 600 ? 16.0 : 32.0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          isDestructive
                              ? Icons.lock_open_rounded
                              : Icons.shield_outlined,
                          size: 48,
                          color: isDestructive
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (widget.mode != PinManagementMode.setup) ...[
                          _PinField(
                            controller: _currentPinController,
                            label: 'Current PIN',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (widget.mode != PinManagementMode.disable) ...[
                          _PinField(
                            controller: _newPinController,
                            label: 'New PIN',
                          ),
                          const SizedBox(height: 12),
                          _PinField(
                            controller: _confirmPinController,
                            label: 'Confirm PIN',
                            onSubmitted: (_) => _submit(),
                          ),
                        ],
                        if (_validationError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _validationError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        PrimaryButton(
                          text: _buttonLabel,
                          icon: isDestructive
                              ? Icons.lock_open_rounded
                              : Icons.check_rounded,
                          isLoading: _isSubmitting,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: '4 or 6 digits',
        prefixIcon: const Icon(Icons.pin_outlined),
      ),
    );
  }
}
