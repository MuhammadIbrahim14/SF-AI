import os
import re

path = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\shared\widgets\premium_auth_scaffold.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if "import 'cinematic_background.dart';" not in content:
    content = content.replace("import 'theme_orb_button.dart';", "import 'theme_orb_button.dart';\nimport 'cinematic_background.dart';")

# Replace MeshGradient and BackdropFilter with CinematicBackground
mesh_pattern = r'          // Adaptive Mesh Gradient Background.*?// Main Content'
cinematic_replacement = """          // Cinematic Background
          Positioned.fill(
            child: CinematicBackground(particlesEnabled: true),
          ),

          // Main Content"""

content = re.sub(mesh_pattern, cinematic_replacement, content, flags=re.DOTALL)

# Remove _MeshGradientPainter class
mesh_class_pattern = r'class _MeshGradientPainter extends CustomPainter \{.*?\}\n'
content = re.sub(mesh_class_pattern, '', content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
