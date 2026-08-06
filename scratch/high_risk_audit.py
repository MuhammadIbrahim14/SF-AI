import os
import re

def analyze_visual_effects(lib_dir):
    report_lines = []
    report_lines.append("# Phase 5E: High-Risk Visual Effects Audit Report\n")
    
    high_risk_files = []
    performance_risks = []
    
    # Files explicitly mentioned to inspect
    target_files = [
        "splash_screen.dart",
        "home_screen.dart",
        "login_screen.dart",
        "signup_screen.dart",
        "forgot_password_screen.dart",
        "animated_theme_switcher.dart",
        "mcq_attempt_screen.dart",
        "grand_test_attempt_screen.dart"
    ]
    
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith(".dart"): continue
            
            path = os.path.join(root, file)
            rel_path = os.path.relpath(path, lib_dir)
            
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            risk_reasons = []
            risk_level = "LOW"
            is_target = any(t in file for t in target_files)
            
            # 1. CustomPainters
            if "extends CustomPainter" in content:
                painters = re.findall(r'class\s+(\w+)\s+extends\s+CustomPainter', content)
                risk_reasons.append(f"CustomPainter(s): {', '.join(painters)}")
                risk_level = "HIGH" if "HIGH" not in risk_level else risk_level
                performance_risks.append(f"- **{rel_path}**: Uses CustomPainter `{', '.join(painters)}`. Modifying colors may break light/dark mode visibility.")
            
            # 2. AnimationControllers
            if "AnimationController" in content:
                controllers = len(re.findall(r'AnimationController\(', content))
                if controllers > 0:
                    risk_reasons.append(f"{controllers} AnimationController(s)")
                    risk_level = "CRITICAL" if controllers > 2 else ("HIGH" if controllers > 0 else risk_level)
                    if controllers > 2:
                        performance_risks.append(f"- **{rel_path}**: Heavy animation logic ({controllers} controllers). High risk of jank if gradients/colors are blindly standardized.")
            
            # 3. BackdropFilters (Glassmorphism)
            if "BackdropFilter" in content:
                filters = len(re.findall(r'BackdropFilter', content))
                risk_reasons.append(f"BackdropFilter ({filters} instances)")
                if risk_level not in ["CRITICAL", "HIGH"]: risk_level = "MEDIUM"
                performance_risks.append(f"- **{rel_path}**: Uses BackdropFilter. Ensure white/black opacities are preserved for glassmorphism frosting.")
            
            # 4. Cinematic Background Hexes
            cinematic_hexes = ['0xFF040810', '0xFF0A0F1F', '0xFF0E142A', '0xFF060A18', '0xFF5B7CFF']
            found_hexes = [h for h in cinematic_hexes if h in content]
            if found_hexes:
                risk_reasons.append(f"Cinematic Colors: {', '.join(found_hexes)}")
                risk_level = "CRITICAL"
                
            if risk_reasons or is_target:
                if not risk_reasons:
                    risk_reasons.append("Strict UI constraints / Complex UI")
                    risk_level = "MEDIUM"
                high_risk_files.append(f"| `{rel_path}` | {', '.join(risk_reasons)} | **{risk_level}** |")

    report_lines.append("## 1. High-Risk File List\n")
    report_lines.append("| File Path | Visual Effect Type / Triggers | Risk Level |")
    report_lines.append("| :--- | :--- | :--- |")
    report_lines.extend(sorted(high_risk_files))
    
    report_lines.append("\n## 2. Hardcoded Colors That Should Stay")
    report_lines.append("- **Splash/Role Selection Backgrounds:** `Color(0xFF040810)`, `Color(0xFF0A0F1F)`, `Color(0xFF0E142A)` (Deep space cinematic void).")
    report_lines.append("- **Theme Switcher:** `Color(0xFF5B7CFF)` (Tied directly to wave morphing).")
    report_lines.append("- **Glassmorphism Overlays:** `Colors.black.withValues(...)` and `Colors.white.withValues(...)` used inside BackdropFilter.")
    
    report_lines.append("\n## 3. Hardcoded Colors That Should Be Reviewed Later")
    report_lines.append("- **Glows and DropShadows:** Generic static colors used in `BoxShadow` for glowing orbs in `home_screen.dart`.")
    report_lines.append("- **Glassmorphism Base Layers:** Static backgrounds backing a `BackdropFilter` might need specific light/dark adjustments.")

    report_lines.append("\n## 4. Performance Risks")
    report_lines.extend(performance_risks)

    report_lines.append("\n## 5. Safe Recommendations")
    report_lines.append("- `features/onboarding/presentation/splash_screen.dart`: **Leave unchanged**")
    report_lines.append("- `features/home/presentation/home_screen.dart`: **Leave unchanged**")
    report_lines.append("- Auth Screens (`login_screen.dart`, `signup_screen.dart`): **Leave unchanged**")
    report_lines.append("- `shared/widgets/animated_theme_switcher.dart`: **Leave unchanged**")
    report_lines.append("- Exam Screens (`mcq_attempt_screen.dart`, `grand_test_attempt_screen.dart`): **Review manually** to ensure color standardization doesn't break readability constraints.")

    with open(os.path.join(os.environ.get('TEMP', ''), 'phase5e_report.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(report_lines))

if __name__ == '__main__':
    lib_path = os.path.join(os.environ.get('cwd', '.'), 'lib')
    analyze_visual_effects(lib_path)
    print(f"Report generated at TEMP\\phase5e_report.md")
