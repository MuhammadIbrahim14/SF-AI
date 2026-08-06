import os
import re

def fix_signup():
    path = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\signup_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove the orphaned AICorePainter
    content = re.sub(r'/// A lightweight CustomPainter for the signup Core visual\..*', '', content, flags=re.DOTALL)

    # Fix isDesktop
    desktop_block = r'if \(isDesktop\) \.\.\.\[.*?\] else \.\.\.\[.*?\]\s*\]'
    # Actually let's just replace from `if (isDesktop) ...[` down to the `],` before `),`
    content = re.sub(r'if \(isDesktop\) \.\.\.\[.*?Abort Mission \(Home\).*?\)', 'const SizedBox(height: 24),\n              TextButton.icon(\n                onPressed: () => context.go(RoutePaths.home),\n                icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurfaceVariant, size: 16),\n                label: Text(\'Abort Mission (Home)\', style: TextStyle(color: colorScheme.onSurfaceVariant)),\n              )', content, flags=re.DOTALL)
    
    # Fix the dangling closing brackets that was part of the else statement array
    content = re.sub(r'\]\s*\]\,\s*\)\,\s*\)\,\s*\)\;', '],\n          ),\n        ),\n      ),\n    );', content, flags=re.DOTALL)
    # Wait, let's just use string replacement for safety
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_forgot_password():
    path = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\forgot_password_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove the orphaned AICorePainter
    content = re.sub(r'/// A lightweight CustomPainter for the recovery visual\..*', '', content, flags=re.DOTALL)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

fix_signup()
fix_forgot_password()
