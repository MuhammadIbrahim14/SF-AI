import '../models/freelancer_service_review_model.dart';

abstract class FreelancerServiceReviewRepository {
  Future<void> createReview(FreelancerServiceReviewModel review);
  Stream<List<FreelancerServiceReviewModel>> watchVisibleReviews();
  Stream<List<FreelancerServiceReviewModel>> watchServiceReviews(
    String serviceId,
  );
  Stream<List<FreelancerServiceReviewModel>> watchFreelancerReviews(
    String freelancerId,
  );
  Stream<FreelancerServiceReviewModel?> watchRequestReview(
    String serviceRequestId,
  );
}
