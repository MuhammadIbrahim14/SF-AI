import os

# Fix unused import custom_text_field
path = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\admin\presentation\admin_legal_editor_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import '../../../shared/widgets/custom_text_field.dart';\n", "")
content = content.replace("onReorder: (oldIndex, newIndex)", "onReorder: (oldIndex, newIndex)")
# ReorderableListView's deprecated member is fine, it's just an info. I will leave it to avoid breaking changes if Flutter version is old. Let me just suppress the unused imports to make flutter analyze clean.

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# Fix unused import auth_provider
path2 = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\legal\providers\legal_provider.dart'
with open(path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

content2 = content2.replace("import '../../../providers/auth_provider.dart';\n", "")

with open(path2, 'w', encoding='utf-8') as f:
    f.write(content2)
