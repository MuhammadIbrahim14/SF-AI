import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/app_exceptions.dart';
import '../core/services/firestore_permission_logger.dart';
import '../models/invoice_model.dart';
import '../models/service_order_model.dart';
import 'invoice_repository.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  const InvoiceRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _invoicesRef =>
      _firestore.collection('invoices');

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('serviceOrders');

  @override
  Stream<List<InvoiceModel>> watchClientInvoices(String clientId) {
    return _invoicesRef.where('clientId', isEqualTo: clientId).snapshots().map((
      snapshot,
    ) {
      final invoices = snapshot.docs.map(InvoiceModel.fromFirestore).toList();
      invoices.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      return invoices;
    });
  }

  @override
  Stream<List<InvoiceModel>> watchFreelancerInvoices(String freelancerId) {
    return _invoicesRef
        .where('freelancerId', isEqualTo: freelancerId)
        .snapshots()
        .map((snapshot) {
          final invoices = snapshot.docs
              .map(InvoiceModel.fromFirestore)
              .toList();
          invoices.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
          return invoices;
        });
  }

  @override
  Stream<List<InvoiceModel>> watchAdminInvoices() {
    return _invoicesRef.snapshots().map((snapshot) {
      final invoices = snapshot.docs.map(InvoiceModel.fromFirestore).toList();
      invoices.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      return invoices;
    });
  }

  @override
  Stream<List<InvoiceModel>> watchOrderInvoices(String orderId) {
    return _invoicesRef.where('orderId', isEqualTo: orderId).snapshots().map((
      snapshot,
    ) {
      final invoices = snapshot.docs.map(InvoiceModel.fromFirestore).toList();
      invoices.sort((a, b) => a.type.compareTo(b.type));
      return invoices;
    });
  }

  @override
  Stream<InvoiceModel?> watchInvoice(String invoiceId) {
    return _invoicesRef.doc(invoiceId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return InvoiceModel.fromFirestore(doc);
    });
  }

  @override
  Future<List<String>> generateInvoicesForOrder({
    required String orderId,
    required String actorId,
  }) async {
    try {
      final trimmedOrderId = orderId.trim();
      if (trimmedOrderId.isEmpty) {
        throw const FirestoreException('Order is required.');
      }
      _logInvoiceStep(
        'start',
        actorId,
        trimmedOrderId,
        detail: 'path=serviceOrders/$trimmedOrderId',
      );
      final created = <String>[];
      var currentStep = 'start';
      await _firestore.runTransaction((transaction) async {
        currentStep = 'readOrder';
        final orderRef = _ordersRef.doc(trimmedOrderId);
        _logInvoiceStep(
          currentStep,
          actorId,
          trimmedOrderId,
          detail: 'path=serviceOrders/$trimmedOrderId',
        );
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists || orderDoc.data() == null) {
          throw const FirestoreException('Order not found.');
        }

        final order = ServiceOrderModel.fromFirestore(orderDoc);
        currentStep = 'validateOrder';
        _logInvoiceStep(
          currentStep,
          actorId,
          trimmedOrderId,
          detail:
              'clientId=${order.clientId} freelancerId=${order.freelancerId} '
              'paymentStatus=${order.paymentStatus} '
              'escrowStatus=${order.escrowStatus}',
        );
        final actorCanGenerate =
            order.clientId == actorId || order.freelancerId == actorId;
        if (!actorCanGenerate) {
          throw const FirestoreException(
            'You can only generate invoices for your own orders.',
          );
        }
        if (order.paymentStatus == ServiceOrderPaymentStatus.unpaid) {
          throw const FirestoreException(
            'Invoices are available after sandbox payment is completed.',
          );
        }

        final now = DateTime.now();
        final preparedInvoices = InvoiceType.values
            .map((type) => invoiceFromOrder(order, type: type, now: now))
            .toList();
        final preparedRefs = preparedInvoices
            .map((invoice) => _invoicesRef.doc(invoice.invoiceId))
            .toList();
        final preparedDocs = <DocumentSnapshot<Map<String, dynamic>>>[];

        for (var index = 0; index < preparedInvoices.length; index++) {
          final invoice = preparedInvoices[index];
          currentStep = 'readInvoice:${invoice.type}';
          _logInvoiceStep(
            currentStep,
            actorId,
            trimmedOrderId,
            detail: 'path=invoices/${invoice.invoiceId}',
          );
          preparedDocs.add(await transaction.get(preparedRefs[index]));
        }

        for (var index = 0; index < preparedInvoices.length; index++) {
          final invoice = preparedInvoices[index];
          if (preparedDocs[index].exists) continue;
          final invoiceRef = preparedRefs[index];
          currentStep = 'createInvoice:${invoice.type}';
          _logInvoiceStep(
            currentStep,
            actorId,
            trimmedOrderId,
            detail:
                'path=invoices/${invoice.invoiceId} '
                'keys=${invoice.toJson().keys.toList()}',
          );
          transaction.set(invoiceRef, invoice.toJson());
          created.add(invoice.invoiceId);
        }
      });
      _logInvoiceStep(
        'success',
        actorId,
        trimmedOrderId,
        detail: 'created=${created.join(',')}',
      );
      return created;
    } on FirebaseException catch (e) {
      _logInvoiceError(
        actorId: actorId,
        orderId: orderId,
        code: e.code,
        message: e.message ?? e.toString(),
        stackTrace: e.stackTrace,
      );
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'InvoiceGeneration',
        repository: 'InvoiceRepositoryImpl',
        operation: 'generateInvoicesForOrder',
        path: 'serviceOrders/${orderId.trim()} + invoices',
        action: 'transaction',
        uid: actorId,
        accountType: 'commerce',
      );
    } on FirestoreException catch (e, stackTrace) {
      _logInvoiceError(
        actorId: actorId,
        orderId: orderId,
        code: e.code ?? 'invoice-validation',
        message: e.message,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      final message = e.toString();
      _logInvoiceError(
        actorId: actorId,
        orderId: orderId,
        code: e.runtimeType.toString(),
        message: message,
        stackTrace: stackTrace,
      );
      if (message.contains('Dart exception thrown from converted Future')) {
        throw const FirestoreException(
          'Unable to generate invoices. Please try again.',
        );
      }
      throw FirestoreException('Failed to generate invoices: $message');
    }
  }

  void _logInvoiceStep(
    String step,
    String actorId,
    String orderId, {
    String? detail,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[InvoiceGeneration] step=$step actorId=$actorId orderId=$orderId'
      '${detail == null ? '' : ' $detail'}',
    );
  }

  void _logInvoiceError({
    required String actorId,
    required String orderId,
    required String code,
    required String message,
    required StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[InvoiceGenerationError] actorId=$actorId orderId=$orderId '
      'code=$code message=$message stack=$stackTrace',
    );
  }
}

