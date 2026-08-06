import os

def remove_line(file_path, target_string):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    with open(file_path, 'w', encoding='utf-8') as f:
        for line in lines:
            if target_string not in line:
                f.write(line)

login = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\features\auth\presentation\login_screen.dart'
scaffold = r'd:\Ibrahim Work\2nd Aptech Vision (SkillForge AI) 2026\Project\lib\shared\widgets\premium_auth_scaffold.dart'

remove_line(login, "import 'dart:math';")
remove_line(login, "import 'dart:ui';")
remove_line(login, "import '../../../shared/widgets/loading_overlay.dart';")
remove_line(scaffold, "import '../../core/theme/app_colors.dart';")
