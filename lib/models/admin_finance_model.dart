import '../features/payment/config/stripe_config.dart';
import 'commerce_transaction_model.dart';
import 'commission_ledger_model.dart';
import 'dispute_model.dart';
import 'escrow_hold_model.dart';
import '../features/courses/data/models/marketplace_models.dart';
import 'freelancer_service_model.dart';
import 'freelancer_wallet_model.dart';
import 'invoice_model.dart';
import 'payout_model.dart';
import 'refund_model.dart';
import 'service_order_model.dart';

class AdminFinanceSnapshot {
  const AdminFinanceSnapshot({
    required this.orders,
    required this.transactions,
    required this.wallets,
    required this.invoices,
    required this.payouts,
    required this.refunds,
    required this.disputes,
    required this.escrows,
    required this.commissions,
    required this.services,
    required this.coursePurchases,
    required this.generatedAt,
  });

  final List<ServiceOrderModel> orders;
  final List<CommerceTransactionModel> transactions;
  final List<FreelancerWalletModel> wallets;
  final List<InvoiceModel> invoices;
  final List<PayoutModel> payouts;
  final List<RefundModel> refunds;
  final List<DisputeModel> disputes;
  final List<EscrowHoldModel> escrows;
  final List<CommissionLedgerModel> commissions;
  final List<FreelancerServiceModel> services;
  final List<CoursePurchase> coursePurchases;
  final DateTime generatedAt;

  String get currency {
    if (orders.isNotEmpty) return orders.first.currency;
    if (transactions.isNotEmpty) return transactions.first.currency;
    if (wallets.isNotEmpty) return wallets.first.currency;
    if (coursePurchases.isNotEmpty) return coursePurchases.first.currency;
    return 'USD';
  }

  AdminFinanceSnapshot filtered(AdminFinanceFilter filter) {
    final filteredOrders = orders.where(filter.matchesOrder).toList();
    final orderIds = filteredOrders.map((order) => order.orderId).toSet();
    return AdminFinanceSnapshot(
      orders: filteredOrders,
      transactions: transactions
          .where((item) => orderIds.isEmpty || orderIds.contains(item.orderId))
          .toList(),
      wallets: wallets.where(filter.matchesWallet).toList(),
      invoices: invoices
          .where((item) => orderIds.isEmpty || orderIds.contains(item.orderId))
          .toList(),
      payouts: payouts.where(filter.matchesPayout).toList(),
      refunds: refunds
          .where((item) => orderIds.isEmpty || orderIds.contains(item.orderId))
          .toList(),
      disputes: disputes
          .where((item) => orderIds.isEmpty || orderIds.contains(item.orderId))
          .toList(),
      escrows: escrows
          .where((item) => orderIds.isEmpty || orderIds.contains(item.orderId))
          .toList(),
      commissions: commissions
          .where((item) => orderIds.isEmpty || orderIds.contains(item.orderId))
          .toList(),
      services: services.where(filter.matchesService).toList(),
      coursePurchases: coursePurchases
          .where(filter.matchesCoursePurchase)
          .toList(),
      generatedAt: generatedAt,
    );
  }

