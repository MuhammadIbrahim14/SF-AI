import os
import re

files_to_update = [
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\login_screen.dart',
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\signup_screen.dart',
    r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\forgot_password_screen.dart'
]

for filepath in files_to_update:
    if not os.path.exists(filepath):
        continue
        
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fix onSurface10
    content = content.replace('colorScheme.onSurface10', 'colorScheme.onSurface.withValues(alpha: 0.1)')
    
    # We will remove 'const ' from declarations that now use colorScheme.
    # A simple regex approach to find 'const ' followed by anything that has colorScheme inside the same line or block.
    # Actually, it's safer to just replace specific 'const ' that are causing issues:
    
    # "const BoxDecoration" -> "BoxDecoration"
    content = content.replace('const BoxDecoration(', 'BoxDecoration(')
    
    # "const Text(" with colorScheme inside
    content = re.sub(r'const Text\(([^)]*colorScheme[^)]*)\)', r'Text(\1)', content)
    
    # Sometimes it spans multiple lines. Just remove "const " before Text, TextStyle, Icon, Border, BorderSide if they contain colorScheme.
    # Actually, it's safer to just remove all `const ` before `Icon`, `Text`, `TextStyle`, `BorderSide` in these files, since Flutter performance isn't heavily impacted by a few missing consts on auth screens, OR we can be precise.
    
    # Let's remove `const ` in lines that contain `colorScheme`
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'colorScheme' in line and 'const ' in line:
            lines[i] = line.replace('const ', '')
            
    # Rejoin lines
    content = '\n'.join(lines)
    
    # There might be multi-line issues like:
    # const Text('...', style: TextStyle(color:
    #   colorScheme.onSurfaceVariant))
    # We can just run a blanket regex to remove const from Text, TextStyle, Icon, BoxConstraints? No BoxConstraints is fine.
    
    content = content.replace("const Icon(Icons.arrow_back_rounded", "Icon(Icons.arrow_back_rounded")
    content = content.replace("const Text('Abort Mission (Home)'", "Text('Abort Mission (Home)'")
    content = content.replace("const TextStyle(", "TextStyle(")
    
    # Fix 'const Border(' and 'const BorderSide('
    content = content.replace("const Border(", "Border(")
    content = content.replace("const BorderSide(", "BorderSide(")

    # Fix TextStyle that might have had const
    content = content.replace("const TextStyle", "TextStyle")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Fixed {filepath}")
