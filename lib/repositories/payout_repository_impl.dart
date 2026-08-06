import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/commerce_transaction_model.dart';
import '../models/freelancer_wallet_model.dart';
import '../models/payout_model.dart';
import 'payout_repository.dart';

class PayoutRepositoryImpl implements PayoutRepository {
  const PayoutRepositoryImpl(this._firestore);

  static const double minimumWithdrawal = 25;
  static const double maximumWithdrawal = 10000;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _payoutsRef =>
      _firestore.collection('payouts');

  CollectionReference<Map<String, dynamic>> get _walletsRef =>
      _firestore.collection('freelancerWallets');

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('commerceTransactions');

  @override
  Stream<List<PayoutModel>> watchFreelancerPayouts(String freelancerId) {
    return _payoutsRef
        .where('freelancerId', isEqualTo: freelancerId)
        .snapshots()
        .map((snapshot) {
          final payouts = snapshot.docs.map(PayoutModel.fromFirestore).toList();
          payouts.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
          return payouts;
        });
  }

  @override
  Stream<List<PayoutModel>> watchAdminPayouts() {
    return _payoutsRef.snapshots().map((snapshot) {
      final payouts = snapshot.docs.map(PayoutModel.fromFirestore).toList();
      payouts.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return payouts;
    });
  }

