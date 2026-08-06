import os
import re

def audit_contrast(lib_dir):
    report = []
    
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'):
                continue
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()

            issues = []
            
            # Look for Colors.white inside TextStyle not conditionally bound to theme
            white_text_matches = re.finditer(r'TextStyle\([^)]*color:\s*Colors\.white[^)]*\)', content)
            for m in white_text_matches:
                # heuristic: if there's no isDark check nearby, it might be an issue.
                snippet = content[max(0, m.start() - 200):m.end() + 200]
                if 'isDark' not in snippet and 'primary' not in snippet and 'accent' not in snippet:
                    issues.append(f"Colors.white text without isDark check: {m.group(0)}")

            # Look for Colors.black inside TextStyle
            black_text_matches = re.finditer(r'TextStyle\([^)]*color:\s*Colors\.black[^)]*\)', content)
            for m in black_text_matches:
                snippet = content[max(0, m.start() - 200):m.end() + 200]
                if 'isDark' not in snippet:
                    issues.append(f"Colors.black text without isDark check: {m.group(0)}")
            
            # Look for unreadable borders (alpha < 0.1 in light mode is invisible)
            # Actually, Border.all(color: colorScheme.outline.withValues(alpha: 0.05))
            border_matches = re.finditer(r'Border\.all\([^)]*alpha:\s*0\.0[1-9][^)]*\)', content)
            for m in border_matches:
                issues.append(f"Very low alpha border: {m.group(0)}")

            if issues:
                report.append(f"### `{path.replace(lib_dir, 'lib')}`")
                for issue in issues:
                    report.append(f"- {issue}")

    with open('scratch/contrast_audit_report.md', 'w', encoding='utf-8') as f:
        f.write("\n".join(report))

audit_contrast(r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib')
print("Audit complete.")
