import os, re

files = [
    'lib/features/student/presentation/student_dashboard.dart',
    'lib/features/teacher/presentation/teacher_dashboard.dart',
    'lib/features/company/presentation/company_dashboard.dart',
    'lib/features/freelancer/presentation/freelancer_dashboard.dart',
    'lib/features/admin/presentation/admin_dashboard.dart',
    'lib/features/admin/presentation/super_admin_dashboard.dart',
]

rules = {
    'student': {
        'role': 'AppColors.studentPrimary',
        'metrics': {
            'courses': 'AppColors.studentPrimary',
            'lessons': 'AppColors.info',
            'assignments': 'AppColors.warning',
            'projects': 'AppColors.accent',
            'grand tests': 'AppColors.secondary',
            'certificates': 'AppColors.warning',
        }
    },
    'teacher': {
        'role': 'AppColors.teacherPrimary',
        'metrics': {
            'courses': 'AppColors.teacherPrimary',
            'lessons': 'AppColors.info',
            'assignments': 'AppColors.warning',
            'projects': 'AppColors.accent',
            'grand tests': 'AppColors.secondary',
            'certificates': 'AppColors.warning',
            'revenue': 'AppColors.success',
            'students': 'AppColors.info'
        }
    },
    'company': {
        'role': 'AppColors.companyPrimary',
        'metrics': {
            'jobs': 'AppColors.companyPrimary',
            'applications': 'AppColors.info',
            'interviews': 'AppColors.accent',
        }
    },
    'freelancer': {
        'role': 'AppColors.freelancerPrimary',
        'metrics': {
            'jobs': 'AppColors.companyPrimary',
            'applications': 'AppColors.info',
            'projects': 'AppColors.accent',
            'revenue': 'AppColors.success'
        }
    },
    'admin': {
        'role': 'AppColors.adminPrimary',
        'metrics': {
            'total users': 'AppColors.info',
            'users': 'AppColors.info',
            'verifications': 'AppColors.success',
            'system health': 'AppColors.success',
            'critical': 'AppColors.error',
            'errors': 'AppColors.error'
        }
    },
    'super_admin': {
        'role': 'AppColors.superAdminPrimary',
        'metrics': {
            'total users': 'AppColors.info',
            'users': 'AppColors.info',
            'verifications': 'AppColors.success',
            'system health': 'AppColors.success',
            'critical': 'AppColors.error',
            'errors': 'AppColors.error'
        }
    }
}

plan = ["# Phase 5B: Dashboard Color Standardization\n"]

for file in files:
    full_path = os.path.join(os.environ.get('cwd', '.'), file.replace('/', '\\'))
    if not os.path.exists(full_path):
        continue
        
    role_type = ''
    if 'student' in file: role_type = 'student'
    elif 'teacher' in file: role_type = 'teacher'
    elif 'company' in file: role_type = 'company'
    elif 'freelancer' in file: role_type = 'freelancer'
    elif 'super_admin' in file: role_type = 'super_admin'
    elif 'admin' in file: role_type = 'admin'
    
    with open(full_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    changes = []
    
    for i, line in enumerate(lines):
        line_num = i + 1
        
        # Look for AppColors or Colors
        matches = re.findall(r'(AppColors\.[a-zA-Z]+|Colors\.[a-zA-Z]+)', line)
        if not matches: continue
        
        lower_line = line.lower()
        if 'transparent' in lower_line or 'white' in lower_line or 'black' in lower_line or 'divider' in lower_line: continue
        if 'background' in lower_line or 'surface' in lower_line or 'shadow' in lower_line or 'gradient' in lower_line or 'textstyle' in lower_line: continue
        
        for match in matches:
            replacement = ''
            
            # Contextual replacement based on metrics
            if 'courses' in lower_line and 'student' not in lower_line: replacement = rules[role_type]['metrics'].get('courses', rules[role_type]['role'])
            elif 'lessons' in lower_line: replacement = 'AppColors.info'
            elif 'assignments' in lower_line: replacement = 'AppColors.warning'
            elif 'projects' in lower_line: replacement = 'AppColors.accent'
            elif 'grand tests' in lower_line: replacement = 'AppColors.secondary'
            elif 'certificates' in lower_line: replacement = 'AppColors.warning'
            elif 'jobs' in lower_line: replacement = 'AppColors.companyPrimary'
            elif 'applications' in lower_line: replacement = 'AppColors.info'
            elif 'interviews' in lower_line: replacement = 'AppColors.accent'
            elif 'total users' in lower_line or 'students' in lower_line or 'teachers' in lower_line or 'freelancers' in lower_line or 'companies' in lower_line:
                if 'total users' in lower_line: replacement = 'AppColors.info'
                elif 'students' in lower_line: replacement = 'AppColors.studentPrimary'
                elif 'teachers' in lower_line: replacement = 'AppColors.teacherPrimary'
                elif 'freelancers' in lower_line: replacement = 'AppColors.freelancerPrimary'
                elif 'companies' in lower_line: replacement = 'AppColors.companyPrimary'
            elif 'verifications' in lower_line: replacement = 'AppColors.success'
            elif 'banned' in lower_line: replacement = 'AppColors.error'
            elif 'revenue' in lower_line or 'earnings' in lower_line: replacement = 'AppColors.success'
            else:
                # Replace generic dashboard accents (AppColors.primary) with role primary
                if match == 'AppColors.primary' or match == 'Colors.blue' or match == 'Colors.purple' or match == 'Colors.green' or match == 'AppColors.primaryLight':
                    replacement = rules[role_type]['role']
                
            if replacement and match != replacement:
                changes.append(f"Line {line_num}: Replace `{match}` with `{replacement}` (Context: `{line.strip()}`)")
                
    if changes:
        plan.append(f"### `{file}`")
        # remove duplicate messages to prevent huge logs
        seen = set()
        for ch in changes:
            ch_str = re.sub(r'Line \d+: ', '', ch)
            if ch_str not in seen:
                plan.append(f"- {ch}")
                seen.add(ch_str)
        plan.append("")

with open(os.path.join(os.environ.get('TEMP', ''), 'dash_plan_v2.md'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(plan))