  @override
  Future<PayoutModel?> getPayout(String payoutId) async {
    final id = payoutId.trim();
    if (id.isEmpty) return null;
    try {
      final doc = await _payoutsRef.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return PayoutModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code, e.message);
    } catch (e) {
      throw FirestoreException('Failed to load payout: ${e.toString()}');
    }
  }

  @override
  Future<void> requestPayout({
    required String freelancerId,
    required double amount,
    required String destinationType,
    required String destinationName,
    required String destinationMasked,
    required String notes,
  }) async {
    try {
      final trimmedFreelancerId = freelancerId.trim();
      final cleanDestinationName = destinationName.trim();
      final cleanDestinationMasked = destinationMasked.trim();
      // Rules compare balances with exact equality — keep money at 2dp.
      final withdrawAmount = _roundMoney(amount);
      if (trimmedFreelancerId.isEmpty) {
        throw const FirestoreException('Freelancer is required.');
      }
      if (withdrawAmount < minimumWithdrawal) {
        throw FirestoreException(
          'Minimum sandbox withdrawal is ${minimumWithdrawal.toStringAsFixed(0)}.',
        );
      }
      if (withdrawAmount > maximumWithdrawal) {
        throw FirestoreException(
          'Maximum sandbox withdrawal is ${maximumWithdrawal.toStringAsFixed(0)}.',
        );
      }
      if (cleanDestinationName.isEmpty || cleanDestinationMasked.isEmpty) {
        throw const FirestoreException('Add a sandbox payout destination.');
      }

      await _firestore.runTransaction((transaction) async {
        _log(
          'operation=requestPayout step=readWallet freelancerId=$trimmedFreelancerId amount=$withdrawAmount',
        );
        final walletRef = _walletsRef.doc(trimmedFreelancerId);
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists || walletDoc.data() == null) {
          throw const FirestoreException('Wallet not found.');
        }
        final wallet = FreelancerWalletModel.fromFirestore(walletDoc);
        if ((wallet.activePayoutId ?? '').trim().isNotEmpty) {
          throw const FirestoreException(
            'You already have an active sandbox payout request.',
          );
        }
        if (wallet.pendingBalance > 0 || wallet.escrowBalance > 0) {
          // These balances are visible, but not withdrawable.
        }
        if (wallet.availableBalance < withdrawAmount) {
          throw const FirestoreException(
            'Available balance is not enough for this withdrawal.',
          );
        }

        final now = DateTime.now();
        final payoutRef = _payoutsRef.doc(_payoutId(trimmedFreelancerId, now));
        final ledgerRef = _transactionsRef.doc(
          _payoutLedgerId('request', payoutRef.id),
        );
        final payoutDoc = await transaction.get(payoutRef);
        final ledgerDoc = await transaction.get(ledgerRef);
        if (payoutDoc.exists || ledgerDoc.exists) {
          throw const FirestoreException('This payout request already exists.');
        }
        // Rules require payout.walletId == auth.uid (not a legacy wallet field).
        final payout = PayoutModel(
          payoutId: payoutRef.id,
          freelancerId: trimmedFreelancerId,
          walletId: trimmedFreelancerId,
          amount: withdrawAmount,
          currency: wallet.currency.trim().isEmpty ? 'USD' : wallet.currency,
          destinationType: PayoutDestinationType.normalize(destinationType),
          destinationName: cleanDestinationName,
          destinationMasked: cleanDestinationMasked,
          status: PayoutStatus.pendingApproval,
          requestedAt: now,
          approvedAt: null,
          processedAt: null,
          completedAt: null,
          notes: notes.trim(),
        );

        _log(
          'operation=requestPayout step=createPayout payoutId=${payoutRef.id}',
        );
        transaction.set(payoutRef, {
          ...payout.toJson(),
          'requestedBy': trimmedFreelancerId,
          'method': 'demoBank',
          'accountLabel': cleanDestinationName,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
        _log(
          'operation=requestPayout step=updateWallet payoutId=${payoutRef.id}',
        );
        transaction.set(walletRef, {
          // Heal identity fields so wallet update rules can authorize top-up wallets.
          'walletId': trimmedFreelancerId,
          'freelancerId': trimmedFreelancerId,
          // Keep raw wallet operands so rules equality matches getAfter(payout).amount.
          'availableBalance': wallet.availableBalance - withdrawAmount,
          'pendingPayoutBalance':
              wallet.pendingPayoutBalance + withdrawAmount,
          'activePayoutId': payoutRef.id,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        _log(
          'operation=requestPayout step=createLedger payoutId=${payoutRef.id}',
        );
        transaction.set(
          ledgerRef,
          _ledgerJson(
            transactionId: ledgerRef.id,
            payout: payout,
            type: CommerceTransactionType.payoutRequest,
            status: CommerceTransactionStatus.pending,
            description:
                'Demo payout request created. Funds are reserved from available balance.',
            createdAt: now,
          ),
        );
      });
    } on FirebaseException catch (e) {
      _permissionLog(
        operation: 'requestPayout',
        path:
            'freelancerWallets/$freelancerId + payouts + commerceTransactions',
        uid: freelancerId,
        error: e,
      );
      developer.log(
        '[FreelancerPayoutV2] requestPayout FirebaseException '
        'code=${e.code} message=${e.message}',
      );
      throw FirestoreException.fromCode(e.code, e.message);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to request payout: ${e.toString()}');
    }
  }

  @override
  Future<void> approvePayout({
    required String payoutId,
    required String adminId,
  }) {
    return _setStatus(
      payoutId: payoutId,
      expected: PayoutStatus.pendingApproval,
      next: PayoutStatus.approved,
      field: 'approvedAt',
      actorField: 'approvedBy',
      adminId: adminId,
    );
  }

  @override
  Future<void> processPayout({
    required String payoutId,
    required String adminId,
  }) {
    return _setStatus(
      payoutId: payoutId,
      expected: PayoutStatus.approved,
      next: PayoutStatus.processing,
      field: 'processedAt',
      actorField: 'processedBy',
      adminId: adminId,
    );
  }

  @override
  Future<void> rejectPayout({
    required String payoutId,
    required String adminId,
    required String notes,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        _log(
          'operation=rejectPayout step=readPayout payoutId=$payoutId adminId=$adminId',
        );
        final payoutRef = _payoutsRef.doc(payoutId);
        final payoutDoc = await transaction.get(payoutRef);
        if (!payoutDoc.exists || payoutDoc.data() == null) {
          throw const FirestoreException('Payout request not found.');
        }
        final payout = PayoutModel.fromFirestore(payoutDoc);
        if (!PayoutStatus.isActive(payout.status)) {
          throw const FirestoreException(
            'Only active payout requests can be rejected.',
          );
        }
        final walletRef = _walletsRef.doc(payout.freelancerId);
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists || walletDoc.data() == null) {
          throw const FirestoreException('Wallet not found.');
        }
        final wallet = FreelancerWalletModel.fromFirestore(walletDoc);
        if (wallet.pendingPayoutBalance < payout.amount) {
          throw const FirestoreException(
            'Reserved payout balance is not enough for this rejection.',
          );
        }
        final now = DateTime.now();
        final transactionRef = _transactionsRef.doc(
          _payoutLedgerId('rejected', payoutId),
        );
        final transactionDoc = await transaction.get(transactionRef);
        if (transactionDoc.exists) {
          throw const FirestoreException(
            'This payout rejection is already recorded.',
          );
        }
        transaction.set(payoutRef, {
          'status': PayoutStatus.rejected,
          'completedAt': Timestamp.fromDate(now),
          'rejectedAt': Timestamp.fromDate(now),
          'rejectedBy': adminId,
          'updatedAt': Timestamp.fromDate(now),
          'notes': notes.trim().isEmpty
              ? 'Rejected by sandbox admin.'
              : notes.trim(),
        }, SetOptions(merge: true));
        transaction.set(walletRef, {
          'availableBalance': wallet.availableBalance + payout.amount,
          'pendingPayoutBalance': math.max(
            0,
            wallet.pendingPayoutBalance - payout.amount,
          ),
          'activePayoutId': FieldValue.delete(),
          'lastPayoutId': payout.payoutId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        transaction.set(
          transactionRef,
          _ledgerJson(
            transactionId: transactionRef.id,
            payout: payout,
            type: CommerceTransactionType.payoutRejected,
            status: CommerceTransactionStatus.cleared,
            description:
                'Demo payout rejected and reserved funds returned to available balance.',
            createdAt: now,
          ),
        );
      });
    } on FirebaseException catch (e) {
      _permissionLog(
        operation: 'rejectPayout',
        path: 'payouts/$payoutId + freelancerWallets + commerceTransactions',
        uid: adminId,
        error: e,
      );
      throw FirestoreException.fromCode(e.code, e.message);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to reject payout: ${e.toString()}');
    }
  }

  @override
  Future<void> markPayoutPaid({
    required String payoutId,
    required String adminId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        _log(
          'operation=markPayoutPaid step=readPayout payoutId=$payoutId adminId=$adminId',
        );
        final payoutRef = _payoutsRef.doc(payoutId);
        final payoutDoc = await transaction.get(payoutRef);
        if (!payoutDoc.exists || payoutDoc.data() == null) {
          throw const FirestoreException('Payout request not found.');
        }
        final payout = PayoutModel.fromFirestore(payoutDoc);
        if (payout.status != PayoutStatus.processing &&
            payout.status != PayoutStatus.approved) {
          throw const FirestoreException(
            'Only approved or processing payouts can be marked paid.',
          );
        }

        final walletRef = _walletsRef.doc(payout.freelancerId);
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists || walletDoc.data() == null) {
          throw const FirestoreException('Wallet not found.');
        }
        final wallet = FreelancerWalletModel.fromFirestore(walletDoc);
        if (wallet.pendingPayoutBalance < payout.amount) {
          throw const FirestoreException(
            'Reserved payout balance is not enough to mark this paid.',
          );
        }
        final now = DateTime.now();
        final transactionRef = _transactionsRef.doc(
          _payoutLedgerId('paid', payoutId),
        );
        final transactionDoc = await transaction.get(transactionRef);
        if (transactionDoc.exists) {
          throw const FirestoreException('This payout is already recorded.');
        }

        transaction.set(payoutRef, {
          'status': PayoutStatus.paid,
          'processedAt': payout.processedAt == null
              ? Timestamp.fromDate(now)
              : Timestamp.fromDate(payout.processedAt!),
          'completedAt': Timestamp.fromDate(now),
          'paidAt': Timestamp.fromDate(now),
          'paidBy': adminId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        transaction.set(walletRef, {
          'pendingPayoutBalance': math.max(
            0,
            wallet.pendingPayoutBalance - payout.amount,
          ),
          'lifetimeWithdrawn': wallet.lifetimeWithdrawn + payout.amount,
          'activePayoutId': FieldValue.delete(),
          'lastPayoutId': payout.payoutId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        transaction.set(
          transactionRef,
          _ledgerJson(
            transactionId: transactionRef.id,
            payout: payout,
            type: CommerceTransactionType.payoutPaid,
            status: CommerceTransactionStatus.cleared,
            description:
                'Demo payout marked paid to ${payout.destinationType}. No real money was transferred.',
            createdAt: now,
          ),
        );
      });
    } on FirebaseException catch (e) {
      _permissionLog(
        operation: 'markPayoutPaid',
        path: 'payouts/$payoutId + freelancerWallets + commerceTransactions',
        uid: adminId,
        error: e,
      );
      throw FirestoreException.fromCode(e.code, e.message);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to mark payout paid: ${e.toString()}');
    }
  }

  Future<void> _setStatus({
    required String payoutId,
    required String expected,
    required String next,
    required String field,
    required String actorField,
    required String adminId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        _log(
          'operation=$next step=readPayout payoutId=$payoutId adminId=$adminId',
        );
        final payoutRef = _payoutsRef.doc(payoutId);
        final doc = await transaction.get(payoutRef);
        if (!doc.exists || doc.data() == null) {
          throw const FirestoreException('Payout request not found.');
        }
        final payout = PayoutModel.fromFirestore(doc);
        if (payout.status != expected) {
          throw FirestoreException('Payout must be $expected before $next.');
        }
        transaction.set(payoutRef, {
          'status': next,
          field: Timestamp.fromDate(DateTime.now()),
          actorField: adminId,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'notes': 'Updated by sandbox admin $adminId.',
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      _permissionLog(
        operation: next,
        path: 'payouts/$payoutId',
        uid: adminId,
        error: e,
      );
      throw FirestoreException.fromCode(e.code, e.message);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to update payout: ${e.toString()}');
    }
  }

  String _payoutId(String freelancerId, DateTime now) {
    return 'sandbox_payout_${freelancerId}_${now.millisecondsSinceEpoch}';
  }

  @override
  Future<void> cancelPayout({
    required String payoutId,
    required String freelancerId,
  }) async {
    try {
      final trimmedFreelancerId = freelancerId.trim();
      await _firestore.runTransaction((transaction) async {
        _log(
          'operation=cancelPayout step=readPayout payoutId=$payoutId freelancerId=$trimmedFreelancerId',
        );
        final payoutRef = _payoutsRef.doc(payoutId);
        final payoutDoc = await transaction.get(payoutRef);
        if (!payoutDoc.exists || payoutDoc.data() == null) {
          throw const FirestoreException('Payout request not found.');
        }
        final payout = PayoutModel.fromFirestore(payoutDoc);
        if (payout.freelancerId != trimmedFreelancerId) {
          throw const FirestoreException(
            'You can only cancel your own payout.',
          );
        }
        if (payout.status != PayoutStatus.pendingApproval) {
          throw const FirestoreException(
            'Only pending payout requests can be cancelled.',
          );
        }

        final walletRef = _walletsRef.doc(trimmedFreelancerId);
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists || walletDoc.data() == null) {
          throw const FirestoreException('Wallet not found.');
        }
        final wallet = FreelancerWalletModel.fromFirestore(walletDoc);
        if (wallet.pendingPayoutBalance < payout.amount) {
          throw const FirestoreException(
            'Reserved payout balance is not enough for cancellation.',
          );
        }

        final now = DateTime.now();
        final ledgerRef = _transactionsRef.doc(
          _payoutLedgerId('cancelled', payoutId),
        );
        final ledgerDoc = await transaction.get(ledgerRef);
        if (ledgerDoc.exists) {
          throw const FirestoreException(
            'This payout cancellation is already recorded.',
          );
        }
        transaction.set(payoutRef, {
          'status': PayoutStatus.cancelled,
          'completedAt': Timestamp.fromDate(now),
          'cancelledAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'notes': 'Cancelled by freelancer.',
        }, SetOptions(merge: true));
        transaction.set(walletRef, {
          'availableBalance': wallet.availableBalance + payout.amount,
          'pendingPayoutBalance': math.max(
            0,
            wallet.pendingPayoutBalance - payout.amount,
          ),
          'activePayoutId': FieldValue.delete(),
          'lastPayoutId': payout.payoutId,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        transaction.set(
          ledgerRef,
          _ledgerJson(
            transactionId: ledgerRef.id,
            payout: payout,
            type: CommerceTransactionType.payoutCancelled,
            status: CommerceTransactionStatus.cleared,
            description:
                'Demo payout cancelled and reserved funds returned to available balance.',
            createdAt: now,
          ),
        );
      });
    } on FirebaseException catch (e) {
      _permissionLog(
        operation: 'cancelPayout',
        path:
            'payouts/$payoutId + freelancerWallets/$freelancerId + commerceTransactions',
        uid: freelancerId,
        error: e,
      );
      throw FirestoreException.fromCode(e.code, e.message);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to cancel payout: ${e.toString()}');
    }
  }

  String _payoutLedgerId(String action, String payoutId) =>
      'sandbox_payout_${action}_$payoutId';

  double _roundMoney(double value) => (value * 100).round() / 100;

  Map<String, dynamic> _ledgerJson({
    required String transactionId,
    required PayoutModel payout,
    required String type,
    required String status,
    required String description,
    required DateTime createdAt,
  }) {
    return CommerceTransactionModel(
      transactionId: transactionId,
      orderId: '',
      serviceRequestId: '',
      userId: payout.freelancerId,
      walletId: payout.walletId,
      type: type,
      amount: payout.amount,
      currency: payout.currency,
      status: status,
      referenceId: payout.payoutId,
      description: description,
      createdAt: createdAt,
    ).toJson();
  }

  void _log(String message) {
    developer.log('[FreelancerPayoutV2] $message');
  }

  void _permissionLog({
    required String operation,
    required String path,
    required String uid,
    required FirebaseException error,
  }) {
    final normalized = error.code
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .split('/')
        .last;
    final message = (error.message ?? '').toLowerCase();
    final looksDenied =
        normalized == 'permission-denied' ||
        message.contains('permission-denied') ||
        message.contains('permission_denied') ||
        message.contains('missing or insufficient permissions');
    // Windows desktop often reports permission-denied as code "unknown".
    if (!looksDenied && normalized != 'unknown') return;
    developer.log(
      '[FirestorePermissionDenied] feature=FreelancerPayoutV2 '
      'repository=PayoutRepository operation=$operation path=$path '
      'action=transaction uid=$uid code=${error.code} message=${error.message}',
    );
  }
}
