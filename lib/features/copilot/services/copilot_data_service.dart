import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_logger.dart';
import '../../../models/user_model.dart';
import '../models/copilot_data_summary_model.dart';
import '../models/copilot_intent_model.dart';
import 'copilot_route_catalog.dart';

class CopilotDataService {
  CopilotDataService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<CopilotDataSummaryModel> resolve({
    required CopilotIntentModel intent,
    required UserModel? user,
  }) async {
    if (user == null) {
      return _unauthorized('Please sign in first to read workspace data.');
    }

    try {
      switch (intent.type) {
        case CopilotIntentType.getWalletBalance:
          return _walletSummary(user);
        case CopilotIntentType.getCustomerOrderSummary:
          return _ordersSummary(
            title: 'Customer Orders',
            field: 'clientId',
            userId: user.uid,
            routeId: 'customerOrders',
          );
        case CopilotIntentType.getCustomerResolutionSummary:
          return _resolutionSummary(
            title: 'Customer Resolution Cases',
            fields: const ['clientId', 'requestedBy', 'openedBy'],
            userId: user.uid,
            routeId: 'customerResolution',
          );
        case CopilotIntentType.getFreelancerOrderSummary:
          return _ordersSummary(
            title: 'Freelancer Orders',
            field: 'freelancerId',
            userId: user.uid,
            routeId: 'freelancerOrders',
          );
        case CopilotIntentType.getFreelancerServiceRequestSummary:
          return _serviceRequestSummary(user.uid);
        case CopilotIntentType.getFreelancerPayoutSummary:
          return _payoutSummary(user.uid);
        case CopilotIntentType.getFreelancerResolutionSummary:
          return _resolutionSummary(
            title: 'Freelancer Resolution Cases',
            fields: const ['freelancerId', 'requestedBy', 'openedBy'],
            userId: user.uid,
            routeId: 'freelancerResolution',
          );
        case CopilotIntentType.getAdminResolutionSummary:
          return _adminCollectionSummary(
            title: 'Admin Resolution Desk',
            collection: 'resolutionCases',
            statusField: 'status',
            routeId: 'adminResolutionDesk',
          );
        case CopilotIntentType.getAdminPayoutSummary:
          return _adminCollectionSummary(
            title: 'Admin Payout Queue',
            collection: 'payouts',
            statusField: 'status',
            routeId: 'adminPayouts',
          );
        case CopilotIntentType.getSettlementBackendStatus:
          return _settlementBackendSummary();
        case CopilotIntentType.getTeacherCourseSummary:
          return _teacherCourseSummary(user.uid);
        case CopilotIntentType.getTeacherCertificateSummary:
          return _teacherCertificateSummary(user.uid);
        case CopilotIntentType.getTeacherStudentProgressSummary:
          return _unavailable(
            'Student Progress',
            'Student progress is available on the Teacher Student Progress screen. Copilot is not reading the full cross-course analytics table yet because that view joins several private collections.',
            routeId: 'teacherStudentProgress',
          );
        case CopilotIntentType.getCompanyJobSummary:
          return _companyJobSummary(user.uid);
        case CopilotIntentType.getCompanyApplicationsSummary:
          return _companyApplicationSummary(user.uid);
        case CopilotIntentType.getCompanyHiringSummary:
          return _companyApplicationSummary(user.uid, title: 'Hiring Summary');
        case CopilotIntentType.getMyRole:
          return _myRoleSummary(user);
        case CopilotIntentType.getDashboardSummary:
          return _dashboardSummary(user);
        case CopilotIntentType.getProfileSummary:
          return _profileSummary(user);
        default:
          return _unavailable(
            'Copilot Data',
            'I can answer safe workspace summaries like wallet balance, orders, requests, payouts, courses, jobs, and resolution cases.',
          );
      }
    } on FirebaseException {
      AppLogger.warn('Copilot data read was blocked by Firestore.');
      return _unavailable(
        'Data unavailable',
        'I could not read that safely right now. If this keeps happening, the related Firestore rule or index may need review.',
      );
    } catch (_) {
      AppLogger.warn('Copilot data read failed.');
      return _unavailable(
        'Data unavailable',
        'Something went wrong while reading that summary. Your data was not changed.',
      );
    }
  }

