import json
import re
import os
from collections import defaultdict

with open(os.path.join(os.environ.get('TEMP', ''), 'color_audit.json'), 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

# Categories
total_found = len(data)
violation_candidates = 0
acceptable_usages = 0
files_count = defaultdict(int)

raw_colors = defaultdict(int)
raw_colors_files = defaultdict(set)

role_violations = []
semantic_violations = []
surface_violations = []
gradient_violations = []

for item in data:
    line = item['Line'].strip()
    path = item['Path']
    # Skip AppColors and AppTheme
    if 'app_colors.dart' in path or 'app_theme.dart' in path or 'app_typography.dart' in path:
        continue

    files_count[path] += 1
    
    # Extract raw colors
    colors_found = re.findall(r'(Colors\.[a-zA-Z]+|Color\(0x[0-9A-Fa-f]+\))', line)
    
    is_acceptable = False
    if 'Colors.transparent' in line:
        is_acceptable = True
        acceptable_usages += 1
    
    if not is_acceptable:
        violation_candidates += 1
        
    for c in colors_found:
        raw_colors[c] += 1
        raw_colors_files[c].add(path)
        
    # Heuristics for categorization
    lower_path = path.lower()
    
    # Semantic: success/error/warning
    if re.search(r'(error|fail|success|warning|alert|snack)', lower_path) or re.search(r'(error|fail|success|warning)', line.lower()):
        if len(semantic_violations) < 10:
            semantic_violations.append({
                'path': path.split('lib\\')[-1] if 'lib\\' in path else path,
                'color': colors_found[0] if colors_found else 'unknown',
                'line': line,
                'recommend': 'AppColors.error/success/warning'
            })
            
    # Roles
    elif re.search(r'(student|teacher|freelancer|company|admin|super_admin)', lower_path):
        if len(role_violations) < 10:
            role = 'unknown'
            if 'student' in lower_path: role = 'AppColors.studentPrimary'
            elif 'teacher' in lower_path: role = 'AppColors.teacherPrimary'
            elif 'company' in lower_path: role = 'AppColors.companyPrimary'
            elif 'freelancer' in lower_path: role = 'AppColors.freelancerPrimary'
            elif 'super_admin' in lower_path: role = 'AppColors.superAdminPrimary'
            elif 'admin' in lower_path: role = 'AppColors.adminPrimary'
            
            role_violations.append({
                'path': path.split('lib\\')[-1] if 'lib\\' in path else path,
                'color': colors_found[0] if colors_found else 'unknown',
                'line': line,
                'recommend': role
            })
            
    # Surface/Text
    elif 'background' in line.lower() or 'color: isDark' in line or 'color: Theme' in line or 'TextStyle' in line:
        if len(surface_violations) < 10:
            surface_violations.append({
                'path': path.split('lib\\')[-1] if 'lib\\' in path else path,
                'color': colors_found[0] if colors_found else 'unknown',
                'line': line,
                'recommend': 'AppColors.surface/background or textPrimary'
            })
            
    # Gradients
    if 'LinearGradient' in line or 'RadialGradient' in line:
        if len(gradient_violations) < 10:
            gradient_violations.append({
                'path': path.split('lib\\')[-1] if 'lib\\' in path else path,
                'color': str(colors_found),
                'line': line,
                'recommend': 'AppColors gradient tokens'
            })

# Top 10 files
top_files = sorted(files_count.items(), key=lambda x: x[1], reverse=True)[:10]

report = []
report.append("# Hardcoded Color Audit Report\n")
report.append("## 1. Executive Summary")
report.append(f"- **Total hardcoded colors found:** {total_found}")
report.append(f"- **Total violation candidates:** {violation_candidates}")
report.append(f"- **Total acceptable usages:** {acceptable_usages}")
report.append("\n### Top 10 Most Affected Files")
for f, count in top_files:
    short_f = f.split('lib\\')[-1] if 'lib\\' in f else f
    report.append(f"- `{short_f}`: {count} usages")

report.append("\n## 2. Hardcoded Role Color Violations")
report.append("*(Sample of identified violations)*")
for v in role_violations:
    report.append(f"- **File:** `{v['path']}`\n  - **Color Used:** `{v['color']}`\n  - **Context:** `{v['line'].strip()}`\n  - **Recommended Token:** `{v['recommend']}`\n  - **Risk Level:** SAFE TO FIX FIRST")

report.append("\n## 3. Hardcoded Semantic Color Violations")
report.append("*(Sample of identified violations)*")
for v in semantic_violations:
    report.append(f"- **File:** `{v['path']}`\n  - **Color Used:** `{v['color']}`\n  - **Context:** `{v['line'].strip()}`\n  - **Recommended Token:** `{v['recommend']}`\n  - **Risk Level:** SAFE TO FIX FIRST")

report.append("\n## 4. Hardcoded Surface/Text Violations")
report.append("*(Sample of identified violations)*")
for v in surface_violations:
    report.append(f"- **File:** `{v['path']}`\n  - **Color Used:** `{v['color']}`\n  - **Context:** `{v['line'].strip()}`\n  - **Recommended Token:** `{v['recommend']}`\n  - **Risk Level:** MEDIUM RISK")

report.append("\n## 5. Hardcoded Gradient Violations")
report.append("*(Sample of identified violations)*")
for v in gradient_violations:
    report.append(f"- **File:** `{v['path']}`\n  - **Colors Used:** `{v['color']}`\n  - **Context:** `{v['line'].strip()}`\n  - **Recommended Token:** `{v['recommend']}`\n  - **Action:** Convert to shared AppColors gradient unless custom hero effect.")

report.append("\n## 6. Raw Material Colors Report")
for color, count in sorted(raw_colors.items(), key=lambda x: x[1], reverse=True)[:15]:
    files = list(raw_colors_files[color])[:3]
    short_files = [f.split('lib\\')[-1] if 'lib\\' in f else f for f in files]
    report.append(f"### `{color}`")
    report.append(f"- **Count:** {count}")
    report.append(f"- **Top Files:** {', '.join(short_files)}...")
    if 'transparent' in color.lower():
        report.append("- **Rule:** Acceptable if used for invisible overlays/borders. Needs review if excessive.")
    elif 'white' in color.lower() or 'black' in color.lower():
        report.append("- **Rule:** Medium risk. Replace with `AppColors.textPrimary`/`textSecondary` or surface colors unless explicitly required for dark-mode overrides.")
    else:
        report.append("- **Rule:** High risk violation. Must map to semantic, role, or action color tokens.")

report.append("\n## 7. Acceptable Exceptions")
report.append("- `Colors.transparent` for invisible overlays, border removal, and ink splashes.")
report.append("- `Colors.white` inside icons or text when placed on fixed-dark hero backgrounds or cinematic UI.")
report.append("- `Colors.black` inside overlays/shadows if opacity requires true black regardless of theme.")
report.append("\n*Note: Flag as “needs review” if usage exceeds normal bounds.*")

report.append("\n## 8. Risk Classification")
report.append("""
**SAFE TO FIX FIRST:**
- Simple role colors
- Simple semantic colors
- Badge colors

**MEDIUM RISK:**
- Cards and surfaces
- Gradients
- Text colors

**HIGH RISK:**
- Theme switcher
- Auth cinematic UI
- Home screen hero effects
- Custom painters
- Charts
- Overlays
- Exam screens
""")

report.append("\n## 9. Recommended Fix Phases")
report.append("- **Phase 5A** — Safe Role/Semantic Color Fixes")
report.append("- **Phase 5B** — Dashboard Color Standardization")
report.append("- **Phase 5C** — Surface/Text Color Cleanup")
report.append("- **Phase 5D** — Gradient Cleanup")
report.append("- **Phase 5E** — High-Risk Visual Effects Review")

report.append("\n## 10. Files to Avoid For Now")
report.append("""
*Modifications in these files are risky due to highly custom visual behaviors:*
- `lib/features/auth/presentation/auth_cinematic_screen.dart` (cinematic UI)
- `lib/features/home/presentation/home_hero_screen.dart` (visual effects)
- `lib/shared/widgets/animated_theme_switcher.dart` (theme transition)
- `lib/features/exams/presentation/exam_active_screen.dart` (strict UI constraints)
- Files with CustomPainters or Canvas operations
""")

with open(os.path.join(os.environ.get('TEMP', ''), 'report.md'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(report))
