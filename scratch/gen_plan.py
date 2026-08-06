import json, os, re
from collections import defaultdict

with open(os.path.join(os.environ.get('TEMP', ''), 'safe_colors.json'), 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

modifications = defaultdict(list)

# Define safe patterns
safe_colors = r'Colors\.(green|orange|blue|purple|cyan|amber|redAccent|red|success|error|warning|info|primary)'

for item in data:
    path = item['Path']
    if any(ignore in path for ignore in ['app_colors.dart', 'app_theme.dart', 'app_typography.dart', 'auth_cinematic_screen', 'home_hero_screen', 'animated_theme_switcher', 'exam_active_screen']):
        continue
    
    line = item['Line'].strip()
    
    # Exclude complex things (backgrounds, text, gradients, shadows, surfaces)
    if re.search(r'(background|gradient|shadow|surface|elevation|textstyle|canvas|painter)', line, re.I):
        continue
        
    matches = re.findall(safe_colors, line)
    if not matches:
        continue
        
    for color in matches:
        color = color.lower()
        replacement = ""
        context_lower = line.lower() + " " + path.lower()
        
        # Determine replacement based on context
        if 'student' in context_lower and color in ['blue', 'primary']:
            replacement = 'AppColors.studentPrimary'
        elif 'teacher' in context_lower and color in ['purple', 'primary']:
            replacement = 'AppColors.teacherPrimary'
        elif 'freelancer' in context_lower and color in ['cyan', 'primary']:
            replacement = 'AppColors.freelancerPrimary'
        elif 'company' in context_lower and color in ['green', 'primary']:
            replacement = 'AppColors.companyPrimary'
        elif 'admin' in context_lower and 'super' not in context_lower and color in ['red', 'redaccent', 'primary']:
            # Be careful with red and admin vs error
            if 'error' in context_lower or 'fail' in context_lower or 'warning' in context_lower or 'delete' in context_lower:
                replacement = 'AppColors.error'
            else:
                replacement = 'AppColors.adminPrimary'
        elif 'super_admin' in context_lower and color in ['purple', 'primary']:
             replacement = 'AppColors.superAdminPrimary'
        
        # Semantic mapping if role is not strictly matched or semantic implies heavily
        if not replacement:
             if color in ['green', 'success']: replacement = 'AppColors.success'
             elif color in ['orange', 'amber', 'warning']: replacement = 'AppColors.warning'
             elif color in ['redaccent', 'red', 'error']: replacement = 'AppColors.error'
             elif color in ['blue', 'info']: replacement = 'AppColors.info'
        
        if replacement:
            modifications[path].append({
                'original': f"Colors.{item['Line'].split('Colors.')[1].split()[0].split(',')[0].split(')')[0]}", # naive extraction
                'replacement': replacement,
                'line': line
            })

report = []
report.append("# Phase 5A: Safe Role + Semantic Color Fixes\n")
report.append("This plan outlines the minimal, safe token replacements for role identities and semantic statuses across the application.\n")
report.append("## Proposed Changes\n")

for path, changes in sorted(modifications.items()):
    short_path = path.split('lib\\')[-1] if 'lib\\' in path else path
    report.append(f"### `lib/{short_path}`")
    seen_changes = set()
    for change in changes:
        chg_str = f"- Replace `{change['original']}` with `{change['replacement']}`"
        if chg_str not in seen_changes:
            report.append(chg_str)
            seen_changes.add(chg_str)
    report.append("")

report.append("## User Review Required")
report.append("> [!WARNING]")
report.append("> Please review the proposed replacements to ensure they align with the design intent.")
report.append("> Only safe tokens (Icon colors, simple chips/badges) are targeted. Backgrounds, surfaces, and complex UI elements have been specifically excluded.")

with open(os.path.join(os.environ.get('TEMP', ''), 'impl_plan.md'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(report))
