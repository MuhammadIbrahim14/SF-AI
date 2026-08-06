import os

def remove_line(file_path, target_string):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    with open(file_path, 'w', encoding='utf-8') as f:
        for line in lines:
            if target_string not in line:
                f.write(line)

fp = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\forgot_password_screen.dart'
su = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\signup_screen.dart'

remove_line(fp, "import 'dart:math';")
remove_line(fp, "import 'dart:ui';")
remove_line(su, "import 'dart:math';")
remove_line(su, "import 'dart:ui';")
remove_line(su, "import '../../../shared/widgets/loading_overlay.dart';")
