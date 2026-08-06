import 'package:go_router/go_router.dart';
import 'package:skillforge_ai/features/admin/sie/admin_sie_route_mapper.dart';
import 'package:skillforge_ai/features/company/sie/company_sie_route_mapper.dart';
import 'package:skillforge_ai/features/freelancer/sie/freelancer_sie_route_mapper.dart';
import 'package:skillforge_ai/features/student/sie/student_sie_route_mapper.dart';
import 'package:skillforge_ai/features/teacher/sie/teacher_sie_route_mapper.dart';

/// Resolves GoRouter location → SIE route id for any production module.
///
/// Prefer [resolveFromRouter] from [MaterialApp.builder] (no context lookup).
abstract final class SieAppRouteResolver {
  /// Maps a [GoRouter] instance's current state to a SIE catalog route id.
  static String? resolveFromRouter(GoRouter router) {
    final state = router.state;
    return resolve(
      location: state.uri.toString(),
      routeName: state.name,
    );
  }

  /// Maps location + optional route name to SIE catalog route id.
  static String? resolve({
    required String location,
    String? routeName,
  }) {
    if (AdminSieRouteMapper.isAdminLocation(location)) {
      return AdminSieRouteMapper.resolve(
        location: location,
        routeName: routeName,
      );
    }
    if (CompanySieRouteMapper.isCompanyLocation(location)) {
      return CompanySieRouteMapper.resolve(
        location: location,
        routeName: routeName,
      );
    }
    if (FreelancerSieRouteMapper.isFreelancerLocation(location)) {
      return FreelancerSieRouteMapper.resolve(
        location: location,
        routeName: routeName,
      );
    }
    if (TeacherSieRouteMapper.isTeacherLocation(location)) {
      return TeacherSieRouteMapper.resolve(
        location: location,
        routeName: routeName,
      );
    }
    if (StudentSieRouteMapper.isStudentLocation(location)) {
      return StudentSieRouteMapper.resolve(
        location: location,
        routeName: routeName,
      );
    }
    return null;
  }
}
