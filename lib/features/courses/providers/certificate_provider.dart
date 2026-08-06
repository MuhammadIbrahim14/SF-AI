import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../core/utils/app_logger.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../data/models/certificate_model.dart';
import '../data/repositories/certificate_repository.dart';
import 'enrollment_provider.dart';

final certificateRepositoryProvider = Provider<CertificateRepository>((ref) {
  return FirestoreCertificateRepository(ref.watch(firestoreProvider));
});

final studentCertificatesProvider = StreamProvider<List<CertificateModel>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <CertificateModel>[]);
  return ref
      .watch(certificateRepositoryProvider)
      .watchStudentCertificates(user.uid);
});

final courseCertificatesProvider =
    StreamProvider.family<List<CertificateModel>, String>((ref, courseId) {
      return ref
          .watch(certificateRepositoryProvider)
          .watchCourseCertificates(courseId);
    });

final certificateDetailProvider =
    StreamProvider.family<CertificateModel?, String>((ref, certificateId) {
      return ref
          .watch(certificateRepositoryProvider)
          .watchCertificate(certificateId);
    });

final certificateEligibilityProvider =
    FutureProvider.family<
      CertificateEligibilityResult,
      ({String courseId, String studentId})
    >((ref, args) {
      ref.watch(courseEnrollmentsProvider(args.courseId));
      return ref
          .watch(certificateRepositoryProvider)
          .checkEligibility(courseId: args.courseId, studentId: args.studentId);
    });

final certificateActionProvider =
    AsyncNotifierProvider<CertificateActionNotifier, void>(
      CertificateActionNotifier.new,
    );

class CertificateActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> issueCertificate({
    required String courseId,
    required String studentId,
    required String certificateType,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in teacher is required.');
      final issued = await ref
          .read(certificateRepositoryProvider)
          .issueCertificate(
            courseId: courseId,
            studentId: studentId,
            certificateType: certificateType,
            issuedBy: user.uid,
          );
      await _notifyCertificateIssued(
        courseId: courseId,
        studentId: studentId,
        teacherId: user.uid,
        certificate: issued,
      );
    });
    return !state.hasError;
  }

  Future<bool> revokeCertificate({
    required String certificateId,
    required String reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final teacherId = ref.read(authRepositoryProvider).currentUser?.uid;
      final certificate = await ref
          .read(certificateRepositoryProvider)
          .watchCertificate(certificateId)
          .first;
      if (certificate == null) {
        throw StateError('Certificate not found.');
      }
      await ref
          .read(certificateRepositoryProvider)
          .revokeCertificate(certificateId: certificateId, reason: reason);
      await _notifyCertificateRevoked(
        certificate: certificate,
        reason: reason,
        teacherId: teacherId,
      );
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();

  Future<void> _notifyCertificateIssued({
    required String courseId,
    required String studentId,
    required String teacherId,
    required CertificateModel certificate,
  }) async {
    try {
      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      final certTitle = certificate.title.trim().isEmpty
          ? 'a certificate'
          : '"${certificate.title.trim()}"';
      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: studentId,
        title: 'Certificate issued',
        body: 'You earned $certTitle.',
        category: NotificationCategories.learning,
        event: NotificationEvents.learningCertificateIssued,
        actorId: teacherId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: 'certificates/${certificate.certificateId}',
        routeName: RouteNames.studentCertificateDetail,
        routeParams: {'certificateId': certificate.certificateId},
        meta: {
          'courseId': courseId,
          'certificateId': certificate.certificateId,
          'certificateType': certificate.certificateType,
          'courseTitle': certificate.courseTitle,
        },
      );
    } catch (_) {
      AppLogger.warn('Certificate issued notification could not be sent.');
    }
  }

  Future<void> _notifyCertificateRevoked({
    required CertificateModel certificate,
    required String reason,
    String? teacherId,
  }) async {
    try {
      final studentId = certificate.studentId.trim();
      if (studentId.isEmpty) return;

      final actorName =
          (ref.read(currentUserProvider).value?.fullName ?? '').trim();
      final certTitle = certificate.title.trim().isEmpty
          ? 'a certificate'
          : '"${certificate.title.trim()}"';
      final trimmedReason = reason.trim();
      final body = trimmedReason.isEmpty
          ? 'Your certificate $certTitle was revoked.'
          : 'Your certificate $certTitle was revoked: $trimmedReason';

      await ref.read(notificationServiceProvider).notifyOne(
        recipientId: studentId,
        title: 'Certificate revoked',
        body: body,
        category: NotificationCategories.learning,
        event: NotificationEvents.learningCertificateRevoked,
        actorId: teacherId,
        actorName: actorName.isEmpty ? null : actorName,
        actorRole: 'teacher',
        relatedPath: 'certificates/${certificate.certificateId}',
        routeName: RouteNames.studentCertificateDetail,
        routeParams: {'certificateId': certificate.certificateId},
        meta: {
          'courseId': certificate.courseId,
          'certificateId': certificate.certificateId,
          'certificateType': certificate.certificateType,
          'courseTitle': certificate.courseTitle,
          if (trimmedReason.isNotEmpty) 'reason': trimmedReason,
        },
      );
    } catch (_) {
      AppLogger.warn('Certificate revoked notification could not be sent.');
    }
  }
}
