import '../models/service_order_model.dart';
import '../models/service_order_delivery_model.dart';

abstract class CommerceOrderRepository {
  Future<String> createOrderFromServiceRequest({
    required String serviceRequestId,
    required String clientId,
  });

  Stream<List<ServiceOrderModel>> watchClientOrders(String clientId);
  Stream<List<ServiceOrderModel>> watchFreelancerOrders(String freelancerId);
  Stream<List<ServiceOrderModel>> watchAdminOrders();
  Stream<ServiceOrderModel?> watchOrder(String orderId);
  Future<ServiceOrderModel?> getOrder(String orderId);
  Stream<List<ServiceOrderDeliveryModel>> watchOrderDeliveries(String orderId);
  Stream<ServiceOrderModel?> watchOrderByServiceRequestId(
    String serviceRequestId,
  );
  Future<ServiceOrderModel?> getOrderByServiceRequestId(
    String serviceRequestId,
  );
  Future<void> confirmSandboxPayment({
    required String orderId,
    required String clientId,
    required String paymentMethod,
  });
  Future<void> cancelOrder({required String orderId, required String clientId});
  Future<void> startWork({
    required String orderId,
    required String freelancerId,
  });
  Future<void> submitDelivery({
    required String orderId,
    required String freelancerId,
    required String message,
    required List<String> attachmentUrls,
    List<Map<String, dynamic>> attachmentMetadata = const [],
  });
}
