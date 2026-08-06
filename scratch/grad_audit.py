import os, re
from collections import defaultdict

lib_dir = os.path.join(os.environ.get('cwd', '.'), 'lib')

ignore_files = ['app_colors.dart', 'app_theme.dart', 'app_typography.dart', 'auth_cinematic_screen.dart', 'home_hero_screen.dart', 'animated_theme_switcher.dart', 'exam_active_screen.dart', 'student_grand_test_overview_screen.dart', 'teacher_grand_tests_screen.dart', 'mcq']

results = []

for root, _, files in os.walk(lib_dir):
    for file in files:
        if not file.endswith('.dart'): continue
        if any(ign in file.lower() for ign in ignore_files): continue
        
        path = os.path.join(root, file)
        rel_path = os.path.relpath(path, lib_dir)
        
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Find LinearGradient
        matches = re.finditer(r'LinearGradient\s*\([^)]+colors:\s*\[([^\]]+)\]', content)
        for match in matches:
            colors = match.group(1).strip()
            # If the gradient already uses AppColors extensively, skip if it's already clean
            if 'AppColors' in colors and 'Colors.' not in colors and 'Color(' not in colors:
                # Might be a clean role gradient
                if 'Primary' in colors and 'Secondary' in colors:
                    continue
            results.append({
                'path': rel_path,
                'gradient_colors': re.sub(r'\s+', ' ', colors)
            })

report = ["# Gradient Audit Results\n"]
for r in results:
    report.append(f"File: {r['path']}\nColors: {r['gradient_colors']}\n")

with open(os.path.join(os.environ.get('TEMP', ''), 'gradients.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(report))
