import os
import re
from collections import defaultdict

def generate_spacing_radius_audit(lib_dir, output_file):
    total_spacing = 0
    total_radius = 0
    
    files_count = defaultdict(lambda: {'spacing': 0, 'radius': 0, 'total': 0})
    
    spacing_violations = []
    radius_violations = []
    
    # Excludes
    exclude_files = ['app_theme.dart', 'app_colors.dart', 'app_typography.dart']
    
    # Regex patterns
    spacing_pattern = re.compile(r'(SizedBox\((?:height|width):\s*([\d.]+)\)|EdgeInsets\.(?:all|symmetric|only)\([^)]*\)|padding:\s*EdgeInsets|margin:\s*EdgeInsets)')
    radius_pattern = re.compile(r'(BorderRadius\.circular\(([\d.]+)\)|Radius\.circular\(([\d.]+)\)|RoundedRectangleBorder|BoxDecoration\(\s*borderRadius)')
    
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'): continue
            if any(exc in file for exc in exclude_files): continue
            
            path = os.path.join(root, file)
            rel_path = os.path.relpath(path, lib_dir)
            
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            lines = content.split('\n')
            
            for i, line in enumerate(lines):
                line_num = i + 1
                
                # Check spacing
                for s_match in spacing_pattern.finditer(line):
                    total_spacing += 1
                    files_count[rel_path]['spacing'] += 1
                    files_count[rel_path]['total'] += 1
                    
                    val = s_match.group(2) if s_match.group(2) else "EdgeInsets"
                    risk = "SAFE"
                    
                    if any(x in rel_path for x in ['mcq', 'exam', 'grand_test']): risk = "HIGH"
                    elif 'auth' in rel_path or 'home' in rel_path or 'theme_switcher' in rel_path: risk = "HIGH"
                    elif 'painter' in line.lower() or 'custompainter' in line.lower(): risk = "HIGH"
                    elif 'dialog' in rel_path or 'form' in rel_path: risk = "MEDIUM"
                    
                    if len(spacing_violations) < 200:  # Sample to avoid huge memory
                        spacing_violations.append({
                            'file': rel_path,
                            'value': val,
                            'usage': line.strip()[:100],
                            'risk': risk
                        })

                # Check radius
                for r_match in radius_pattern.finditer(line):
                    total_radius += 1
                    files_count[rel_path]['radius'] += 1
                    files_count[rel_path]['total'] += 1
                    
                    val = r_match.group(2) if r_match.group(2) else (r_match.group(3) if r_match.group(3) else "BorderRadius")
                    risk = "SAFE"
                    
                    if any(x in rel_path for x in ['mcq', 'exam', 'grand_test']): risk = "HIGH"
                    elif 'auth' in rel_path or 'home' in rel_path or 'theme_switcher' in rel_path: risk = "HIGH"
                    elif 'dialog' in rel_path or 'form' in rel_path: risk = "MEDIUM"
                    
                    if len(radius_violations) < 200:
                        radius_violations.append({
                            'file': rel_path,
                            'value': val,
                            'usage': line.strip()[:100],
                            'risk': risk
                        })

    # Sort files by total
    sorted_files = sorted(files_count.items(), key=lambda x: x[1]['total'], reverse=True)
    
    report = []
    report.append("# Phase 6: Spacing + Radius Audit Report\n")
    report.append("## 1. Executive Summary")
    report.append(f"- **Total hardcoded spacing found:** {total_spacing}")
    report.append(f"- **Total hardcoded radius found:** {total_radius}")
    report.append("- **Top affected files:**")
    for f, counts in sorted_files[:10]:
        report.append(f"  - `{f}`: {counts['total']} usages ({counts['spacing']} spacing, {counts['radius']} radius)")
        
    report.append("\n## 2. Spacing Violations (Sample)")
    for v in spacing_violations[:50]:
        report.append(f"- **File:** `{v['file']}`\n  - **Current Value:** `{v['value']}`\n  - **Usage:** `{v['usage']}`\n  - **Recommended:** `AppSpacing.x`\n  - **Risk Level:** {v['risk']}")
        
    report.append("\n## 3. Radius Violations (Sample)")
    for v in radius_violations[:50]:
        report.append(f"- **File:** `{v['file']}`\n  - **Current Value:** `{v['value']}`\n  - **Usage:** `{v['usage']}`\n  - **Recommended:** `AppRadius.x`\n  - **Risk Level:** {v['risk']}")
        
    report.append("\n## 4. Acceptable Exceptions")
    report.append("- Very small icon spacing (e.g., `SizedBox(width: 4)` inside a dense row).")
    report.append("- Precise animation offset constraints.")
    report.append("- Custom painter geometry (explicit pixel math).")
    report.append("- Chart geometry overlays.")
    report.append("- Exam layout constraints where standard tokens would break strict readability flow.")
    
    report.append("\n## 5. Risk Classification")
    report.append("- **SAFE:** Cards, padding, simple sections, buttons.")
    report.append("- **MEDIUM:** Forms, dialogs, responsive grids.")
    report.append("- **HIGH:** Custom painters, auth cinematic UI, home hero effects, exam screens, animated theme switcher.")
    
    report.append("\n## 6. Recommended Fix Phases")
    report.append("- **Phase 6A:** Safe spacing token migration")
    report.append("- **Phase 6B:** Safe radius token migration")
    report.append("- **Phase 6C:** Forms/dialogs spacing cleanup")
    report.append("- **Phase 6D:** High-risk layout review")
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(report))

if __name__ == "__main__":
    lib_path = os.path.join(os.environ.get('cwd', '.'), 'lib')
    out_path = os.path.join(os.environ.get('TEMP', ''), 'spacing_audit_report.md')
    generate_spacing_radius_audit(lib_path, out_path)
    print("Done")
