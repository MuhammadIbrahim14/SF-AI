import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../core/services/firestore_permission_logger.dart';
import '../models/commerce_transaction_model.dart';
import '../models/commission_ledger_model.dart';
import '../models/escrow_hold_model.dart';
import '../models/freelancer_service_model.dart';
import '../models/invoice_model.dart';
import '../models/service_order_model.dart';
import '../models/service_order_delivery_model.dart';
import '../models/service_request_model.dart';
import 'commerce_order_repository.dart';
import 'invoice_repository_impl.dart';

class CommerceOrderRepositoryImpl implements CommerceOrderRepository {
  const CommerceOrderRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('serviceOrders');

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('serviceRequests');

  CollectionReference<Map<String, dynamic>> get _servicesRef =>
      _firestore.collection('freelancerServices');

  CollectionReference<Map<String, dynamic>> get _escrowsRef =>
      _firestore.collection('serviceEscrows');

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('commerceTransactions');

  CollectionReference<Map<String, dynamic>> get _commissionLedgerRef =>
      _firestore.collection('commissionLedger');

  CollectionReference<Map<String, dynamic>> get _walletsRef =>
      _firestore.collection('freelancerWallets');

  CollectionReference<Map<String, dynamic>> get _invoicesRef =>
      _firestore.collection('invoices');

