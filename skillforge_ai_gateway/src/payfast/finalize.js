import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { computePlatformFee, roundMoney } from './fees.js';

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

  const gateway =
    intent.gateway ||
    (intent.isDemo || intent.environment === "demo"
      ? "skillforge_demo"
      : "payfast");
  const isDemo =
    Boolean(intent.isDemo) ||
    intent.environment === "demo" ||
    gateway === "skillforge_demo";
  const environment = isDemo ? "demo" : intent.environment || "live";
  const cardLast4 = String(
    ipnPayload.cardLast4 || ipnPayload.card_last4 || intent.cardLast4 || "",
  )
    .replace(/\D/g, "")
    .slice(-4);
  const defaultDescription = isDemo
    ? "SkillForge demo payment"
    : "PayFast payment";

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
      gateway,
      isDemo,
      environment,
      cardLast4: cardLast4 || "",
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
        gateway,
        isDemo,
        environment,
        cardLast4: cardLast4 || "",
        planId: intent.planId || null,
        creditPackId: intent.creditPackId || null,
        teacherId: intent.teacherId || null,
        description: intent.description || defaultDescription,
        metadata: {
          ...(intent.metadata || {}),
          intentId: intent.intentId,
          platformFee: fee.platformFee,
          sellerNet: fee.sellerNet,
          platformFeeRate: fee.platformFeeRate,
          paymentMethod: intent.paymentMethod || null,
          isDemo,
          environment,
          gateway,
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
        gateway,
        isDemo,
        environment,
        cardLast4: cardLast4 || "",
        paymentId,
        description: intent.description || defaultDescription,
        metadata: {
          ...(intent.metadata || {}),
          intentId: intent.intentId,
          platformFee: fee.platformFee,
          isDemo,
          environment,
          gateway,
        },
        createdAt: intent.createdAt || now,
        updatedAt: now,
      },
      { merge: true },
    );

  const commissionDocId = `${gateway}_commission_${intent.intentId}`;
  await db
    .collection("commissionLedger")
    .doc(commissionDocId)
    .set(
      {
        commissionId: commissionDocId,
        intentId: intent.intentId,
        orderId: intent.orderId || null,
        courseId: intent.metadata?.courseId || null,
        userId: intent.userId,
        amount: fee.platformFee,
        percentage: fee.platformFeeRate,
        currency: intent.currency || "PKR",
        source: intent.type,
        status: "collected",
        gateway,
        isDemo,
        environment,
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

  // TODO(Wave B): Admin SDK user_notifications on finalize — deferred;
  // Flutter demo checkout paths write inbox alerts instead.

  return { alreadyPaid: false, fee };
}

async function finalizePlan(db, intent, fee, now) {
  const userId = intent.userId;
  const planId = intent.planId || 'pro_plan';
  const teacherId = intent.teacherId || userId;
  const planSnap = await db.collection('plans').doc(planId).get();
  const plan = planSnap.exists ? planSnap.data() : {};
  const aiCredits = Number(plan.maxAiCreditsPerMonth) || 2500;
  const periodEnd = Timestamp.fromDate(
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  );

  // Prefer upgrading the existing active subscription in place (no duplicate subs).
  let subId =
    intent.subscriptionId ||
    intent.metadata?.previousSubscriptionId ||
    null;
  if (!subId) {
    const existing = await db
      .collection('subscriptions')
      .where('userId', '==', userId)
      .get();
    const candidates = existing.docs
      .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
      .filter((s) => {
        const status = String(s.status || '').toLowerCase();
        return status === 'success' || status === 'active' || status === 'paid';
      })
      .sort((a, b) => {
        const aMs = a.updatedAt?.toMillis?.() || 0;
        const bMs = b.updatedAt?.toMillis?.() || 0;
        return bMs - aMs;
      });
    if (candidates.length) subId = candidates[0].subscriptionId || candidates[0].id;
  }
  if (!subId) subId = id('sub');

  const subRef = db.collection('subscriptions').doc(subId);
  const existingSub = await subRef.get();
  await subRef.set(
    {
      subscriptionId: subId,
      userId,
      planId,
      status: 'Success',
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      autoRenew: true,
      cancelAtPeriodEnd: false,
      cancelledAt: null,
      updatedAt: now,
      ...(existingSub.exists ? {} : { createdAt: now }),
      lastChangeType:
        intent.metadata?.changeType ||
        (intent.metadata?.upgrade ? 'upgrade' : 'purchase'),
      previousPlanId: intent.metadata?.previousPlanId || null,
    },
    { merge: true },
  );

  // Revoke prior plan entitlements so access reflects the new plan only.
  const entitlements = await db
    .collection('teacher_entitlements')
    .where('teacherId', '==', teacherId)
    .get();
  const batch = db.batch();
  for (const doc of entitlements.docs) {
    const data = doc.data() || {};
    const existingPlanId = String(data.planId || '');
    if (!existingPlanId || existingPlanId === 'credit_pack') continue;
    batch.delete(doc.ref);
  }

  const entId = id('ent');
  const entRef = db.collection('teacher_entitlements').doc(entId);
  batch.set(entRef, {
    entitlementId: entId,
    teacherId,
    planId,
    packageName: plan.name || 'Premium Plan',
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
    status: 'Success',
    createdAt: now,
    updatedAt: now,
  });
  await batch.commit();

  await db
    .collection('users')
    .doc(userId)
    .set(
      {
        aiCreditsMonthly: aiCredits,
        aiCreditsRemaining: aiCredits,
        aiCredits: FieldValue.increment(aiCredits),
      },
      { merge: true },
    );

  await syncAiCredits(db, userId, 'teacher', aiCredits, 0);
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
  const courseId =
    intent.metadata?.courseId ||
    intent.courseId ||
    intent.metadata?.course_id ||
    null;
  let teacherId =
    intent.teacherId ||
    intent.metadata?.teacherId ||
    intent.metadata?.teacher_id ||
    null;
  const courseTitle = intent.metadata?.courseTitle || "Course";
  if (!courseId) {
    console.warn(
      `[finalizeCourse] missing courseId for intent=${intent.intentId}`,
    );
    return;
  }

  // Resolve teacher from the course doc when checkout omitted teacherId.
  if (!teacherId) {
    const courseSnap = await db.collection("courses").doc(String(courseId)).get();
    if (courseSnap.exists) {
      const course = courseSnap.data() || {};
      teacherId =
        course.teacherId ||
        course.ownerId ||
        course.createdBy ||
        course.authorId ||
        null;
    }
  }
  if (!teacherId) {
    console.warn(
      `[finalizeCourse] missing teacherId for course=${courseId} intent=${intent.intentId}`,
    );
    return;
  }

  let totalLessons = 0;
  try {
    const lessonsSnap = await db
      .collection("courses")
      .doc(String(courseId))
      .collection("lessons")
      .where("isArchived", "==", false)
      .get();
    totalLessons = lessonsSnap.size;
  } catch (_) {
    // Lesson count is optional for unlock; keep enrollment writable.
  }

  const purchaseId = `${studentId}_${courseId}`;
  const enrollmentId = `${studentId}_${courseId}`;

  await db
    .collection("course_purchases")
    .doc(purchaseId)
    .set(
      {
        purchaseId,
        courseId: String(courseId),
        studentId,
        teacherId: String(teacherId),
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
        courseTitle,
        gateway: intent.gateway || "skillforge_demo",
        isDemo: Boolean(intent.isDemo) || intent.environment === "demo",
      },
      { merge: true },
    );

  await db
    .collection("enrollments")
    .doc(enrollmentId)
    .set(
      {
        enrollmentId,
        courseId: String(courseId),
        studentId,
        teacherId: String(teacherId),
        status: "active",
        source: "purchase",
        createdAt: now,
        updatedAt: now,
        enrolledAt: now,
        progressPercent: 0,
        completedLessons: 0,
        totalLessons,
      },
      { merge: true },
    );
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
  const txId = id("wtx");

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
        totalAdded: FieldValue.increment(amount),
        lastTopUpAt: now,
        updatedAt: now,
      },
      { merge: true },
    );

  await db.collection("walletTransactions").doc(txId).set({
    transactionId: txId,
    walletId: userId,
    ownerId: userId,
    ownerType: role === "freelancer" ? "freelancer" : "customer",
    userId,
    type: "topUp",
    direction: "credit",
    amount,
    currency: intent.currency || "PKR",
    status: "completed",
    referenceId: transactionId,
    description: intent.description || "SkillForge wallet top-up",
    gateway: intent.gateway || "skillforge_demo",
    isDemo: Boolean(intent.isDemo) || intent.environment === "demo",
    environment: intent.environment || "demo",
    intentId: intent.intentId,
    createdAt: now,
    updatedAt: now,
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

export { finalizePaidIntent, isSuccessStatus, id };

