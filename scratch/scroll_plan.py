import os
import re

files = [
    r"lib\features\auth\presentation\forgot_password_screen.dart",
    r"lib\features\auth\presentation\login_screen.dart",
    r"lib\features\auth\presentation\signup_screen.dart",
    r"lib\features\courses\presentation\course_detail_screen.dart",
    r"lib\features\courses\presentation\student_assignments_screen.dart",
    r"lib\features\legal\presentation\account_deletion_policy_screen.dart",
    r"lib\features\legal\presentation\privacy_policy_screen.dart",
    r"lib\features\legal\presentation\terms_of_service_screen.dart",
    r"lib\features\onboarding\presentation\role_selection_screen.dart",
    r"lib\features\profile\presentation\preference_settings_screen.dart",
    r"lib\features\profile\presentation\security_settings_screen.dart"
]

def check_structure(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Very crude check: find index of SingleChildScrollView, then see if Expanded appears before its closing paren.
    # To do this right, we need bracket matching.
    
    def find_closing_paren(text, start_idx):
        count = 0
        for i in range(start_idx, len(text)):
            if text[i] == '(': count += 1
            elif text[i] == ')':
                count -= 1
                if count == 0: return i
        return -1

    idx = 0
    while True:
        idx = content.find('SingleChildScrollView(', idx)
        if idx == -1: break
        
        close_idx = find_closing_paren(content, idx + len('SingleChildScrollView') )
        if close_idx != -1:
            snippet = content[idx:close_idx]
            if 'Expanded(' in snippet:
                print(f"[{filepath}] Expanded is INSIDE SingleChildScrollView!")
                # Print the Expanded line
                lines = snippet.split('\n')
                for i, l in enumerate(lines):
                    if 'Expanded(' in l:
                        print(f"   -> {l.strip()}")
            else:
                pass
                # print(f"[{filepath}] SingleChildScrollView does not contain Expanded.")
        
        idx += 1

for f in files:
    check_structure(f)
print("Done")
