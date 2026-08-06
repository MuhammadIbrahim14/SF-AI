import os
import re

# Fix admin_legal_editor_screen.dart
path = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\admin\presentation\admin_legal_editor_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('const LegalPolicies(updatedAt: null)', 'LegalPolicies(updatedAt: DateTime.now())')
content = content.replace('final colorScheme = Theme.of(context).colorScheme;\n', '')
content = content.replace('CustomTextField(\n                            label: \'Section Title\',', 'TextFormField(\n                            decoration: const InputDecoration(labelText: \'Section Title\'),')
content = content.replace('CustomTextField(\n                            label: \'Section Body\',', 'TextFormField(\n                            decoration: const InputDecoration(labelText: \'Section Body\'),')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# Fix legal_provider.dart
path = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\legal\providers\legal_provider.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'repository_providers.dart' not in content:
    content = content.replace('import \'../../../providers/auth_provider.dart\';', 'import \'../../../providers/auth_provider.dart\';\nimport \'../../../providers/repository_providers.dart\';')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# Fix unused imports
screens = [
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\legal\presentation\account_deletion_policy_screen.dart',
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\legal\presentation\privacy_policy_screen.dart',
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\legal\presentation\terms_of_service_screen.dart'
]

for screen in screens:
    with open(screen, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace("import '../domain/models/legal_policy.dart';\n", "")
    with open(screen, 'w', encoding='utf-8') as f:
        f.write(content)