  @override
  Future<String> createOrderFromServiceRequest({
    required String serviceRequestId,
    required String clientId,
  }) async {
    try {
      final orderId = serviceRequestId.trim();
      if (orderId.isEmpty) {
        throw const FirestoreException('Service request is required.');
      }

      final requestRef = _requestsRef.doc(orderId);
      final orderRef = _ordersRef.doc(orderId);
      final requestDoc = await requestRef.get();

      if (!requestDoc.exists || requestDoc.data() == null) {
        throw const FirestoreException('Service request not found.');
      }

      final request = ServiceRequestModel.fromFirestore(requestDoc);
      _assertOrderEligible(request, clientId);

      FreelancerServiceModel? service;
      if (request.budget <= 0 && request.serviceId.trim().isNotEmpty) {
        final serviceDoc = await _servicesRef.doc(request.serviceId).get();
        if (serviceDoc.exists && serviceDoc.data() != null) {
          service = FreelancerServiceModel.fromFirestore(serviceDoc);
        }
      }

      final package = _packageFrom(request, service);
      final subtotal = package.price > 0
          ? package.price
          : _amountFrom(request, service);
      final currency = request.currency.trim().isEmpty
          ? service?.currency ?? 'USD'
          : request.currency;
      final platformFee =
          subtotal * SandboxCommerceConfig.platformCommissionPercent;
      final taxTotal = 0.0;
      final totalAmount = subtotal + taxTotal;
      final freelancerEarnings = subtotal - platformFee;
      final now = DateTime.now();
      final deliveryDays = package.deliveryDays;
      final dueDate = now.add(Duration(days: deliveryDays));
      final order = ServiceOrderModel(
        orderId: orderId,
        orderNumber: _orderNumber(orderId, now),
        serviceRequestId: request.requestId,
        serviceId: request.serviceId,
        serviceTitle: request.serviceTitle,
        serviceCategory: request.serviceCategory,
        clientId: request.clientId ?? clientId,
        clientName: request.clientName,
        clientEmail: request.clientEmail,
        freelancerId: request.freelancerId,
        freelancerName: request.freelancerName,
        subtotal: subtotal,
        platformFee: platformFee,
        taxTotal: taxTotal,
        taxBreakdown: const [],
        totalAmount: totalAmount,
        freelancerEarnings: freelancerEarnings,
        currency: currency,
        selectedPackageId: package.packageId,
        selectedPackageTitle: package.title,
        selectedPackagePrice: package.price,
        selectedDeliveryDays: package.deliveryDays,
        selectedRevisionsIncluded: package.revisionsIncluded,
        paymentStatus: ServiceOrderPaymentStatus.unpaid,
        escrowStatus: ServiceOrderEscrowStatus.notFunded,
        orderStatus: ServiceOrderStatus.pending,
        deliveryStatus: ServiceOrderDeliveryStatus.none,
        revisionCount: 0,
        revisionLimit: package.revisionsIncluded,
        revisionStatus: null,
        revisionNotes: null,
        isMilestoneBased: false,
        milestoneIds: const [],
        createdAt: now,
        updatedAt: now,
        acceptedAt: request.acceptedAt,
        workStartedAt: null,
        dueDate: dueDate,
        paidAt: null,
        escrowHeldAt: null,
        expectedReleaseAt: null,
        escrowReleasedAt: null,
        fundsClearedAt: null,
        sandboxPaymentMethod: null,
        transactionReference: null,
        lastDeliveryId: null,
        deliveredAt: null,
        reviewDueAt: null,
        completedAt: null,
        cancelledAt: null,
      );

      await _firestore.runTransaction((transaction) async {
        transaction.set(orderRef, order.toJson());
      });

      return orderId;
    } on FirebaseException catch (e) {
      final attemptedOrderId = serviceRequestId.trim();
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'Commerce',
        repository: 'CommerceOrderRepositoryImpl',
        operation: 'createOrderFromServiceRequest',
        path:
            'serviceRequests/$attemptedOrderId + serviceOrders/$attemptedOrderId + freelancerServices',
        action: 'transaction',
        uid: clientId,
      );
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to create order: ${e.toString()}');
    }
  }

  @override
  Stream<List<ServiceOrderModel>> watchClientOrders(String clientId) {
    return _ordersRef.where('clientId', isEqualTo: clientId).snapshots().map((
      snapshot,
    ) {
      final orders = snapshot.docs
          .map(ServiceOrderModel.fromFirestore)
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  @override
  Stream<List<ServiceOrderModel>> watchFreelancerOrders(String freelancerId) {
    return _ordersRef
        .where('freelancerId', isEqualTo: freelancerId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map(ServiceOrderModel.fromFirestore)
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  @override
  Stream<List<ServiceOrderModel>> watchAdminOrders() {
    return _ordersRef.snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map(ServiceOrderModel.fromFirestore)
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  @override
  Stream<ServiceOrderModel?> watchOrder(String orderId) {
    return _ordersRef.doc(orderId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ServiceOrderModel.fromFirestore(doc);
    });
  }

  @override
  Future<ServiceOrderModel?> getOrder(String orderId) async {
    try {
      final trimmed = orderId.trim();
      if (trimmed.isEmpty) return null;
      final doc = await _ordersRef.doc(trimmed).get();
      if (!doc.exists || doc.data() == null) return null;
      return ServiceOrderModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load order: ${e.toString()}');
    }
  }

  @override
  Stream<List<ServiceOrderDeliveryModel>> watchOrderDeliveries(String orderId) {
    final trimmed = orderId.trim();
    if (trimmed.isEmpty) {
      return Stream.value(const <ServiceOrderDeliveryModel>[]);
    }
    return _ordersRef.doc(trimmed).collection('deliveries').snapshots().map((
      snapshot,
    ) {
      final deliveries = snapshot.docs
          .map(ServiceOrderDeliveryModel.fromFirestore)
          .toList();
      deliveries.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return deliveries;
    });
  }

  @override
  Stream<ServiceOrderModel?> watchOrderByServiceRequestId(
    String serviceRequestId,
  ) {
    return watchOrder(serviceRequestId);
  }

  @override
  Future<ServiceOrderModel?> getOrderByServiceRequestId(
    String serviceRequestId,
  ) async {
    try {
      final doc = await _ordersRef.doc(serviceRequestId).get();
      if (!doc.exists || doc.data() == null) return null;
      return ServiceOrderModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load order: ${e.toString()}');
    }
  }

  @override
  Future<void> confirmSandboxPayment({
    required String orderId,
    required String clientId,
    required String paymentMethod,
  }) async {
    try {
      final trimmedOrderId = orderId.trim();
      final method = paymentMethod.trim();
      if (trimmedOrderId.isEmpty) {
        throw const FirestoreException('Order is required.');
      }
      if (method.isEmpty) {
        throw const FirestoreException('Choose a sandbox payment method.');
      }

      final orderRef = _ordersRef.doc(trimmedOrderId);
      final escrowRef = _escrowsRef.doc(trimmedOrderId);
      final transactionRef = _transactionsRef.doc(
        _transactionId(trimmedOrderId),
      );
      final commissionRef = _commissionLedgerRef.doc(
        _commissionId(trimmedOrderId),
      );
      final invoiceRefs = [
        _invoicesRef.doc(
          invoiceIdForOrder(trimmedOrderId, InvoiceType.clientReceipt),
        ),
        _invoicesRef.doc(
          invoiceIdForOrder(trimmedOrderId, InvoiceType.freelancerInvoice),
        ),
        _invoicesRef.doc(
          invoiceIdForOrder(
            trimmedOrderId,
            InvoiceType.platformCommissionInvoice,
          ),
        ),
      ];

      final preflight = await Future.wait([
        orderRef.get(),
        escrowRef.get(),
        transactionRef.get(),
        commissionRef.get(),
      ]);
      final orderDoc = preflight[0];
      if (!orderDoc.exists || orderDoc.data() == null) {
        throw const FirestoreException('Order not found.');
      }
      final order = ServiceOrderModel.fromFirestore(orderDoc);
      if (order.clientId != clientId) {
        throw const FirestoreException('You can only pay for your own orders.');
      }
      if (preflight[1].exists || preflight[2].exists || preflight[3].exists) {
        if (order.paymentStatus == ServiceOrderPaymentStatus.demoPaid &&
            order.escrowStatus == ServiceOrderEscrowStatus.held) {
          return;
        }
        throw const FirestoreException(
          'Sandbox payment records already exist but the order is inconsistent.',
        );
      }
      if (!order.canCancel ||
          order.escrowStatus != ServiceOrderEscrowStatus.notFunded) {
        throw const FirestoreException(
          'This order is not eligible for another sandbox payment.',
        );
      }

      await _firestore.runTransaction((transaction) async {
        final escrowDoc = await transaction.get(escrowRef);
        final commerceTransactionDoc = await transaction.get(transactionRef);
        final commissionDoc = await transaction.get(commissionRef);
        final invoiceDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final invoiceRef in invoiceRefs) {
          invoiceDocs.add(await transaction.get(invoiceRef));
        }

        if (escrowDoc.exists ||
            commerceTransactionDoc.exists ||
            commissionDoc.exists) {
          return;
        }

        final walletRef = _walletsRef.doc(order.freelancerId);

        final now = DateTime.now();
        final expectedRelease = now.add(
          const Duration(days: SandboxCommerceConfig.escrowHoldingDays),
        );
        final reference = _sandboxReference(trimmedOrderId, now);
        final paidOrder = order.copyWith(
          paymentStatus: ServiceOrderPaymentStatus.demoPaid,
          escrowStatus: ServiceOrderEscrowStatus.held,
          orderStatus: ServiceOrderStatus.active,
          paidAt: now,
          escrowHeldAt: now,
          expectedReleaseAt: expectedRelease,
          sandboxPaymentMethod: method,
          transactionReference: reference,
          updatedAt: now,
        );
        final escrow = EscrowHoldModel(
          escrowId: trimmedOrderId,
          orderId: trimmedOrderId,
          clientId: order.clientId,
          freelancerId: order.freelancerId,
          amount: order.totalAmount,
          currency: order.currency,
          status: EscrowHoldStatus.held,
          holdStartedAt: now,
          expectedReleaseAt: expectedRelease,
          holdReason: 'Sandbox payment confirmed for service order.',
          createdAt: now,
        );
        final commerceTransaction = CommerceTransactionModel(
          transactionId: transactionRef.id,
          orderId: order.orderId,
          serviceRequestId: order.serviceRequestId,
          userId: order.clientId,
          walletId: null,
          type: CommerceTransactionType.escrowHold,
          amount: order.totalAmount,
          currency: order.currency,
          status: CommerceTransactionStatus.pending,
          referenceId: reference,
          description:
              'Sandbox escrow hold via $method for ${order.serviceTitle}.',
          createdAt: now,
        );
        final commission = CommissionLedgerModel(
          commissionId: commissionRef.id,
          orderId: order.orderId,
          serviceRequestId: order.serviceRequestId,
          amount: order.platformFee,
          percentage: SandboxCommerceConfig.platformCommissionPercent,
          currency: order.currency,
          source: CommissionLedgerSource.freelancerService,
          status: CommissionLedgerStatus.pending,
          createdAt: now,
        );
        transaction.set(escrowRef, escrow.toJson());
        transaction.set(transactionRef, commerceTransaction.toJson());
        transaction.set(commissionRef, commission.toJson());
        final invoiceTypes = [
          InvoiceType.clientReceipt,
          InvoiceType.freelancerInvoice,
          InvoiceType.platformCommissionInvoice,
        ];
        for (var index = 0; index < invoiceRefs.length; index++) {
          if (invoiceDocs[index].exists) continue;
          final invoice = invoiceFromOrder(
            paidOrder,
            type: invoiceTypes[index],
            now: now,
          );
          transaction.set(invoiceRefs[index], invoice.toJson());
        }
        transaction.set(walletRef, {
          'walletId': order.freelancerId,
          'freelancerId': order.freelancerId,
          'currency': order.currency,
          'escrowBalance': FieldValue.increment(order.totalAmount),
          'lastEscrowOrderId': order.orderId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        transaction.set(orderRef, {
          'paymentStatus': ServiceOrderPaymentStatus.demoPaid,
          'escrowStatus': ServiceOrderEscrowStatus.held,
          'orderStatus': ServiceOrderStatus.active,
          'paidAt': Timestamp.fromDate(now),
          'escrowHeldAt': Timestamp.fromDate(now),
          'expectedReleaseAt': Timestamp.fromDate(expectedRelease),
          'sandboxPaymentMethod': method,
          'transactionReference': reference,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'Commerce',
        repository: 'CommerceOrderRepositoryImpl',
        operation: 'confirmSandboxPayment',
        path:
            'serviceOrders/$orderId + serviceEscrows/$orderId + commerceTransactions/sandbox_escrow_hold_$orderId + commissionLedger/sandbox_commission_$orderId + invoices + freelancerWallets',
        action: 'transaction',
        uid: clientId,
      );
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException(
        'Failed to process sandbox payment: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> cancelOrder({
    required String orderId,
    required String clientId,
  }) async {
    try {
      final doc = await _ordersRef.doc(orderId).get();
      if (!doc.exists || doc.data() == null) {
        throw const FirestoreException('Order not found.');
      }
      final order = ServiceOrderModel.fromFirestore(doc);
      if (order.clientId != clientId) {
        throw const FirestoreException('You can only cancel your own orders.');
      }
      if (!order.canCancel) {
        throw const FirestoreException(
          'Only unpaid pending sandbox orders can be cancelled.',
        );
      }
      final now = DateTime.now();
      await _ordersRef.doc(orderId).set({
        'orderStatus': ServiceOrderStatus.cancelled,
        'updatedAt': Timestamp.fromDate(now),
        'cancelledAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to cancel order: ${e.toString()}');
    }
  }

  @override
  Future<void> startWork({
    required String orderId,
    required String freelancerId,
  }) async {
    try {
      final trimmedOrderId = orderId.trim();
      final trimmedFreelancerId = freelancerId.trim();
      if (trimmedOrderId.isEmpty || trimmedFreelancerId.isEmpty) {
        throw const FirestoreException('Order and freelancer are required.');
      }
      await _firestore.runTransaction((transaction) async {
        final orderRef = _ordersRef.doc(trimmedOrderId);
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists || orderDoc.data() == null) {
          throw const FirestoreException('Order not found.');
        }
        final order = ServiceOrderModel.fromFirestore(orderDoc);
        if (order.freelancerId != trimmedFreelancerId) {
          throw const FirestoreException('You can only start your own order.');
        }
        if (order.paymentStatus != ServiceOrderPaymentStatus.demoPaid ||
            order.escrowStatus != ServiceOrderEscrowStatus.held) {
          throw const FirestoreException(
            'Client has not funded escrow yet. You can start work after escrow is funded.',
          );
        }
        if (order.orderStatus != ServiceOrderStatus.active) {
          throw const FirestoreException('This order is not ready to start.');
        }
        final now = DateTime.now();
        transaction.set(orderRef, {
          'orderStatus': ServiceOrderStatus.inProgress,
          'deliveryStatus': ServiceOrderDeliveryStatus.pending,
          'workStartedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'OrderLifecycleDeliveryV2',
        repository: 'CommerceOrderRepositoryImpl',
        operation: 'startWork',
        path: 'serviceOrders/$orderId',
        action: 'transaction',
        uid: freelancerId,
      );
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to start work: ${e.toString()}');
    }
  }

  @override
  Future<void> submitDelivery({
    required String orderId,
    required String freelancerId,
    required String message,
    required List<String> attachmentUrls,
    List<Map<String, dynamic>> attachmentMetadata = const [],
  }) async {
    try {
      final trimmedOrderId = orderId.trim();
      final trimmedFreelancerId = freelancerId.trim();
      final cleanMessage = message.trim();
      final cleanUrls = attachmentUrls
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList();
      final cleanMetadata = attachmentMetadata
          .where((item) {
            final secureUrl = (item['secureUrl'] ?? '').toString().trim();
            final url = (item['url'] ?? '').toString().trim();
            return secureUrl.isNotEmpty || url.isNotEmpty;
          })
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final totalAttachments = cleanUrls.length + cleanMetadata.length;
      if (cleanMessage.isEmpty && totalAttachments == 0) {
        throw const FirestoreException('Add a message or at least one file.');
      }
      if (totalAttachments > 10) {
        throw const FirestoreException('Attach up to 10 delivery links.');
      }

      await _firestore.runTransaction((transaction) async {
        final orderRef = _ordersRef.doc(trimmedOrderId);
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists || orderDoc.data() == null) {
          throw const FirestoreException('Order not found.');
        }
        final order = ServiceOrderModel.fromFirestore(orderDoc);
        if (order.freelancerId != trimmedFreelancerId) {
          throw const FirestoreException(
            'You can only deliver your own order.',
          );
        }
        if (order.paymentStatus != ServiceOrderPaymentStatus.demoPaid ||
            order.escrowStatus != ServiceOrderEscrowStatus.held) {
          throw const FirestoreException('Escrow is not funded.');
        }
        if (order.orderStatus != ServiceOrderStatus.inProgress) {
          throw const FirestoreException(
            'Start work before submitting delivery.',
          );
        }
        final now = DateTime.now();
        final deliveryId = 'delivery_${now.millisecondsSinceEpoch}';
        final deliveryRef = orderRef.collection('deliveries').doc(deliveryId);
        final deliveryDoc = await transaction.get(deliveryRef);
        if (deliveryDoc.exists) {
          throw const FirestoreException('This delivery already exists.');
        }
        final attachments = [
          ...cleanMetadata,
          ...cleanUrls.map((url) => deliveryAttachmentFromUrl(url, now)),
        ];
        final delivery = ServiceOrderDeliveryModel(
          deliveryId: deliveryId,
          orderId: order.orderId,
          clientId: order.clientId,
          freelancerId: order.freelancerId,
          message: cleanMessage,
          attachments: attachments,
          status: ServiceOrderDeliveryStatus.submitted,
          submittedAt: now,
          updatedAt: now,
        );
        transaction.set(deliveryRef, delivery.toJson());
        transaction.set(orderRef, {
          'orderStatus': ServiceOrderStatus.delivered,
          'deliveryStatus': ServiceOrderDeliveryStatus.submitted,
          'deliveredAt': Timestamp.fromDate(now),
          'reviewDueAt': Timestamp.fromDate(now.add(const Duration(days: 3))),
          'lastDeliveryId': deliveryId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'OrderLifecycleDeliveryV2',
        repository: 'CommerceOrderRepositoryImpl',
        operation: 'submitDelivery',
        path: 'serviceOrders/$orderId + deliveries',
        action: 'transaction',
        uid: freelancerId,
      );
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to submit delivery: ${e.toString()}');
    }
  }

  void _assertOrderEligible(ServiceRequestModel request, String clientId) {
    if (request.clientId != clientId) {
      throw const FirestoreException(
        'You can only create orders for your own requests.',
      );
    }
    final eligible = {
      ServiceRequestStatus.accepted,
      ServiceRequestStatus.inProgress,
      ServiceRequestStatus.delivered,
      ServiceRequestStatus.completed,
    }.contains(request.status);
    if (!eligible) {
      throw const FirestoreException(
        'Order can be created only after the freelancer accepts the request.',
      );
    }
  }

  double _amountFrom(
    ServiceRequestModel request,
    FreelancerServiceModel? service,
  ) {
    if (request.budget > 0) return request.budget;
    if ((service?.startingPrice ?? 0) > 0) return service!.startingPrice;
    throw const FirestoreException(
      'Add a request budget or service starting price before creating an order.',
    );
  }

  ServicePackageModel _packageFrom(
    ServiceRequestModel request,
    FreelancerServiceModel? service,
  ) {
    final requestPackageId = request.selectedPackageId?.trim();
    if (requestPackageId != null &&
        requestPackageId.isNotEmpty &&
        request.selectedPackagePrice > 0 &&
        request.selectedDeliveryDays > 0) {
      return ServicePackageModel(
        packageId: requestPackageId,
        title: request.selectedPackageTitle ?? 'Selected package',
        description: 'Client selected package',
        price: request.selectedPackagePrice,
        deliveryDays: request.selectedDeliveryDays,
        revisionsIncluded: request.selectedRevisionsIncluded,
        isActive: true,
      );
    }

    final packages = service?.activePackages ?? const <ServicePackageModel>[];
    if (request.budget > 0 && packages.isNotEmpty) {
      for (final package in packages) {
        if ((package.price - request.budget).abs() < 0.01) {
          return package;
        }
      }
    }
    if (packages.isNotEmpty) return packages.first;

    return ServicePackageModel(
      packageId: 'legacy_standard',
      title: 'Standard',
      description: 'Legacy service package',
      price: request.budget > 0 ? request.budget : service?.startingPrice ?? 0,
      deliveryDays: _deliveryDaysFrom(service?.estimatedDelivery),
      revisionsIncluded: 1,
      isActive: true,
    );
  }

  int _deliveryDaysFrom(String? estimatedDelivery) {
    final value = estimatedDelivery?.trim() ?? '';
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return 7;
    final parsed = int.tryParse(match.group(0) ?? '') ?? 7;
    return parsed.clamp(1, 365).toInt();
  }

  String _orderNumber(String orderId, DateTime now) {
    final suffix = orderId.length <= 6
        ? orderId.toUpperCase()
        : orderId.substring(0, 6).toUpperCase();
    return 'SF-${now.year}-${now.millisecondsSinceEpoch}-$suffix';
  }

  String _transactionId(String orderId) => 'sandbox_escrow_hold_$orderId';

  String _commissionId(String orderId) => 'sandbox_commission_$orderId';

  String _sandboxReference(String orderId, DateTime now) {
    final suffix = orderId.length <= 8
        ? orderId.toUpperCase()
        : orderId.substring(0, 8).toUpperCase();
    return 'SBOX-${now.millisecondsSinceEpoch}-$suffix';
  }
}
