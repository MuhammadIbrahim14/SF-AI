import '../models/freelancer_model.dart';

abstract class FreelancerRepository {
  Future<void> createFreelancer(FreelancerModel freelancer);
  Future<FreelancerModel?> getFreelancer(String userId);
  Stream<FreelancerModel?> freelancerStream(String userId);
  Future<void> updateFreelancer({
    required String userId,
    required Map<String, dynamic> data,
  });
}
