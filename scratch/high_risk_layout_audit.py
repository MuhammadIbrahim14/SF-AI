import os
import re
from collections import defaultdict

def generate_layout_audit(lib_dir):
    critical_risks = []
    medium_risks = []
    safe_files = []
    do_not_auto_fix = set()
    
    # Target high-risk files based on prompt
    target_files = [
        "login_screen.dart", "signup_screen.dart", "forgot_password_screen.dart",
        "home_screen.dart", "splash_screen.dart", "app_onboarding_screen.dart",
        "role_selection_screen.dart", "animated_theme_switcher.dart",
        "mcq_attempt_screen.dart", "grand_test_attempt_screen.dart",
        "student_grand_test_overview_screen.dart", "grand_test_result_screen.dart"
    ]
    
    # General risks to search for
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'): continue
            
            path = os.path.join(root, file)
            rel_path = os.path.relpath(path, lib_dir)
            
            is_target = any(t in file for t in target_files)
            
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # If it's a target file, it's definitely on the do-not-auto-fix list
            if is_target:
                do_not_auto_fix.add(rel_path)
                
            if 'CustomPainter' in content or 'AnimationController' in content or 'BackdropFilter' in content:
                do_not_auto_fix.add(rel_path)
                
            # --- Analyzers ---
            file_risks = []
            
            # 1. Overflow Risk
            # Looking for simple Rows that might not have Flexible/Expanded children
            if 'Row(' in content and 'Expanded(' not in content and 'Flexible(' not in content and 'Wrap(' not in content:
                file_risks.append(("Overflow Risk", "Row used without Flexible/Expanded or Wrap, potential overflow on small screens.", "MEDIUM"))
            
            # 2. Scroll Risk
            if 'SingleChildScrollView(' in content and 'Expanded(' in content:
                file_risks.append(("Scroll Risk", "Expanded inside SingleChildScrollView throws unbounded height exception.", "CRITICAL"))
            
            if 'GridView' in content and 'shrinkWrap: true' not in content and ('SingleChildScrollView' in content or 'ListView' in content):
                file_risks.append(("Scroll Risk", "GridView inside scroll view without shrinkWrap: true causes infinite height.", "CRITICAL"))
                
            if 'ListView' in content and 'Column(' in content and 'Expanded(' not in content and 'shrinkWrap: true' not in content:
                file_risks.append(("Scroll Risk", "ListView inside Column without Expanded or shrinkWrap.", "MEDIUM"))

            # 3. Animation Risk
            if 'AnimationController(' in content and 'dispose()' not in content:
                file_risks.append(("Animation Risk", "AnimationController created but dispose() not found.", "CRITICAL"))

            # 4. Performance Risk
            if content.count('BackdropFilter') > 1:
                file_risks.append(("Performance Risk", "Multiple BackdropFilters detected. Heavy blur passes.", "MEDIUM"))
                
            # 5. Form / Keyboard Risk
            if 'Form(' in content and 'SingleChildScrollView(' not in content and 'ListView(' not in content:
                file_risks.append(("Keyboard Risk", "Form not wrapped in a scrollable view. Keyboard may cover inputs.", "CRITICAL"))

            # Categorize
            if file_risks:
                if is_target:
                    do_not_auto_fix.add(rel_path)
                
                for risk_type, reason, level in file_risks:
                    if level == "CRITICAL":
                        critical_risks.append((rel_path, risk_type, reason, "Phase 7" + ("A" if "Overflow" in risk_type else ("B" if "Scroll" in risk_type else ("E" if "Keyboard" in risk_type else "C")))))
                    else:
                        medium_risks.append((rel_path, risk_type, reason, "Phase 7" + ("A" if "Overflow" in risk_type else ("B" if "Scroll" in risk_type else ("C" if "Performance" in risk_type else "D")))))
            else:
                if is_target:
                    safe_files.append(rel_path + " (But complex visual layout)")
                elif 'Form(' in content or 'ListView' in content:
                    safe_files.append(rel_path)

    # Generate Report
    report = []
    report.append("# Phase 6D: High-Risk Layout Review Report\n")
    report.append("## 1. Executive Summary")
    report.append(f"- **Total critical risks:** {len(critical_risks)}")
    report.append(f"- **Total medium risks:** {len(medium_risks)}")
    report.append(f"- **Total do-not-auto-fix files:** {len(do_not_auto_fix)}")
    report.append(f"- **Total safe/no-action files (sampled):** {len(safe_files)}\n")

    report.append("## 2. Critical Risk Files")
    for file, rtype, reason, phase in critical_risks[:30]:
        report.append(f"### `lib/{file}`")
        report.append(f"- **Risk Type:** {rtype}")
        report.append(f"- **Reason:** {reason}")
        report.append(f"- **Recommended Fix:** {phase}\n")

    report.append("## 3. Medium Risk Files")
    for file, rtype, reason, phase in medium_risks[:30]:
        report.append(f"### `lib/{file}`")
        report.append(f"- **Risk Type:** {rtype}")
        report.append(f"- **Reason:** {reason}")
        report.append(f"- **Recommended Fix:** {phase}\n")

    report.append("## 4. Safe Files (Sample)")
    for sf in safe_files[:15]:
        report.append(f"- `lib/{sf}`")
        
    report.append("\n## 5. Do Not Auto-Fix List")
    for daf in sorted(list(do_not_auto_fix))[:40]:
        report.append(f"- `lib/{daf}`")
        
    report.append("\n## 6. Manual Review Required")
    report.append("These screens need manual visual testing on Android (360/430px), tablet (768px), desktop (1200px), and Windows:")
    for tf in target_files:
        report.append(f"- `{tf}`")
        
    report.append("\n## 7. Recommended Next Fix Phases")
    report.append("- **Phase 7A** — Critical Overflow Fixes")
    report.append("- **Phase 7B** — Critical Scroll Fixes")
    report.append("- **Phase 7C** — Animation Performance Fixes")
    report.append("- **Phase 7D** — Light/Dark Contrast Fixes")
    report.append("- **Phase 7E** — Keyboard Safety Fixes")

    with open(os.path.join(os.environ.get('TEMP', ''), 'high_risk_layout_report.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(report))

if __name__ == '__main__':
    generate_layout_audit(os.path.join(os.environ.get('cwd', '.'), 'lib'))
    print("Done")
