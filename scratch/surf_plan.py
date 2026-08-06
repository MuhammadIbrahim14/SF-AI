import json, os, re
from collections import defaultdict

with open(os.path.join(os.environ.get('TEMP', ''), 'surface_colors.json'), 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

modifications = defaultdict(list)

# Files to explicitly ignore
ignore_files = ['app_colors.dart', 'app_theme.dart', 'app_typography.dart', 'auth_cinematic_screen.dart', 'home_hero_screen.dart', 'animated_theme_switcher.dart', 'exam_active_screen.dart', 'student_grand_test_overview_screen.dart', 'teacher_grand_tests_screen.dart', 'mcq']

color_map = {
    '0xFF121A2E': 'AppColors.card',
    '0xFF1A2540': 'AppColors.cardLight',
    '0xFF18233D': 'AppColors.elevatedSurface',
    '0xFF0A0F1F': 'AppColors.background',
    '0xFF030712': 'AppColors.background',
    '0xFF161616': 'AppColors.card',
    '0xFFF9FAFB': 'AppColors.lightCardLight',
    '0xFFF3F4F6': 'AppColors.lightBackground',
    '0xFFE5E7EB': 'AppColors.lightCardBorder',
    '0xFFB0B8CD': 'AppColors.textSecondary',
    '0xFF6B7494': 'AppColors.textTertiary',
    '0xFF0F172A': 'AppColors.lightTextPrimary',
    '0xFF334155': 'AppColors.lightTextSecondary',
    '0xFF000000': 'AppColors.background' # if surface
}

for item in data:
    path = item['Path'].split('lib\\\\')[-1]
    
    if any(ign in path.lower() for ign in ignore_files):
        continue
        
    line = item['Line'].strip()
    
    # Exclude complex effects explicitly listed
    if re.search(r'(gradient|overlay|shadow|blur|glass|painter)', line, re.I):
        continue
    
    # Check for hardcoded hex colors
    hex_matches = re.findall(r'Color\((0xFF[0-9A-Fa-f]{6})\)', line)
    
    # Check for Colors.white and Colors.black 
    material_matches = re.findall(r'(Colors\.(white|black|grey)(?:54|38|12|26|70)?)(?![a-zA-Z])', line)
    
    context = line.lower()
    
    for match in hex_matches:
        match_upper = match.upper()
        if match_upper in color_map:
            modifications[path].append(f"Line {item['LineNumber']}: Replace `Color({match_upper})` with `{color_map[match_upper]}` (Context: `{line}`)")

    for match_tuple in material_matches:
        full_match = match_tuple[0]
        base_color = match_tuple[1]
        
        replacement = ""
        # Prefer Theme context if possible
        if 'textstyle' in context and 'color:' in context:
            if 'white' in base_color:
                if '54' in full_match or '70' in full_match:
                    replacement = "AppColors.textSecondary"
                elif '38' in full_match:
                    replacement = "AppColors.textTertiary"
                else:
                    replacement = "AppColors.textPrimary"
            elif 'black' in base_color:
                if '54' in full_match or '70' in full_match:
                    replacement = "AppColors.lightTextSecondary"
                else:
                    replacement = "AppColors.lightTextPrimary"
            elif 'grey' in base_color:
                replacement = "AppColors.textSecondary" # approximate
                
        elif 'color:' in context and ('container' in context or 'boxdecoration' in context or 'card' in context or 'background' in context):
            if 'white' in base_color:
                if 'withopacity' in context or 'withvalues' in context: continue # let it be
                replacement = "AppColors.lightCard"
            elif 'black' in base_color:
                if 'withopacity' in context or 'withvalues' in context: continue # often overlay
                replacement = "AppColors.card"
        
        if replacement:
             # Just roughly suggest it
             modifications[path].append(f"Line {item['LineNumber']}: Replace `{full_match}` with `{replacement}` (Context: `{line}`)")

plan = ["# Phase 5C: Surface & Text Color Cleanup\n"]

for path, changes in modifications.items():
    if not changes: continue
    plan.append(f"### `{path}`")
    seen = set()
    for ch in changes:
        ch_str = re.sub(r'Line \d+: ', '', ch)
        if ch_str not in seen:
            plan.append(f"- {ch}")
            seen.add(ch_str)
    plan.append("")

with open(os.path.join(os.environ.get('TEMP', ''), 'surface_plan.md'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(plan))
