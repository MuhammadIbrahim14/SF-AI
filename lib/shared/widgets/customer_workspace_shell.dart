import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/copilot/presentation/copilot_floating_button.dart';
import 'customer_app_bar.dart';

class CustomerWorkspaceShell extends ConsumerWidget {
  const CustomerWorkspaceShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A simple, lightweight shell exclusively for customer accounts.
    // It provides the CustomerAppBar and a standard body.
    // Bottom Navigation could be added here for mobile if desired.
    return Scaffold(
      appBar: const CustomerAppBar(),
      body: Stack(
        children: [
          Positioned.fill(child: child),
          const CopilotFloatingButton(),
        ],
      ),
    );
  }
}
