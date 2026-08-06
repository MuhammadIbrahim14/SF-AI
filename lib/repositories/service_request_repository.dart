import '../models/service_request_model.dart';

abstract class ServiceRequestRepository {
  Future<String> createRequest(ServiceRequestModel request);
  Future<ServiceRequestModel?> getRequest(String requestId);
  Stream<List<ServiceRequestModel>> watchClientRequests(String clientId);
  Stream<List<ServiceRequestModel>> watchFreelancerRequests(
    String freelancerId,
  );
  Stream<ServiceRequestModel?> watchRequest(String requestId);
  Future<void> updateFreelancerStatus({
    required String requestId,
    required String freelancerId,
    required String status,
    String? freelancerNote,
  });
  Future<void> cancelClientRequest({
    required String requestId,
    required String clientId,
    String? clientNote,
  });
  Future<void> completeClientRequest({
    required String requestId,
    required String clientId,
    String? clientNote,
  });
}