InvoiceModel invoiceFromOrder(
  ServiceOrderModel order, {
  required String type,
  required DateTime now,
}) {
  final normalizedType = InvoiceType.normalize(type);
  final paidAt = order.paidAt ?? now;
  final invoiceId = invoiceIdForOrder(order.orderId, normalizedType);
  final invoiceNumber = _invoiceNumber(order, normalizedType, now);
  final isFreelancer = normalizedType == InvoiceType.freelancerInvoice;
  final isCommission = normalizedType == InvoiceType.platformCommissionInvoice;
  final subtotal = isCommission
      ? order.platformFee
      : isFreelancer
      ? order.subtotal
      : order.subtotal;
  final platformFee = isCommission ? order.platformFee : order.platformFee;
  final total = isCommission
      ? order.platformFee
      : isFreelancer
      ? order.freelancerEarnings
      : order.totalAmount;

  return InvoiceModel(
    invoiceId: invoiceId,
    orderId: order.orderId,
    clientId: order.clientId,
    freelancerId: order.freelancerId,
    invoiceNumber: invoiceNumber,
    type: normalizedType,
    status: order.paymentStatus == ServiceOrderPaymentStatus.unpaid
        ? InvoiceStatus.issued
        : InvoiceStatus.paid,
    currency: order.currency,
    subtotal: subtotal,
    platformFee: platformFee,
    taxAmount: order.taxTotal,
    totalAmount: total,
    issuedAt: now,
    dueAt: paidAt,
    paidAt: order.paymentStatus == ServiceOrderPaymentStatus.unpaid
        ? null
        : paidAt,
    createdAt: now,
    updatedAt: now,
    platformName: 'SkillForge AI',
    platformEmail: 'support@skillforge.ai',
    platformWebsite: 'https://skillforge.ai',
    clientName: order.clientName,
    clientEmail: order.clientEmail,
    freelancerName: order.freelancerName,
    freelancerEmail: '',
    serviceTitle: order.serviceTitle,
    serviceDescription: order.serviceCategory.trim().isEmpty
        ? 'Sandbox service order ${order.orderNumber}'
        : '${order.serviceCategory} service order ${order.orderNumber}',
    verificationCode: _verificationCode(order.orderId, normalizedType),
  );
}

String invoiceIdForOrder(String orderId, String type) {
  return '${orderId}_${InvoiceType.normalize(type)}';
}

String _invoiceNumber(ServiceOrderModel order, String type, DateTime now) {
  final prefix = switch (InvoiceType.normalize(type)) {
    InvoiceType.freelancerInvoice => 'FR',
    InvoiceType.platformCommissionInvoice => 'PC',
    _ => 'CR',
  };
  final suffix = order.orderId.length <= 6
      ? order.orderId.toUpperCase()
      : order.orderId.substring(0, 6).toUpperCase();
  return 'INV-$prefix-${now.year}-$suffix';
}

String _verificationCode(String orderId, String type) {
  final suffix = orderId.length <= 8
      ? orderId.toUpperCase()
      : orderId.substring(0, 8).toUpperCase();
  final typeCode = switch (InvoiceType.normalize(type)) {
    InvoiceType.freelancerInvoice => 'FR',
    InvoiceType.platformCommissionInvoice => 'PC',
    _ => 'CR',
  };
  return 'SF-$typeCode-$suffix';
}
