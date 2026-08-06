/**
 * SkillForge Demo Gateway handlers.
 * Creates payment intents and finalizes via the same finalizePaidIntent pipeline.
 * No PayFast merchant keys. No real money.
 */

import { Timestamp } from 'firebase-admin/firestore';
import { computePlatformFee } from '../payfast/fees.js';
import { finalizePaidIntent, id } from '../payfast/finalize.js';
import { getFirestore } from '../payfast/firebase.js';
import {
  isAvailable,
  pausedMessage,
  getCurrency,
  getGatewayId,
  getGatewayBaseUrl,
  getMerchantDisplayName,
} from './config.js';

async function resolveMarketplaceRate(type) {
  if (type !== 'course') return null;
  const snap = await getFirestore().collection('settings').doc('marketplace').get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  return data.platformCommissionPercent ?? null;
}

/**
 * POST /api/demo/checkout — create pending demo intent.
 */
export async function handleDemoCheckout(req, res, { userId, email }) {
  if (!userId) {
    json(res, 401, { status: 'error', code: 'unauthenticated', message: 'Sign in required.' });
    return;
  }
  if (!isAvailable()) {
    json(res, 503, {
      status: 'error',
      code: 'payments-paused',
      message: pausedMessage(),
    });
    return;
  }

  const data = await readBody(req);
  const type = String(data.type || '').trim();
  const amount = Number(data.amount);
  const paymentMethod = String(data.paymentMethod || 'card').trim();
  const description = String(data.description || 'SkillForge demo payment').trim();
  const currency = String(data.currency || getCurrency()).trim() || 'PKR';
  const gateway = getGatewayId();

  if (!type) {
    json(res, 400, { status: 'error', code: 'invalid-argument', message: 'Payment type is required.' });
    return;
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    json(res, 400, {
      status: 'error',
      code: 'invalid-argument',
      message: 'Amount must be greater than zero.',
    });
    return;
  }

  const db = getFirestore();
  const marketplaceRate = await resolveMarketplaceRate(type);
  const fee = computePlatformFee({
    amount,
    type,
    marketplaceCommissionPercent: marketplaceRate,
  });

  const intentId = id('pi');
  const basketId = intentId;
  const paymentId = id('pay');
  const transactionId = id('txn');
  const now = Timestamp.now();

  const metadata = {
    ...(data.metadata && typeof data.metadata === 'object' ? data.metadata : {}),
    isDemo: true,
    environment: 'demo',
    gateway,
  };

  const intent = {
    intentId,
    basketId,
    paymentId,
    transactionId,
    userId,
    role: String(data.role || '').trim() || null,
    type,
    status: 'pending',
    amount: fee.subtotal,
    currency,
    description,
    paymentMethod,
    planId: data.planId || null,
    creditPackId: data.creditPackId || null,
    teacherId:
      data.teacherId ||
      (data.metadata && typeof data.metadata === 'object'
        ? data.metadata.teacherId
        : null) ||
      null,
    orderId: data.orderId || null,
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    platformFeeRate: fee.platformFeeRate,
    gateway,
    isDemo: true,
    environment: 'demo',
    metadata,
    customerEmail: data.customerEmail || email || null,
    customerMobile: data.customerMobile || null,
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('paymentIntents').doc(intentId).set(intent);

  await db.collection('payments').doc(paymentId).set({
    paymentId,
    transactionId,
    userId,
    type,
    status: 'Pending',
    amount: fee.subtotal,
    currency,
    gateway,
    isDemo: true,
    environment: 'demo',
    cardLast4: '',
    planId: intent.planId,
    creditPackId: intent.creditPackId,
    teacherId: intent.teacherId,
    description,
    metadata: {
      ...metadata,
      intentId,
      platformFee: fee.platformFee,
      paymentMethod,
    },
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    createdAt: now,
    updatedAt: now,
  });

  const checkoutPageUrl = `${getGatewayBaseUrl()}/api/demo/checkout-page?intentId=${encodeURIComponent(intentId)}`;

  await db.collection('paymentIntents').doc(intentId).set(
    {
      checkoutPageUrl,
      updatedAt: Timestamp.now(),
    },
    { merge: true },
  );

  json(res, 200, {
    ok: true,
    intentId,
    basketId,
    paymentId,
    transactionId,
    status: 'pending',
    amount: fee.subtotal,
    currency,
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    platformFeeRate: fee.platformFeeRate,
    checkoutPageUrl,
    gateway,
    isDemo: true,
    environment: 'demo',
    merchantDisplayName: getMerchantDisplayName(),
  });
}

/**
 * POST /api/demo/confirm — simulate success or failure, then finalize on success.
 */
export async function handleDemoConfirm(req, res, { userId }) {
  if (!userId) {
    json(res, 401, { status: 'error', code: 'unauthenticated', message: 'Sign in required.' });
    return;
  }
  if (!isAvailable()) {
    json(res, 503, {
      status: 'error',
      code: 'payments-paused',
      message: pausedMessage(),
    });
    return;
  }

  const data = await readBody(req);
  const intentId = String(data.intentId || '').trim();
  const outcome = String(data.outcome || data.status || 'success').trim().toLowerCase();
  const cardLast4 = String(data.cardLast4 || '').replace(/\D/g, '').slice(-4);

  if (!intentId) {
    json(res, 400, { status: 'error', code: 'invalid-argument', message: 'intentId is required.' });
    return;
  }

  const db = getFirestore();
  const intentRef = db.collection('paymentIntents').doc(intentId);
  const snap = await intentRef.get();
  if (!snap.exists) {
    json(res, 404, { status: 'error', code: 'not-found', message: 'Payment intent not found.' });
    return;
  }

  const intent = snap.data() || {};
  if (intent.userId !== userId) {
    json(res, 403, { status: 'error', code: 'permission-denied', message: 'Not your payment intent.' });
    return;
  }

  if (intent.status === 'paid' || intent.status === 'Success') {
    json(res, 200, {
      ok: true,
      alreadyPaid: true,
      intentId,
      status: 'paid',
      paymentId: intent.paymentId,
      transactionId: intent.transactionId,
      isDemo: true,
    });
    return;
  }

  if (intent.status === 'failed') {
    json(res, 200, {
      ok: true,
      alreadyFailed: true,
      intentId,
      status: 'failed',
      isDemo: true,
    });
    return;
  }

  const gateway = intent.gateway || getGatewayId();
  const now = Timestamp.now();

  if (outcome === 'failed' || outcome === 'fail' || outcome === 'failure') {
    const errorMessage = String(data.errorMessage || 'Demo payment declined.').trim();
    await intentRef.set(
      {
        status: 'failed',
        errorMessage,
        updatedAt: now,
        gateway,
        isDemo: true,
        environment: 'demo',
      },
      { merge: true },
    );
    if (intent.paymentId) {
      await db.collection('payments').doc(intent.paymentId).set(
        {
          status: 'Failed',
          updatedAt: now,
          gateway,
          isDemo: true,
          environment: 'demo',
        },
        { merge: true },
      );
    }
    // TODO(Wave B): optional Admin SDK fail inbox — Flutter demo sheet notifies instead.
    json(res, 200, {
      ok: true,
      intentId,
      status: 'failed',
      message: errorMessage,
      isDemo: true,
      environment: 'demo',
      gateway,
    });
    return;
  }

  const demoTxnId = `demo_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
  await finalizePaidIntent(db, intentRef, {
    ...intent,
    gateway,
    isDemo: true,
    environment: 'demo',
  }, {
    transaction_id: demoTxnId,
    cardLast4: cardLast4 || '4242',
    demo: true,
    payment_method: intent.paymentMethod || 'card',
  });

  const refreshed = (await intentRef.get()).data() || {};
  json(res, 200, {
    ok: true,
    intentId,
    status: 'paid',
    paymentId: refreshed.paymentId || intent.paymentId,
    transactionId: refreshed.transactionId || intent.transactionId,
    amount: refreshed.amount || intent.amount,
    currency: refreshed.currency || intent.currency,
    platformFee: refreshed.platformFee,
    sellerNet: refreshed.sellerNet,
    isDemo: true,
    environment: 'demo',
    gateway,
  });
}

/**
 * POST /api/demo/subscription/cancel — schedule cancel-at-period-end (Admin SDK).
 */
export async function handleSubscriptionCancel(req, res, { userId }) {
  if (!userId) {
    json(res, 401, { status: 'error', code: 'unauthenticated', message: 'Sign in required.' });
    return;
  }

  const db = getFirestore();
  const now = Timestamp.now();
  const snap = await db.collection('subscriptions').where('userId', '==', userId).get();
  const candidates = snap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
    .sort((a, b) => {
      const aMs = a.updatedAt?.toMillis?.() || 0;
      const bMs = b.updatedAt?.toMillis?.() || 0;
      return bMs - aMs;
    });

  const subscription = candidates[0];
  if (!subscription) {
    json(res, 404, {
      status: 'error',
      code: 'not-found',
      message: 'No active subscription found to cancel.',
    });
    return;
  }

  const status = String(subscription.status || '').toLowerCase();
  const periodEnd = subscription.currentPeriodEnd?.toDate?.() || null;
  if (status === 'cancelled' && periodEnd && periodEnd.getTime() < Date.now()) {
    json(res, 400, {
      status: 'error',
      code: 'already-cancelled',
      message: 'This subscription is already cancelled.',
      subscriptionId: subscription.subscriptionId || subscription.id,
    });
    return;
  }

  if (subscription.cancelAtPeriodEnd === true) {
    json(res, 200, {
      ok: true,
      alreadyScheduled: true,
      subscriptionId: subscription.subscriptionId || subscription.id,
      accessUntil: periodEnd ? periodEnd.toISOString() : null,
      cancelAtPeriodEnd: true,
      message:
        'Cancellation already scheduled. You keep full plan benefits until period end.',
    });
    return;
  }

  const subId = subscription.subscriptionId || subscription.id;
  await db.collection('subscriptions').doc(subId).set(
    {
      autoRenew: false,
      cancelAtPeriodEnd: true,
      cancelledAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  const paymentId = id('pay');
  const transactionId = id('txn');
  const planId = subscription.planId || null;
  let planName = planId || 'Plan';
  if (planId) {
    const planSnap = await db.collection('plans').doc(planId).get();
    if (planSnap.exists) planName = planSnap.data()?.name || planName;
  }

  await db.collection('payments').doc(paymentId).set({
    paymentId,
    transactionId,
    userId,
    type: 'subscription_cancel',
    status: 'Cancelled',
    amount: 0,
    currency: subscription.currency || 'PKR',
    gateway: getGatewayId(),
    planId,
    teacherId: userId,
    description: `Plan cancelled — ${planName} access continues until period end.`,
    metadata: {
      event: 'cancel_at_period_end',
      subscriptionId: subId,
      planName,
      accessUntil: periodEnd ? periodEnd.toISOString() : null,
      cancelledAt: now.toDate().toISOString(),
      autoRenewStopped: true,
    },
    createdAt: now,
    updatedAt: now,
    isDemo: true,
    environment: 'demo',
  });

  json(res, 200, {
    ok: true,
    subscriptionId: subId,
    accessUntil: periodEnd ? periodEnd.toISOString() : null,
    cancelAtPeriodEnd: true,
    message: `Cancellation scheduled. You keep all ${planName} benefits until period end.`,
  });
}

/**
 * POST /api/demo/subscription/finalize-expiry — revoke after cancel-at-period-end.
 */
export async function handleSubscriptionFinalizeExpiry(req, res, { userId }) {
  if (!userId) {
    json(res, 401, { status: 'error', code: 'unauthenticated', message: 'Sign in required.' });
    return;
  }

  const db = getFirestore();
  const now = Timestamp.now();
  const snap = await db.collection('subscriptions').where('userId', '==', userId).get();
  const candidates = snap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
    .sort((a, b) => {
      const aMs = a.updatedAt?.toMillis?.() || 0;
      const bMs = b.updatedAt?.toMillis?.() || 0;
      return bMs - aMs;
    });

  const subscription = candidates[0];
  if (!subscription || subscription.cancelAtPeriodEnd !== true) {
    json(res, 200, { ok: true, finalized: false, reason: 'nothing-to-finalize' });
    return;
  }

  const status = String(subscription.status || '').toLowerCase();
  if (status === 'cancelled') {
    json(res, 200, { ok: true, finalized: false, reason: 'already-cancelled' });
    return;
  }

  const periodEnd = subscription.currentPeriodEnd?.toDate?.() || null;
  if (periodEnd && periodEnd.getTime() > Date.now()) {
    json(res, 200, {
      ok: true,
      finalized: false,
      reason: 'period-active',
      accessUntil: periodEnd.toISOString(),
    });
    return;
  }

  const subId = subscription.subscriptionId || subscription.id;
  await db.collection('subscriptions').doc(subId).set(
    {
      status: 'Cancelled',
      autoRenew: false,
      cancelAtPeriodEnd: true,
      updatedAt: now,
    },
    { merge: true },
  );

  const entitlements = await db
    .collection('teacher_entitlements')
    .where('teacherId', '==', userId)
    .get();
  const batch = db.batch();
  for (const doc of entitlements.docs) {
    const data = doc.data() || {};
    const existingPlanId = String(data.planId || '');
    if (!existingPlanId || existingPlanId === 'credit_pack') continue;
    batch.delete(doc.ref);
  }
  await batch.commit();

  json(res, 200, {
    ok: true,
    finalized: true,
    subscriptionId: subId,
  });
}

function json(res, statusCode, payload) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 256_000) {
        reject(new Error('Request too large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch {
        try {
          resolve(Object.fromEntries(new URLSearchParams(raw).entries()));
        } catch {
          resolve({});
        }
      }
    });
    req.on('error', reject);
  });
}
