import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'firebase_providers.dart';

final companyPermissionProvider = FutureProvider<CompanyPermissionState>((
  ref,
) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) return CompanyPermissionState.signedOut;

  final firestore = ref.watch(firestoreProvider);
  final userDoc = await firestore.collection('users').doc(authState.uid).get();
  final userData = userDoc.data() ?? const <String, dynamic>{};
  final userStatus = (userData['status']?.toString() ?? 'active')
      .trim()
      .toLowerCase();
  final role = (userData['primaryRole']?.toString() ?? '').trim().toLowerCase();

  if (role != 'company') {
    return CompanyPermissionState(
      userId: authState.uid,
      userStatus: userStatus,
      verificationStatus: '',
      isCompany: false,
    );
  }

  final companyDoc = await firestore
      .collection('companies')
      .doc(authState.uid)
      .get();
  final companyData = companyDoc.data() ?? const <String, dynamic>{};
  final verificationStatus =
      (companyData['verificationStatus']?.toString() ?? 'pending')
          .trim()
          .toLowerCase();

  return CompanyPermissionState(
    userId: authState.uid,
    userStatus: userStatus,
    verificationStatus: verificationStatus,
    isCompany: true,
  );
});

class CompanyPermissionState {
  const CompanyPermissionState({
    required this.userId,
    required this.userStatus,
    required this.verificationStatus,
    required this.isCompany,
  });

  final String userId;
  final String userStatus;
  final String verificationStatus;
  final bool isCompany;

  bool get isActiveAccount => userStatus == 'active';
  bool get isApproved =>
      verificationStatus == 'approved' || verificationStatus == 'verified';
  bool get isPending =>
      verificationStatus.isEmpty || verificationStatus == 'pending';
  bool get isRejected => verificationStatus == 'rejected';
  bool get isSuspended => userStatus == 'suspended' || userStatus == 'banned';

  bool get canEditCompanyProfile => isCompany && isActiveAccount;
  bool get canCreateJob => isCompany && isActiveAccount && isApproved;
  bool get canEditJob => canCreateJob;
  bool get canDeleteJob => canCreateJob;
  bool get canViewApplicants => canCreateJob;
  bool get canScheduleInterview => canCreateJob;
  bool get canEvaluateInterview => canCreateJob;
  bool get canHire => canCreateJob;
  bool get canReject => canCreateJob;
  bool get canAccessAnalytics => canCreateJob;
  bool get canDownloadReports => false;

  String get normalizedVerificationStatus {
    if (verificationStatus.isEmpty) return 'pending';
    return verificationStatus;
  }

  String get restrictionMessage {
    if (!isCompany) {
      return 'Only company accounts can perform this action.';
    }
    if (isSuspended) {
      return 'This company account is suspended and cannot perform hiring actions.';
    }
    if (isPending) {
      return 'Company verification is pending. Hiring actions unlock after admin approval.';
    }
    if (isRejected) {
      return 'Company verification was rejected. Update your company profile and request review again.';
    }
    if (!isApproved) {
      return 'Company verification is required before performing hiring actions.';
    }
    return 'This action is not available for the current company status.';
  }

  void ensureCanManageHiring() {
    if (!canCreateJob) {
      throw StateError(restrictionMessage);
    }
  }

  static const signedOut = CompanyPermissionState(
    userId: '',
    userStatus: 'signed_out',
    verificationStatus: '',
    isCompany: false,
  );
}
