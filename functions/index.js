const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const DECISION = {
  refund: "refundToClient",
  release: "releaseToFreelancer",
  split: "splitRelease",
  reject: "rejectCase",
};

exports.resolutionSettlementExecutor = onDocumentCreated(
  "resolutionSettlementRequests/{requestId}",
  async (event) => {
    const requestId = event.params.requestId;
    const requestRef = db.collection("resolutionSettlementRequests").doc(requestId);

    try {
      await requestRef.set(
        {
          status: "processing",
          updatedAt: Timestamp.now(),
        },
        { merge: true },
      );

      await db.runTransaction(async (transaction) => {
        await executeSettlementRequest(transaction, requestRef, requestId);
      });
    } catch (error) {
      logger.error("[ResolutionSettlementExecutor] failed", {
        requestId,
        code: error.code || error.name || "settlement-failed",
        message: error.message || String(error),
      });
      await requestRef.set(
        {
          status: "failed",
          errorCode: error.code || error.name || "settlement-failed",
          errorMessage: error.message || String(error),
          updatedAt: Timestamp.now(),
          processedAt: Timestamp.now(),
        },
        { merge: true },
      );
    }
  },
);

async function executeSettlementRequest(transaction, requestRef, requestId) {
  let step = "readRequest";
  const now = Timestamp.now();

  logger.info("[ResolutionSettlementExecutor]", { requestId, step });
  const requestSnap = await transaction.get(requestRef);
  if (!requestSnap.exists) {
    throw new SettlementError("request-not-found", "Settlement request not found.");
  }
  const request = requestSnap.data();
  if (!["pending", "processing"].includes(request.status)) {
    logger.info("[ResolutionSettlementExecutor] skipped non-pending request", {
      requestId,
      status: request.status,
    });
    return;
  }

  const decision = stringValue(request.decision);
  const releaseAmount = numberValue(request.releaseAmount);
  const refundAmount = numberValue(request.refundAmount);
  const settlementTotal = releaseAmount + refundAmount;

  const caseRef = db.collection("resolutionCases").doc(stringValue(request.caseId));
  const orderRef = db.collection("serviceOrders").doc(stringValue(request.orderId));
  const escrowRef = db.collection("serviceEscrows").doc(stringValue(request.orderId));
  const customerWalletRef = db.collection("customerWallets").doc(stringValue(request.clientId));
  const freelancerWalletRef = db.collection("freelancerWallets").doc(stringValue(request.freelancerId));
  const settlementRef = db.collection("resolutionSettlements").doc(`settlement_${request.caseId}`);
  const releaseLedgerRef = db
    .collection("walletTransactions")
    .doc(decision === DECISION.split ? `wallet_split_release_${request.caseId}` : `wallet_release_${request.caseId}`);
  const refundLedgerRef = db
    .collection("walletTransactions")
    .doc(decision === DECISION.split ? `wallet_split_refund_${request.caseId}` : `wallet_refund_${request.caseId}`);

  step = "readCase";
  logger.info("[ResolutionSettlementExecutor]", { requestId, step, decision });
  const caseSnap = await transaction.get(caseRef);
  if (!caseSnap.exists) {
    throw new SettlementError("case-not-found", "Resolution case not found.");
  }
  const item = caseSnap.data();

  if (decision === DECISION.reject) {
    await rejectCase(transaction, {
      request,
      requestRef,
      caseRef,
      item,
      now,
    });
    return;
  }

  step = "readOrder";
  logger.info("[ResolutionSettlementExecutor]", { requestId, step, decision });
  const orderSnap = await transaction.get(orderRef);
  if (!orderSnap.exists) {
    throw new SettlementError("order-not-found", "Service order not found.");
  }
  const order = orderSnap.data();

  step = "readEscrow";
  const escrowSnap = await transaction.get(escrowRef);
  if (!escrowSnap.exists) {
    throw new SettlementError("escrow-not-found", "Service escrow not found.");
  }
  const escrow = escrowSnap.data();

  step = "readWallets";
  const customerWalletSnap = await transaction.get(customerWalletRef);
  const freelancerWalletSnap = releaseAmount > 0
    ? await transaction.get(freelancerWalletRef)
    : null;

  step = "readSettlement";
  const settlementSnap = await transaction.get(settlementRef);
  const releaseLedgerSnap = releaseAmount > 0
    ? await transaction.get(releaseLedgerRef)
    : null;
  const refundLedgerSnap = refundAmount > 0
    ? await transaction.get(refundLedgerRef)
    : null;
  const relatedRefund = await readLinkedRefundCase(transaction, item, request.caseId);

  validateSettlement({
    request,
    item,
    order,
    escrow,
    settlementSnap,
    releaseLedgerSnap,
    refundLedgerSnap,
    decision,
    releaseAmount,
    refundAmount,
    settlementTotal,
  });

  const fullRefund = refundAmount > 0 && releaseAmount === 0;
  const splitSettlement = refundAmount > 0 && releaseAmount > 0;
  const escrowStatus = fullRefund ? "refunded" : splitSettlement ? "split" : "released";
  const paymentStatus = fullRefund ? "refunded" : splitSettlement ? "partiallyRefunded" : "released";
  const orderStatus = fullRefund ? "cancelled" : splitSettlement ? "splitSettled" : "completed";

  step = "updateCase";
  logger.info("[ResolutionSettlementExecutor]", { requestId, step, decision });
  transaction.set(
    caseRef,
    {
      status: "resolved",
      resolutionDecision: decision,
      releaseAmount,
      refundAmount,
      adminNotes: stringValue(request.adminNote),
      settlementStatus: "completed",
      isFinancialSettlementRequired: true,
      resolvedAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  closeLinkedRefundCase(transaction, relatedRefund, request, decision, releaseAmount, refundAmount, now);

  step = "updateEscrow";
  transaction.set(
    escrowRef,
    {
      status: escrowStatus,
      releasedAmount: releaseAmount,
      refundedAmount: refundAmount,
      ...(releaseAmount > 0 ? { releasedAt: now } : {}),
      ...(refundAmount > 0 ? { refundedAt: now } : {}),
      resolvedAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  step = "updateOrder";
  transaction.set(
    orderRef,
    {
      paymentStatus,
      escrowStatus,
      orderStatus,
      ...(releaseAmount > 0 ? { escrowReleasedAt: now } : {}),
      ...(refundAmount > 0 ? { refundedAt: now } : {}),
      resolvedAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  step = "updateWallets";
  logger.info("[ResolutionSettlementExecutor]", { requestId, step, decision });
  writeCustomerWallet(transaction, customerWalletRef, customerWalletSnap, {
    clientId: request.clientId,
    currency: request.currency || item.currency || order.currency || "USD",
    refundAmount,
    settlementTotal,
    now,
  });

  if (releaseAmount > 0) {
    writeFreelancerWallet(transaction, freelancerWalletRef, freelancerWalletSnap, {
      freelancerId: request.freelancerId,
      currency: request.currency || item.currency || order.currency || "USD",
      releaseAmount,
      now,
    });
  }

  step = "createSettlement";
  transaction.set(settlementRef, {
    settlementId: settlementRef.id,
    caseId: request.caseId,
    orderId: request.orderId,
    serviceRequestId: item.serviceRequestId,
    clientId: request.clientId,
    freelancerId: request.freelancerId,
    type: decision,
    releaseAmount,
    refundAmount,
    totalAmount: settlementTotal,
    currency: request.currency || item.currency || order.currency || "USD",
    status: "completed",
    recordedBy: request.requestedByAdminId,
    recordedAt: now,
    createdAt: now,
    updatedAt: now,
  });

  step = "createLedger";
  if (releaseAmount > 0) {
    transaction.set(releaseLedgerRef, walletLedgerPayload({
      transactionId: releaseLedgerRef.id,
      ownerId: request.freelancerId,
      ownerType: "freelancer",
      type: "escrowRelease",
      amount: releaseAmount,
      currency: request.currency || item.currency || order.currency || "USD",
      orderId: request.orderId,
      caseId: request.caseId,
      description: "Resolution settlement released demo escrow to freelancer.",
      now,
    }));
  }
  if (refundAmount > 0) {
    transaction.set(refundLedgerRef, walletLedgerPayload({
      transactionId: refundLedgerRef.id,
      ownerId: request.clientId,
      ownerType: "customer",
      type: decision === DECISION.split ? "splitRefund" : "refund",
      amount: refundAmount,
      currency: request.currency || item.currency || order.currency || "USD",
      orderId: request.orderId,
      caseId: request.caseId,
      description: "Resolution settlement refunded demo escrow to customer.",
      now,
    }));
  }

  addCaseEvent(transaction, caseRef, {
    caseId: request.caseId,
    actorId: request.requestedByAdminId,
    eventType: "settlementRecorded",
    message: `Financial settlement completed. Release: ${releaseAmount.toFixed(2)}, Refund: ${refundAmount.toFixed(2)} ${request.currency || "USD"}.`,
    now,
  });

  step = "completed";
  logger.info("[ResolutionSettlementExecutor]", { requestId, step, decision });
  transaction.set(
    requestRef,
    {
      status: "completed",
      resultSettlementId: settlementRef.id,
      updatedAt: now,
      processedAt: now,
    },
    { merge: true },
  );
}

async function rejectCase(transaction, { request, requestRef, caseRef, item, now }) {
  if (item.status === "resolved" || item.status === "rejected") {
    throw new SettlementError("case-closed", "This case is already closed.");
  }
  transaction.set(
    caseRef,
    {
      status: "rejected",
      resolutionDecision: DECISION.reject,
      settlementStatus: "rejected",
      adminFindings: stringValue(request.adminNote),
      adminNotes: stringValue(request.adminNote),
      resolvedAt: now,
      updatedAt: now,
    },
    { merge: true },
  );
  addCaseEvent(transaction, caseRef, {
    caseId: request.caseId,
    actorId: request.requestedByAdminId,
    eventType: "caseRejected",
    message: stringValue(request.adminNote) || "Case rejected by admin.",
    now,
  });
  transaction.set(
    requestRef,
    {
      status: "completed",
      updatedAt: now,
      processedAt: now,
    },
    { merge: true },
  );
}

async function readLinkedRefundCase(transaction, item, caseId) {
  const relatedRefundCaseId = stringValue(item.relatedRefundCaseId);
  if (item.type !== "dispute" || !relatedRefundCaseId || relatedRefundCaseId === caseId) {
    return null;
  }
  const relatedRefundRef = db.collection("resolutionCases").doc(relatedRefundCaseId);
  const relatedRefundSnap = await transaction.get(relatedRefundRef);
  if (!relatedRefundSnap.exists) return null;
  return { ref: relatedRefundRef, data: relatedRefundSnap.data() };
}

function closeLinkedRefundCase(transaction, relatedRefundRecord, request, decision, releaseAmount, refundAmount, now) {
  if (!relatedRefundRecord) return;
  const relatedRefundRef = relatedRefundRecord.ref;
  const relatedRefund = relatedRefundRecord.data;
  if (
    relatedRefund.status === "resolved" ||
    relatedRefund.status === "rejected" ||
    relatedRefund.settlementStatus === "completed"
  ) {
    return;
  }
  transaction.set(
    relatedRefundRef,
    {
      status: "resolved",
      resolutionDecision: decision,
      releaseAmount,
      refundAmount,
      adminNotes: stringValue(request.adminNote) || `Resolved through related dispute ${request.caseId}.`,
      settlementStatus: "completed",
      isFinancialSettlementRequired: true,
      resolvedAt: now,
      updatedAt: now,
    },
    { merge: true },
  );
}

function validateSettlement({
  request,
  item,
  order,
  escrow,
  settlementSnap,
  releaseLedgerSnap,
  refundLedgerSnap,
  decision,
  releaseAmount,
  refundAmount,
  settlementTotal,
}) {
  if (!["refund", "dispute"].includes(item.type)) {
    throw new SettlementError("unsupported-case-type", "Only refund and dispute cases can be financially settled.");
  }
  if (item.status === "resolved" || item.status === "rejected" || item.settlementStatus === "completed") {
    throw new SettlementError("case-settled", "This case has already been settled.");
  }
  if (item.orderId !== request.orderId || order.orderId !== request.orderId || escrow.orderId !== request.orderId) {
    throw new SettlementError("order-mismatch", "Settlement data does not match the order.");
  }
  if (order.clientId !== request.clientId || order.freelancerId !== request.freelancerId) {
    throw new SettlementError("participant-mismatch", "Settlement participants do not match the order.");
  }
  if (escrow.clientId !== request.clientId || escrow.freelancerId !== request.freelancerId) {
    throw new SettlementError("escrow-mismatch", "Escrow participants do not match the order.");
  }
  if (settlementSnap.exists || (releaseLedgerSnap && releaseLedgerSnap.exists) || (refundLedgerSnap && refundLedgerSnap.exists)) {
    throw new SettlementError("duplicate-settlement", "This settlement has already been recorded.");
  }
  if (order.paymentStatus !== "demoPaid" || !["held", "disputed"].includes(order.escrowStatus) || !["held", "disputed"].includes(escrow.status)) {
    throw new SettlementError("escrow-unavailable", "Escrow is not available for settlement.");
  }
  if (releaseAmount < 0 || refundAmount < 0) {
    throw new SettlementError("invalid-amount", "Settlement amounts cannot be negative.");
  }
  if (decision !== DECISION.reject && settlementTotal <= 0) {
    throw new SettlementError("invalid-amount", "Enter a settlement amount greater than 0.");
  }
  if (decision === DECISION.release && (releaseAmount <= 0 || refundAmount !== 0)) {
    throw new SettlementError("invalid-release", "Release settlement needs a release amount only.");
  }
  if (decision === DECISION.refund && (refundAmount <= 0 || releaseAmount !== 0)) {
    throw new SettlementError("invalid-refund", "Refund settlement needs a refund amount only.");
  }
  if (decision === DECISION.split && (releaseAmount <= 0 || refundAmount <= 0)) {
    throw new SettlementError("invalid-split", "Split settlement needs both release and refund amounts.");
  }
  const remainingEscrow = numberValue(escrow.amount) - numberValue(escrow.releasedAmount) - numberValue(escrow.refundedAmount);
  if (settlementTotal > remainingEscrow + 0.001) {
    throw new SettlementError("amount-exceeds-escrow", "Settlement amount exceeds available escrow.");
  }
}

function writeCustomerWallet(transaction, walletRef, walletSnap, data) {
  const current = walletSnap.exists ? walletSnap.data() : {};
  const totalEscrowed = Math.max(0, numberValue(current.totalEscrowed) - data.settlementTotal);
  transaction.set(
    walletRef,
    {
      walletId: data.clientId,
      customerId: data.clientId,
      currency: data.currency,
      availableBalance: numberValue(current.availableBalance) + data.refundAmount,
      totalAdded: numberValue(current.totalAdded),
      totalSpent: numberValue(current.totalSpent),
      totalRefunded: numberValue(current.totalRefunded) + data.refundAmount,
      totalEscrowed,
      status: current.status || "active",
      createdAt: current.createdAt || data.now,
      updatedAt: data.now,
    },
    { merge: true },
  );
}

function writeFreelancerWallet(transaction, walletRef, walletSnap, data) {
  const current = walletSnap && walletSnap.exists ? walletSnap.data() : {};
  transaction.set(
    walletRef,
    {
      walletId: data.freelancerId,
      freelancerId: data.freelancerId,
      currency: data.currency,
      availableBalance: numberValue(current.availableBalance),
      pendingBalance: numberValue(current.pendingBalance) + data.releaseAmount,
      escrowBalance: numberValue(current.escrowBalance),
      pendingPayoutBalance: numberValue(current.pendingPayoutBalance),
      lifetimeEarnings: numberValue(current.lifetimeEarnings),
      lifetimeWithdrawn: numberValue(current.lifetimeWithdrawn),
      monthlyEarnings: numberValue(current.monthlyEarnings),
      weeklyEarnings: numberValue(current.weeklyEarnings),
      ordersThisMonth: numberValue(current.ordersThisMonth) + 1,
      ...(current.activePayoutId ? { activePayoutId: current.activePayoutId } : {}),
      createdAt: current.createdAt || data.now,
      updatedAt: data.now,
    },
    { merge: true },
  );
}

function walletLedgerPayload({
  transactionId,
  ownerId,
  ownerType,
  type,
  amount,
  currency,
  orderId,
  caseId,
  description,
  now,
}) {
  return {
    transactionId,
    ownerId,
    ownerType,
    walletId: ownerId,
    type,
    direction: "credit",
    amount,
    currency,
    status: "completed",
    orderId,
    caseId,
    description,
    createdAt: now,
    updatedAt: now,
  };
}

function addCaseEvent(transaction, caseRef, { caseId, actorId, eventType, message, now }) {
  const eventRef = caseRef.collection("events").doc();
  transaction.set(eventRef, {
    eventId: eventRef.id,
    caseId,
    actorId,
    actorRole: "admin",
    eventType,
    message,
    metadata: {},
    createdAt: now,
  });
}

function numberValue(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function stringValue(value) {
  return typeof value === "string" ? value : "";
}

class SettlementError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

// PayFast Pakistan payment gateway
const payfast = require("./payfast/handlers");
exports.createPayFastCheckout = payfast.createPayFastCheckout;
exports.payfastCheckoutPage = payfast.payfastCheckoutPage;
exports.payfastIpn = payfast.payfastIpn;
exports.payfastReturn = payfast.payfastReturn;