  FinanceKpis get kpis {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    final yearStart = DateTime(now.year);

    double revenueFrom(DateTime start) => orders
        .where(
          (order) => order.paidAt != null && !order.paidAt!.isBefore(start),
        )
        .fold<double>(0, (sum, order) => sum + order.totalAmount);

    final lifetimeRevenue = orders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );
    final commission = commissions
        .where((item) => item.source != 'course')
        .fold<double>(0, (sum, item) => sum + item.amount);
    final courseFees = coursePurchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.platformFee,
    );
    final refundValue = refunds
        .where((item) => item.status == RefundStatus.processed)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final completed = orders
        .where((order) => order.orderStatus == ServiceOrderStatus.completed)
        .toList();
    final completionSeconds = completed
        .where((order) => order.completedAt != null)
        .map(
          (order) => order.completedAt!.difference(order.createdAt).inSeconds,
        )
        .toList();
    final averageCompletionHours = completionSeconds.isEmpty
        ? 0.0
        : completionSeconds.fold<int>(0, (sum, seconds) => sum + seconds) /
              completionSeconds.length /
              3600;

    return FinanceKpis(
      todayRevenue: revenueFrom(todayStart),
      weeklyRevenue: revenueFrom(weekStart),
      monthlyRevenue: revenueFrom(monthStart),
      yearlyRevenue: revenueFrom(yearStart),
      lifetimeRevenue: lifetimeRevenue,
      grossRevenue: lifetimeRevenue,
      platformCommission: commission + courseFees,
      netRevenue: commission + courseFees - refundValue,
      orderCount: orders.length,
      completedOrders: completed.length,
      pendingOrders: orders
          .where((order) => order.orderStatus == ServiceOrderStatus.pending)
          .length,
      cancelledOrders: orders
          .where((order) => order.orderStatus == ServiceOrderStatus.cancelled)
          .length,
      refundCount: refunds.length,
      refundValue: refundValue,
      escrowHeld: escrows
          .where((item) => item.status == EscrowHoldStatus.held)
          .fold<double>(0, (sum, item) => sum + item.amount),
      escrowReleased: orders
          .where(
            (order) => order.escrowStatus == ServiceOrderEscrowStatus.released,
          )
          .fold<double>(0, (sum, order) => sum + order.totalAmount),
      pendingWithdrawals: payouts
          .where((item) => PayoutStatus.isActive(item.status))
          .fold<double>(0, (sum, item) => sum + item.amount),
      completedWithdrawals: payouts
          .where((item) => item.status == PayoutStatus.paid)
          .fold<double>(0, (sum, item) => sum + item.amount),
      walletAvailable: wallets.fold<double>(
        0,
        (sum, wallet) => sum + wallet.availableBalance,
      ),
      walletPending: wallets.fold<double>(
        0,
        (sum, wallet) => sum + wallet.pendingBalance,
      ),
      walletEscrow: wallets.fold<double>(
        0,
        (sum, wallet) => sum + wallet.escrowBalance,
      ),
      averageOrderValue: orders.isEmpty ? 0 : lifetimeRevenue / orders.length,
      averageCompletionHours: averageCompletionHours,
    );
  }

  List<FinanceBreakdownItem> topServices() {
    return _topBy(
      orders,
      keyOf: (order) => order.serviceTitle,
      amountOf: (order) => order.totalAmount,
    );
  }

  List<FinanceBreakdownItem> topFreelancers() {
    return _topBy(
      orders,
      keyOf: (order) => order.freelancerName,
      amountOf: (order) => order.freelancerEarnings,
    );
  }

  List<FinanceBreakdownItem> topCategories() {
    return _topBy(
      orders,
      keyOf: (order) => order.serviceCategory,
      amountOf: (order) => order.totalAmount,
    );
  }

  List<FinanceBreakdownItem> topClients() {
    return _topBy(
      orders,
      keyOf: (order) => order.clientName,
      amountOf: (order) => order.totalAmount,
    );
  }

  List<FinanceTrendPoint> trend(
    DateTime Function(ServiceOrderModel order) dateOf,
    double Function(ServiceOrderModel order) amountOf,
  ) {
    final buckets = <String, double>{};
    for (final order in orders) {
      final date = dateOf(order);
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      buckets[key] = (buckets[key] ?? 0) + amountOf(order);
    }
    final points =
        buckets.entries
            .map(
              (entry) =>
                  FinanceTrendPoint(label: entry.key, value: entry.value),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    return points.length > 14 ? points.sublist(points.length - 14) : points;
  }

  /// Phase 5 — platform fees split by the checkout provider that produced
  /// them. Presentation only: KPI totals are unchanged, and records without a
  /// provider tag fall into "Unattributed".
  List<FinanceBreakdownItem> platformFeesByProvider() {
    final totals = <String, double>{};
    final counts = <String, int>{};

    void add(String? raw, double amount) {
      final label = paymentProviderLabel(raw);
      totals[label] = (totals[label] ?? 0) + amount;
      counts[label] = (counts[label] ?? 0) + 1;
    }

    for (final purchase in coursePurchases) {
      add(
        purchase.provider.isNotEmpty ? purchase.provider : purchase.paymentMethod,
        purchase.platformFee,
      );
    }
    for (final order in orders) {
      add(order.sandboxPaymentMethod, order.platformFee);
    }

    final items =
        totals.entries
            .map(
              (entry) => FinanceBreakdownItem(
                label: entry.key,
                amount: entry.value,
                count: counts[entry.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    return items.length > 5 ? items.sublist(0, 5) : items;
  }

  List<FinanceTrendPoint> platformCommissionTrend() {
    final buckets = <String, double>{};
    void add(DateTime date, double amount) {
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      buckets[key] = (buckets[key] ?? 0) + amount;
    }

    for (final commission in commissions.where(
      (item) => item.source != 'course',
    )) {
      add(commission.createdAt, commission.amount);
    }
    for (final purchase in coursePurchases) {
      add(purchase.purchasedAt, purchase.platformFee);
    }

    final points =
        buckets.entries
            .map(
              (entry) =>
                  FinanceTrendPoint(label: entry.key, value: entry.value),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    return points.length > 14 ? points.sublist(points.length - 14) : points;
  }
}

class FinanceKpis {
  const FinanceKpis({
    required this.todayRevenue,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.yearlyRevenue,
    required this.lifetimeRevenue,
    required this.grossRevenue,
    required this.platformCommission,
    required this.netRevenue,
    required this.orderCount,
    required this.completedOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.refundCount,
    required this.refundValue,
    required this.escrowHeld,
    required this.escrowReleased,
    required this.pendingWithdrawals,
    required this.completedWithdrawals,
    required this.walletAvailable,
    required this.walletPending,
    required this.walletEscrow,
    required this.averageOrderValue,
    required this.averageCompletionHours,
  });

  final double todayRevenue;
  final double weeklyRevenue;
  final double monthlyRevenue;
  final double yearlyRevenue;
  final double lifetimeRevenue;
  final double grossRevenue;
  final double platformCommission;
  final double netRevenue;
  final int orderCount;
  final int completedOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final int refundCount;
  final double refundValue;
  final double escrowHeld;
  final double escrowReleased;
  final double pendingWithdrawals;
  final double completedWithdrawals;
  final double walletAvailable;
  final double walletPending;
  final double walletEscrow;
  final double averageOrderValue;
  final double averageCompletionHours;
}

class AdminFinanceFilter {
  const AdminFinanceFilter({
    this.startDate,
    this.endDate,
    this.status = 'all',
    this.freelancerQuery = '',
    this.customerQuery = '',
    this.category = 'all',
    this.minRevenue,
    this.maxRevenue,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String freelancerQuery;
  final String customerQuery;
  final String category;
  final double? minRevenue;
  final double? maxRevenue;

  bool matchesOrder(ServiceOrderModel order) {
    final date = order.paidAt ?? order.createdAt;
    if (startDate != null && date.isBefore(startDate!)) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;
    if (status != 'all' && order.orderStatus != status) return false;
    if (category != 'all' && order.serviceCategory != category) return false;
    if (freelancerQuery.trim().isNotEmpty &&
        !order.freelancerName.toLowerCase().contains(
          freelancerQuery.trim().toLowerCase(),
        )) {
      return false;
    }
    if (customerQuery.trim().isNotEmpty &&
        !order.clientName.toLowerCase().contains(
          customerQuery.trim().toLowerCase(),
        )) {
      return false;
    }
    if (minRevenue != null && order.totalAmount < minRevenue!) return false;
    if (maxRevenue != null && order.totalAmount > maxRevenue!) return false;
    return true;
  }

  bool matchesWallet(FreelancerWalletModel wallet) {
    if (freelancerQuery.trim().isEmpty) return true;
    return wallet.freelancerId.toLowerCase().contains(
      freelancerQuery.trim().toLowerCase(),
    );
  }

  bool matchesPayout(PayoutModel payout) {
    if (freelancerQuery.trim().isEmpty) return true;
    return payout.freelancerId.toLowerCase().contains(
      freelancerQuery.trim().toLowerCase(),
    );
  }

  bool matchesService(FreelancerServiceModel service) {
    if (category != 'all' && service.category != category) return false;
    if (freelancerQuery.trim().isEmpty) return true;
    return service.freelancerName.toLowerCase().contains(
      freelancerQuery.trim().toLowerCase(),
    );
  }

  bool matchesCoursePurchase(CoursePurchase purchase) {
    if (startDate != null && purchase.purchasedAt.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null && purchase.purchasedAt.isAfter(endDate!)) return false;
    if (freelancerQuery.trim().isNotEmpty &&
        !purchase.teacherId.toLowerCase().contains(
          freelancerQuery.trim().toLowerCase(),
        )) {
      return false;
    }
    if (customerQuery.trim().isNotEmpty &&
        !purchase.studentId.toLowerCase().contains(
          customerQuery.trim().toLowerCase(),
        )) {
      return false;
    }
    return true;
  }

  AdminFinanceFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    bool clearStart = false,
    bool clearEnd = false,
    String? status,
    String? freelancerQuery,
    String? customerQuery,
    String? category,
    double? minRevenue,
    double? maxRevenue,
    bool clearMin = false,
    bool clearMax = false,
  }) {
    return AdminFinanceFilter(
      startDate: clearStart ? null : startDate ?? this.startDate,
      endDate: clearEnd ? null : endDate ?? this.endDate,
      status: status ?? this.status,
      freelancerQuery: freelancerQuery ?? this.freelancerQuery,
      customerQuery: customerQuery ?? this.customerQuery,
      category: category ?? this.category,
      minRevenue: clearMin ? null : minRevenue ?? this.minRevenue,
      maxRevenue: clearMax ? null : maxRevenue ?? this.maxRevenue,
    );
  }
}

class FinanceBreakdownItem {
  const FinanceBreakdownItem({
    required this.label,
    required this.amount,
    required this.count,
  });

  final String label;
  final double amount;
  final int count;
}

class FinanceTrendPoint {
  const FinanceTrendPoint({required this.label, required this.value});

  final String label;
  final double value;
}

List<FinanceBreakdownItem> _topBy(
  List<ServiceOrderModel> orders, {
  required String Function(ServiceOrderModel order) keyOf,
  required double Function(ServiceOrderModel order) amountOf,
}) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final order in orders) {
    final key = keyOf(order).trim().isEmpty ? 'Uncategorized' : keyOf(order);
    totals[key] = (totals[key] ?? 0) + amountOf(order);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final items =
      totals.entries
          .map(
            (entry) => FinanceBreakdownItem(
              label: entry.key,
              amount: entry.value,
              count: counts[entry.key] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
  return items.length > 5 ? items.sublist(0, 5) : items;
}
