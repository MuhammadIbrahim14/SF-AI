import os
import re

path = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\signup_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add premium_auth_scaffold import
if 'premium_auth_scaffold.dart' not in content:
    content = content.replace("import '../../../shared/widgets/primary_button.dart';", "import '../../../shared/widgets/primary_button.dart';\nimport '../../../shared/widgets/premium_auth_scaffold.dart';")

# Remove _coreController
content = re.sub(r'late final AnimationController _coreController;\n', '', content)
content = re.sub(r'_coreController = AnimationController\(.*?vsync: this,\s*duration: const Duration\(seconds: 20\),\s*\)\.\.repeat\(\);\n', '', content, flags=re.DOTALL)
content = re.sub(r'_coreController\.dispose\(\);\n', '', content)

# Replace build method
build_replacement = """  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final platformSettings = ref.watch(platformSettingsProvider).value;
    final registrationEnabled = platformSettings?.registrationEnabled ?? true;
    final colorScheme = Theme.of(context).colorScheme;

    return PremiumAuthScaffold(
      title: 'Initialize Core',
      subtitle: 'Create your SkillForge identity and join the network.',
      isLoading: authState.isLoading,
      child: _buildAuthForm(registrationEnabled: registrationEnabled, colorScheme: colorScheme),
    );
  }

  Widget _buildAuthForm({required bool registrationEnabled, required ColorScheme colorScheme}) {"""

# Replace from @override Widget build to Widget _buildAuthForm
content = re.sub(r'  @override\s*Widget build\(BuildContext context\).*?Widget _buildAuthForm\(\{.*?\}\) \{', build_replacement, content, flags=re.DOTALL)

# Fix the method signature inside _buildAuthForm body where it might reference isDesktop or isDark (which we removed from parameters).
# We can just remove usages of isDesktop and isDark since it's responsive now.
# _buildAuthForm is big. Let's see how it uses isDesktop and isDark.
# Let's just remove isDesktop and isDark from the Form body.
# Actually, I should just replace the beginning of _buildAuthForm to remove isDesktop/isDark logic.
content = re.sub(r'if \(!isDesktop\).*?const SizedBox\(height: 24\),\s*],', '', content, flags=re.DOTALL)
content = re.sub(r'fontSize: isDesktop \? 36 : 28,', 'fontSize: 28,', content)
content = re.sub(r'textAlign: isDesktop \? TextAlign\.left : TextAlign\.center,', 'textAlign: TextAlign.center,', content)

# Remove the isDesktop block at the bottom
content = re.sub(r'if \(isDesktop\) \[\s*const SizedBox\(height: 48\),\s*IconButton\.filledTonal\(.*?\),\s*\] else \[\s*', '', content, flags=re.DOTALL)
# And the closing bracket of the else block
content = content.replace("]\n            ],", "            ],")

# Remove _AICorePainter
content = re.sub(r'class _AICorePainter extends CustomPainter {.*?}\n', '', content, flags=re.DOTALL)

# Remove _buildBrandStoryOverlay entirely
content = re.sub(r'  Widget _buildBrandStoryOverlay\(.*?}\n', '', content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
