import json, os, re
from collections import defaultdict

with open(os.path.join(os.environ.get('TEMP', ''), 'dashboards.json'), 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

modifications = defaultdict(list)

for item in data:
    path = item['Path'].split('lib\\\\')[-1]
    line = item['Line'].strip()
    
    if 'transparent' in line.lower() or 'white' in line.lower() or 'black' in line.lower() or 'divider' in line.lower(): continue
    if 'background' in line.lower() or 'surface' in line.lower() or 'shadow' in line.lower() or 'gradient' in line.lower() or 'textstyle' in line.lower(): continue
    
    matches = re.findall(r'(Colors\.[a-zA-Z]+|AppColors\.[a-zA-Z]+)', line)
    
    replacement = ""
    # Rule 2: Metric Colors
    if 'Courses' in line:
        if 'student' in path: replacement = "AppColors.studentPrimary"
        elif 'teacher' in path: replacement = "AppColors.teacherPrimary"
        elif 'company' in path: replacement = "AppColors.companyPrimary"
        elif 'freelancer' in path: replacement = "AppColors.freelancerPrimary"
        elif 'admin' in path: replacement = "AppColors.adminPrimary"
    elif 'Lessons' in line: replacement = "AppColors.info"
    elif 'Assignments' in line: replacement = "AppColors.warning"
    elif 'Projects' in line: replacement = "AppColors.accent"
    elif 'Grand Tests' in line: replacement = "AppColors.secondary"
    elif 'Certificates' in line: replacement = "AppColors.warning"
    elif 'Jobs' in line: replacement = "AppColors.companyPrimary"
    elif 'Applications' in line: replacement = "AppColors.info"
    elif 'Interviews' in line: replacement = "AppColors.accent"
    elif 'Total Users' in line or 'Students' in line or 'Teachers' in line or 'Freelancers' in line or 'Companies' in line or 'Users' in line: 
        if 'Total Users' in line: replacement = "AppColors.info"
        elif 'Students' in line: replacement = "AppColors.studentPrimary"
        elif 'Teachers' in line: replacement = "AppColors.teacherPrimary"
        elif 'Freelancers' in line: replacement = "AppColors.freelancerPrimary"
        elif 'Companies' in line: replacement = "AppColors.companyPrimary"
    elif 'Verifications' in line: replacement = "AppColors.success"
    elif 'Banned Users' in line: replacement = "AppColors.error"
    elif 'maintenanceActive' in line: 
        if 'orange' in line.lower(): replacement = "AppColors.warning"
        # don't replace Colors.redAccent for maintenance if it's correct logic
        
    for color in matches:
        if color.startswith('AppColors.'): continue
        if replacement:
            modifications[path].append(f"Line {item['LineNumber']}: Replace `{color}` with `{replacement}` (Context: `{line}`)")

report = ["# Phase 5B: Dashboard Color Standardization\n"]
for path, changes in modifications.items():
    if not changes: continue
    report.append(f"### {path}")
    for change in changes:
        report.append(f"- {change}")

with open(os.path.join(os.environ.get('TEMP', ''), 'dash_plan.md'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(report))
