import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/commerce_transaction_model.dart';
import '../models/escrow_hold_model.dart';
import '../models/freelancer_wallet_model.dart';
import '../models/service_order_model.dart';
import '../models/service_request_model.dart';
import 'freelancer_wallet_repository.dart';

class FreelancerWalletRepositoryImpl implements FreelancerWalletRepository {
  const FreelancerWalletRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _walletsRef =>
      _firestore.collection('freelancerWallets');

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('serviceOrders');

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('serviceRequests');

  CollectionReference<Map<String, dynamic>> get _escrowsRef =>
      _firestore.collection('serviceEscrows');

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('commerceTransactions');

  @override
  Stream<FreelancerWalletModel?> watchWallet(String freelancerId) {
    return _walletsRef.doc(freelancerId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return FreelancerWalletModel.fromFirestore(doc);
    });
  }

  @override
  Stream<List<FreelancerWalletModel>> watchAdminWallets() {
    return _walletsRef.snapshots().map((snapshot) {
      final wallets = snapshot.docs
          .map(FreelancerWalletModel.fromFirestore)
          .toList();
      wallets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return wallets;
    });
  }

  @override
  Stream<List<CommerceTransactionModel>> watchWalletTransactions(
    String freelancerId,
  ) {
    return _transactionsRef
        .where('userId', isEqualTo: freelancerId)
        .snapshots()
        .map((snapshot) {
          final transactions = snapshot.docs
              .map(CommerceTransactionModel.fromFirestore)
              .toList();
          transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return transactions;
        });
  }

  @override
  Future<void> ensureWallet(String freelancerId) async {
    try {
      final trimmed = freelancerId.trim();
      if (trimmed.isEmpty) return;
      final walletRef = _walletsRef.doc(trimmed);
      final walletDoc = await walletRef.get();
      if (walletDoc.exists) return;
      final now = DateTime.now();
      await walletRef.set(
        FreelancerWalletModel.empty(freelancerId: trimmed, now: now).toJson(),
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to prepare wallet: ${e.toString()}');
    }
  }

  @override
  Future<void> releaseEscrowForCompletedRequest({
    required String requestId,
    required String clientId,
  }) async {
    try {
      final orderId = requestId.trim();
      if (orderId.isEmpty) return;

      await _firestore.runTransaction((transaction) async {
        final requestRef = _requestsRef.doc(orderId);
        final orderRef = _ordersRef.doc(orderId);
        final escrowRef = _escrowsRef.doc(orderId);
        final releaseRef = _transactionsRef.doc(_releaseTransactionId(orderId));

        final requestDoc = await transaction.get(requestRef);
        final orderDoc = await transaction.get(orderRef);
        final escrowDoc = await transaction.get(escrowRef);
        final releaseDoc = await transaction.get(releaseRef);

        if (!requestDoc.exists || requestDoc.data() == null) {
          throw const FirestoreException('Service request not found.');
        }
        if (!orderDoc.exists || orderDoc.data() == null) {
          return;
        }
        if (releaseDoc.exists) return;

        final request = ServiceRequestModel.fromFirestore(requestDoc);
        final order = ServiceOrderModel.fromFirestore(orderDoc);
        if (request.clientId != clientId || order.clientId != clientId) {
          throw const FirestoreException(
            'Only the client can release escrow for this order.',
          );
        }
        if (request.status != ServiceRequestStatus.completed) {
          throw const FirestoreException(
            'Escrow can be released only after completion.',
          );
        }
        if (order.paymentStatus != ServiceOrderPaymentStatus.demoPaid ||
            order.escrowStatus != ServiceOrderEscrowStatus.held) {
          return;
        }
        if (!escrowDoc.exists || escrowDoc.data() == null) {
          throw const FirestoreException('Escrow hold not found.');
        }

        final now = DateTime.now();
        final walletRef = _walletsRef.doc(order.freelancerId);
        transaction.set(walletRef, {
          'walletId': order.freelancerId,
          'freelancerId': order.freelancerId,
          'currency': order.currency,
          'escrowBalance': FieldValue.increment(-order.totalAmount),
          'pendingBalance': FieldValue.increment(order.freelancerEarnings),
          'ordersThisMonth': FieldValue.increment(1),
          'lastReleaseOrderId': order.orderId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        transaction.set(
          releaseRef,
          CommerceTransactionModel(
            transactionId: releaseRef.id,
            orderId: order.orderId,
            serviceRequestId: order.serviceRequestId,
            userId: order.freelancerId,
            walletId: order.freelancerId,
            type: CommerceTransactionType.escrowRelease,
            amount: order.freelancerEarnings,
            currency: order.currency,
            status: CommerceTransactionStatus.pending,
            referenceId: order.transactionReference,
            description:
                'Sandbox escrow released to pending wallet balance for ${order.serviceTitle}.',
            createdAt: now,
          ).toJson(),
        );
        transaction.set(orderRef, {
          'paymentStatus': ServiceOrderPaymentStatus.released,
          'escrowStatus': ServiceOrderEscrowStatus.released,
          'orderStatus': ServiceOrderStatus.completed,
          'completedAt': Timestamp.fromDate(now),
          'escrowReleasedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        transaction.set(escrowRef, {
          'status': EscrowHoldStatus.released,
          'releasedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to release escrow: ${e.toString()}');
    }
  }

  @override
  Future<void> clearSandboxFunds(String freelancerId) async {
    try {
      final trimmed = freelancerId.trim();
      if (trimmed.isEmpty) {
        throw const FirestoreException('Freelancer is required.');
      }

      await _firestore.runTransaction((transaction) async {
        final walletRef = _walletsRef.doc(trimmed);
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists || walletDoc.data() == null) {
          throw const FirestoreException('Wallet not found.');
        }
        final wallet = FreelancerWalletModel.fromFirestore(walletDoc);
        if (wallet.pendingBalance <= 0) {
          throw const FirestoreException('No pending sandbox funds to clear.');
        }

        final now = DateTime.now();
        final amount = wallet.pendingBalance;
        final reference = 'SBOX-CLEAR-${now.millisecondsSinceEpoch}';
        final clearanceRef = _transactionsRef.doc(
          _clearanceTransactionId(trimmed, now),
        );
        transaction.set(walletRef, {
          'pendingBalance': 0,
          'availableBalance': wallet.availableBalance + amount,
          'lifetimeEarnings': wallet.lifetimeEarnings + amount,
          'monthlyEarnings': wallet.monthlyEarnings + amount,
          'weeklyEarnings': wallet.weeklyEarnings + amount,
          'lastClearanceReference': reference,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        transaction.set(
          clearanceRef,
          CommerceTransactionModel(
            transactionId: clearanceRef.id,
            orderId: '',
            serviceRequestId: '',
            userId: trimmed,
            walletId: trimmed,
            type: CommerceTransactionType.walletClearance,
            amount: amount,
            currency: wallet.currency,
            status: CommerceTransactionStatus.cleared,
            referenceId: reference,
            description:
                'Sandbox clearance moved pending funds into available balance. No real payout was processed.',
            createdAt: now,
          ).toJson(),
        );
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException(
        'Failed to clear sandbox funds: ${e.toString()}',
      );
    }
  }

  String _releaseTransactionId(String orderId) =>
      'sandbox_escrow_release_$orderId';

  String _clearanceTransactionId(String freelancerId, DateTime now) =>
      'sandbox_wallet_clearance_${freelancerId}_${now.millisecondsSinceEpoch}';
}
