import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exceptions.dart';
import '../models/invoice_model.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/invoice_repository_impl.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'repository_providers.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepositoryImpl(ref.watch(firestoreProvider));
});

final myClientInvoicesProvider = StreamProvider<List<InvoiceModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <InvoiceModel>[]);
  return ref.watch(invoiceRepositoryProvider).watchClientInvoices(user.uid);
});

final myFreelancerInvoicesProvider = StreamProvider<List<InvoiceModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <InvoiceModel>[]);
  return ref.watch(invoiceRepositoryProvider).watchFreelancerInvoices(user.uid);
});

final adminInvoicesProvider = StreamProvider<List<InvoiceModel>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchAdminInvoices();
});

final orderInvoicesProvider = StreamProvider.family<List<InvoiceModel>, String>(
  (ref, orderId) {
    if (orderId.trim().isEmpty) return Stream.value(const <InvoiceModel>[]);
    return ref.watch(invoiceRepositoryProvider).watchOrderInvoices(orderId);
  },
);

final invoiceProvider = StreamProvider.family<InvoiceModel?, String>((
  ref,
  invoiceId,
) {
  if (invoiceId.trim().isEmpty) return Stream.value(null);
  return ref.watch(invoiceRepositoryProvider).watchInvoice(invoiceId);
});

final invoiceActionProvider =
    AsyncNotifierProvider<InvoiceActionNotifier, void>(
      InvoiceActionNotifier.new,
    );

class InvoiceActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> generateForOrder(String orderId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in first.');
      await ref
          .read(invoiceRepositoryProvider)
          .generateInvoicesForOrder(orderId: orderId, actorId: user.uid);
    });
    return !state.hasError;
  }

  String? get errorMessage {
    final error = state.error;
    if (error == null) return null;
    if (error is AppException) return error.message;
    final message = error.toString();
    if (message.contains('Dart exception thrown from converted Future')) {
      return 'Unable to generate invoices. Please try again.';
    }
    return message;
  }
}
