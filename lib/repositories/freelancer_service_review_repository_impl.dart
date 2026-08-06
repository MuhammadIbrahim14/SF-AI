import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/freelancer_service_review_model.dart';
import '../models/service_request_model.dart';
import 'freelancer_service_review_repository.dart';

class FreelancerServiceReviewRepositoryImpl
    implements FreelancerServiceReviewRepository {
  const FreelancerServiceReviewRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reviewsRef =>
      _firestore.collection('serviceReviews');

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('serviceRequests');

  @override
  Future<void> createReview(FreelancerServiceReviewModel review) async {
    try {
      final requestId = review.serviceRequestId.trim();
      if (requestId.isEmpty) {
        throw const FirestoreException('Completed request is required.');
      }

      await _firestore.runTransaction((transaction) async {
        final requestRef = _requestsRef.doc(requestId);
        final reviewRef = _reviewsRef.doc(requestId);
        final requestDoc = await transaction.get(requestRef);
        final existingReview = await transaction.get(reviewRef);

        if (!requestDoc.exists || requestDoc.data() == null) {
          throw const FirestoreException('Service request not found.');
        }
        if (existingReview.exists) {
          throw const FirestoreException(
            'A review already exists for this request.',
          );
        }

        final request = ServiceRequestModel.fromFirestore(requestDoc);
        if (request.status != ServiceRequestStatus.completed) {
          throw const FirestoreException(
            'Only completed service requests can be reviewed.',
          );
        }
        if (request.clientId != review.clientId) {
          throw const FirestoreException(
            'You can only review your own completed requests.',
          );
        }
        if (request.freelancerId == review.clientId) {
          throw const FirestoreException(
            'Freelancers cannot review their own services.',
          );
        }
        if (request.serviceId != review.serviceId ||
            request.freelancerId != review.freelancerId) {
          throw const FirestoreException(
            'Review does not match the completed request.',
          );
        }

        final now = DateTime.now();
        final payload = review
            .copyWith(
              reviewId: requestId,
              serviceRequestId: requestId,
              serviceTitle: request.serviceTitle,
              createdAt: now,
              updatedAt: now,
              isVisible: true,
            )
            .toJson();
        transaction.set(reviewRef, payload);
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to create review: ${e.toString()}');
    }
  }

  @override
  Stream<List<FreelancerServiceReviewModel>> watchVisibleReviews() {
    return _reviewsRef.where('isVisible', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final reviews = snapshot.docs
          .map(FreelancerServiceReviewModel.fromFirestore)
          .toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    });
  }

  @override
  Stream<List<FreelancerServiceReviewModel>> watchServiceReviews(
    String serviceId,
  ) {
    return _reviewsRef
        .where('serviceId', isEqualTo: serviceId)
        .where('isVisible', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
              .map(FreelancerServiceReviewModel.fromFirestore)
              .toList();
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  @override
  Stream<List<FreelancerServiceReviewModel>> watchFreelancerReviews(
    String freelancerId,
  ) {
    return _reviewsRef
        .where('freelancerId', isEqualTo: freelancerId)
        .where('isVisible', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
              .map(FreelancerServiceReviewModel.fromFirestore)
              .toList();
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  @override
  Stream<FreelancerServiceReviewModel?> watchRequestReview(
    String serviceRequestId,
  ) {
    return _reviewsRef.doc(serviceRequestId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final review = FreelancerServiceReviewModel.fromFirestore(doc);
      return review.isVisible ? review : null;
    });
  }
}
