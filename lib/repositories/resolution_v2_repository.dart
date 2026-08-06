import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/app_exceptions.dart';
import '../core/services/firestore_permission_logger.dart';
import '../core/services/resolution_law_engine_service.dart';
import '../models/customer_wallet_model.dart';
import '../models/escrow_hold_model.dart';
import '../models/freelancer_wallet_model.dart';
import '../models/resolution_case_model.dart';
import '../models/service_order_model.dart';

class ResolutionV2Repository {
  const ResolutionV2Repository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _casesRef =>
      _firestore.collection('resolutionCases');

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('serviceOrders');

  CollectionReference<Map<String, dynamic>> get _escrowsRef =>
      _firestore.collection('serviceEscrows');

  CollectionReference<Map<String, dynamic>> get _customerWalletsRef =>
      _firestore.collection('customerWallets');

  CollectionReference<Map<String, dynamic>> get _freelancerWalletsRef =>
      _firestore.collection('freelancerWallets');

  CollectionReference<Map<String, dynamic>> get _walletTransactionsRef =>
      _firestore.collection('walletTransactions');

  CollectionReference<Map<String, dynamic>> get _settlementsRef =>
      _firestore.collection('resolutionSettlements');

  ResolutionLawEngineService get _lawEngine =>
      const ResolutionLawEngineService();

  Stream<List<ResolutionCaseModel>> watchCasesForAdmin() {
    return _watchCases(
      _casesRef.where(
        'type',
        whereIn: const [ResolutionCaseType.dispute, ResolutionCaseType.refund],
      ),
    );
  }

  Stream<List<ResolutionCaseModel>> watchCasesForClient(String clientId) {
    return _watchCases(_casesRef.where('clientId', isEqualTo: clientId));
  }

  Stream<List<ResolutionCaseModel>> watchCasesForFreelancer(
    String freelancerId,
  ) {
    return _watchCases(
      _casesRef.where('freelancerId', isEqualTo: freelancerId),
    );
  }

  Stream<List<ResolutionCaseModel>> watchCasesForOrder(String orderId) {
    return _watchCases(_casesRef.where('orderId', isEqualTo: orderId));
  }

