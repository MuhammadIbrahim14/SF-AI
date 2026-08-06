import '../models/freelancer_service_model.dart';

abstract class FreelancerServiceRepository {
  Future<String> createService(FreelancerServiceModel service);
  Future<void> updateService(FreelancerServiceModel service);
  Future<void> deleteService({
    required String serviceId,
    required String freelancerId,
  });
  Future<String> duplicateService({
    required String serviceId,
    required String freelancerId,
  });
  Future<void> publishService({
    required String serviceId,
    required String freelancerId,
  });
  Future<void> unpublishService({
    required String serviceId,
    required String freelancerId,
  });
  Stream<List<FreelancerServiceModel>> watchMyServices(String freelancerId);
  Stream<List<FreelancerServiceModel>> watchPublishedServices();
  Stream<FreelancerServiceModel?> watchService(String serviceId);
}
