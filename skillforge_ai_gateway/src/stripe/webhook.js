/**
 * POST /api/stripe/webhook — signature-verified Stripe event handler (test mode).
 *
 * Verified success events call the shared `finalizePaidIntent()` seam, so Stripe
 * grants exactly the same entitlements as the Demo gateway. Every event is
 * de-duplicated in `stripeWebhookEvents/{eventId}` and `finalizePaidIntent()` is
 * itself idempotent, so Stripe retries can never double-grant or double-credit.
 */

import { Timestamp } from 'firebase-admin/firestore';
import { finalizePaidIntent } from '../payfast/finalize.js';
import { getFirestore } from '../payfast/firebase.js';
import { getStripe } from './client.js';
import { getWebhookSecrets, hasWebhookSecret } from './config.js';
import { applyAccountUpdate } from './connect.js';
import {
  attachStripeSession,
  markIntentFailed,
  markIntentRefunded,
  STRIPE_GATEWAY,
  tagStripeProvider,
} from './intents.js';
import { fromStripeAmount, toStripeAmount } from './money.js';

const EVENTS_COLLECTION = 'stripeWebhookEvents';

export async function handleStripeWebhook(req, res) {
  if (!hasWebhookSecret()) {
    console.error('[stripe] webhook received but STRIPE_WEBHOOK_SECRET is not set');
    text(res, 503, 'webhook secret not configured');
    return;
  }

  let rawBody;
  try {
    rawBody = await readRawBody(req);
  } catch (error) {
    text(res, 400, `unable to read body: ${error.message}`);
    return;
  }

  const signature = req.headers['stripe-signature'];
  if (!signature) {
    text(res, 400, 'missing stripe-signature header');
    return;
  }

  let event;
  let stripe;
  try {
    stripe = getStripe();
  } catch (error) {
    console.error('[stripe] webhook client unavailable', error.message);
    text(res, 503, 'stripe not configured');
    return;
  }

  let lastError = null;
  for (const secret of getWebhookSecrets()) {
    try {
      event = stripe.webhooks.constructEvent(rawBody, signature, secret);
      lastError = null;
      break;
    } catch (error) {
      lastError = error;
    }
  }
  if (!event) {
    console.warn('[stripe] webhook signature verification failed', lastError?.message);
    text(res, 400, 'invalid signature');
    return;
  }

  if (event.livemode === true) {
    console.error('[stripe] rejected LIVE mode webhook event', event.id);
    text(res, 400, 'live mode events are not accepted');
    return;
  }

  const db = getFirestore();
  const claimed = await claimEvent(db, event);
  if (!claimed) {
    text(res, 200, 'duplicate');
    return;
  }

  try {
    const outcome = await dispatch(db, stripe, event);
    await db.collection(EVENTS_COLLECTION).doc(event.id).set(
      {
        processedAt: Timestamp.now(),
        outcome: outcome || { handled: false },
      },
      { merge: true },
    );
    text(res, 200, 'ok');
  } catch (error) {
    console.error(`[stripe] webhook ${event.type} failed`, error);
    await db
      .collection('stripeWebhookFailures')
      .doc(event.id)
      .set(
        {
          eventId: event.id,
          type: event.type,
          error: String(error?.message || error),
          failedAt: Timestamp.now(),
        },
        { merge: true },
      )
      .catch(() => {});
    // Release the claim so a Stripe retry can reprocess this event.
    await db.collection(EVENTS_COLLECTION).doc(event.id).delete().catch(() => {});
    text(res, 500, 'processing failed');
  }
}

/** Create-only write: the first delivery of an event id wins. */
async function claimEvent(db, event) {
  try {
    await db.collection(EVENTS_COLLECTION).doc(event.id).create({
      eventId: event.id,
      type: event.type,
      livemode: Boolean(event.livemode),
      provider: STRIPE_GATEWAY,
      receivedAt: Timestamp.now(),
      apiVersion: event.api_version || null,
    });
    return true;
  } catch (error) {
    if (error?.code === 6 || /already exists/i.test(String(error?.message))) {
      return false;
    }
    throw error;
  }
}