  Stream<ResolutionCaseModel?> watchCase(String caseId) {
    return _casesRef.doc(caseId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ResolutionCaseModel.fromFirestore(doc);
    });
  }

  Future<ResolutionCaseModel?> getCase(String caseId) async {
    final id = caseId.trim();
    if (id.isEmpty) return null;
    try {
      final doc = await _casesRef.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return ResolutionCaseModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load resolution case: ${e.toString()}');
    }
  }

  Stream<List<ResolutionCaseEventModel>> watchCaseEvents(String caseId) {
    return _casesRef
        .doc(caseId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(ResolutionCaseEventModel.fromFirestore)
              .toList();
        });
  }

  Stream<List<ResolutionCaseEvidenceModel>> watchCaseEvidence(String caseId) {
    return _casesRef
        .doc(caseId)
        .collection('evidence')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(ResolutionCaseEvidenceModel.fromFirestore)
              .toList();
        });
  }

  Future<String> createRevisionCase({
    required String orderId,
    required String actorId,
    required String notes,
  }) {
    return _createCase(
      orderId: orderId,
      actorId: actorId,
      type: ResolutionCaseType.revision,
      status: ResolutionCaseStatus.revisionRequested,
      reason: 'Revision requested',
      description: notes,
      requestedRefundAmount: 0,
    );
  }

  Future<String> createDisputeCase({
    required String orderId,
    required String actorId,
    required String reason,
  }) {
    return _createCase(
      orderId: orderId,
      actorId: actorId,
      type: ResolutionCaseType.dispute,
      status: ResolutionCaseStatus.open,
      reason: 'Dispute opened',
      description: reason,
      requestedRefundAmount: 0,
      financialSettlementRequired: true,
    );
  }

  Future<String> createRefundCase({
    required String orderId,
    required String actorId,
    required String reason,
    double? amount,
  }) async {
    final order = await _loadOrder(orderId);
    return _createCaseFromOrder(
      order: order,
      actorId: actorId,
      type: ResolutionCaseType.refund,
      status: ResolutionCaseStatus.open,
      reason: 'Refund requested',
      description: reason,
      requestedRefundAmount: amount ?? order.totalAmount,
      financialSettlementRequired: true,
    );
  }

  Future<void> acceptRevision({
    required String caseId,
    required String freelancerId,
    required String notes,
  }) {
    return _participantTransition(
      caseId: caseId,
      actorId: freelancerId,
      actorRole: 'freelancer',
      status: ResolutionCaseStatus.revisionAccepted,
      field: 'freelancerNotes',
      notes: notes,
      eventType: ResolutionEventType.revisionAccepted,
      eventMessage: 'Freelancer accepted the revision request.',
      operation: 'acceptRevision',
    );
  }

  Future<void> submitRevision({
    required String caseId,
    required String freelancerId,
    required String notes,
  }) {
    return _participantTransition(
      caseId: caseId,
      actorId: freelancerId,
      actorRole: 'freelancer',
      status: ResolutionCaseStatus.revisionSubmitted,
      field: 'freelancerNotes',
      notes: notes,
      eventType: ResolutionEventType.revisionSubmitted,
      eventMessage: 'Freelancer submitted the revision.',
      operation: 'submitRevision',
    );
  }

  Future<void> completeRevision({
    required String caseId,
    required String clientId,
    required String notes,
  }) {
    return _participantTransition(
      caseId: caseId,
      actorId: clientId,
      actorRole: 'client',
      status: ResolutionCaseStatus.revisionCompleted,
      field: 'clientNotes',
      notes: notes,
      eventType: ResolutionEventType.revisionCompleted,
      eventMessage: 'Client completed the revision case.',
      operation: 'completeRevision',
      close: true,
    );
  }

  Future<void> addEvidence({
    required String caseId,
    required String actorId,
    required String actorRole,
    required String notes,
  }) async {
    try {
      final caseRef = _casesRef.doc(caseId);
      final evidenceRef = caseRef
          .collection('evidence')
          .doc('evidence_${DateTime.now().millisecondsSinceEpoch}');
      final now = DateTime.now();
      await _firestore.runTransaction((transaction) async {
        final caseDoc = await transaction.get(caseRef);
        final item = _caseFromDoc(caseDoc);
        if (actorId != item.clientId && actorId != item.freelancerId) {
          throw const FirestoreException(
            'Only case participants can add evidence.',
          );
        }
        final normalizedRole = actorId == item.freelancerId
            ? 'freelancer'
            : 'client';
        final evidence = ResolutionCaseEvidenceModel(
          evidenceId: evidenceRef.id,
          caseId: caseId,
          actorId: actorId,
          actorRole: normalizedRole,
          title: normalizedRole == 'freelancer'
              ? 'Freelancer Evidence'
              : 'Client Evidence',
          description: notes,
          attachments: const [],
          relatedDeliveryId: item.latestDeliveryId,
          createdAt: now,
        );
        transaction.set(evidenceRef, evidence.toJson());
        final nextClientEvidenceCount =
            item.clientEvidenceCount + (normalizedRole == 'client' ? 1 : 0);
        final nextFreelancerEvidenceCount =
            item.freelancerEvidenceCount +
            (normalizedRole == 'freelancer' ? 1 : 0);
        final nextEvidenceStatus = _nextEvidenceRequestStatus(
          currentStatus: item.evidenceRequestStatus,
          actorRole: normalizedRole,
          clientEvidenceCount: nextClientEvidenceCount,
          freelancerEvidenceCount: nextFreelancerEvidenceCount,
        );
        transaction.set(caseRef, {
          if (normalizedRole == 'freelancer')
            'freelancerEvidenceCount': FieldValue.increment(1)
          else
            'clientEvidenceCount': FieldValue.increment(1),
          if (normalizedRole == 'freelancer') 'freelancerNotes': notes,
          if (normalizedRole != 'freelancer') 'clientNotes': notes,
          'evidenceRequestStatus': nextEvidenceStatus,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        _setEvent(
          transaction,
          caseRef,
          actorId: actorId,
          actorRole: normalizedRole,
          eventType: ResolutionEventType.evidenceAdded,
          message: notes.trim().isEmpty ? 'Evidence added.' : notes,
          now: now,
        );
      });
    } on FirebaseException catch (e) {
      throw _map(e, 'addEvidence', 'resolutionCases/$caseId/evidence', actorId);
    }
  }

  Future<void> addComment({
    required String caseId,
    required String actorId,
    required String actorRole,
    required String message,
  }) async {
    try {
      _logAction(
        operation: 'addComment',
        path: 'resolutionCases/$caseId/events',
        uid: actorId,
        actorRole: actorRole,
        caseId: caseId,
      );
      await _addEvent(
        caseId: caseId,
        actorId: actorId,
        actorRole: actorRole,
        eventType: actorRole == 'admin'
            ? ResolutionEventType.adminComment
            : ResolutionEventType.evidenceAdded,
        message: message,
      );
    } on FirebaseException catch (e) {
      throw _map(e, 'addComment', 'resolutionCases/$caseId/events', actorId);
    }
  }

  Future<void> assignCase({required String caseId, required String adminId}) {
    return _adminUpdate(
      caseId: caseId,
      adminId: adminId,
      operation: 'assignCase',
      updates: {'assignedAdminId': adminId},
      eventType: ResolutionEventType.statusChanged,
      message: 'Case assigned to admin.',
    );
  }

  Future<void> markUnderReview({
    required String caseId,
    required String adminId,
  }) {
    return _adminUpdate(
      caseId: caseId,
      adminId: adminId,
      operation: 'markUnderReview',
      updates: {'status': ResolutionCaseStatus.underReview},
      eventType: ResolutionEventType.statusChanged,
      message: 'Case marked under review.',
    );
  }

  Future<void> requestEvidence({
    required String caseId,
    required String adminId,
    required String message,
    String targetRole = 'both',
  }) {
    if (kDebugMode) {
      debugPrint(
        '[ResolutionDeskV3Action] caseId=$caseId caseType=unknown '
        'openedByRole=unknown action=requestEvidence adminId=$adminId '
        'orderId=unknown releaseAmount=0 refundAmount=0 targetRole=$targetRole',
      );
    }
    final targetStatus = switch (targetRole) {
      'client' => ResolutionEvidenceRequestStatus.requestedFromClient,
      'freelancer' => ResolutionEvidenceRequestStatus.requestedFromFreelancer,
      _ => ResolutionEvidenceRequestStatus.requestedFromBoth,
    };
    return _adminUpdate(
      caseId: caseId,
      adminId: adminId,
      operation: 'requestEvidence',
      updates: {
        'status': ResolutionCaseStatus.evidenceRequested,
        'evidenceRequestStatus': targetStatus,
        'adminEvidenceRequestedFrom': targetRole,
        'adminEvidenceRequestMessage': message,
        'adminNotes': message,
      },
      eventType: 'evidenceRequested',
      message: message.trim().isEmpty
          ? 'Additional evidence requested from $targetRole.'
          : message,
    );
  }

  Future<void> generateLawRecommendation({
    required String caseId,
    required String adminId,
  }) async {
    try {
      final caseRef = _casesRef.doc(caseId);
      final now = DateTime.now();
      await _firestore.runTransaction((transaction) async {
        final caseDoc = await transaction.get(caseRef);
        final item = _caseFromDoc(caseDoc);
        final orderDoc = await transaction.get(_ordersRef.doc(item.orderId));
        if (!orderDoc.exists || orderDoc.data() == null) {
          throw const FirestoreException('Order not found.');
        }
        final order = ServiceOrderModel.fromFirestore(orderDoc);
        final recommendation = _lawEngine.generateRecommendation(
          resolutionCase: item,
          order: order,
        );
        transaction.set(caseRef, {
          ...recommendation.toJson(),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        _setEvent(
          transaction,
          caseRef,
          actorId: adminId,
          actorRole: 'admin',
          eventType: ResolutionEventType.adminComment,
          message: 'Law recommendation generated: ${recommendation.summary}',
          now: now,
        );
      });
    } on FirebaseException catch (e) {
      throw _map(
        e,
        'generateLawRecommendation',
        'resolutionCases/$caseId',
        adminId,
      );
    }
  }

  Future<void> resolveReleaseToFreelancer({
    required String caseId,
    required String adminId,
    required double releaseAmount,
    required String adminNote,
  }) {
    return _resolveCase(
      caseId: caseId,
      adminId: adminId,
      decision: ResolutionDecision.releaseToFreelancer,
      releaseAmount: releaseAmount,
      refundAmount: 0,
      adminNote: adminNote,
    );
  }

  Future<void> resolveRefundToClient({
    required String caseId,
    required String adminId,
    required double refundAmount,
    required String adminNote,
  }) {
    return _resolveCase(
      caseId: caseId,
      adminId: adminId,
      decision: ResolutionDecision.refundToClient,
      releaseAmount: 0,
      refundAmount: refundAmount,
      adminNote: adminNote,
    );
  }

  Future<void> resolveSplit({
    required String caseId,
    required String adminId,
    required double releaseAmount,
    required double refundAmount,
    required String adminNote,
  }) {
    return _resolveCase(
      caseId: caseId,
      adminId: adminId,
      decision: ResolutionDecision.splitRelease,
      releaseAmount: releaseAmount,
      refundAmount: refundAmount,
      adminNote: adminNote,
    );
  }

  Future<void> completeDemoSettlement({
    required String caseId,
    required String adminId,
    required String resolutionType,
    required double freelancerAmount,
    required double customerAmount,
    required String decisionNote,
  }) async {
    var currentStep = 'start';
    try {
      final caseRef = _casesRef.doc(caseId);
      final settlementRef = _settlementsRef.doc('demo_settlement_$caseId');
      final auditRef = _firestore.collection('adminAuditLogs').doc();
      final now = DateTime.now();

      await _firestore.runTransaction((transaction) async {
        currentStep = 'readCase';
        final caseDoc = await transaction.get(caseRef);
        final item = _caseFromDoc(caseDoc);
        if (!item.isOpen &&
            item.status != ResolutionCaseStatus.underReview &&
            item.status != ResolutionCaseStatus.evidenceRequested) {
          throw const FirestoreException(
            'Only open or review cases can be settled in demo mode.',
          );
        }
        if (item.settlementStatus == ResolutionSettlementStatus.completed ||
            item.orderSnapshot['demoSettlementStatus'] == 'completed') {
          throw const FirestoreException(
            'This case already has a completed settlement.',
          );
        }

        currentStep = 'readOrder';
        final orderRef = _ordersRef.doc(item.orderId);
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists || orderDoc.data() == null) {
          throw const FirestoreException('Order not found.');
        }
        final order = ServiceOrderModel.fromFirestore(orderDoc);

        final totalAmount = _demoSettlementTotal(item, order);
        final releaseAmount = freelancerAmount < 0 ? 0.0 : freelancerAmount;
        final refundAmount = customerAmount < 0 ? 0.0 : customerAmount;
        final splitTotal = releaseAmount + refundAmount;
        if (splitTotal <= 0) {
          throw const FirestoreException(
            'Enter a settlement amount greater than 0.',
          );
        }
        if (totalAmount > 0 && splitTotal > totalAmount + 0.01) {
          throw const FirestoreException(
            'Demo settlement cannot exceed the order escrow amount.',
          );
        }
        if (resolutionType == 'demoRelease' && releaseAmount <= 0) {
          throw const FirestoreException('Release amount is required.');
        }
        if (resolutionType == 'demoRefund' && refundAmount <= 0) {
          throw const FirestoreException('Refund amount is required.');
        }
        if (resolutionType == 'demoSplit' &&
            (releaseAmount <= 0 || refundAmount <= 0)) {
          throw const FirestoreException(
            'Split settlement needs release and refund amounts.',
          );
        }

        currentStep = 'readSettlement';
        final settlementDoc = await transaction.get(settlementRef);
        if (settlementDoc.exists) {
          throw const FirestoreException(
            'This case already has a demo settlement record.',
          );
        }

        final settlementStatus = switch (resolutionType) {
          'demoRelease' => 'demoReleased',
          'demoRefund' => 'demoRefunded',
          'demoSplit' => 'demoSplit',
          _ => 'demoReleased',
        };
        final resolutionDecision = switch (resolutionType) {
          'demoRelease' => ResolutionDecision.releaseToFreelancer,
          'demoRefund' => ResolutionDecision.refundToClient,
          'demoSplit' => ResolutionDecision.splitRelease,
          _ => ResolutionDecision.releaseToFreelancer,
        };

        currentStep = 'updateCase';
        transaction.set(caseRef, {
          'status': ResolutionCaseStatus.resolved,
          'resolutionType': resolutionType,
          'resolutionDecision': resolutionDecision,
          'releaseAmount': releaseAmount,
          'refundAmount': refundAmount,
          'decisionNote': decisionNote.trim(),
          'adminNotes': decisionNote.trim(),
          'resolvedBy': adminId,
          'resolvedAt': Timestamp.fromDate(now),
          'demoSettlement': true,
          'demoSettlementStatus': 'completed',
          'settlementStatus': ResolutionSettlementStatus.completed,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'updateOrder';
        transaction.set(orderRef, {
          'settlementStatus': settlementStatus,
          'escrowStatus': settlementStatus,
          'resolvedCaseId': caseId,
          'demoSettlement': true,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'createSettlement';
        transaction.set(settlementRef, {
          'settlementId': settlementRef.id,
          'caseId': caseId,
          'orderId': item.orderId,
          'serviceRequestId': item.serviceRequestId,
          'clientId': item.clientId,
          'freelancerId': item.freelancerId,
          'type': resolutionType,
          'demoMode': true,
          'totalAmount': splitTotal,
          'freelancerAmount': releaseAmount,
          'customerAmount': refundAmount,
          'platformAmount': 0,
          'currency': item.currency,
          'status': 'completed',
          'createdBy': adminId,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        currentStep = 'createLedger';
        if (releaseAmount > 0) {
          final ledgerRef = _walletTransactionsRef.doc(
            'demo_release_${caseId}_${now.millisecondsSinceEpoch}',
          );
          transaction.set(
            ledgerRef,
            _demoLedgerPayload(
              transactionId: ledgerRef.id,
              userId: item.freelancerId,
              role: 'freelancer',
              amount: releaseAmount,
              currency: item.currency,
              type: resolutionType == 'demoSplit'
                  ? 'demoResolutionSplit'
                  : 'demoResolutionRelease',
              direction: 'credit',
              caseId: caseId,
              orderId: item.orderId,
              adminId: adminId,
              now: now,
            ),
          );
        }
        if (refundAmount > 0) {
          final ledgerRef = _walletTransactionsRef.doc(
            'demo_refund_${caseId}_${now.millisecondsSinceEpoch}',
          );
          transaction.set(
            ledgerRef,
            _demoLedgerPayload(
              transactionId: ledgerRef.id,
              userId: item.clientId,
              role: 'customer',
              amount: refundAmount,
              currency: item.currency,
              type: resolutionType == 'demoSplit'
                  ? 'demoResolutionSplit'
                  : 'demoResolutionRefund',
              direction: 'credit',
              caseId: caseId,
              orderId: item.orderId,
              adminId: adminId,
              now: now,
            ),
          );
        }

        currentStep = 'audit';
        transaction.set(auditRef, {
          'action': resolutionType,
          'caseId': caseId,
          'orderId': item.orderId,
          'before': {
            'caseStatus': item.status,
            'settlementStatus': item.settlementStatus,
            'orderStatus': order.orderStatus,
            'escrowStatus': order.escrowStatus,
          },
          'after': {
            'caseStatus': ResolutionCaseStatus.resolved,
            'settlementStatus': 'completed',
            'orderSettlementStatus': settlementStatus,
            'releaseAmount': releaseAmount,
            'refundAmount': refundAmount,
          },
          'adminId': adminId,
          'demoMode': true,
          'createdAt': Timestamp.fromDate(now),
        });

        _setEvent(
          transaction,
          caseRef,
          actorId: adminId,
          actorRole: 'admin',
          eventType: ResolutionEventType.settlementRecorded,
          message:
              'Demo settlement completed. Release: ${releaseAmount.toStringAsFixed(2)}, refund: ${refundAmount.toStringAsFixed(2)} ${item.currency}.',
          now: now,
        );
      });
    } on FirebaseException catch (e) {
      throw _map(
        e,
        'completeDemoSettlement:$currentStep',
        'resolutionCases/$caseId + serviceOrders + resolutionSettlements + walletTransactions + adminAuditLogs',
        adminId,
      );
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException(
        'Unable to complete demo settlement: ${e.toString()}',
      );
    }
  }

  Future<void> rejectCase({
    required String caseId,
    required String adminId,
    required String adminNote,
  }) {
    return _adminUpdate(
      caseId: caseId,
      adminId: adminId,
      operation: 'rejectCase',
      updates: {
        'status': ResolutionCaseStatus.rejected,
        'resolutionDecision': ResolutionDecision.rejectRequest,
        'adminNotes': adminNote,
        'adminFindings': adminNote,
        'settlementStatus': ResolutionSettlementStatus.rejected,
        'resolvedAt': Timestamp.fromDate(DateTime.now()),
      },
      eventType: ResolutionEventType.decisionMade,
      message: adminNote.trim().isEmpty ? 'Case rejected.' : adminNote,
    );
  }

  Future<void> closeCase({required String caseId, required String adminId}) {
    return _adminUpdate(
      caseId: caseId,
      adminId: adminId,
      operation: 'closeCase',
      updates: {'closedAt': Timestamp.fromDate(DateTime.now())},
      eventType: ResolutionEventType.caseClosed,
      message: 'Case closed.',
    );
  }

  Stream<List<ResolutionCaseModel>> _watchCases(
    Query<Map<String, dynamic>> query,
  ) {
    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(ResolutionCaseModel.fromFirestore)
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  Future<ServiceOrderModel> _loadOrder(String orderId) async {
    final doc = await _ordersRef.doc(orderId.trim()).get();
    if (!doc.exists || doc.data() == null) {
      throw const FirestoreException('Order not found.');
    }
    return ServiceOrderModel.fromFirestore(doc);
  }

  Future<String> _createCase({
    required String orderId,
    required String actorId,
    required String type,
    required String status,
    required String reason,
    required String description,
    required double requestedRefundAmount,
    bool financialSettlementRequired = false,
  }) async {
    final order = await _loadOrder(orderId);
    return _createCaseFromOrder(
      order: order,
      actorId: actorId,
      type: type,
      status: status,
      reason: reason,
      description: description,
      requestedRefundAmount: requestedRefundAmount,
      financialSettlementRequired: financialSettlementRequired,
    );
  }

  Future<String> _createCaseFromOrder({
    required ServiceOrderModel order,
    required String actorId,
    required String type,
    required String status,
    required String reason,
    required String description,
    required double requestedRefundAmount,
    required bool financialSettlementRequired,
  }) async {
    try {
      final actorRole = actorId == order.freelancerId ? 'freelancer' : 'client';
      if (actorId != order.clientId && actorId != order.freelancerId) {
        throw const FirestoreException(
          'Only order participants can open cases.',
        );
      }
      final deliveryReady =
          order.orderStatus == ServiceOrderStatus.delivered &&
          order.deliveryStatus == ServiceOrderDeliveryStatus.submitted &&
          (order.lastDeliveryId ?? '').trim().isNotEmpty;
      if (type == ResolutionCaseType.revision && !deliveryReady) {
        throw const FirestoreException(
          'Revision requests are available after delivery is submitted.',
        );
      }
      if (type == ResolutionCaseType.dispute && !deliveryReady) {
        throw const FirestoreException(
          'Disputes are available after delivery is submitted. Request a refund before delivery.',
        );
      }
      final caseId = '${order.orderId}_$type';
      final caseRef = _casesRef.doc(caseId);
      final existing = await caseRef.get();
      if (existing.exists) {
        throw const FirestoreException(
          'A case of this type already exists for this order.',
        );
      }
      String? relatedRefundCaseId;
      String? relatedDisputeCaseId;
      if (type == ResolutionCaseType.dispute) {
        final refundId = '${order.orderId}_${ResolutionCaseType.refund}';
        final refundDoc = await _casesRef.doc(refundId).get();
        if (refundDoc.exists) relatedRefundCaseId = refundId;
      } else if (type == ResolutionCaseType.refund) {
        final disputeId = '${order.orderId}_${ResolutionCaseType.dispute}';
        final disputeDoc = await _casesRef.doc(disputeId).get();
        if (disputeDoc.exists) relatedDisputeCaseId = disputeId;
      }
      final now = DateTime.now();
      final evidenceRequired =
          type == ResolutionCaseType.dispute ||
          (type == ResolutionCaseType.refund && deliveryReady);
      final resolutionCase = ResolutionCaseModel(
        caseId: caseId,
        orderId: order.orderId,
        serviceRequestId: order.serviceRequestId,
        serviceId: order.serviceId,
        serviceTitle: order.serviceTitle,
        clientId: order.clientId,
        clientName: order.clientName,
        freelancerId: order.freelancerId,
        freelancerName: order.freelancerName,
        type: type,
        status: status,
        requestedBy: actorId,
        requestedByRole: actorRole,
        openedBy: actorId,
        openedByRole: actorRole,
        againstUserId: actorRole == 'freelancer'
            ? order.clientId
            : order.freelancerId,
        againstRole: actorRole == 'freelancer' ? 'client' : 'freelancer',
        relatedRefundCaseId: relatedRefundCaseId,
        relatedDisputeCaseId: relatedDisputeCaseId,
        latestDeliveryId: order.lastDeliveryId,
        relatedDeliveryIds: [
          if ((order.lastDeliveryId ?? '').trim().isNotEmpty)
            order.lastDeliveryId!,
        ],
        evidenceRequired: evidenceRequired,
        clientEvidenceCount: 0,
        freelancerEvidenceCount: 0,
        adminEvidenceRequestedFrom: null,
        evidenceRequestStatus: ResolutionEvidenceRequestStatus.none,
        clientEvidence: const [],
        freelancerEvidence: const [],
        lawId: null,
        lawTitle: null,
        aiRecommendationStatus: ResolutionAiRecommendationStatus.notGenerated,
        aiSummary: '',
        aiRecommendedAction: ResolutionDecision.none,
        adminFindings: '',
        orderSnapshot: {
          'orderId': order.orderId,
          'orderStatus': order.orderStatus,
          'paymentStatus': order.paymentStatus,
          'escrowStatus': order.escrowStatus,
          'deliveryStatus': order.deliveryStatus,
          'amount': order.totalAmount,
          'currency': order.currency,
          'deliveredAt': order.deliveredAt == null
              ? null
              : Timestamp.fromDate(order.deliveredAt!),
          'workStartedAt': order.workStartedAt == null
              ? null
              : Timestamp.fromDate(order.workStartedAt!),
          'reviewDueAt': order.reviewDueAt == null
              ? null
              : Timestamp.fromDate(order.reviewDueAt!),
          'lastDeliveryId': order.lastDeliveryId,
        },
        assignedAdminId: null,
        reason: reason,
        description: description,
        clientNotes: actorRole == 'client' ? description : '',
        freelancerNotes: actorRole == 'freelancer' ? description : '',
        adminNotes: '',
        evidenceUrls: const [],
        resolutionDecision: ResolutionDecision.none,
        requestedRefundAmount: requestedRefundAmount,
        releaseAmount: 0,
        refundAmount: 0,
        currency: order.currency,
        priority: ResolutionPriority.normal,
        isFinancialSettlementRequired: financialSettlementRequired,
        settlementStatus: financialSettlementRequired
            ? ResolutionSettlementStatus.pending
            : ResolutionSettlementStatus.none,
        legacyDisputeId: null,
        legacyRevisionId: null,
        legacyRefundId: null,
        createdAt: now,
        updatedAt: now,
        resolvedAt: null,
        closedAt: null,
      );
      final payload = resolutionCase.toJson();
      _logAction(
        operation: 'createCase',
        path: 'resolutionCases/$caseId + resolutionCases/$caseId/events',
        uid: actorId,
        actorRole: actorRole,
        caseId: caseId,
        keys: payload.keys,
      );
      await _firestore.runTransaction((transaction) async {
        transaction.set(caseRef, payload);
        _setEvent(
          transaction,
          caseRef,
          actorId: actorId,
          actorRole: actorRole,
          eventType: ResolutionEventType.caseCreated,
          message: description.trim().isEmpty ? reason : description,
          now: now,
        );
      });
      return caseId;
    } on FirebaseException catch (e) {
      throw _map(e, 'createCase', 'resolutionCases/*', actorId);
    }
  }

  Future<void> _participantTransition({
    required String caseId,
    required String actorId,
    required String actorRole,
    required String status,
    required String field,
    required String notes,
    required String eventType,
    required String eventMessage,
    required String operation,
    bool close = false,
  }) async {
    try {
      final caseRef = _casesRef.doc(caseId);
      final now = DateTime.now();
      _logAction(
        operation: operation,
        path: 'resolutionCases/$caseId + resolutionCases/$caseId/events',
        uid: actorId,
        actorRole: actorRole,
        caseId: caseId,
        keys: ['status', field, 'updatedAt', if (close) 'closedAt'],
      );
      await _firestore.runTransaction((transaction) async {
        final caseDoc = await transaction.get(caseRef);
        final item = _caseFromDoc(caseDoc);
        if (actorId != item.clientId && actorId != item.freelancerId) {
          throw const FirestoreException(
            'Only case participants can update it.',
          );
        }
        transaction.set(caseRef, {
          'status': status,
          field: notes,
          'updatedAt': Timestamp.fromDate(now),
          if (close) 'closedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        _setEvent(
          transaction,
          caseRef,
          actorId: actorId,
          actorRole: actorRole,
          eventType: eventType,
          message: notes.trim().isEmpty ? eventMessage : notes,
          now: now,
        );
      });
    } on FirebaseException catch (e) {
      throw _map(e, operation, 'resolutionCases/$caseId', actorId);
    }
  }

  Future<void> _adminUpdate({
    required String caseId,
    required String adminId,
    required String operation,
    required Map<String, dynamic> updates,
    required String eventType,
    required String message,
  }) async {
    try {
      final caseRef = _casesRef.doc(caseId);
      final now = DateTime.now();
      _logAction(
        operation: operation,
        path: 'resolutionCases/$caseId + resolutionCases/$caseId/events',
        uid: adminId,
        actorRole: 'admin',
        caseId: caseId,
        keys: updates.keys,
      );
      await _firestore.runTransaction((transaction) async {
        updates['updatedAt'] = Timestamp.fromDate(now);
        transaction.set(caseRef, updates, SetOptions(merge: true));
        _setEvent(
          transaction,
          caseRef,
          actorId: adminId,
          actorRole: 'admin',
          eventType: eventType,
          message: message,
          metadata: operation == 'requestEvidence'
              ? {'targetRole': updates['adminEvidenceRequestedFrom']}
              : const <String, dynamic>{},
          now: now,
        );
      });
    } on FirebaseException catch (e) {
      throw _map(e, operation, 'resolutionCases/$caseId', adminId);
    }
  }

  Future<void> _resolveCase({
    required String caseId,
    required String adminId,
    required String decision,
    required double releaseAmount,
    required double refundAmount,
    required String adminNote,
  }) async {
    var currentStep = 'start';
    try {
      final caseRef = _casesRef.doc(caseId);
      final settlementRef = _settlementsRef.doc(_settlementId(caseId));
      final releaseLedgerRef = _walletTransactionsRef.doc(
        _releaseLedgerId(caseId, decision),
      );
      final refundLedgerRef = _walletTransactionsRef.doc(
        _refundLedgerId(caseId, decision),
      );
      _logFinancialStep(
        operation: _financialOperation(decision),
        step: currentStep,
        caseId: caseId,
        adminId: adminId,
        releaseAmount: releaseAmount,
        refundAmount: refundAmount,
      );
      await _firestore.runTransaction((transaction) async {
        currentStep = 'readCase';
        final caseDoc = await transaction.get(caseRef);
        final item = _caseFromDoc(caseDoc);
        _logResolutionDeskV3Action(
          caseId: caseId,
          caseType: item.type,
          openedByRole: item.openedByRole,
          action: decision,
          adminId: adminId,
          orderId: item.orderId,
          releaseAmount: releaseAmount,
          refundAmount: refundAmount,
        );
        final orderRef = _ordersRef.doc(item.orderId);
        final escrowRef = _escrowsRef.doc(item.orderId);
        final customerWalletRef = _customerWalletsRef.doc(item.clientId);
        final freelancerWalletRef = _freelancerWalletsRef.doc(
          item.freelancerId,
        );

        currentStep = 'readOrder';
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists || orderDoc.data() == null) {
          throw const FirestoreException('Order not found.');
        }
        final order = ServiceOrderModel.fromFirestore(orderDoc);

        currentStep = 'readEscrow';
        final escrowDoc = await transaction.get(escrowRef);
        if (!escrowDoc.exists || escrowDoc.data() == null) {
          throw const FirestoreException(
            'Escrow is not available for settlement.',
          );
        }
        final escrow = EscrowHoldModel.fromFirestore(escrowDoc);

        final normalized = _normalizeSettlementAmounts(
          decision: decision,
          requestedReleaseAmount: releaseAmount,
          requestedRefundAmount: refundAmount,
          requestedRefundFallback: item.requestedRefundAmount,
          escrowAmount: escrow.amount,
        );
        final finalReleaseAmount = normalized.$1;
        final finalRefundAmount = normalized.$2;
        final settlementTotal = finalReleaseAmount + finalRefundAmount;

        currentStep = 'readCustomerWallet';
        final customerWalletDoc = await transaction.get(customerWalletRef);

        currentStep = 'readFreelancerWallet';
        final freelancerWalletDoc = finalReleaseAmount > 0
            ? await transaction.get(freelancerWalletRef)
            : null;

        currentStep = 'readSettlement';
        final settlementDoc = await transaction.get(settlementRef);

        currentStep = 'readRelatedRefundCase';
        final relatedRefundCaseId = item.type == ResolutionCaseType.dispute
            ? (item.relatedRefundCaseId ?? '').trim()
            : '';
        final relatedRefundRef =
            relatedRefundCaseId.isNotEmpty && relatedRefundCaseId != caseId
            ? _casesRef.doc(relatedRefundCaseId)
            : null;
        final relatedRefundDoc = relatedRefundRef == null
            ? null
            : await transaction.get(relatedRefundRef);

        currentStep = 'readLedgers';
        final releaseLedgerDoc = finalReleaseAmount > 0
            ? await transaction.get(releaseLedgerRef)
            : null;
        final refundLedgerDoc = finalRefundAmount > 0
            ? await transaction.get(refundLedgerRef)
            : null;

        currentStep = 'validateSettlement';
        _validateSettlement(
          item: item,
          order: order,
          escrow: escrow,
          settlementExists: settlementDoc.exists,
          releaseLedgerExists: releaseLedgerDoc?.exists ?? false,
          refundLedgerExists: refundLedgerDoc?.exists ?? false,
          releaseAmount: finalReleaseAmount,
          refundAmount: finalRefundAmount,
          settlementTotal: settlementTotal,
        );

        final now = DateTime.now();
        final fullRefund = finalRefundAmount > 0 && finalReleaseAmount == 0;
        final splitSettlement = finalRefundAmount > 0 && finalReleaseAmount > 0;
        final escrowStatus = fullRefund
            ? EscrowHoldStatus.refunded
            : splitSettlement
            ? ServiceOrderEscrowStatus.split
            : EscrowHoldStatus.released;
        final paymentStatus = fullRefund
            ? ServiceOrderPaymentStatus.refunded
            : splitSettlement
            ? ServiceOrderPaymentStatus.partiallyRefunded
            : ServiceOrderPaymentStatus.released;
        final orderStatus = fullRefund
            ? ServiceOrderStatus.cancelled
            : splitSettlement
            ? ServiceOrderStatus.splitSettled
            : ServiceOrderStatus.completed;

        currentStep = 'updateCase';
        transaction.set(caseRef, {
          'status': ResolutionCaseStatus.resolved,
          'resolutionDecision': decision,
          'releaseAmount': finalReleaseAmount,
          'refundAmount': finalRefundAmount,
          'adminNotes': adminNote,
          'settlementStatus': ResolutionSettlementStatus.completed,
          'isFinancialSettlementRequired': true,
          'resolvedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        if (relatedRefundRef != null &&
            relatedRefundDoc != null &&
            relatedRefundDoc.exists) {
          final relatedRefund = ResolutionCaseModel.fromFirestore(
            relatedRefundDoc,
          );
          if (relatedRefund.status != ResolutionCaseStatus.resolved &&
              relatedRefund.status != ResolutionCaseStatus.rejected &&
              relatedRefund.settlementStatus !=
                  ResolutionSettlementStatus.completed) {
            transaction.set(relatedRefundRef, {
              'status': ResolutionCaseStatus.resolved,
              'resolutionDecision': decision,
              'releaseAmount': finalReleaseAmount,
              'refundAmount': finalRefundAmount,
              'adminNotes': adminNote.trim().isEmpty
                  ? 'Resolved through related dispute $caseId.'
                  : adminNote,
              'settlementStatus': ResolutionSettlementStatus.completed,
              'isFinancialSettlementRequired': true,
              'resolvedAt': Timestamp.fromDate(now),
              'updatedAt': Timestamp.fromDate(now),
            }, SetOptions(merge: true));
          }
        }

        currentStep = 'updateEscrow';
        transaction.set(escrowRef, {
          'status': escrowStatus,
          'releasedAmount': finalReleaseAmount,
          'refundedAmount': finalRefundAmount,
          if (finalReleaseAmount > 0) 'releasedAt': Timestamp.fromDate(now),
          if (finalRefundAmount > 0) 'refundedAt': Timestamp.fromDate(now),
          'resolvedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'updateOrder';
        transaction.set(orderRef, {
          'paymentStatus': paymentStatus,
          'escrowStatus': escrowStatus,
          'orderStatus': orderStatus,
          if (finalReleaseAmount > 0)
            'escrowReleasedAt': Timestamp.fromDate(now),
          if (finalRefundAmount > 0) 'refundedAt': Timestamp.fromDate(now),
          'resolvedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'updateCustomerWallet';
        _writeCustomerSettlementWallet(
          transaction: transaction,
          walletRef: customerWalletRef,
          walletDoc: customerWalletDoc,
          clientId: item.clientId,
          currency: item.currency,
          refundAmount: finalRefundAmount,
          settlementTotal: settlementTotal,
          now: now,
        );

        if (finalReleaseAmount > 0) {
          currentStep = 'updateFreelancerWallet';
          _writeFreelancerSettlementWallet(
            transaction: transaction,
            walletRef: freelancerWalletRef,
            walletDoc: freelancerWalletDoc,
            freelancerId: item.freelancerId,
            currency: item.currency,
            releaseAmount: finalReleaseAmount,
            now: now,
          );
        }

        currentStep = 'createSettlement';
        transaction.set(settlementRef, {
          'settlementId': settlementRef.id,
          'caseId': caseId,
          'orderId': item.orderId,
          'serviceRequestId': item.serviceRequestId,
          'clientId': item.clientId,
          'freelancerId': item.freelancerId,
          'type': decision,
          'releaseAmount': finalReleaseAmount,
          'refundAmount': finalRefundAmount,
          'totalAmount': settlementTotal,
          'currency': item.currency,
          'status': ResolutionSettlementStatus.completed,
          'recordedBy': adminId,
          'recordedAt': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        currentStep = 'createWalletTransactions';
        if (finalReleaseAmount > 0) {
          transaction.set(
            releaseLedgerRef,
            _walletLedgerPayload(
              transactionId: releaseLedgerRef.id,
              ownerId: item.freelancerId,
              ownerType: WalletTransactionOwnerType.freelancer,
              type: WalletTransactionType.escrowRelease,
              amount: finalReleaseAmount,
              currency: item.currency,
              orderId: item.orderId,
              caseId: caseId,
              description:
                  'Resolution settlement released demo escrow to freelancer.',
              now: now,
            ),
          );
        }
        if (finalRefundAmount > 0) {
          transaction.set(
            refundLedgerRef,
            _walletLedgerPayload(
              transactionId: refundLedgerRef.id,
              ownerId: item.clientId,
              ownerType: WalletTransactionOwnerType.customer,
              type: decision == ResolutionDecision.splitRelease
                  ? WalletTransactionType.splitRefund
                  : WalletTransactionType.refund,
              amount: finalRefundAmount,
              currency: item.currency,
              orderId: item.orderId,
              caseId: caseId,
              description:
                  'Resolution settlement refunded demo escrow to customer.',
              now: now,
            ),
          );
        }

        _setEvent(
          transaction,
          caseRef,
          actorId: adminId,
          actorRole: 'admin',
          eventType: ResolutionEventType.decisionMade,
          message: adminNote.trim().isEmpty
              ? 'Admin completed a resolution settlement.'
              : adminNote,
          now: now,
        );
        _setEvent(
          transaction,
          caseRef,
          actorId: adminId,
          actorRole: 'admin',
          eventType: ResolutionEventType.settlementRecorded,
          message:
              'Financial settlement completed. Release: ${finalReleaseAmount.toStringAsFixed(2)}, Refund: ${finalRefundAmount.toStringAsFixed(2)} ${item.currency}.',
          now: now,
        );
      });
      _logFinancialStep(
        operation: _financialOperation(decision),
        step: 'success',
        caseId: caseId,
        adminId: adminId,
        releaseAmount: releaseAmount,
        refundAmount: refundAmount,
      );
    } on FirebaseException catch (e) {
      _logFinancialError(
        operation: _financialOperation(decision),
        step: currentStep,
        caseId: caseId,
        adminId: adminId,
        code: e.code,
        message: e.message ?? e.toString(),
        stackTrace: e.stackTrace,
      );
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'ResolutionFinancialV2',
        repository: 'ResolutionV2Repository',
        operation: _financialOperation(decision),
        path:
            'resolutionCases/$caseId + serviceOrders + serviceEscrows + customerWallets + freelancerWallets + resolutionSettlements + walletTransactions',
        action: 'transaction',
        uid: adminId,
        role: 'admin',
      );
    } on FirestoreException catch (e, stackTrace) {
      _logFinancialError(
        operation: _financialOperation(decision),
        step: currentStep,
        caseId: caseId,
        adminId: adminId,
        code: e.code ?? 'resolution-settlement',
        message: e.message,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      final message = e.toString();
      _logFinancialError(
        operation: _financialOperation(decision),
        step: currentStep,
        caseId: caseId,
        adminId: adminId,
        code: e.runtimeType.toString(),
        message: message,
        stackTrace: stackTrace,
      );
      if (message.contains('Dart exception thrown from converted Future')) {
        throw const FirestoreException('Unable to complete settlement.');
      }
      throw FirestoreException('Unable to complete settlement: $message');
    }
  }

  (double, double) _normalizeSettlementAmounts({
    required String decision,
    required double requestedReleaseAmount,
    required double requestedRefundAmount,
    required double requestedRefundFallback,
    required double escrowAmount,
  }) {
    if (decision == ResolutionDecision.releaseToFreelancer) {
      return (
        requestedReleaseAmount > 0 ? requestedReleaseAmount : escrowAmount,
        0,
      );
    }
    if (decision == ResolutionDecision.refundToClient) {
      final fallback = requestedRefundFallback > 0
          ? requestedRefundFallback
          : escrowAmount;
      return (0, requestedRefundAmount > 0 ? requestedRefundAmount : fallback);
    }
    return (requestedReleaseAmount, requestedRefundAmount);
  }

  void _validateSettlement({
    required ResolutionCaseModel item,
    required ServiceOrderModel order,
    required EscrowHoldModel escrow,
    required bool settlementExists,
    required bool releaseLedgerExists,
    required bool refundLedgerExists,
    required double releaseAmount,
    required double refundAmount,
    required double settlementTotal,
  }) {
    if (item.type == ResolutionCaseType.revision) {
      throw const FirestoreException(
        'Revision cases do not use admin settlement.',
      );
    }
    if (item.status == ResolutionCaseStatus.resolved ||
        item.settlementStatus == ResolutionSettlementStatus.completed ||
        item.resolutionDecision != ResolutionDecision.none) {
      throw const FirestoreException('This case has already been settled.');
    }
    if (settlementExists) {
      throw const FirestoreException(
        'Settlement record exists but case is not marked settled. Please contact admin.',
      );
    }
    if (releaseLedgerExists || refundLedgerExists) {
      throw const FirestoreException('This case has already been settled.');
    }
    if (order.orderId != item.orderId ||
        order.clientId != item.clientId ||
        order.freelancerId != item.freelancerId ||
        escrow.orderId != item.orderId ||
        escrow.clientId != item.clientId ||
        escrow.freelancerId != item.freelancerId) {
      throw const FirestoreException(
        'Settlement data does not match the order.',
      );
    }
    if (order.paymentStatus != ServiceOrderPaymentStatus.demoPaid ||
        !{
          ServiceOrderEscrowStatus.held,
          ServiceOrderEscrowStatus.disputed,
        }.contains(order.escrowStatus) ||
        !{
          EscrowHoldStatus.held,
          EscrowHoldStatus.disputed,
        }.contains(escrow.status)) {
      throw const FirestoreException('Escrow is not available for settlement.');
    }
    if (releaseAmount < 0 || refundAmount < 0 || settlementTotal <= 0) {
      throw const FirestoreException(
        'Enter a settlement amount greater than 0.',
      );
    }
    if (settlementTotal > escrow.amount) {
      throw const FirestoreException(
        'Settlement amount exceeds escrow amount.',
      );
    }
  }

  String _nextEvidenceRequestStatus({
    required String currentStatus,
    required String actorRole,
    required int clientEvidenceCount,
    required int freelancerEvidenceCount,
  }) {
    if (currentStatus == ResolutionEvidenceRequestStatus.requestedFromBoth) {
      return clientEvidenceCount > 0 && freelancerEvidenceCount > 0
          ? ResolutionEvidenceRequestStatus.submitted
          : currentStatus;
    }
    if (currentStatus == ResolutionEvidenceRequestStatus.requestedFromClient) {
      return actorRole == 'client'
          ? ResolutionEvidenceRequestStatus.submitted
          : currentStatus;
    }
    if (currentStatus ==
        ResolutionEvidenceRequestStatus.requestedFromFreelancer) {
      return actorRole == 'freelancer'
          ? ResolutionEvidenceRequestStatus.submitted
          : currentStatus;
    }
    return ResolutionEvidenceRequestStatus.submitted;
  }

  void _writeCustomerSettlementWallet({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> walletRef,
    required DocumentSnapshot<Map<String, dynamic>> walletDoc,
    required String clientId,
    required String currency,
    required double refundAmount,
    required double settlementTotal,
    required DateTime now,
  }) {
    if (!walletDoc.exists || walletDoc.data() == null) {
      final wallet = CustomerWalletModel(
        walletId: clientId,
        customerId: clientId,
        currency: currency,
        availableBalance: refundAmount,
        totalAdded: 0,
        totalSpent: 0,
        totalRefunded: refundAmount,
        totalEscrowed: 0,
        createdAt: now,
        updatedAt: now,
        lastTopUpAt: null,
        status: CustomerWalletStatus.active,
      );
      transaction.set(walletRef, wallet.toJson());
      return;
    }
    final wallet = CustomerWalletModel.fromFirestore(walletDoc);
    final nextEscrowed = wallet.totalEscrowed - settlementTotal;
    if (nextEscrowed < -0.01) {
      throw const FirestoreException(
        'Customer escrow balance is inconsistent.',
      );
    }
    transaction.set(walletRef, {
      if (refundAmount > 0)
        'availableBalance': FieldValue.increment(refundAmount),
      if (refundAmount > 0) 'totalRefunded': FieldValue.increment(refundAmount),
      'totalEscrowed': FieldValue.increment(-settlementTotal),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
  }

  void _writeFreelancerSettlementWallet({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> walletRef,
    required DocumentSnapshot<Map<String, dynamic>>? walletDoc,
    required String freelancerId,
    required String currency,
    required double releaseAmount,
    required DateTime now,
  }) {
    if (walletDoc == null || !walletDoc.exists || walletDoc.data() == null) {
      final wallet = FreelancerWalletModel.empty(
        freelancerId: freelancerId,
        currency: currency,
        now: now,
      );
      transaction.set(walletRef, {
        ...wallet.toJson(),
        'pendingBalance': releaseAmount,
        'ordersThisMonth': 1,
      });
      return;
    }
    transaction.set(walletRef, {
      'walletId': freelancerId,
      'freelancerId': freelancerId,
      'currency': currency,
      'pendingBalance': FieldValue.increment(releaseAmount),
      'ordersThisMonth': FieldValue.increment(1),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _walletLedgerPayload({
    required String transactionId,
    required String ownerId,
    required String ownerType,
    required String type,
    required double amount,
    required String currency,
    required String orderId,
    required String caseId,
    required String description,
    required DateTime now,
  }) {
    return {
      'transactionId': transactionId,
      'ownerId': ownerId,
      'ownerType': ownerType,
      'walletId': ownerId,
      'type': type,
      'direction': WalletTransactionDirection.credit,
      'amount': amount,
      'currency': currency,
      'status': WalletTransactionStatus.completed,
      'orderId': orderId,
      'caseId': caseId,
      'description': description,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  double _demoSettlementTotal(
    ResolutionCaseModel item,
    ServiceOrderModel order,
  ) {
    final snapshotAmount = item.orderSnapshot['amount'];
    if (snapshotAmount is num) return snapshotAmount.toDouble();
    if (snapshotAmount is String) {
      final parsed = double.tryParse(snapshotAmount);
      if (parsed != null) return parsed;
    }
    if (order.totalAmount > 0) return order.totalAmount;
    final known =
        item.releaseAmount + item.refundAmount + item.requestedRefundAmount;
    return known > 0 ? known : 0;
  }

  Map<String, dynamic> _demoLedgerPayload({
    required String transactionId,
    required String userId,
    required String role,
    required double amount,
    required String currency,
    required String type,
    required String direction,
    required String caseId,
    required String orderId,
    required String adminId,
    required DateTime now,
  }) {
    return {
      'transactionId': transactionId,
      'userId': userId,
      'ownerId': userId,
      'ownerType': role,
      'role': role,
      'walletId': userId,
      'amount': amount,
      'currency': currency,
      'type': type,
      'direction': direction,
      'status': WalletTransactionStatus.completed,
      'demoMode': true,
      'caseId': caseId,
      'orderId': orderId,
      'createdBy': adminId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  String _settlementId(String caseId) => 'settlement_$caseId';

  String _releaseLedgerId(String caseId, String decision) {
    return decision == ResolutionDecision.splitRelease
        ? 'wallet_split_release_$caseId'
        : 'wallet_release_$caseId';
  }

  String _refundLedgerId(String caseId, String decision) {
    return decision == ResolutionDecision.splitRelease
        ? 'wallet_split_refund_$caseId'
        : 'wallet_refund_$caseId';
  }

  String _financialOperation(String decision) {
    return switch (decision) {
      ResolutionDecision.releaseToFreelancer => 'executeReleaseToFreelancer',
      ResolutionDecision.refundToClient => 'executeRefundToCustomer',
      ResolutionDecision.splitRelease => 'executeSplitSettlement',
      _ => 'executeSettlement',
    };
  }

  void _logFinancialStep({
    required String operation,
    required String step,
    required String caseId,
    required String adminId,
    required double releaseAmount,
    required double refundAmount,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ResolutionDeskV3Step] operation=$operation step=$step '
      'caseId=$caseId uid=$adminId releaseAmount=$releaseAmount '
      'refundAmount=$refundAmount',
    );
  }

  void _logResolutionDeskV3Action({
    required String caseId,
    required String caseType,
    required String openedByRole,
    required String action,
    required String adminId,
    required String orderId,
    required double releaseAmount,
    required double refundAmount,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ResolutionDeskV3Action] caseId=$caseId caseType=$caseType '
      'openedByRole=$openedByRole action=$action adminId=$adminId '
      'orderId=$orderId releaseAmount=$releaseAmount '
      'refundAmount=$refundAmount',
    );
  }

  void _logFinancialError({
    required String operation,
    required String step,
    required String caseId,
    required String adminId,
    required String code,
    required String message,
    required StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[FirestorePermissionDenied] feature=ResolutionDeskV3 '
      'repository=ResolutionV2Repository operation=$operation step=$step '
      'caseId=$caseId adminId=$adminId code=$code message=$message '
      'stack=$stackTrace',
    );
  }

  ResolutionCaseModel _caseFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists || doc.data() == null) {
      throw const FirestoreException('Resolution case not found.');
    }
    return ResolutionCaseModel.fromFirestore(doc);
  }

  void _setEvent(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> caseRef, {
    required String actorId,
    required String actorRole,
    required String eventType,
    required String message,
    required DateTime now,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    final eventRef = caseRef.collection('events').doc();
    transaction.set(eventRef, {
      'eventId': eventRef.id,
      'caseId': caseRef.id,
      'actorId': actorId,
      'actorRole': actorRole,
      'eventType': eventType,
      'message': message,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(now),
    });
  }

  Future<void> _addEvent({
    required String caseId,
    required String actorId,
    required String actorRole,
    required String eventType,
    required String message,
  }) async {
    final now = DateTime.now();
    final caseRef = _casesRef.doc(caseId);
    await _firestore.runTransaction((transaction) async {
      _caseFromDoc(await transaction.get(caseRef));
      _setEvent(
        transaction,
        caseRef,
        actorId: actorId,
        actorRole: actorRole,
        eventType: eventType,
        message: message,
        now: now,
      );
    });
  }

  FirestoreException _map(
    FirebaseException exception,
    String operation,
    String path,
    String uid,
  ) {
    return FirestorePermissionLogger.toFirestoreException(
      exception,
      feature: 'ResolutionV2',
      repository: 'ResolutionV2Repository',
      operation: operation,
      path: path,
      action: 'read/write',
      uid: uid,
    );
  }

  void _logAction({
    required String operation,
    required String path,
    required String uid,
    String? actorRole,
    String? caseId,
    Iterable<Object?>? keys,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ResolutionV2Action] operation=$operation path=$path uid=$uid '
      'role=${actorRole ?? 'unknown'} caseId=${caseId ?? '-'} '
      'keys=${keys?.map((key) => key.toString()).join(',') ?? '-'}',
    );
  }
}