  Future<CopilotDataSummaryModel> _walletSummary(UserModel user) async {
    final isCustomer = user.isCustomerAccount;
    final collection = isCustomer ? 'customerWallets' : 'freelancerWallets';
    final doc = await _firestore.collection(collection).doc(user.uid).get();
    if (!doc.exists) {
      return _unavailable(
        'Wallet Balance',
        'No wallet has been initialized for this account yet.',
        routeId: isCustomer ? 'customerWallet' : 'freelancerWallet',
      );
    }
    final data = doc.data() ?? const <String, dynamic>{};
    final currency = _string(data['currency'], 'USD');
    final available = _number(data['availableBalance']);
    final pending = _number(data['pendingBalance']);
    final escrow = _number(data['escrowBalance']);
    final pendingPayout = _number(data['pendingPayoutBalance']);
    final spent = _number(data['totalSpent']);
    final refunded = _number(data['totalRefunded']);
    final lifetime = _number(data['lifetimeEarnings']);
    final routeId = isCustomer ? 'customerWallet' : 'freelancerWallet';
    final extra = isCustomer
        ? 'Spent: ${_money(spent, currency)}. Refunded: ${_money(refunded, currency)}.'
        : 'Pending: ${_money(pending, currency)}. Escrow: ${_money(escrow, currency)}. Pending payout: ${_money(pendingPayout, currency)}.';
    return _ready(
      'Wallet Balance',
      'Available balance is ${_money(available, currency)}. $extra',
      routeId: routeId,
      facts: {
        'availableBalance': available,
        'pendingBalance': pending,
        'escrowBalance': escrow,
        'pendingPayoutBalance': pendingPayout,
        'lifetimeEarnings': lifetime,
        'currency': currency,
      },
    );
  }

  Future<CopilotDataSummaryModel> _ordersSummary({
    required String title,
    required String field,
    required String userId,
    required String routeId,
  }) async {
    final docs = await _queryByField('serviceOrders', field, userId);
    final counts = _countByStatus(docs, 'orderStatus');
    final total = docs.length;
    final active =
        (counts['active'] ?? 0) +
        (counts['inProgress'] ?? 0) +
        (counts['accepted'] ?? 0);
    final pending = counts['pending'] ?? 0;
    final delivered = counts['delivered'] ?? 0;
    final completed = counts['completed'] ?? 0;
    return _ready(
      title,
      '$total orders found. Active: $active. Pending: $pending. Delivered: $delivered. Completed: $completed.',
      routeId: routeId,
      facts: counts,
    );
  }

  Future<CopilotDataSummaryModel> _serviceRequestSummary(String userId) async {
    final docs = await _queryByField('serviceRequests', 'freelancerId', userId);
    final counts = _countByStatus(docs, 'status');
    final pending = counts['pending'] ?? 0;
    final active =
        (counts['accepted'] ?? 0) +
        (counts['inProgress'] ?? 0) +
        (counts['delivered'] ?? 0);
    final completed = counts['completed'] ?? 0;
    return _ready(
      'Service Requests',
      '${docs.length} service requests found. Pending: $pending. Active: $active. Completed: $completed.',
      routeId: 'freelancerServiceRequests',
      facts: counts,
    );
  }

  Future<CopilotDataSummaryModel> _payoutSummary(String freelancerId) async {
    final docs = await _queryByField('payouts', 'freelancerId', freelancerId);
    final counts = _countByStatus(docs, 'status');
    final pending =
        (counts['pendingApproval'] ?? 0) +
        (counts['pending'] ?? 0) +
        (counts['approved'] ?? 0) +
        (counts['processing'] ?? 0);
    final paid = counts['paid'] ?? 0;
    final rejected = counts['rejected'] ?? 0;
    return _ready(
      'Payout Status',
      '${docs.length} payout requests found. Pending/active: $pending. Paid: $paid. Rejected: $rejected.',
      routeId: 'freelancerPayouts',
      facts: counts,
    );
  }

  Future<CopilotDataSummaryModel> _resolutionSummary({
    required String title,
    required List<String> fields,
    required String userId,
    required String routeId,
  }) async {
    final docs = await _queryByAnyField('resolutionCases', fields, userId);
    final counts = _countByStatus(docs, 'status');
    final open =
        (counts['open'] ?? 0) +
        (counts['underReview'] ?? 0) +
        (counts['evidenceRequested'] ?? 0) +
        (counts['revisionRequested'] ?? 0) +
        (counts['revisionSubmitted'] ?? 0);
    final resolved = counts['resolved'] ?? 0;
    return _ready(
      title,
      '${docs.length} cases found. Open/review: $open. Resolved: $resolved.',
      routeId: routeId,
      facts: counts,
    );
  }

