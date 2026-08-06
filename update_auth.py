import os
import re

files_to_update = [
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\login_screen.dart',
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\signup_screen.dart',
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\forgot_password_screen.dart'
]

for filepath in files_to_update:
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        continue
        
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Uncomment isDark
    content = content.replace('//     final isDark = Theme.of(context).brightness == Brightness.dark;', 
                              'final isDark = Theme.of(context).brightness == Brightness.dark;\n    final colorScheme = Theme.of(context).colorScheme;')
    
    # In forgot password, isDark might not be commented out or present. Let's make sure it's injected.
    if 'final isDark = ' not in content:
        content = content.replace('final isLoading = ref.watch(authNotifierProvider).isLoading;',
                                  'final isLoading = ref.watch(authNotifierProvider).isLoading;\n    final isDark = Theme.of(context).brightness == Brightness.dark;\n    final colorScheme = Theme.of(context).colorScheme;')

    # Replace Scaffold background
    content = content.replace('backgroundColor: const Color(0xFF030712), // Deep futuristic black/blue', 
                              'backgroundColor: colorScheme.surface,')
    content = content.replace('backgroundColor: const Color(0xFF030712),', 
                              'backgroundColor: colorScheme.surface,')

    # Replace desktop auth panel background and border
    content = content.replace('color: Colors.white10', 'color: colorScheme.outlineVariant.withValues(alpha: 0.5)')
    content = content.replace('color: const Color(0xFF0B0F19)', 'color: colorScheme.surfaceContainerHigh')
    content = content.replace('color: Color(0xFF0B0F19)', 'color: colorScheme.surfaceContainerHigh')
    
    # Replace mobile panel background
    content = content.replace('color: const Color(0xFF0B0F19).withValues(alpha: 0.7)', 'color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.7)')
    content = content.replace('color: Colors.black.withValues(alpha: 0.5)', 'color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1)')

    # Replace colors in texts and icons
    content = content.replace('Colors.white54', 'colorScheme.onSurfaceVariant')
    content = content.replace('Colors.white60', 'colorScheme.onSurfaceVariant')
    content = content.replace('Colors.white38', 'colorScheme.onSurfaceVariant.withValues(alpha: 0.7)')
    content = content.replace('Colors.white', 'colorScheme.onSurface')

    # Update _buildAuthForm arguments from isDark: true to isDark: isDark
    content = content.replace('isDark: true', 'isDark: isDark')

    # Pass colorScheme to _buildBrandStoryOverlay if needed, or simply extract colorScheme locally
    # It's better to replace _buildBrandStoryOverlay() with _buildBrandStoryOverlay(colorScheme)
    content = content.replace('_buildBrandStoryOverlay()', '_buildBrandStoryOverlay(colorScheme)')
    content = content.replace('Widget _buildBrandStoryOverlay() {', 'Widget _buildBrandStoryOverlay(ColorScheme colorScheme) {')
    
    # Same for _buildAuthForm and _buildForm
    content = content.replace('_buildAuthForm({required bool isDesktop, required bool isDark})', '_buildAuthForm({required bool isDesktop, required bool isDark, required ColorScheme colorScheme})')
    content = content.replace('isDesktop: true, isDark: isDark', 'isDesktop: true, isDark: isDark, colorScheme: colorScheme')
    content = content.replace('isDesktop: false, isDark: isDark', 'isDesktop: false, isDark: isDark, colorScheme: colorScheme')
    
    content = content.replace('_buildAuthForm(\n                            isDesktop: true,\n                            isDark: isDark,\n                            registrationEnabled: registrationEnabled,\n                          )', '_buildAuthForm(\n                            isDesktop: true,\n                            isDark: isDark,\n                            registrationEnabled: registrationEnabled,\n                            colorScheme: colorScheme,\n                          )')
    content = content.replace('_buildAuthForm(\n                              isDesktop: false,\n                              isDark: isDark,\n                              registrationEnabled: registrationEnabled,\n                            )', '_buildAuthForm(\n                              isDesktop: false,\n                              isDark: isDark,\n                              registrationEnabled: registrationEnabled,\n                              colorScheme: colorScheme,\n                            )')
    content = content.replace('Widget _buildAuthForm({required bool isDesktop, required bool isDark, required bool registrationEnabled}) {', 'Widget _buildAuthForm({required bool isDesktop, required bool isDark, required bool registrationEnabled, required ColorScheme colorScheme}) {')

    # Forgot password uses _buildForm
    content = content.replace('Widget _buildForm({required bool isDesktop, required bool isLoading}) {', 'Widget _buildForm({required bool isDesktop, required bool isLoading, required ColorScheme colorScheme}) {')
    content = content.replace('_buildForm(\n                          isDesktop: true,\n                          isLoading: isLoading,\n                        )', '_buildForm(\n                          isDesktop: true,\n                          isLoading: isLoading,\n                          colorScheme: colorScheme,\n                        )')
    content = content.replace('_buildForm(\n                            isDesktop: false,\n                            isLoading: isLoading,\n                          )', '_buildForm(\n                            isDesktop: false,\n                            isLoading: isLoading,\n                            colorScheme: colorScheme,\n                          )')
    
    # Fix the legal consent colors in signup
    content = content.replace('Widget _buildLegalConsent(BuildContext context) {', 'Widget _buildLegalConsent(BuildContext context, ColorScheme colorScheme) {')
    content = content.replace('_buildLegalConsent(context)', '_buildLegalConsent(context, colorScheme)')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Updated {filepath}")
