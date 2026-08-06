import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/courses/data/models/marketplace_models.dart';
import '../models/admin_finance_model.dart';
import '../models/commerce_transaction_model.dart';
import '../models/commission_ledger_model.dart';
import '../models/dispute_model.dart';
import '../models/escrow_hold_model.dart';
import '../models/freelancer_service_model.dart';
import '../models/freelancer_wallet_model.dart';
import '../models/invoice_model.dart';
import '../models/payout_model.dart';
import '../models/refund_model.dart';
import '../models/service_order_model.dart';
import 'firebase_providers.dart';

/// Caps each collection scan used by the admin finance dashboard.
const int kAdminFinancePageSize = 200;

Future<QuerySnapshot<Map<String, dynamic>>> _limitedCollection(
  FirebaseFirestore firestore,
  String collection, {
  String? orderByField,
}) async {
  try {
    Query<Map<String, dynamic>> query = firestore.collection(collection);
    if (orderByField != null) {
      query = query.orderBy(orderByField, descending: true);
    }
    return await query.limit(kAdminFinancePageSize).get();
  } on FirebaseException {
    // Fallback if a single-field index is still building.
    return firestore.collection(collection).limit(kAdminFinancePageSize).get();
  }
}

final adminFinanceSnapshotProvider = FutureProvider<AdminFinanceSnapshot>((
  ref,
) async {
  final firestore = ref.watch(firestoreProvider);
  final results = await Future.wait([
    _limitedCollection(firestore, 'serviceOrders', orderByField: 'createdAt'),
    _limitedCollection(
      firestore,
      'commerceTransactions',
      orderByField: 'createdAt',
    ),
    _limitedCollection(
      firestore,
      'freelancerWallets',
      orderByField: 'updatedAt',
    ),
    _limitedCollection(firestore, 'invoices', orderByField: 'issuedAt'),
    _limitedCollection(firestore, 'payouts', orderByField: 'requestedAt'),
    _limitedCollection(firestore, 'refunds', orderByField: 'createdAt'),
    _limitedCollection(firestore, 'disputes', orderByField: 'createdAt'),
    _limitedCollection(firestore, 'serviceEscrows', orderByField: 'createdAt'),
    _limitedCollection(
      firestore,
      'commissionLedger',
      orderByField: 'createdAt',
    ),
    _limitedCollection(
      firestore,
      'freelancerServices',
      orderByField: 'updatedAt',
    ),
    _limitedCollection(
      firestore,
      'course_purchases',
      orderByField: 'purchasedAt',
    ),
  ]);

  final orders = _mapDocs<ServiceOrderModel>(
    results[0],
    ServiceOrderModel.fromFirestore,
  )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final transactions = _mapDocs<CommerceTransactionModel>(
    results[1],
    CommerceTransactionModel.fromFirestore,
  )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final wallets = _mapDocs<FreelancerWalletModel>(
    results[2],
    FreelancerWalletModel.fromFirestore,
  )..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final invoices = _mapDocs<InvoiceModel>(
    results[3],
    InvoiceModel.fromFirestore,
  )..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  final payouts = _mapDocs<PayoutModel>(results[4], PayoutModel.fromFirestore)
    ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  final refunds = _mapDocs<RefundModel>(results[5], RefundModel.fromFirestore)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final disputes = _mapDocs<DisputeModel>(
    results[6],
    DisputeModel.fromFirestore,
  )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final escrows = _mapDocs<EscrowHoldModel>(
    results[7],
    EscrowHoldModel.fromFirestore,
  )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final commissions = _mapDocs<CommissionLedgerModel>(
    results[8],
    CommissionLedgerModel.fromFirestore,
  )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final services = _mapDocs<FreelancerServiceModel>(
    results[9],
    FreelancerServiceModel.fromFirestore,
  )..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final coursePurchases = _mapDocs<CoursePurchase>(
    results[10],
    CoursePurchase.fromFirestore,
  )..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

  return AdminFinanceSnapshot(
    orders: orders,
    transactions: transactions,
    wallets: wallets,
    invoices: invoices,
    payouts: payouts,
    refunds: refunds,
    disputes: disputes,
    escrows: escrows,
    commissions: commissions,
    services: services,
    coursePurchases: coursePurchases,
    generatedAt: DateTime.now(),
  );
});

List<T> _mapDocs<T>(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  T Function(DocumentSnapshot<Map<String, dynamic>> doc) mapper,
) {
  return snapshot.docs.map(mapper).toList();
}
