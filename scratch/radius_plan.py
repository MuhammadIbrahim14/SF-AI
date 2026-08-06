import os
import re
from collections import defaultdict

def generate_radius_plan(lib_dir):
    token_map = {
        '8': 'AppTheme.radiusSm',
        '8.0': 'AppTheme.radiusSm',
        '12': 'AppTheme.radiusMd',
        '12.0': 'AppTheme.radiusMd',
        '16': 'AppTheme.radiusLg',
        '16.0': 'AppTheme.radiusLg',
        '24': 'AppTheme.radiusXl',
        '24.0': 'AppTheme.radiusXl',
        '32': 'AppTheme.radiusXxl',
        '32.0': 'AppTheme.radiusXxl'
    }

    files_to_update = defaultdict(list)
    skipped_files = set()
    
    # Excludes
    exclude_files = ['app_theme.dart', 'app_colors.dart', 'app_typography.dart']
    high_risk_files = ['mcq', 'exam', 'grand_test', 'auth', 'home', 'theme_switcher']
    
    # Simple patterns: BorderRadius.circular(X), Radius.circular(X)
    radius_pattern = re.compile(r'(BorderRadius\.circular\(\s*([\d.]+)\s*\)|Radius\.circular\(\s*([\d.]+)\s*\))')
    
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'): continue
            if any(exc in file for exc in exclude_files): continue
            
            path = os.path.join(root, file)
            rel_path = os.path.relpath(path, lib_dir)
            
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            has_theme_import = 'app_theme.dart' in content
            
            if any(hr in rel_path.lower() for hr in high_risk_files):
                skipped_files.add(rel_path)
                continue
                
            if 'CustomPainter' in content or 'AnimationController' in content:
                skipped_files.add(rel_path)
                continue
                
            if not has_theme_import:
                continue

            lines = content.split('\n')
            
            for i, line in enumerate(lines):
                line_num = i + 1
                
                # Check radius
                for r_match in radius_pattern.finditer(line):
                    full_match = r_match.group(1)
                    val = r_match.group(2) if r_match.group(2) else r_match.group(3)
                    
                    if val in token_map:
                        replacement = full_match.replace(val, token_map[val])
                        files_to_update[rel_path].append(f"- Replace `{full_match}` with `{replacement}` (Line {line_num})")

    report = []
    report.append("# Phase 6B: Safe Radius Token Migration\n")
    report.append("## Proposed Changes")
    
    # Remove duplicates
    for file, changes in files_to_update.items():
        report.append(f"### `lib/{file}`")
        seen = set()
        for ch in changes:
            if ch not in seen:
                report.append(ch)
                seen.add(ch)
        report.append("")
        
    report.append("## Intentionally Skipped Files (High Risk or Missing Imports)")
    for f in sorted(list(skipped_files))[:20]:
        report.append(f"- `lib/{f}`")
    report.append("- *(and other high risk or missing import files)*")
        
    with open(os.path.join(os.environ.get('TEMP', ''), 'radius_plan.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(report))

if __name__ == '__main__':
    generate_radius_plan(os.path.join(os.environ.get('cwd', '.'), 'lib'))
    print("Done")
