import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/admin_repository.dart';
import '../repositories/admin_repository_impl.dart';
import '../repositories/application_repository.dart';
import '../repositories/application_repository_impl.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/company_repository.dart';
import '../repositories/company_repository_impl.dart';
import '../repositories/freelancer_repository.dart';
import '../repositories/freelancer_repository_impl.dart';
import '../repositories/job_repository.dart';
import '../repositories/job_repository_impl.dart';
import '../repositories/interview_repository.dart';
import '../repositories/interview_repository_impl.dart';
import '../repositories/notification_repository.dart';
import '../repositories/notification_repository_impl.dart';
import '../repositories/student_repository.dart';
import '../repositories/student_repository_impl.dart';
import '../repositories/teacher_repository.dart';
import '../repositories/teacher_repository_impl.dart';
import '../repositories/user_repository.dart';
import '../repositories/user_repository_impl.dart';
import 'firebase_providers.dart';

/// SkillForge AI — Repository Providers
/// Provides repository implementations with proper dependency injection.

/// Provides [AuthRepository] backed by Firebase Auth.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firebaseAuthProvider));
});

/// Provides [UserRepository] backed by Cloud Firestore.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [StudentRepository] backed by Cloud Firestore.
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [TeacherRepository] backed by Cloud Firestore.
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [FreelancerRepository] backed by Cloud Firestore.
final freelancerRepositoryProvider = Provider<FreelancerRepository>((ref) {
  return FreelancerRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [CompanyRepository] backed by Cloud Firestore.
final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [JobRepository] backed by Cloud Firestore.
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [InterviewRepository] backed by Cloud Firestore.
final interviewRepositoryProvider = Provider<InterviewRepository>((ref) {
  return InterviewRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [ApplicationRepository] backed by Cloud Firestore.
final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [NotificationRepository] backed by Cloud Firestore.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(firestoreProvider));
});

/// Provides [AdminRepository] backed by Cloud Firestore.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(ref.watch(firestoreProvider));
});
