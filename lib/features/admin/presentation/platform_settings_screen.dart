import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/role_theme.dart';
import '../../../../models/user_role.dart';
import '../../../../shared/widgets/primary_button.dart';

class PlatformSettingsScreen extends StatelessWidget {
  const PlatformSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roleTheme = getRoleTheme(UserRole.admin);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Global Configurations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Maintenance Mode'),
                  subtitle: const Text(
                    'Temporarily disable access for non-admins.',
                  ),
                  value: false,
                  onChanged: (val) {},
                  activeThumbColor: AppColors.error,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Allow New Registrations'),
                  value: true,
                  onChanged: (val) {},
                  activeThumbColor: roleTheme.primary,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Clear System Cache'),
                  trailing: const Icon(
                    Icons.delete_sweep_rounded,
                    color: AppColors.warning,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Database Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: 'Trigger Manual Backup',
            backgroundColor: roleTheme.secondary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup triggered successfully.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
