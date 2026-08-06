import '../models/invoice_model.dart';

abstract class InvoiceRepository {
  Stream<List<InvoiceModel>> watchClientInvoices(String clientId);

  Stream<List<InvoiceModel>> watchFreelancerInvoices(String freelancerId);

  Stream<List<InvoiceModel>> watchAdminInvoices();

  Stream<List<InvoiceModel>> watchOrderInvoices(String orderId);

  Stream<InvoiceModel?> watchInvoice(String invoiceId);

  Future<List<String>> generateInvoicesForOrder({
    required String orderId,
    required String actorId,
  });
}
