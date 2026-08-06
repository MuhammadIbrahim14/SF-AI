import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/app_exceptions.dart';
import '../core/services/firestore_permission_logger.dart';
import '../models/customer_wallet_model.dart';
import '../models/escrow_hold_model.dart';
import '../models/resolution_case_model.dart';
import '../models/service_order_model.dart';
import 'customer_wallet_repository.dart';

class CustomerWalletRepositoryImpl implements CustomerWalletRepository {
  const CustomerWalletRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _walletsRef =>
      _firestore.collection('customerWallets');

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('walletTransactions');

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('serviceOrders');

  CollectionReference<Map<String, dynamic>> get _escrowsRef =>
      _firestore.collection('serviceEscrows');

  CollectionReference<Map<String, dynamic>> get _casesRef =>
      _firestore.collection('resolutionCases');

  @override
  Stream<CustomerWalletModel?> watchMyWallet(String customerId) {
    return _walletsRef.doc(customerId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return CustomerWalletModel.fromFirestore(doc);
    });
  }

  @override
  Stream<List<WalletTransactionModel>> watchMyWalletTransactions(
    String customerId,
  ) {
    return _transactionsRef
        .where('ownerId', isEqualTo: customerId)
        .where('ownerType', isEqualTo: WalletTransactionOwnerType.customer)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(WalletTransactionModel.fromFirestore)
              .toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  @override
  Future<CustomerWalletModel> getOrCreateMyWallet(String customerId) async {
    final uid = customerId.trim();
    if (uid.isEmpty) {
      throw const FirestoreException('Please log in to use your wallet.');
    }
    final walletRef = _walletsRef.doc(uid);
    _logAction(
      operation: 'getOrCreateMyWallet',
      uid: uid,
      path: 'customerWallets/$uid',
    );

    try {
      final snapshot = await walletRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        return CustomerWalletModel.fromFirestore(snapshot);
      }

      final wallet = CustomerWalletModel.empty(uid, DateTime.now());
      await walletRef.set(wallet.toJson());
      return wallet;
    } on FirebaseException catch (e) {
      throw _map(
        e,
        'getOrCreateMyWallet',
        'customerWallets/$uid',
        uid,
        'read/write',
      );
    }
  }

  @override
  Future<void> addDemoBalance({
    required String customerId,
    required double amount,
  }) async {
    throw const FirestoreException(
      'Wallet top-ups must go through the SkillForge Demo Gateway. '
      'Client self-mint is disabled.',
    );
  }

  @override
  Future<void> payOrderFromWallet({
    required String customerId,
    required String orderId,
  }) async {
    final uid = customerId.trim();
    final trimmedOrderId = orderId.trim();
    if (uid.isEmpty) {
      throw const FirestoreException('Please log in to use your wallet.');
    }
    if (trimmedOrderId.isEmpty) {
      throw const FirestoreException('Order is required.');
    }

    final walletRef = _walletsRef.doc(uid);
    final orderRef = _ordersRef.doc(trimmedOrderId);
    final escrowRef = _escrowsRef.doc(trimmedOrderId);
    final ledgerRef = _transactionsRef.doc(
      _walletPaymentTransactionId(trimmedOrderId),
    );

    _logAction(
      operation: 'payOrderFromWallet',
      uid: uid,
      path:
          'customerWallets/$uid + serviceOrders/$trimmedOrderId + serviceEscrows/$trimmedOrderId + walletTransactions/${ledgerRef.id}',
    );

    var currentStep = 'start';
    _logPaymentStep(currentStep, uid, trimmedOrderId);
    try {
      await _firestore.runTransaction((transaction) async {
        currentStep = 'readWallet';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail: 'path=customerWallets/$uid',
        );
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists || walletDoc.data() == null) {
          throw const FirestoreException(
            'Please add demo balance to your wallet first.',
          );
        }
        final wallet = CustomerWalletModel.fromFirestore(walletDoc);
        if (wallet.status != CustomerWalletStatus.active) {
          throw const FirestoreException('Your wallet is not active.');
        }

        currentStep = 'readOrder';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail: 'path=serviceOrders/$trimmedOrderId',
        );
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists || orderDoc.data() == null) {
          throw const FirestoreException('Order not found.');
        }
        final order = ServiceOrderModel.fromFirestore(orderDoc);
        currentStep = 'validateOrder';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail:
              'clientId=${order.clientId} freelancerId=${order.freelancerId} '
              'amount=${order.totalAmount} currency=${order.currency} '
              'paymentStatus=${order.paymentStatus} '
              'escrowStatus=${order.escrowStatus} '
              'orderStatus=${order.orderStatus}',
        );
        if (order.clientId != uid) {
          throw const FirestoreException(
            'You can only pay for your own orders.',
          );
        }
        if (order.totalAmount <= 0) {
          throw const FirestoreException(
            'Order amount must be greater than 0.',
          );
        }

        currentStep = 'readEscrow';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail: 'path=serviceEscrows/$trimmedOrderId',
        );
        final escrowDoc = await transaction.get(escrowRef);
        currentStep = 'readLedger';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail: 'path=walletTransactions/${ledgerRef.id}',
        );
        final ledgerDoc = await transaction.get(ledgerRef);
        final alreadyPaid =
            order.paymentStatus == ServiceOrderPaymentStatus.demoPaid &&
            order.escrowStatus == ServiceOrderEscrowStatus.held;
        if (ledgerDoc.exists && alreadyPaid) {
          return;
        }
        if (ledgerDoc.exists && !alreadyPaid) {
          throw const FirestoreException(
            'Payment record exists but order is not marked paid. Please contact support.',
          );
        }
        if (escrowDoc.exists && alreadyPaid) {
          return;
        }
        if (order.paymentStatus != ServiceOrderPaymentStatus.unpaid ||
            order.escrowStatus != ServiceOrderEscrowStatus.notFunded ||
            order.orderStatus != ServiceOrderStatus.pending) {
          throw const FirestoreException('This order has already been paid.');
        }
        if (escrowDoc.exists) {
          throw const FirestoreException(
            'Escrow record already exists for this order.',
          );
        }
        currentStep = 'validateWallet';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail:
              'availableBalance=${wallet.availableBalance} '
              'amount=${order.totalAmount} currency=${wallet.currency}',
        );
        if (wallet.currency != order.currency) {
          throw FirestoreException(
            'Your wallet currency (${wallet.currency}) does not match this order (${order.currency}).',
          );
        }
        if (wallet.availableBalance < order.totalAmount) {
          throw const FirestoreException('Insufficient wallet balance.');
        }

        final now = DateTime.now();
        final expectedRelease = now.add(
          const Duration(days: SandboxCommerceConfig.escrowHoldingDays),
        );
        final reference = _walletPaymentReference(trimmedOrderId, now);
        currentStep = 'updateWallet';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail: 'keys=[availableBalance,totalSpent,totalEscrowed,updatedAt]',
        );
        transaction.set(walletRef, {
          'availableBalance': FieldValue.increment(-order.totalAmount),
          'totalSpent': FieldValue.increment(order.totalAmount),
          'totalEscrowed': FieldValue.increment(order.totalAmount),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'updateOrder';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail:
              'keys=[paymentStatus,escrowStatus,orderStatus,paidAt,'
              'escrowHeldAt,expectedReleaseAt,sandboxPaymentMethod,'
              'transactionReference,updatedAt]',
        );
        transaction.set(orderRef, {
          'paymentStatus': ServiceOrderPaymentStatus.demoPaid,
          'escrowStatus': ServiceOrderEscrowStatus.held,
          'orderStatus': ServiceOrderStatus.active,
          'paidAt': Timestamp.fromDate(now),
          'escrowHeldAt': Timestamp.fromDate(now),
          'expectedReleaseAt': Timestamp.fromDate(expectedRelease),
          'sandboxPaymentMethod': 'SkillForge Wallet',
          'transactionReference': reference,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'createOrUpdateEscrow';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail:
              'keys=[escrowId,orderId,clientId,freelancerId,amount,currency,'
              'status,holdStartedAt,expectedReleaseAt,holdReason,createdAt]',
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
          holdReason: 'SkillForge Wallet demo payment moved to escrow.',
          createdAt: now,
        );
        transaction.set(escrowRef, escrow.toJson());

        currentStep = 'createLedger';
        _logPaymentStep(
          currentStep,
          uid,
          trimmedOrderId,
          detail:
              'path=walletTransactions/${ledgerRef.id} '
              'keys=[transactionId,ownerId,ownerType,walletId,type,direction,'
              'amount,currency,status,orderId,referenceId,description,'
              'createdAt,updatedAt]',
        );
        final walletTransaction = WalletTransactionModel(
          transactionId: ledgerRef.id,
          ownerId: uid,
          ownerType: WalletTransactionOwnerType.customer,
          walletId: uid,
          type: WalletTransactionType.orderPayment,
          direction: WalletTransactionDirection.debit,
          amount: order.totalAmount,
          currency: order.currency,
          status: WalletTransactionStatus.completed,
          orderId: order.orderId,
          caseId: null,
          referenceId: reference,
          description:
              'Payment moved to escrow for order ${order.orderNumber}.',
          createdAt: now,
          updatedAt: now,
        );
        transaction.set(ledgerRef, walletTransaction.toJson());
      });
      _logPaymentStep('success', uid, trimmedOrderId);
    } on FirebaseException catch (e) {
      _logPaymentError(
        currentStep,
        uid,
        trimmedOrderId,
        e.code,
        e.message ?? e.toString(),
        e.stackTrace,
      );
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'WalletPaymentV2',
        repository: 'CustomerWalletRepository',
        operation: 'payOrderFromWallet',
        path:
            'customerWallets/$uid + serviceOrders/$trimmedOrderId + serviceEscrows/$trimmedOrderId + walletTransactions/${ledgerRef.id}',
        action: 'transaction',
        uid: uid,
        accountType: 'customer',
      );
    } on FirestoreException catch (e, stackTrace) {
      _logPaymentError(
        currentStep,
        uid,
        trimmedOrderId,
        e.code ?? 'wallet-validation',
        e.message,
        stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      final message = e.toString();
      _logPaymentError(
        currentStep,
        uid,
        trimmedOrderId,
        e.runtimeType.toString(),
        message,
        stackTrace,
      );
      if (message.contains('Dart exception thrown from converted Future')) {
        throw const FirestoreException(
          'Unable to complete wallet payment. Please try again.',
        );
      }
      throw FirestoreException('Unable to complete wallet payment: $message');
    }
  }

  @override
  Future<void> completeOrderAndReleaseEscrow({
    required String customerId,
    required String orderId,
  }) async {
    final uid = customerId.trim();
    final trimmedOrderId = orderId.trim();
    if (uid.isEmpty) {
      throw const FirestoreException('Please log in to use your wallet.');
    }
    if (trimmedOrderId.isEmpty) {
      throw const FirestoreException('Order is required.');
    }

    final orderRef = _ordersRef.doc(trimmedOrderId);
    final escrowRef = _escrowsRef.doc(trimmedOrderId);
    final customerWalletRef = _walletsRef.doc(uid);
    final releaseLedgerRef = _transactionsRef.doc(
      _walletReleaseTransactionId(trimmedOrderId),
    );
    final disputeRef = _casesRef.doc('${trimmedOrderId}_dispute');
    final refundRef = _casesRef.doc('${trimmedOrderId}_refund');
    var currentStep = 'start';

    _logCompletionStep(
      step: currentStep,
      customerId: uid,
      orderId: trimmedOrderId,
    );
    try {
      await _firestore.runTransaction((transaction) async {
        currentStep = 'readOrder';
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists || orderDoc.data() == null) {
          throw const FirestoreException('Order not found.');
        }
        final order = ServiceOrderModel.fromFirestore(orderDoc);

        currentStep = 'readEscrow';
        final escrowDoc = await transaction.get(escrowRef);
        if (!escrowDoc.exists || escrowDoc.data() == null) {
          throw const FirestoreException(
            'Escrow is not available for release.',
          );
        }
        final escrow = EscrowHoldModel.fromFirestore(escrowDoc);

        currentStep = 'readCustomerWallet';
        final customerWalletDoc = await transaction.get(customerWalletRef);
        if (!customerWalletDoc.exists || customerWalletDoc.data() == null) {
          throw const FirestoreException('Customer wallet not found.');
        }
        final customerWallet = CustomerWalletModel.fromFirestore(
          customerWalletDoc,
        );

        currentStep = 'readReleaseLedger';
        final releaseLedgerDoc = await transaction.get(releaseLedgerRef);

        currentStep = 'readResolutionCases';
        final disputeDoc = await transaction.get(disputeRef);
        final refundDoc = await transaction.get(refundRef);

        currentStep = 'validateCompletion';
        final releaseAmount = order.freelancerEarnings > 0
            ? order.freelancerEarnings
            : order.totalAmount;
        _validateCompletionRelease(
          customerId: uid,
          order: order,
          escrow: escrow,
          customerWallet: customerWallet,
          releaseLedgerExists: releaseLedgerDoc.exists,
          disputeDoc: disputeDoc,
          refundDoc: refundDoc,
          releaseAmount: releaseAmount,
        );

        final now = DateTime.now();
        currentStep = 'updateOrder';
        transaction.set(orderRef, {
          'paymentStatus': ServiceOrderPaymentStatus.released,
          'escrowStatus': ServiceOrderEscrowStatus.released,
          'orderStatus': ServiceOrderStatus.completed,
          'deliveryStatus': ServiceOrderDeliveryStatus.accepted,
          'completedAt': Timestamp.fromDate(now),
          'escrowReleasedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'updateEscrow';
        transaction.set(escrowRef, {
          'status': EscrowHoldStatus.released,
          'releasedAmount': escrow.amount,
          'refundedAmount': 0,
          'releasedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'updateCustomerWallet';
        transaction.set(customerWalletRef, {
          'totalEscrowed': FieldValue.increment(-escrow.amount),
          'lastReleaseOrderId': order.orderId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'updateFreelancerWallet';
        final freelancerWalletRef = _firestore
            .collection('freelancerWallets')
            .doc(order.freelancerId);
        transaction.set(freelancerWalletRef, {
          'walletId': order.freelancerId,
          'freelancerId': order.freelancerId,
          'availableBalance': FieldValue.increment(0),
          'pendingBalance': FieldValue.increment(releaseAmount),
          'escrowBalance': FieldValue.increment(0),
          'pendingPayoutBalance': FieldValue.increment(0),
          'lifetimeEarnings': FieldValue.increment(0),
          'lifetimeWithdrawn': FieldValue.increment(0),
          'currency': order.currency,
          'monthlyEarnings': FieldValue.increment(0),
          'weeklyEarnings': FieldValue.increment(0),
          'ordersThisMonth': FieldValue.increment(1),
          'lastReleaseOrderId': order.orderId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        currentStep = 'createReleaseLedger';
        final releaseLedger = WalletTransactionModel(
          transactionId: releaseLedgerRef.id,
          ownerId: order.freelancerId,
          ownerType: WalletTransactionOwnerType.freelancer,
          walletId: order.freelancerId,
          type: WalletTransactionType.escrowRelease,
          direction: WalletTransactionDirection.credit,
          amount: releaseAmount,
          currency: order.currency,
          status: WalletTransactionStatus.completed,
          orderId: order.orderId,
          caseId: null,
          referenceId: null,
          description:
              'Escrow released after customer completed order ${order.orderNumber}.',
          createdAt: now,
          updatedAt: now,
        );
        transaction.set(releaseLedgerRef, releaseLedger.toJson());
      });
      _logCompletionStep(
        step: 'success',
        customerId: uid,
        orderId: trimmedOrderId,
      );
    } on FirebaseException catch (e) {
      _logCompletionError(
        step: currentStep,
        customerId: uid,
        orderId: trimmedOrderId,
        code: e.code,
        message: e.message ?? e.toString(),
        stackTrace: e.stackTrace,
      );
      throw FirestorePermissionLogger.toFirestoreException(
        e,
        feature: 'OrderCompletionReleaseV2',
        repository: 'CustomerWalletRepository',
        operation: 'completeOrderAndReleaseEscrow',
        path:
            'serviceOrders/$trimmedOrderId + serviceEscrows/$trimmedOrderId + customerWallets/$uid + freelancerWallets + walletTransactions/${releaseLedgerRef.id}',
        action: 'transaction',
        uid: uid,
        accountType: 'customer',
      );
    } on FirestoreException catch (e, stackTrace) {
      _logCompletionError(
        step: currentStep,
        customerId: uid,
        orderId: trimmedOrderId,
        code: e.code ?? 'completion-release',
        message: e.message,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      final message = e.toString();
      _logCompletionError(
        step: currentStep,
        customerId: uid,
        orderId: trimmedOrderId,
        code: e.runtimeType.toString(),
        message: message,
        stackTrace: stackTrace,
      );
      if (message.contains('Dart exception thrown from converted Future')) {
        throw const FirestoreException('Unable to complete order.');
      }
      throw FirestoreException('Unable to complete order: $message');
    }
  }

  FirestoreException _map(
    FirebaseException exception,
    String operation,
    String path,
    String uid,
    String action,
  ) {
    return FirestorePermissionLogger.toFirestoreException(
      exception,
      feature: 'CustomerWallet',
      repository: 'CustomerWalletRepository',
      operation: operation,
      path: path,
      action: action,
      uid: uid,
      accountType: 'customer',
    );
  }

  String _walletPaymentTransactionId(String orderId) {
    return 'wallet_order_payment_$orderId';
  }

  String _walletPaymentReference(String orderId, DateTime now) {
    final suffix = orderId.length <= 8
        ? orderId.toUpperCase()
        : orderId.substring(0, 8).toUpperCase();
    return 'WALLET-${now.millisecondsSinceEpoch}-$suffix';
  }

  String _walletReleaseTransactionId(String orderId) {
    return 'wallet_order_release_$orderId';
  }

  void _validateCompletionRelease({
    required String customerId,
    required ServiceOrderModel order,
    required EscrowHoldModel escrow,
    required CustomerWalletModel customerWallet,
    required bool releaseLedgerExists,
    required DocumentSnapshot<Map<String, dynamic>> disputeDoc,
    required DocumentSnapshot<Map<String, dynamic>> refundDoc,
    required double releaseAmount,
  }) {
    final alreadyCompleted =
        order.orderStatus == ServiceOrderStatus.completed ||
        order.paymentStatus == ServiceOrderPaymentStatus.released ||
        order.escrowStatus == ServiceOrderEscrowStatus.released;
    if (releaseLedgerExists && alreadyCompleted) {
      throw const FirestoreException(
        'This order has already been completed and released.',
      );
    }
    if (releaseLedgerExists) {
      throw const FirestoreException(
        'Release record exists but order is not completed. Please contact support.',
      );
    }
    if (alreadyCompleted) {
      throw const FirestoreException('This order has already been completed.');
    }
    if (order.clientId != customerId ||
        customerWallet.customerId != customerId) {
      throw const FirestoreException('You can only complete your own orders.');
    }
    if (order.sandboxPaymentMethod != 'SkillForge Wallet') {
      throw const FirestoreException(
        'This completion release is available for SkillForge Wallet orders.',
      );
    }
    if (order.paymentStatus != ServiceOrderPaymentStatus.demoPaid ||
        order.escrowStatus != ServiceOrderEscrowStatus.held ||
        escrow.status != EscrowHoldStatus.held) {
      throw const FirestoreException('This order is not ready to complete.');
    }
    final deliveryReady =
        order.orderStatus == ServiceOrderStatus.delivered &&
        order.deliveryStatus == ServiceOrderDeliveryStatus.submitted &&
        (order.lastDeliveryId ?? '').trim().isNotEmpty &&
        order.deliveredAt != null;
    if (!deliveryReady) {
      throw const FirestoreException(
        'Freelancer delivery is required before escrow can be released.',
      );
    }
    if (order.orderId != escrow.orderId ||
        order.clientId != escrow.clientId ||
        order.freelancerId != escrow.freelancerId) {
      throw const FirestoreException('Escrow is not available for release.');
    }
    if (escrow.amount <= 0 || order.totalAmount <= 0 || releaseAmount <= 0) {
      throw const FirestoreException('Escrow is not available for release.');
    }
    if ((escrow.amount - order.totalAmount).abs() > 0.01 ||
        releaseAmount > escrow.amount) {
      throw const FirestoreException(
        'Escrow amount does not match this order.',
      );
    }
    if (customerWallet.currency != order.currency ||
        customerWallet.totalEscrowed + 0.01 < escrow.amount) {
      throw const FirestoreException(
        'Customer escrow balance is inconsistent.',
      );
    }
    if (_caseBlocksCompletion(disputeDoc) || _caseBlocksCompletion(refundDoc)) {
      throw const FirestoreException(
        'A dispute or refund case is active for this order.',
      );
    }
  }

  bool _caseBlocksCompletion(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists || doc.data() == null) return false;
    final status = doc.data()?['status']?.toString().trim() ?? '';
    return !{
      ResolutionCaseStatus.resolved,
      ResolutionCaseStatus.rejected,
      ResolutionCaseStatus.cancelled,
    }.contains(status);
  }

  void _logCompletionStep({
    required String step,
    required String customerId,
    required String orderId,
    String? detail,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[OrderCompletionReleaseV2] operation=completeOrderAndReleaseEscrow '
      'step=$step orderId=$orderId customerId=$customerId'
      '${detail == null ? '' : ' $detail'}',
    );
  }

  void _logCompletionError({
    required String step,
    required String customerId,
    required String orderId,
    required String code,
    required String message,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[FirestorePermissionDenied] feature=OrderCompletionReleaseV2 '
      'repository=CustomerWalletRepository '
      'operation=completeOrderAndReleaseEscrow step=$step '
      'path=serviceOrders/$orderId + serviceEscrows/$orderId + wallets + ledgers '
      'action=transaction uid=$customerId code=$code message=$message '
      'stack=$stackTrace',
    );
  }

  void _logPaymentStep(
    String step,
    String uid,
    String orderId, {
    String? detail,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[WalletPaymentV2] step=$step uid=$uid orderId=$orderId'
      '${detail == null ? '' : ' $detail'}',
    );
  }

  void _logPaymentError(
    String step,
    String uid,
    String orderId,
    String code,
    String message,
    StackTrace? stackTrace,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      '[WalletPaymentV2Error] step=$step uid=$uid orderId=$orderId '
      'code=$code message=$message stack=$stackTrace',
    );
  }

  void _logAction({
    required String operation,
    required String uid,
    required String path,
    double? amount,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[CustomerWalletAction] operation=$operation uid=$uid path=$path '
      'amount=${amount?.toStringAsFixed(2) ?? '-'}',
    );
  }
}
