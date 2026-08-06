import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';

/// Brief celebratory popup shown after a successful Demo or Stripe checkout.
///
/// Prefer calling with a [BuildContext] that outlives the checkout sheet, or
/// pass [navigator] from `Navigator.of(context, rootNavigator: true)` captured
/// *before* the sheet closes so Windows overlay still has a valid host.
Future<void> showPaymentSuccessToast(
  BuildContext context, {
  String message = 'Purchase successful!',
  Duration duration = const Duration(milliseconds: 1500),
  NavigatorState? navigator,
}) async {
  final rootNav =
      navigator ?? Navigator.maybeOf(context, rootNavigator: true);
  if (rootNav == null) return;

  // Wait one frame so modal-bottom-sheet disposal finishes on Windows.
  await SchedulerBinding.instance.endOfFrame;
  await Future<void>.delayed(Duration.zero);
  if (!rootNav.mounted) return;

  await rootNav.push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Dismiss payment success',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return _PaymentSuccessToastBody(
          message: message,
          duration: duration,
        );
      },
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _PaymentSuccessToastBody extends StatefulWidget {
  const _PaymentSuccessToastBody({
    required this.message,
    required this.duration,
  });

  final String message;
  final Duration duration;

  @override
  State<_PaymentSuccessToastBody> createState() =>
      _PaymentSuccessToastBodyState();
}

class _PaymentSuccessToastBodyState extends State<_PaymentSuccessToastBody> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.elevatedSurface : AppColors.lightSurface;
    final onSurface =
        isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                surface,
                AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.06),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks a short celebratory label based on checkout type.
String paymentSuccessMessageForType(String type) {
  switch (type) {
    case 'wallet_topup':
      return 'Payment successful!';
    default:
      return 'Purchase successful!';
  }
}
