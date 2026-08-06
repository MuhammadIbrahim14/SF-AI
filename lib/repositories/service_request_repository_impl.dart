import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/service_request_model.dart';
import 'service_request_repository.dart';

class ServiceRequestRepositoryImpl implements ServiceRequestRepository {
  const ServiceRequestRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('serviceRequests');

  @override
  Future<String> createRequest(ServiceRequestModel request) async {
    try {
      final doc = request.requestId.trim().isEmpty
          ? _requestsRef.doc()
          : _requestsRef.doc(request.requestId);
      final now = DateTime.now();
      final payload = request
          .copyWith(
            requestId: doc.id,
            status: ServiceRequestStatus.pending,
            createdAt: now,
            updatedAt: now,
          )
          .toJson();
      await doc.set(payload);
      return doc.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create request: ${e.toString()}');
    }
  }

  @override
  Future<ServiceRequestModel?> getRequest(String requestId) async {
    try {
      final trimmed = requestId.trim();
      if (trimmed.isEmpty) return null;
      final doc = await _requestsRef.doc(trimmed).get();
      if (!doc.exists || doc.data() == null) return null;
      return ServiceRequestModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load request: ${e.toString()}');
    }
  }

  @override
  Stream<List<ServiceRequestModel>> watchClientRequests(String clientId) {
    return _requestsRef.where('clientId', isEqualTo: clientId).snapshots().map((
      snapshot,
    ) {
      final requests = snapshot.docs
          .map(ServiceRequestModel.fromFirestore)
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  @override
  Stream<List<ServiceRequestModel>> watchFreelancerRequests(
    String freelancerId,
  ) {
    return _requestsRef
        .where('freelancerId', isEqualTo: freelancerId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(ServiceRequestModel.fromFirestore)
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  @override
  Stream<ServiceRequestModel?> watchRequest(String requestId) {
    return _requestsRef.doc(requestId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ServiceRequestModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> updateFreelancerStatus({
    required String requestId,
    required String freelancerId,
    required String status,
    String? freelancerNote,
  }) async {
    try {
      final request = await _loadRequest(requestId);
      _assertFreelancer(request, freelancerId);
      final normalized = ServiceRequestStatus.normalize(status);
      _assertFreelancerTransition(request.status, normalized);
      final now = DateTime.now();
      final updates = <String, dynamic>{
        'status': normalized,
        'updatedAt': Timestamp.fromDate(now),
      };
      if (freelancerNote != null) updates['freelancerNote'] = freelancerNote;
      if (normalized == ServiceRequestStatus.accepted) {
        updates['acceptedAt'] = Timestamp.fromDate(now);
      }
      if (normalized == ServiceRequestStatus.delivered) {
        updates['deliveredAt'] = Timestamp.fromDate(now);
      }
      if (normalized == ServiceRequestStatus.completed) {
        updates['completedAt'] = Timestamp.fromDate(now);
      }
      if (normalized == ServiceRequestStatus.rejected) {
        updates['cancelledAt'] = Timestamp.fromDate(now);
      }
      await _requestsRef.doc(requestId).set(updates, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to update request: ${e.toString()}');
    }
  }

  @override
  Future<void> cancelClientRequest({
    required String requestId,
    required String clientId,
    String? clientNote,
  }) async {
    try {
      final request = await _loadRequest(requestId);
      _assertClient(request, clientId);
      if (!request.canClientCancel) {
        throw const FirestoreException(
          'Only pending requests can be cancelled by the client.',
        );
      }
      final now = DateTime.now();
      await _requestsRef.doc(requestId).set({
        'status': ServiceRequestStatus.cancelled,
        'clientNote': clientNote,
        'updatedAt': Timestamp.fromDate(now),
        'cancelledAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to cancel request: ${e.toString()}');
    }
  }

  @override
  Future<void> completeClientRequest({
    required String requestId,
    required String clientId,
    String? clientNote,
  }) async {
    try {
      final request = await _loadRequest(requestId);
      _assertClient(request, clientId);
      if (!request.canClientComplete) {
        throw const FirestoreException(
          'Only delivered requests can be marked completed.',
        );
      }
      final now = DateTime.now();
      await _requestsRef.doc(requestId).set({
        'status': ServiceRequestStatus.completed,
        'clientNote': clientNote,
        'updatedAt': Timestamp.fromDate(now),
        'completedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to complete request: ${e.toString()}');
    }
  }

  Future<ServiceRequestModel> _loadRequest(String requestId) async {
    final doc = await _requestsRef.doc(requestId).get();
    if (!doc.exists || doc.data() == null) {
      throw const FirestoreException('Service request not found.');
    }
    return ServiceRequestModel.fromFirestore(doc);
  }

  void _assertFreelancer(ServiceRequestModel request, String freelancerId) {
    if (request.freelancerId != freelancerId) {
      throw const FirestoreException(
        'You can only manage requests assigned to you.',
      );
    }
  }

  void _assertFreelancerTransition(String currentStatus, String nextStatus) {
    final isValid = switch (currentStatus) {
      ServiceRequestStatus.pending =>
        nextStatus == ServiceRequestStatus.accepted ||
            nextStatus == ServiceRequestStatus.rejected,
      _ => false,
    };
    if (!isValid) {
      throw const FirestoreException(
        'This service request cannot move to that status.',
      );
    }
  }

  void _assertClient(ServiceRequestModel request, String clientId) {
    if (request.clientId != clientId) {
      throw const FirestoreException('You can only manage your own requests.');
    }
  }
}
