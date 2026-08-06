import 'package:flutter/material.dart';

import '../../../models/user_role.dart';
import '../../../shared/widgets/role_edit_profile_form.dart';

class CompanyEditProfileScreen extends StatelessWidget {
  const CompanyEditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleEditProfileForm(role: UserRole.company);
  }
}