async function dispatch(db, stripe, event) {
  switch (event.type) {
    case 'checkout.session.completed':
    case 'checkout.session.async_payment_succeeded': {
      const session = event.data.object;
      if (session.payment_status !== 'paid' && event.type === 'checkout.session.completed') {
        return { handled: true, action: 'awaiting-payment', sessionId: session.id };
      }
      return finalizeFromSession(db, stripe, session, event);
    }
    case 'payment_intent.succeeded': {
      const paymentIntent = event.data.object;
      return finalizeFromPaymentIntent(db, stripe, paymentIntent, event);
    }
    case 'checkout.session.expired': {
      const session = event.data.object;
      return failIntent(db, resolveIntentId(session), event, {
        failureReason: 'session_expired',
        errorMessage: 'Stripe Checkout session expired before payment.',
        ids: { sessionId: session.id },
      });
    }
    case 'checkout.session.async_payment_failed': {
      const session = event.data.object;
      return failIntent(db, resolveIntentId(session), event, {
        errorMessage: 'Stripe reported the payment failed.',
        ids: { sessionId: session.id },
      });
    }
    case 'payment_intent.payment_failed': {
      const paymentIntent = event.data.object;
      const message =
        paymentIntent.last_payment_error?.message || 'Stripe payment failed.';
      return failIntent(db, resolveIntentId(paymentIntent), event, {
        errorMessage: message,
        ids: { paymentIntentId: paymentIntent.id },
        paymentIntentId: paymentIntent.id,
      });
    }
    case 'charge.refunded': {
      return refundFromCharge(db, event.data.object, event);
    }
    case 'account.updated': {
      const result = await applyAccountUpdate(db, event.data.object);
      return { handled: true, action: 'connect-updated', ...result };
    }
    default:
      return { handled: false, action: 'ignored', type: event.type };
  }
}

function resolveIntentId(object) {
  return (
    object?.metadata?.intentId ||
    object?.client_reference_id ||
    null
  );
}

async function loadIntent(db, intentId) {
  if (!intentId) return null;
  const ref = db.collection('paymentIntents').doc(String(intentId));
  const snap = await ref.get();
  if (!snap.exists) return null;
  return { ref, intent: { ...(snap.data() || {}), intentId: String(intentId) } };
}

