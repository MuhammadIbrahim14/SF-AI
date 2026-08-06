/**
 * Firestore paymentIntents writes for the Stripe (test mode) gateway.
 *
 * The intent shape is intentionally identical to the Demo/PayFast intents so the
 * shared `finalizePaidIntent()` pipeline and the Flutter `watchIntent()` stream
 * keep working without changes. Stripe-specific fields are additive.
 */

import { Timestamp } from 'firebase-admin/firestore';
import { computePlatformFee } from '../payfast/fees.js';
import { id } from '../payfast/finalize.js';
import { getGatewayId } from './config.js';
import { normalizeChargeAmount } from './money.js';

export const STRIPE_GATEWAY = 'stripe';
export const STRIPE_ENVIRONMENT = 'test';
export const STRIPE_PAYMENT_METHOD = 'stripe_card';

export async function resolveMarketplaceRate(db, type) {
  if (type !== 'course') return null;
  const snap = await db.collection('settings').doc('marketplace').get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  return data.platformCommissionPercent ?? data.commissionPercent ?? null;
}

/**
 * Creates the pending intent + pending payment mirror docs.
 * Amount is already normalized for the currency (whole rupees for PKR).
 */
export async function createStripeIntent(db, {
  userId,
  email,
  charge,
  currency,
  role,
  customerMobile,
  marketplaceRate,
}) {
  const chargeAmount = normalizeChargeAmount(charge.amount, currency);
  const fee = computePlatformFee({
    amount: chargeAmount,
    type: charge.type,
    marketplaceCommissionPercent: marketplaceRate,
  });

  const intentId = id('pi');
  const paymentId = id('pay');
  const transactionId = id('txn');
  const now = Timestamp.now();
  const storedCurrency = String(currency || 'pkr').toUpperCase();

  const metadata = {
    ...charge.metadata,
    provider: STRIPE_GATEWAY,
    gateway: STRIPE_GATEWAY,
    environment: STRIPE_ENVIRONMENT,
    isTestMode: true,
    isDemo: false,
    stripeMode: 'test',
    amountSource: charge.amountSource,
  };

  const intent = {
    intentId,
    basketId: intentId,
    paymentId,
    transactionId,
    userId,
    role: role || null,
    type: charge.type,
    status: 'pending',
    amount: fee.subtotal,
    currency: storedCurrency,
    description: charge.description,
    paymentMethod: STRIPE_PAYMENT_METHOD,
    planId: charge.planId || null,
    creditPackId: charge.creditPackId || null,
    teacherId: charge.teacherId || null,
    orderId: charge.orderId || null,
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    platformFeeRate: fee.platformFeeRate,
    gateway: getGatewayId(),
    provider: STRIPE_GATEWAY,
    isDemo: false,
    isTestMode: true,
    environment: STRIPE_ENVIRONMENT,
    metadata,
    customerEmail: email || null,
    customerMobile: customerMobile || null,
    stripeSessionId: null,
    stripePaymentIntentId: null,
    stripeChargeId: null,
    stripeConnectAccountId: null,
    stripeChargeMode: 'platform',
    applicationFeeAmount: null,
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('paymentIntents').doc(intentId).set(intent);

  await db.collection('payments').doc(paymentId).set({
    paymentId,
    transactionId,
    userId,
    type: charge.type,
    status: 'Pending',
    amount: fee.subtotal,
    currency: storedCurrency,
    gateway: STRIPE_GATEWAY,
    provider: STRIPE_GATEWAY,
    isDemo: false,
    isTestMode: true,
    environment: STRIPE_ENVIRONMENT,
    cardLast4: '',
    planId: intent.planId,
    creditPackId: intent.creditPackId,
    teacherId: intent.teacherId,
    description: charge.description,
    metadata: {
      ...metadata,
      intentId,
      platformFee: fee.platformFee,
      paymentMethod: STRIPE_PAYMENT_METHOD,
    },
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    createdAt: now,
    updatedAt: now,
  });

  return { intent, fee };
}

/** Stores Stripe session/charge identifiers on the intent. */
export async function attachStripeSession(db, intentId, patch) {
  await db.collection('paymentIntents').doc(intentId).set(
    {
      ...patch,
      updatedAt: Timestamp.now(),
    },
    { merge: true },
  );
}

/**
 * Phase 5: tags the ledger documents written by finalizePaidIntent with Stripe
 * provider identifiers so Admin Finance can attribute revenue per provider.
 */
export async function tagStripeProvider(db, intent, ids = {}) {
  const now = Timestamp.now();
  const tag = {
    provider: STRIPE_GATEWAY,
    gateway: STRIPE_GATEWAY,
    environment: STRIPE_ENVIRONMENT,
    isTestMode: true,
    isDemo: false,
    stripeSessionId: ids.sessionId || null,
    stripePaymentIntentId: ids.paymentIntentId || null,
    ...(ids.chargeId ? { stripeChargeId: ids.chargeId } : {}),
    ...(ids.connectAccountId ? { stripeConnectAccountId: ids.connectAccountId } : {}),
    updatedAt: now,
  };

  const writes = [];
  if (intent.paymentId) {
    writes.push(db.collection('payments').doc(intent.paymentId).set(tag, { merge: true }));
  }
  if (intent.transactionId) {
    writes.push(
      db.collection('transactions').doc(intent.transactionId).set(tag, { merge: true }),
    );
  }
  if (intent.intentId) {
    writes.push(
      db
        .collection('commissionLedger')
        .doc(`${STRIPE_GATEWAY}_commission_${intent.intentId}`)
        .set(tag, { merge: true }),
    );
  }
  if (intent.orderId) {
    // finalizePaidIntent uses fixed `payfast_…` doc ids for commerce escrow rows.
    writes.push(
      db
        .collection('commissionLedger')
        .doc(`payfast_commission_order_${intent.orderId}`)
        .set(tag, { merge: true }),
    );
    writes.push(
      db
        .collection('commerceTransactions')
        .doc(`payfast_escrow_hold_${intent.orderId}`)
        .set(tag, { merge: true }),
    );
  }
  const courseId = intent.metadata?.courseId || intent.courseId || null;
  if (courseId && intent.userId) {
    writes.push(
      db
        .collection('course_purchases')
        .doc(`${intent.userId}_${courseId}`)
        .set(
          {
            provider: STRIPE_GATEWAY,
            gateway: STRIPE_GATEWAY,
            isDemo: false,
            isTestMode: true,
            paymentMethod: STRIPE_PAYMENT_METHOD,
            stripeSessionId: ids.sessionId || null,
            stripePaymentIntentId: ids.paymentIntentId || null,
          },
          { merge: true },
        ),
    );
  }

  const results = await Promise.allSettled(writes);
  for (const result of results) {
    if (result.status === 'rejected') {
      console.warn('[stripe] provider tag write failed', result.reason?.message || result.reason);
    }
  }
}

/**
 * Marks an intent failed without touching entitlements.
 * The status stays the terminal `failed` the Flutter client already understands;
 * `failureReason` carries the nuance (e.g. an expired Checkout session).
 */
export async function markIntentFailed(db, intentRef, intent, {
  errorMessage = 'Stripe payment failed.',
  failureReason = 'payment_failed',
  event = null,
  ids = {},
} = {}) {
  const now = Timestamp.now();
  if (intent.status === 'paid' || intent.status === 'Success') {
    return { skipped: true, reason: 'already-paid' };
  }

  await intentRef.set(
    {
      status: 'failed',
      errorMessage,
      failureReason,
      updatedAt: now,
      provider: STRIPE_GATEWAY,
      gateway: STRIPE_GATEWAY,
      environment: STRIPE_ENVIRONMENT,
      isTestMode: true,
      stripeSessionId: ids.sessionId || intent.stripeSessionId || null,
      stripePaymentIntentId: ids.paymentIntentId || intent.stripePaymentIntentId || null,
      ...(event ? { stripeLastEvent: event } : {}),
    },
    { merge: true },
  );

  if (intent.paymentId) {
    await db.collection('payments').doc(intent.paymentId).set(
      {
        status: failureReason === 'session_expired' ? 'Cancelled' : 'Failed',
        provider: STRIPE_GATEWAY,
        gateway: STRIPE_GATEWAY,
        environment: STRIPE_ENVIRONMENT,
        isTestMode: true,
        errorMessage,
        failureReason,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  return { skipped: false, status: 'failed', failureReason };
}

/**
 * Records a Stripe refund. Entitlement reversal stays a manual admin action, so
 * this only marks the money trail (no double finalize, no silent revoke).
 */
export async function markIntentRefunded(db, intentRef, intent, {
  amountRefunded = null,
  currency = 'PKR',
  ids = {},
} = {}) {
  const now = Timestamp.now();
  await intentRef.set(
    {
      refundStatus: 'refunded',
      refundedAt: now,
      refundedAmount: amountRefunded,
      updatedAt: now,
      provider: STRIPE_GATEWAY,
      gateway: STRIPE_GATEWAY,
      environment: STRIPE_ENVIRONMENT,
      isTestMode: true,
      stripeChargeId: ids.chargeId || intent.stripeChargeId || null,
      stripePaymentIntentId: ids.paymentIntentId || intent.stripePaymentIntentId || null,
    },
    { merge: true },
  );

  const patch = {
    status: 'Refunded',
    refundedAt: now,
    refundedAmount: amountRefunded,
    currency: String(currency || intent.currency || 'PKR').toUpperCase(),
    provider: STRIPE_GATEWAY,
    gateway: STRIPE_GATEWAY,
    environment: STRIPE_ENVIRONMENT,
    isTestMode: true,
    updatedAt: now,
  };

  const writes = [];
  if (intent.paymentId) {
    writes.push(db.collection('payments').doc(intent.paymentId).set(patch, { merge: true }));
  }
  if (intent.transactionId) {
    writes.push(
      db.collection('transactions').doc(intent.transactionId).set(patch, { merge: true }),
    );
  }
  if (intent.intentId) {
    writes.push(
      db
        .collection('commissionLedger')
        .doc(`${STRIPE_GATEWAY}_commission_${intent.intentId}`)
        .set(
          {
            status: 'reversed',
            reversedAt: now,
            provider: STRIPE_GATEWAY,
            updatedAt: now,
          },
          { merge: true },
        ),
    );
  }
  await Promise.allSettled(writes);
}
