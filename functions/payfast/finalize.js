const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { computePlatformFee, roundMoney } = require("./fees");

function id(prefix) {
  return `${prefix}_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
}

async function loadMarketplaceCommission(db) {
  const snap = await db.collection("settings").doc("marketplace").get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  return data.platformCommissionPercent ?? data.commissionPercent ?? null;
}

/**
 * Marks intent paid and runs type-specific finalization (idempotent).
 */
async function finalizePaidIntent(db, intentRef, intent, ipnPayload = {}) {
  if (intent.status === "paid" || intent.status === "Success") {
    return { alreadyPaid: true };
  }

  const now = Timestamp.now();
  const marketplacePct = await loadMarketplaceCommission(db);
  const fee = computePlatformFee({
    amount: intent.amount,
    type: intent.type,
    marketplaceCommissionPercent:
      intent.platformFeeRate != null
        ? intent.platformFeeRate
        : marketplacePct,
  });

  await intentRef.set(
    {
      status: "paid",
      paidAt: now,
      updatedAt: now,
      platformFee: fee.platformFee,
      sellerNet: fee.sellerNet,
      platformFeeRate: fee.platformFeeRate,
      payfastTransactionId:
        ipnPayload.transaction_id ||
        ipnPayload.TRANSACTION_ID ||
        intent.payfastTransactionId ||
        null,
      ipn: ipnPayload,
      gateway: "payfast",
    },
    { merge: true },
  );

  const paymentId = intent.paymentId || id("pay");
  const transactionId = intent.transactionId || id("txn");

  await db
    .collection("payments")
    .doc(paymentId)
    .set(
      {
        paymentId,
        transactionId,
        userId: intent.userId,
        type: intent.type,
        status: "Success",
        amount: fee.subtotal,
        currency: intent.currency || "PKR",
        gateway: "payfast",
        cardLast4: "",
        planId: intent.planId || null,
        creditPackId: intent.creditPackId || null,
        teacherId: intent.teacherId || null,
        description: intent.description || "PayFast payment",
        metadata: {
          ...(intent.metadata || {}),
          intentId: intent.intentId,
          platformFee: fee.platformFee,
          sellerNet: fee.sellerNet,
          platformFeeRate: fee.platformFeeRate,
          paymentMethod: intent.paymentMethod || null,
        },
        platformFee: fee.platformFee,
        sellerNet: fee.sellerNet,
        createdAt: intent.createdAt || now,
        updatedAt: now,
      },
      { merge: true },
    );

  await db
    .collection("transactions")
    .doc(transactionId)
    .set(
      {
        transactionId,
        userId: intent.userId,
        type: intent.type,
        status: "Success",
        amount: fee.subtotal,
        currency: intent.currency || "PKR",
        gateway: "payfast",
        cardLast4: "",
        paymentId,
        description: intent.description || "PayFast payment",
        metadata: {
          ...(intent.metadata || {}),
          intentId: intent.intentId,
          platformFee: fee.platformFee,
        },
        createdAt: intent.createdAt || now,
        updatedAt: now,
      },
      { merge: true },
    );

  await db
    .collection("commissionLedger")
    .doc(`payfast_commission_${intent.intentId}`)
    .set(
      {
        commissionId: `payfast_commission_${intent.intentId}`,
        intentId: intent.intentId,
        orderId: intent.orderId || null,
        courseId: intent.metadata?.courseId || null,
        userId: intent.userId,
        amount: fee.platformFee,
        percentage: fee.platformFeeRate,
        currency: intent.currency || "PKR",
        source: intent.type,
        status: "collected",
        gateway: "payfast",
        createdAt: now,
      },
      { merge: true },
    );

  switch (intent.type) {
    case "plan":
      await finalizePlan(db, intent, fee, now);
      break;
    case "credit_pack":
      await finalizeCreditPack(db, intent, now);
      break;
    case "course":
      await finalizeCourse(db, intent, fee, now, paymentId, transactionId);
      break;
    case "commerce_order":
      await finalizeCommerceOrder(db, intent, now);
      break;
    case "wallet_topup":
      await finalizeWalletTopup(db, intent, now, transactionId);
      break;
    default:
      break;
  }

  // TODO(Wave B): Admin SDK user_notifications deferred — Flutter demo paths notify.

  return { alreadyPaid: false, fee };
}

async function finalizePlan(db, intent, fee, now) {
  const userId = intent.userId;
  const planId = intent.planId || "pro_plan";
  const teacherId = intent.teacherId || userId;
  const planSnap = await db.collection("plans").doc(planId).get();
  const plan = planSnap.exists ? planSnap.data() : {};
  const aiCredits = Number(plan.maxAiCreditsPerMonth) || 2500;
  const periodEnd = Timestamp.fromDate(
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  );

  let subId =
    intent.subscriptionId ||
    intent.metadata?.previousSubscriptionId ||
    null;
  if (!subId) {
    const existing = await db
      .collection("subscriptions")
      .where("userId", "==", userId)
      .get();
    const candidates = existing.docs
      .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
      .filter((s) => {
        const status = String(s.status || "").toLowerCase();
        return status === "success" || status === "active" || status === "paid";
      })
      .sort((a, b) => {
        const aMs = a.updatedAt?.toMillis?.() || 0;
        const bMs = b.updatedAt?.toMillis?.() || 0;
        return bMs - aMs;
      });
    if (candidates.length) {
      subId = candidates[0].subscriptionId || candidates[0].id;
    }
  }
  if (!subId) subId = id("sub");

  const subRef = db.collection("subscriptions").doc(subId);
  const existingSub = await subRef.get();
  await subRef.set(
    {
      subscriptionId: subId,
      userId,
      planId,
      status: "Success",
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      autoRenew: true,
      cancelAtPeriodEnd: false,
      cancelledAt: null,
      updatedAt: now,
      ...(existingSub.exists ? {} : { createdAt: now }),
      lastChangeType:
        intent.metadata?.changeType ||
        (intent.metadata?.upgrade ? "upgrade" : "purchase"),
      previousPlanId: intent.metadata?.previousPlanId || null,
    },
    { merge: true },
  );

  const entitlements = await db
    .collection("teacher_entitlements")
    .where("teacherId", "==", teacherId)
    .get();
  const batch = db.batch();
  for (const doc of entitlements.docs) {
    const data = doc.data() || {};
    const existingPlanId = String(data.planId || "");
    if (!existingPlanId || existingPlanId === "credit_pack") continue;
    batch.delete(doc.ref);
  }

  const entId = id("ent");
  batch.set(db.collection("teacher_entitlements").doc(entId), {
    entitlementId: entId,
    teacherId,
    planId,
    packageName: plan.name || "Premium Plan",
    credits: aiCredits,
    features: {
      ai_assistant: true,
      priority_support: true,
      analytics: plan.allowAnalytics !== false,
      paid_courses: plan.allowPaidCourses === true,
      maxPublishedCourses: plan.maxPublishedCourses || 50,
      maxLessonsPerCourse: plan.maxLessonsPerCourse || 200,
      maxAssignmentsPerCourse: plan.maxAssignmentsPerCourse || 200,
      maxProjectsPerCourse: plan.maxProjectsPerCourse || 50,
      maxGrandTestsPerCourse: plan.maxGrandTestsPerCourse || 20,
    },
    status: "Success",
    createdAt: now,
    updatedAt: now,
  });
  await batch.commit();

  await db
    .collection("users")
    .doc(userId)
    .set(
      {
        aiCreditsMonthly: aiCredits,
        aiCreditsRemaining: aiCredits,
        aiCredits: FieldValue.increment(aiCredits),
      },
      { merge: true },
    );

  await syncAiCredits(db, userId, "teacher", aiCredits, 0);
}

async function finalizeCreditPack(db, intent, now) {
  const packId = intent.creditPackId;
  let credits = 0;
  if (packId) {
    const packSnap = await db.collection("credit_packs").doc(packId).get();
    if (packSnap.exists) {
      const pack = packSnap.data();
      credits = (Number(pack.credits) || 0) + (Number(pack.bonusCredits) || 0);
    }
  }
  if (credits <= 0) credits = Math.round(Number(intent.amount) || 0);

  await db
    .collection("users")
    .doc(intent.userId)
    .set(
      {
        aiCredits: FieldValue.increment(credits),
        aiCreditsRemaining: FieldValue.increment(credits),
      },
      { merge: true },
    );
  await syncAiCredits(db, intent.userId, "teacher", null, credits);
}

async function finalizeCourse(db, intent, fee, now, paymentId, transactionId) {
  const studentId = intent.userId;
  const courseId = intent.metadata?.courseId;
  const teacherId = intent.teacherId;
  const courseTitle = intent.metadata?.courseTitle || "Course";
  if (!courseId || !teacherId) return;

  const purchaseId = id("cp");
  const enrollmentId = id("enr");

  await db
    .collection("course_purchases")
    .doc(purchaseId)
    .set({
      purchaseId,
      courseId,
      studentId,
      teacherId,
      price: fee.subtotal,
      discountAmount: 0,
      finalAmount: fee.sellerNet,
      platformFee: fee.platformFee,
      currency: intent.currency || "PKR",
      purchasedAt: now,
      enrollmentId,
      transactionReference: transactionId,
      paymentMethod: intent.paymentMethod || "payfast",
      paymentId,
      intentId: intent.intentId,
    });

  await db
    .collection("enrollments")
    .doc(enrollmentId)
    .set({
      enrollmentId,
      courseId,
      studentId,
      teacherId,
      status: "active",
      source: "purchase",
      createdAt: now,
      updatedAt: now,
      enrolledAt: now,
    });
}

async function finalizeCommerceOrder(db, intent, now) {
  const orderId = intent.orderId;
  if (!orderId) return;

  const orderRef = db.collection("serviceOrders").doc(orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) return;
  const order = orderSnap.data();

  if (
    order.paymentStatus === "paid" ||
    order.paymentStatus === "demoPaid"
  ) {
    if (order.paymentStatus === "demoPaid") {
      await orderRef.set({ paymentStatus: "paid", updatedAt: now }, { merge: true });
    }
    return;
  }

  const escrowDays = 5;
  const expectedRelease = Timestamp.fromDate(
    new Date(Date.now() + escrowDays * 24 * 60 * 60 * 1000),
  );
  const reference = `PF-${orderId}-${Date.now()}`;
  const method = intent.paymentMethod || "payfast";

  const escrowRef = db.collection("serviceEscrows").doc(orderId);
  const transactionRef = db
    .collection("commerceTransactions")
    .doc(`payfast_escrow_hold_${orderId}`);
  const commissionRef = db
    .collection("commissionLedger")
    .doc(`payfast_commission_order_${orderId}`);

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(orderRef);
    if (!fresh.exists) return;
    const current = fresh.data();
    if (
      current.paymentStatus === "paid" ||
      current.paymentStatus === "demoPaid"
    ) {
      return;
    }

    tx.set(
      escrowRef,
      {
        escrowId: orderId,
        orderId,
        clientId: current.clientId,
        freelancerId: current.freelancerId,
        amount: current.totalAmount,
        currency: current.currency || "PKR",
        status: "held",
        holdStartedAt: now,
        expectedReleaseAt: expectedRelease,
        holdReason: "PayFast payment confirmed for service order.",
        createdAt: now,
      },
      { merge: true },
    );

    tx.set(
      transactionRef,
      {
        transactionId: transactionRef.id,
        orderId,
        serviceRequestId: current.serviceRequestId || null,
        userId: current.clientId,
        walletId: null,
        type: "escrowHold",
        amount: current.totalAmount,
        currency: current.currency || "PKR",
        status: "pending",
        referenceId: reference,
        description: `PayFast escrow hold via ${method} for ${current.serviceTitle || "service"}.`,
        createdAt: now,
      },
      { merge: true },
    );

    tx.set(
      commissionRef,
      {
        commissionId: commissionRef.id,
        orderId,
        serviceRequestId: current.serviceRequestId || null,
        amount: current.platformFee || 0,
        percentage: 0.1,
        currency: current.currency || "PKR",
        source: "freelancerService",
        status: "pending",
        createdAt: now,
      },
      { merge: true },
    );

    tx.set(
      db.collection("freelancerWallets").doc(current.freelancerId),
      {
        walletId: current.freelancerId,
        freelancerId: current.freelancerId,
        currency: current.currency || "PKR",
        escrowBalance: FieldValue.increment(Number(current.totalAmount) || 0),
        lastEscrowOrderId: orderId,
        updatedAt: now,
      },
      { merge: true },
    );

    tx.set(
      orderRef,
      {
        paymentStatus: "paid",
        escrowStatus: "held",
        orderStatus: "active",
        paidAt: now,
        escrowHeldAt: now,
        expectedReleaseAt: expectedRelease,
        sandboxPaymentMethod: method,
        paymentMethod: method,
        transactionReference: reference,
        updatedAt: now,
      },
      { merge: true },
    );
  });
}

async function finalizeWalletTopup(db, intent, now, transactionId) {
  const userId = intent.userId;
  const role = intent.metadata?.walletRole || "customer";
  const amount = roundMoney(intent.amount);
  const collection =
    role === "freelancer" ? "freelancerWallets" : "customerWallets";

  await db
    .collection(collection)
    .doc(userId)
    .set(
      {
        walletId: userId,
        ...(role === "freelancer"
          ? { freelancerId: userId }
          : { customerId: userId }),
        currency: intent.currency || "PKR",
        availableBalance: FieldValue.increment(amount),
        updatedAt: now,
      },
      { merge: true },
    );

  await db.collection("walletTransactions").doc(id("wtx")).set({
    transactionId: id("wtx"),
    walletId: userId,
    userId,
    type: "topUp",
    amount,
    currency: intent.currency || "PKR",
    status: "completed",
    referenceId: transactionId,
    description: "PayFast wallet top-up",
    gateway: "payfast",
    intentId: intent.intentId,
    createdAt: now,
  });
}

async function syncAiCredits(db, userId, role, monthlyFreeCredits, bonusDelta) {
  const ref = db.collection("aiUserCredits").doc(userId);
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const data = doc.exists ? doc.data() : {};
    const currentMonth = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, "0")}`;
    const storedMonth = data.currentMonthKey || currentMonth;
    const used =
      storedMonth === currentMonth
        ? Number(data.usedCreditsThisMonth) || 0
        : 0;
    const currentMonthly = Number(data.monthlyFreeCredits) || 200;
    const currentBonus = Number(data.bonusCredits) || 0;
    const monthly =
      monthlyFreeCredits != null ? monthlyFreeCredits : currentMonthly;
    const bonus = Math.max(0, currentBonus + (bonusDelta || 0));
    const remaining = Math.max(0, monthly + bonus - used);
    tx.set(
      ref,
      {
        userId,
        role,
        monthlyFreeCredits: monthly,
        bonusCredits: bonus,
        usedCreditsThisMonth: used,
        remainingCredits: remaining,
        currentMonthKey: currentMonth,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

function isSuccessStatus(code) {
  const raw = String(code ?? "").trim().toLowerCase();
  return (
    raw === "00" ||
    raw === "0" ||
    raw === "success" ||
    raw === "successful" ||
    raw === "paid" ||
    raw === "completed"
  );
}

module.exports = {
  finalizePaidIntent,
  isSuccessStatus,
  id,
};