async function findIntentByPaymentIntentId(db, paymentIntentId) {
  if (!paymentIntentId) return null;
  const snap = await db
    .collection('paymentIntents')
    .where('stripePaymentIntentId', '==', paymentIntentId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  const doc = snap.docs[0];
  return { ref: doc.ref, intent: { ...(doc.data() || {}), intentId: doc.id } };
}

async function finalizeFromSession(db, stripe, session, event) {
  const paymentIntentId =
    typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id || null;
  return finalize(db, stripe, {
    intentId: resolveIntentId(session),
    sessionId: session.id,
    paymentIntentId,
    paidMinorAmount: session.amount_total,
    currency: session.currency,
    event,
  });
}

async function finalizeFromPaymentIntent(db, stripe, paymentIntent, event) {
  return finalize(db, stripe, {
    intentId: resolveIntentId(paymentIntent),
    sessionId: paymentIntent.metadata?.sessionId || null,
    paymentIntentId: paymentIntent.id,
    paidMinorAmount: paymentIntent.amount_received || paymentIntent.amount,
    currency: paymentIntent.currency,
    event,
  });
}

async function finalize(db, stripe, {
  intentId,
  sessionId,
  paymentIntentId,
  paidMinorAmount,
  currency,
  event,
}) {
  let loaded = await loadIntent(db, intentId);
  if (!loaded && paymentIntentId) {
    loaded = await findIntentByPaymentIntentId(db, paymentIntentId);
  }
  if (!loaded) {
    console.warn('[stripe] webhook without a matching paymentIntents doc', {
      intentId,
      paymentIntentId,
      type: event.type,
    });
    return { handled: false, action: 'intent-not-found', intentId, paymentIntentId };
  }

  const { ref, intent } = loaded;
  if (intent.gateway && intent.gateway !== STRIPE_GATEWAY) {
    console.warn('[stripe] refusing to finalize a non-Stripe intent', intent.intentId);
    return { handled: false, action: 'wrong-gateway', intentId: intent.intentId };
  }

  const expectedMinor = toStripeAmount(intent.amount, currency || intent.currency);
  if (Number.isFinite(paidMinorAmount) && paidMinorAmount < expectedMinor) {
    console.error('[stripe] underpayment detected; refusing to finalize', {
      intentId: intent.intentId,
      paidMinorAmount,
      expectedMinor,
    });
    await markIntentFailed(db, ref, intent, {
      errorMessage: `Paid amount ${fromStripeAmount(paidMinorAmount, currency)} is lower than the expected ${intent.amount}.`,
      failureReason: 'amount_mismatch',
      event: event.type,
      ids: { sessionId, paymentIntentId },
    });
    return { handled: true, action: 'amount-mismatch', intentId: intent.intentId };
  }

  const charge = await loadCharge(stripe, paymentIntentId);
  await attachStripeSession(db, intent.intentId, {
    stripeSessionId: sessionId || intent.stripeSessionId || null,
    stripePaymentIntentId: paymentIntentId || intent.stripePaymentIntentId || null,
    stripeChargeId: charge?.id || intent.stripeChargeId || null,
    stripeLastEvent: event.type,
  });

  const payload = {
    provider: STRIPE_GATEWAY,
    gateway: STRIPE_GATEWAY,
    environment: 'test',
    transaction_id: paymentIntentId || sessionId || event.id,
    stripeEventId: event.id,
    stripeEventType: event.type,
    stripeSessionId: sessionId || null,
    stripePaymentIntentId: paymentIntentId || null,
    stripeChargeId: charge?.id || null,
    stripeApplicationFeeAmount: charge?.application_fee_amount ?? null,
    stripeDestination:
      typeof charge?.transfer_data?.destination === 'string'
        ? charge.transfer_data.destination
        : null,
    cardLast4: charge?.payment_method_details?.card?.last4 || '',
    amountPaid: Number.isFinite(paidMinorAmount)
      ? fromStripeAmount(paidMinorAmount, currency || intent.currency)
      : null,
    currency: String(currency || intent.currency || 'PKR').toUpperCase(),
    livemode: false,
  };

  const result = await finalizePaidIntent(db, ref, intent, payload);
  await tagStripeProvider(db, intent, {
    sessionId: sessionId || intent.stripeSessionId || null,
    paymentIntentId: paymentIntentId || intent.stripePaymentIntentId || null,
    chargeId: charge?.id || null,
    connectAccountId: payload.stripeDestination,
  });

  return {
    handled: true,
    action: result?.alreadyPaid ? 'already-paid' : 'finalized',
    intentId: intent.intentId,
    type: intent.type,
  };
}

async function loadCharge(stripe, paymentIntentId) {
  if (!paymentIntentId) return null;
  try {
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId, {
      expand: ['latest_charge'],
    });
    const charge = paymentIntent.latest_charge;
    return charge && typeof charge === 'object' ? charge : null;
  } catch (error) {
    console.warn('[stripe] unable to expand latest_charge', error.message);
    return null;
  }
}

async function failIntent(db, intentId, event, options) {
  let loaded = await loadIntent(db, intentId);
  if (!loaded && options?.paymentIntentId) {
    loaded = await findIntentByPaymentIntentId(db, options.paymentIntentId);
  }
  if (!loaded) {
    return { handled: false, action: 'intent-not-found', intentId };
  }
  const result = await markIntentFailed(db, loaded.ref, loaded.intent, {
    errorMessage: options?.errorMessage,
    failureReason: options?.failureReason || 'payment_failed',
    event: event.type,
    ids: options?.ids || {},
  });
  return {
    handled: true,
    action: result.skipped
      ? `skipped:${result.reason}`
      : `marked-failed:${result.failureReason}`,
    intentId: loaded.intent.intentId,
  };
}

async function refundFromCharge(db, charge, event) {
  const paymentIntentId =
    typeof charge.payment_intent === 'string' ? charge.payment_intent : null;
  let loaded = await loadIntent(db, resolveIntentId(charge));
  if (!loaded) {
    loaded = await findIntentByPaymentIntentId(db, paymentIntentId);
  }
  if (!loaded) {
    return { handled: false, action: 'intent-not-found', chargeId: charge.id };
  }

  await markIntentRefunded(db, loaded.ref, loaded.intent, {
    amountRefunded: fromStripeAmount(charge.amount_refunded, charge.currency),
    currency: String(charge.currency || loaded.intent.currency || 'PKR').toUpperCase(),
    ids: { chargeId: charge.id, paymentIntentId },
  });

  console.log('[stripe] refund recorded', {
    intentId: loaded.intent.intentId,
    chargeId: charge.id,
    event: event.id,
  });
  return { handled: true, action: 'refund-recorded', intentId: loaded.intent.intentId };
}

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1_000_000) {
        reject(new Error('Webhook payload too large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function text(res, statusCode, body) {
  res.writeHead(statusCode, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(body);
}
