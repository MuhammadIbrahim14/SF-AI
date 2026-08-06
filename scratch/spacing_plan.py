import os
import re
from collections import defaultdict

def generate_spacing_plan(lib_dir):
    token_map = {
        '4': 'AppTheme.spacingXs',
        '4.0': 'AppTheme.spacingXs',
        '8': 'AppTheme.spacingSm',
        '8.0': 'AppTheme.spacingSm',
        '16': 'AppTheme.spacingMd',
        '16.0': 'AppTheme.spacingMd',
        '24': 'AppTheme.spacingLg',
        '24.0': 'AppTheme.spacingLg',
        '32': 'AppTheme.spacingXl',
        '32.0': 'AppTheme.spacingXl',
        '48': 'AppTheme.spacingXxl',
        '48.0': 'AppTheme.spacingXxl'
    }

    files_to_update = defaultdict(list)
    skipped_files = set()
    
    # Excludes
    exclude_files = ['app_theme.dart', 'app_colors.dart', 'app_typography.dart']
    high_risk_files = ['mcq', 'exam', 'grand_test', 'auth', 'home', 'theme_switcher']
    
    # Simple patterns: SizedBox(height: X), SizedBox(width: X), EdgeInsets.all(X)
    spacing_pattern = re.compile(r'(SizedBox\((?:height|width):\s*([\d.]+)\)|EdgeInsets\.(all)\(\s*([\d.]+)\)|EdgeInsets\.(symmetric)\([^)]*\)|EdgeInsets\.(only)\([^)]*\))')
    
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'): continue
            if any(exc in file for exc in exclude_files): continue
            
            path = os.path.join(root, file)
            rel_path = os.path.relpath(path, lib_dir)
            
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # If the file does not already import app_theme, we skip it to avoid massive import conflicts
            # Wait, the rule says: "If replacing would require adding new imports to too many files: only fix files that already import AppTheme or theme utilities."
            has_theme_import = 'app_theme.dart' in content
            
            if any(hr in rel_path.lower() for hr in high_risk_files):
                skipped_files.add(rel_path)
                continue
                
            if 'CustomPainter' in content or 'AnimationController' in content:
                skipped_files.add(rel_path)
                continue
                
            if not has_theme_import:
                # To be completely safe and avoid massive import conflicts, we skip files without AppTheme imports
                # unless they have obvious safe replacements and we just add one import. But the rule says "only fix files that already import AppTheme"
                continue

            lines = content.split('\n')
            
            for i, line in enumerate(lines):
                line_num = i + 1
                
                # Check spacing
                for s_match in spacing_pattern.finditer(line):
                    full_match = s_match.group(0)
                    
                    # Manual regex parsing
                    replacements = []
                    
                    # 1. SizedBox
                    m = re.search(r'SizedBox\((height|width):\s*([\d.]+)\)', full_match)
                    if m:
                        val = m.group(2)
                        if val in token_map:
                            replacements.append((full_match, full_match.replace(val, token_map[val])))
                            
                    # 2. EdgeInsets.all
                    m = re.search(r'EdgeInsets\.all\(\s*([\d.]+)\)', full_match)
                    if m:
                        val = m.group(1)
                        if val in token_map:
                            replacements.append((full_match, full_match.replace(val, token_map[val])))
                    
                    # 3. EdgeInsets.symmetric
                    m = re.search(r'EdgeInsets\.symmetric\([^)]*\)', full_match)
                    if m:
                        sym_match = m.group(0)
                        vals = re.findall(r'(?:horizontal|vertical):\s*([\d.]+)', sym_match)
                        new_sym = sym_match
                        replaced = False
                        for val in vals:
                            if val in token_map:
                                # regex replace the exact value in this attribute
                                new_sym = re.sub(r'(horizontal|vertical):\s*' + re.escape(val) + r'([^0-9.])', r'\1: ' + token_map[val] + r'\2', new_sym)
                                replaced = True
                        if replaced:
                            replacements.append((sym_match, new_sym))
                            
                    # 4. EdgeInsets.only
                    m = re.search(r'EdgeInsets\.only\([^)]*\)', full_match)
                    if m:
                        only_match = m.group(0)
                        vals = re.findall(r'(?:left|right|top|bottom):\s*([\d.]+)', only_match)
                        new_only = only_match
                        replaced = False
                        for val in vals:
                            if val in token_map:
                                new_only = re.sub(r'(left|right|top|bottom):\s*' + re.escape(val) + r'([^0-9.])', r'\1: ' + token_map[val] + r'\2', new_only)
                                replaced = True
                        if replaced:
                            replacements.append((only_match, new_only))

                    for orig, rep in replacements:
                        if orig != rep:
                            files_to_update[rel_path].append(f"- Replace `{orig}` with `{rep}` (Line {line_num})")

    report = []
    report.append("# Phase 6A: Safe Spacing Token Migration\n")
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
        
    with open(os.path.join(os.environ.get('TEMP', ''), 'spacing_plan.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(report))

if __name__ == '__main__':
    generate_spacing_plan(os.path.join(os.environ.get('cwd', '.'), 'lib'))
    print("Done")
