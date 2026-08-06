import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../features/courses/data/models/marketplace_models.dart';
import '../features/courses/data/repositories/course_purchase_repository.dart';
import '../models/teacher_wallet_model.dart';
import 'teacher_wallet_repository.dart';

/// Persists teacher wallet on `teachers/{uid}` so it works with existing
/// deployed rules (standalone `teacherWallets` rules may not be deployable yet).
class TeacherWalletRepositoryImpl implements TeacherWalletRepository {
  const TeacherWalletRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  static const _walletField = 'courseWallet';
  static const _transactionsField = 'courseWalletTransactions';
  static const _maxTransactions = 40;

  DocumentReference<Map<String, dynamic>> _teacherRef(String teacherId) =>
      _firestore.collection('teachers').doc(teacherId);

  CoursePurchaseRepository get _purchaseRepo =>
      CoursePurchaseRepository(_firestore);

  TeacherWalletModel? _walletFromTeacherDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) return null;
    final raw = doc.data()![_walletField];
    if (raw is! Map) {
      return TeacherWalletModel.empty(teacherId: doc.id);
    }
    return TeacherWalletModel.fromMap(
      Map<String, dynamic>.from(raw),
      fallbackId: doc.id,
    );
  }

  List<TeacherWalletTransactionModel> _transactionsFromTeacherDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) {
      return const <TeacherWalletTransactionModel>[];
    }
    final raw = doc.data()![_transactionsField];
    if (raw is! List) return const <TeacherWalletTransactionModel>[];
    final items = <TeacherWalletTransactionModel>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      items.add(
        TeacherWalletTransactionModel.fromMap(
          Map<String, dynamic>.from(entry),
        ),
      );
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Stream<TeacherWalletModel?> watchWallet(String teacherId) {
    return _teacherRef(teacherId).snapshots().map(_walletFromTeacherDoc);
  }

  @override
  Stream<List<TeacherWalletTransactionModel>> watchTransactions(
    String teacherId,
  ) {
    return _teacherRef(teacherId).snapshots().map(_transactionsFromTeacherDoc);
  }

  Future<List<CoursePurchase>> _loadSales(String teacherId) async {
    try {
      return await _purchaseRepo.getTeacherSalesHistory(teacherId);
    } catch (_) {
      final query = await _firestore
          .collection('course_purchases')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      final items = query.docs.map(CoursePurchase.fromFirestore).toList();
      items.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
      return items;
    }
  }

  @override
  Future<void> ensureWallet(String teacherId) async {
    try {
      final trimmed = teacherId.trim();
      if (trimmed.isEmpty) return;
      final ref = _teacherRef(trimmed);
      final doc = await ref.get();
      if (!doc.exists) {
        throw const FirestoreException(
          'Teacher profile not found. Complete teacher profile setup first.',
        );
      }
      final data = doc.data() ?? const <String, dynamic>{};
      if (data[_walletField] is Map) return;

      final now = DateTime.now();
      await ref.set({
        _walletField: TeacherWalletModel.empty(
          teacherId: trimmed,
          now: now,
        ).toJson(),
        _transactionsField: <Map<String, dynamic>>[],
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to prepare teacher wallet: $e');
    }
  }

  @override
  Future<void> syncFromCourseSales(String teacherId) async {
    try {
      final trimmed = teacherId.trim();
      if (trimmed.isEmpty) return;

      await ensureWallet(trimmed);
      final purchases = await _loadSales(trimmed);
      final teacherRef = _teacherRef(trimmed);
      final teacherSnap = await teacherRef.get();
      final wallet = _walletFromTeacherDoc(teacherSnap) ??
          TeacherWalletModel.empty(teacherId: trimmed);

      final now = DateTime.now();
      final lifetimeEarnings = purchases.fold<double>(
        0,
        (total, sale) => total + sale.finalAmount,
      );
      final uniqueStudents = purchases.map((p) => p.studentId).toSet().length;
      final monthSales = purchases.where(
        (s) =>
            s.purchasedAt.year == now.year && s.purchasedAt.month == now.month,
      );
      final monthRevenue = monthSales.fold<double>(
        0,
        (total, sale) => total + sale.finalAmount,
      );

      final allocated = wallet.availableBalance + wallet.lifetimeWithdrawn;
      final pendingBalance = (lifetimeEarnings - allocated).clamp(
        0.0,
        double.infinity,
      );

      final nextWallet = TeacherWalletModel(
        walletId: trimmed,
        teacherId: trimmed,
        availableBalance: wallet.availableBalance,
        pendingBalance: pendingBalance,
        lifetimeEarnings: lifetimeEarnings,
        lifetimeWithdrawn: wallet.lifetimeWithdrawn,
        currency: purchases.isNotEmpty
            ? purchases.first.currency
            : wallet.currency,
        totalSalesCount: purchases.length,
        uniqueStudentCount: uniqueStudents,
        monthSalesCount: monthSales.length,
        monthRevenue: monthRevenue,
        updatedAt: now,
        createdAt: wallet.createdAt,
        lastSyncAt: now,
      );

      await teacherRef.set({
        _walletField: nextWallet.toJson(),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to sync teacher wallet: $e');
    }
  }

  Future<void> _mutateWallet({
    required String teacherId,
    required TeacherWalletModel Function(TeacherWalletModel current) update,
    required TeacherWalletTransactionModel Function(TeacherWalletModel current)
        buildTransaction,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final teacherRef = _teacherRef(teacherId);
      final teacherSnap = await transaction.get(teacherRef);
      if (!teacherSnap.exists || teacherSnap.data() == null) {
        throw const FirestoreException('Teacher profile not found.');
      }
      final current = _walletFromTeacherDoc(teacherSnap) ??
          TeacherWalletModel.empty(teacherId: teacherId);
      final next = update(current);
      final txModel = buildTransaction(current);
      final existing = _transactionsFromTeacherDoc(teacherSnap);
      final nextTx = <TeacherWalletTransactionModel>[txModel, ...existing]
          .take(_maxTransactions)
          .toList();

      transaction.set(teacherRef, {
        _walletField: next.toJson(),
        _transactionsField: nextTx.map((item) => item.toJson()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> releasePendingEarnings(String teacherId) async {
    try {
      final trimmed = teacherId.trim();
      if (trimmed.isEmpty) return;

      await _mutateWallet(
        teacherId: trimmed,
        update: (wallet) {
          if (wallet.pendingBalance <= 0) {
            throw const FirestoreException('No pending earnings to release.');
          }
          final now = DateTime.now();
          return TeacherWalletModel(
            walletId: wallet.walletId,
            teacherId: wallet.teacherId,
            availableBalance: wallet.availableBalance + wallet.pendingBalance,
            pendingBalance: 0,
            lifetimeEarnings: wallet.lifetimeEarnings,
            lifetimeWithdrawn: wallet.lifetimeWithdrawn,
            currency: wallet.currency,
            totalSalesCount: wallet.totalSalesCount,
            uniqueStudentCount: wallet.uniqueStudentCount,
            monthSalesCount: wallet.monthSalesCount,
            monthRevenue: wallet.monthRevenue,
            updatedAt: now,
            createdAt: wallet.createdAt,
            lastSyncAt: wallet.lastSyncAt,
          );
        },
        buildTransaction: (wallet) {
          final now = DateTime.now();
          final id = 'teacher_release_${trimmed}_${now.millisecondsSinceEpoch}';
          return TeacherWalletTransactionModel(
            transactionId: id,
            teacherId: trimmed,
            type: TeacherWalletTransactionType.release,
            amount: wallet.pendingBalance,
            currency: wallet.currency,
            description:
                'Demo release moved pending course earnings into available balance.',
            createdAt: now,
            referenceId: 'TW-RELEASE-${now.millisecondsSinceEpoch}',
          );
        },
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to release earnings: $e');
    }
  }

  @override
  Future<void> demoWithdraw(String teacherId, {double? amount}) async {
    try {
      final trimmed = teacherId.trim();
      if (trimmed.isEmpty) return;

      await _mutateWallet(
        teacherId: trimmed,
        update: (wallet) {
          final withdrawAmount = amount ?? wallet.availableBalance;
          if (withdrawAmount <= 0) {
            throw const FirestoreException('No available balance to withdraw.');
          }
          if (withdrawAmount > wallet.availableBalance + 0.001) {
            throw const FirestoreException(
              'Withdraw amount exceeds available balance.',
            );
          }
          final now = DateTime.now();
          return TeacherWalletModel(
            walletId: wallet.walletId,
            teacherId: wallet.teacherId,
            availableBalance: wallet.availableBalance - withdrawAmount,
            pendingBalance: wallet.pendingBalance,
            lifetimeEarnings: wallet.lifetimeEarnings,
            lifetimeWithdrawn: wallet.lifetimeWithdrawn + withdrawAmount,
            currency: wallet.currency,
            totalSalesCount: wallet.totalSalesCount,
            uniqueStudentCount: wallet.uniqueStudentCount,
            monthSalesCount: wallet.monthSalesCount,
            monthRevenue: wallet.monthRevenue,
            updatedAt: now,
            createdAt: wallet.createdAt,
            lastSyncAt: wallet.lastSyncAt,
          );
        },
        buildTransaction: (wallet) {
          final now = DateTime.now();
          final withdrawAmount = amount ?? wallet.availableBalance;
          final id =
              'teacher_withdraw_${trimmed}_${now.millisecondsSinceEpoch}';
          return TeacherWalletTransactionModel(
            transactionId: id,
            teacherId: trimmed,
            type: TeacherWalletTransactionType.withdraw,
            amount: withdrawAmount,
            currency: wallet.currency,
            description:
                'Demo withdrawal recorded. No real bank transfer was processed.',
            createdAt: now,
            referenceId: 'TW-WD-${now.millisecondsSinceEpoch}',
          );
        },
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to withdraw: $e');
    }
  }
}
