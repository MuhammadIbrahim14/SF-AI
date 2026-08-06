import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../core/services/firestore_permission_logger.dart';
import '../core/utils/app_logger.dart';
import '../models/resolution_case_model.dart';
import '../models/resolution_settlement_request_model.dart';

class ResolutionSettlementRequestRepository {
  const ResolutionSettlementRequestRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('resolutionSettlementRequests');

  Stream<ResolutionSettlementRequestModel?> watchRequest(String requestId) {
    final trimmed = requestId.trim();
    if (trimmed.isEmpty) return Stream.value(null);
    return _requestsRef.doc(trimmed).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ResolutionSettlementRequestModel.fromFirestore(doc);
    });
  }

  Future<ResolutionSettlementRequestModel> createSettlementRequest({
    required ResolutionCaseModel item,
    required String adminId,
    required String decision,
    required double releaseAmount,
    required double refundAmount,
    required String adminNote,
  }) async {
    final requestId =
        'settlement_request_${item.caseId}_${DateTime.now().millisecondsSinceEpoch}';
    final totalAmount = releaseAmount + refundAmount;
    final now = DateTime.now();
    final request = ResolutionSettlementRequestModel(
      requestId: requestId,
      caseId: item.caseId,
      orderId: item.orderId,
      requestedByAdminId: adminId,
      decision: decision,
      releaseAmount: releaseAmount,
      refundAmount: refundAmount,
      totalAmount: totalAmount,
      currency: item.currency,
      status: ResolutionSettlementRequestStatus.pending,
      clientId: item.clientId,
      freelancerId: item.freelancerId,
      caseType: item.type,
      openedBy: item.openedBy,
      openedByRole: item.openedByRole,
      paymentStatus: item.orderSnapshot['paymentStatus']?.toString() ?? '',
      escrowStatus: item.orderSnapshot['escrowStatus']?.toString() ?? '',
      orderStatus: item.orderSnapshot['orderStatus']?.toString() ?? '',
      adminNote: adminNote,
      createdAt: now,
      updatedAt: now,
      errorCode: null,
      errorMessage: null,
      resultSettlementId: null,
      processedAt: null,
    );
    try {
      AppLogger.debug('Resolution settlement request creation started.');
      await _requestsRef.doc(requestId).set(request.toJson());
      return request;
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'ResolutionSettlementRequest',
        repository: 'ResolutionSettlementRequestRepository',
        operation: 'createSettlementRequest',
        path: 'resolutionSettlementRequests/$requestId',
        action: 'create',
        uid: adminId,
        role: 'admin',
      );
    } catch (e) {
      throw FirestoreException('Unable to create settlement request: $e');
    }
  }
}