  Future<CopilotDataSummaryModel> _adminCollectionSummary({
    required String title,
    required String collection,
    required String statusField,
    required String routeId,
  }) async {
    final snapshot = await _firestore.collection(collection).limit(100).get();
    final docs = snapshot.docs.map((doc) => doc.data()).toList();
    final counts = _countByStatus(docs, statusField);
    final open =
        (counts['open'] ?? 0) +
        (counts['pending'] ?? 0) +
        (counts['pendingApproval'] ?? 0) +
        (counts['underReview'] ?? 0) +
        (counts['processing'] ?? 0);
    return _ready(
      title,
      '${docs.length} recent records found. Active/pending: $open.',
      routeId: routeId,
      facts: counts,
    );
  }

  CopilotDataSummaryModel _settlementBackendSummary() {
    return _ready(
      'Settlement Backend',
      'Resolution release and split settlement are in backend-pending mode. Full Cloud Functions execution will activate after Blaze is enabled and the settlement executor is deployed.',
      routeId: 'adminResolutionDesk',
      facts: const {
        'mode': 'pendingBackend',
        'releaseSplitEnabled': false,
        'realMoney': false,
      },
    );
  }

  Future<CopilotDataSummaryModel> _teacherCourseSummary(
    String teacherId,
  ) async {
    final docs = await _queryByField('courses', 'teacherId', teacherId);
    final counts = _countByStatus(docs, 'status');
    final published =
        (counts['published'] ?? 0) +
        docs.where((data) => data['isPublished'] == true).length;
    final draft =
        (counts['draft'] ?? 0) +
        docs.where((data) => data['isDraft'] == true).length;
    final archived =
        (counts['archived'] ?? 0) +
        docs.where((data) => data['isArchived'] == true).length;
    return _ready(
      'Teacher Courses',
      '${docs.length} courses found. Published: $published. Draft: $draft. Archived: $archived.',
      routeId: 'teacherCourses',
      facts: counts,
    );
  }

  Future<CopilotDataSummaryModel> _teacherCertificateSummary(
    String teacherId,
  ) async {
    final docs = await _queryByField('certificates', 'teacherId', teacherId);
    final active = docs
        .where((data) => data['status'] == 'active' || data['isActive'] == true)
        .length;
    final revoked = docs
        .where(
          (data) => data['status'] == 'revoked' || data['isRevoked'] == true,
        )
        .length;
    return _ready(
      'Teacher Certificates',
      '${docs.length} certificates found. Active: $active. Revoked: $revoked.',
      routeId: 'teacherCourses',
      facts: {'active': active, 'revoked': revoked, 'total': docs.length},
    );
  }

  Future<CopilotDataSummaryModel> _companyJobSummary(String companyId) async {
    final docs = await _queryByField('jobs', 'companyId', companyId);
    final counts = _countByStatus(docs, 'status');
    final active =
        (counts['active'] ?? 0) +
        (counts['published'] ?? 0) +
        docs.where((data) => data['isActive'] == true).length;
    final draft = counts['draft'] ?? 0;
    final closed = (counts['closed'] ?? 0) + (counts['archived'] ?? 0);
    return _ready(
      'Company Jobs',
      '${docs.length} jobs found. Active: $active. Draft: $draft. Closed/archived: $closed.',
      routeId: 'companyJobs',
      facts: counts,
    );
  }

  Future<CopilotDataSummaryModel> _companyApplicationSummary(
    String companyId, {
    String title = 'Company Applications',
  }) async {
    final docs = await _queryByField('applications', 'companyId', companyId);
    final counts = _countByStatus(docs, 'status');
    if (docs.isEmpty) {
      return _unavailable(
        title,
        'No company-scoped applications were found from the safe applications query. Open Hiring Pipeline for the full joined view.',
        routeId: 'hiringPipeline',
      );
    }
    final reviewed = (counts['reviewed'] ?? 0) + (counts['shortlisted'] ?? 0);
    final interviews = (counts['interview'] ?? 0) + (counts['scheduled'] ?? 0);
    return _ready(
      title,
      '${docs.length} applications found. Reviewed/shortlisted: $reviewed. Interview stage: $interviews.',
      routeId: 'hiringPipeline',
      facts: counts,
    );
  }

