import os
import re

lib_dir = "lib"

# Patterns
color_pattern = re.compile(r'Color\(\s*0x[0-9a-fA-F]{8}\s*\)|Colors\.[a-zA-Z]+(?:\.withOpacity\(.*?\))?|Colors\.[a-zA-Z]+\[[0-9]+\]')
spacing_pattern = re.compile(r'(SizedBox\(.*?height:\s*|SizedBox\(.*?width:\s*|EdgeInsets\.(?:all|symmetric|only)\([^)]*)([0-9]+(?:\.[0-9]+)?)\)')
radius_pattern = re.compile(r'(BorderRadius\.circular\(|Radius\.circular\()([0-9]+(?:\.[0-9]+)?)\)')
route_push_pattern = re.compile(r'(context\.push|context\.go|context\.pushReplacement)(Named)?\s*\(\s*\'(.*?)\'')

issues = []

# Exclusions
color_exempt = ["app_theme.dart", "app_colors.dart"]

known_routes = set()
called_routes = set()

for root, _, files in os.walk(lib_dir):
    for file in files:
        if not file.endswith(".dart"):
            continue
            
        path = os.path.join(root, file)
        with open(path, "r", encoding="utf-8") as f:
            try:
                content = f.read()
                lines = content.split('\n')
            except:
                continue
                
        # Build Routes
        if 'GoRoute(' in content:
            # find name: '...'
            names = re.findall(r'name:\s*\'(.*?)\'', content)
            known_routes.update(names)
            
        # Called Routes
        for match in route_push_pattern.finditer(content):
            route_name = match.group(3)
            # ignore parameters or paths for now, just track what we can
            if match.group(2) == 'Named':
                called_routes.add(route_name)
                
        # Performance Risks
        if 'AnimationController' in content and 'dispose()' not in content:
            issues.append(("Performance", "Missing dispose() for AnimationController", path))
            
        if 'BackdropFilter' in content and 'RepaintBoundary' not in content:
            issues.append(("Performance", "BackdropFilter without RepaintBoundary (High risk of jank)", path))
            
        # Security Risks
        if 'GoRoute(' in content and 'redirect:' not in content and 'admin' in file.lower():
            issues.append(("Security", "Admin route without explicit redirect/guard inside the route definition", path))
            
        # Hardcoded colors
        if file not in color_exempt and not file.endswith('.g.dart') and not file.endswith('.freezed.dart'):
            for i, line in enumerate(lines):
                # Ignore comments
                if line.strip().startswith('//'):
                    continue
                # Colors
                for c_match in color_pattern.finditer(line):
                    col = c_match.group(0)
                    if "Colors.transparent" not in col and "Colors.white" not in col and "Colors.black" not in col:
                        issues.append(("Design System", f"Hardcoded color: {col}", f"{path}:{i+1}"))

# Print report
print("=== FINAL QA AUDIT REPORT ===")
print(f"Total Issues Found: {len(issues)}")
print("\n--- Routes ---")
missing_routes = called_routes - known_routes
if missing_routes:
    print(f"Warning: Routes called but not defined by name: {missing_routes}")

print("\n--- Top Issues ---")
for cat, desc, loc in issues[:100]:
    print(f"[{cat}] {loc} - {desc}")