  CopilotDataSummaryModel _myRoleSummary(UserModel user) {
    final role = user.primaryRole?.trim().isNotEmpty == true
        ? user.primaryRole!
        : 'not selected';
    return _ready(
      'Your Role',
      'You are signed in as ${user.fullName.isEmpty ? 'this account' : user.fullName}. Account type: ${user.accountType}. Primary role: $role.',
      routeId: _dashboardRouteId(user),
      facts: {
        'uid': user.uid,
        'accountType': user.accountType,
        'primaryRole': role,
        'roles': user.roles,
      },
    );
  }

  CopilotDataSummaryModel _dashboardSummary(UserModel user) {
    final routeId = _dashboardRouteId(user);
    return _ready(
      'Dashboard',
      'Your dashboard is available. I can open it or answer safe summaries for your role.',
      routeId: routeId,
      facts: {'routeId': routeId ?? 'none'},
    );
  }

  CopilotDataSummaryModel _profileSummary(UserModel user) {
    final completion = user.profileCompleted.clamp(0, 100);
    return _ready(
      'Profile Summary',
      'Profile completion is $completion%. Status: ${user.status}. City: ${user.city.isEmpty ? 'not added' : user.city}.',
      routeId: _profileRouteId(user),
      facts: {
        'profileCompleted': completion,
        'status': user.status,
        'accountType': user.accountType,
      },
    );
  }

  Future<List<Map<String, dynamic>>> _queryByField(
    String collection,
    String field,
    String value,
  ) async {
    final snapshot = await _firestore
        .collection(collection)
        .where(field, isEqualTo: value)
        .limit(100)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _queryByAnyField(
    String collection,
    List<String> fields,
    String value,
  ) async {
    final byId = <String, Map<String, dynamic>>{};
    for (final field in fields) {
      final snapshot = await _firestore
          .collection(collection)
          .where(field, isEqualTo: value)
          .limit(50)
          .get();
      for (final doc in snapshot.docs) {
        byId[doc.id] = doc.data();
      }
    }
    return byId.values.toList();
  }

  Map<String, int> _countByStatus(
    List<Map<String, dynamic>> docs,
    String statusField,
  ) {
    final counts = <String, int>{};
    for (final data in docs) {
      final status = _string(data[statusField], 'unknown');
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  CopilotDataSummaryModel _ready(
    String title,
    String summary, {
    Map<String, Object?> facts = const <String, Object?>{},
    String? routeId,
  }) {
    final destination = CopilotRouteCatalog.byId(routeId);
    return CopilotDataSummaryModel(
      title: title,
      summaryText: summary,
      status: CopilotDataStatus.ready,
      facts: facts,
      suggestedRouteId: routeId,
      suggestedRoutePath: destination?.path,
    );
  }

  CopilotDataSummaryModel _unavailable(
    String title,
    String summary, {
    String? routeId,
  }) {
    final destination = CopilotRouteCatalog.byId(routeId);
    return CopilotDataSummaryModel(
      title: title,
      summaryText: summary,
      status: CopilotDataStatus.unavailable,
      suggestedRouteId: routeId,
      suggestedRoutePath: destination?.path,
    );
  }

  CopilotDataSummaryModel _unauthorized(String summary) {
    return CopilotDataSummaryModel(
      title: 'Access required',
      summaryText: summary,
      status: CopilotDataStatus.unauthorized,
    );
  }

  String? _dashboardRouteId(UserModel user) {
    if (user.isCustomerAccount) return 'customerDashboard';
    switch (_normalize(user.primaryRole)) {
      case 'student':
        return 'studentDashboard';
      case 'teacher':
        return 'teacherDashboard';
      case 'company':
        return 'companyDashboard';
      case 'freelancer':
        return 'freelancerDashboard';
      case 'admin':
      case 'superadmin':
        return 'adminDashboard';
    }
    return null;
  }

  String? _profileRouteId(UserModel user) {
    if (user.isCustomerAccount) return 'profileCustomer';
    switch (_normalize(user.primaryRole)) {
      case 'student':
        return 'profileStudent';
      case 'teacher':
        return 'profileTeacher';
      case 'company':
        return 'profileCompany';
      case 'freelancer':
        return 'profileFreelancer';
    }
    return null;
  }
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _string(Object? value, [String fallback = '']) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}

String _normalize(String? value) {
  return (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '')
      .trim();
}
