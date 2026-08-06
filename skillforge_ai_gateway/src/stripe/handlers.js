/**
 * Stripe Test (sandbox) gateway handlers.
 *
 * Routes:
 *   POST /api/stripe/checkout          — hosted Checkout Session for any PaymentType
 *   POST /api/stripe/connect/onboard   — Express onboarding link (Phase 4)
 *   GET|POST /api/stripe/connect/status— Connect account status
 *   GET  /api/stripe/config            — publishable key + flags (no secrets)
 *   GET  /api/stripe/return            — browser landing page after Checkout
 *   GET  /api/stripe/connect/return    — browser landing page after onboarding
 */

import { getFirestore } from '../payfast/firebase.js';
import { getStripe, toGatewayError } from './client.js';
import {
  getAppReturnUrl,
  getCancelUrlTemplate,
  getCurrency,
  getGatewayBaseUrl,
  getMerchantDisplayName,
  getPublishableKey,
  getSessionExpiryMinutes,
  getSuccessUrlTemplate,
  isAvailable,
  pausedMessage,
  publicStatus,
} from './config.js';
import {
  createDashboardLink,
  createOnboardingLink,
  ensureConnectAccount,
  readCachedConnect,
  refreshConnectStatus,
  resolveDestination,
} from './connect.js';
import {
  attachStripeSession,
  createStripeIntent,
  markIntentFailed,
  resolveMarketplaceRate,
  STRIPE_ENVIRONMENT,
  STRIPE_GATEWAY,
} from './intents.js';
import { resolveStripeMoney, toStripeAmount } from './money.js';
import { normalizeType, PricingError, resolveCharge } from './pricing.js';

/** POST /api/stripe/checkout */
export async function handleStripeCheckout(req, res, { userId, email }) {
  if (!userId) {
    json(res, 401, { status: 'error', code: 'unauthenticated', message: 'Sign in required.' });
    return;
  }
  if (!isAvailable()) {
    json(res, 503, {
      status: 'error',
      code: 'stripe-unavailable',
      message: pausedMessage() || 'Stripe test checkout unavailable.',
    });
    return;
  }

  const body = await readBody(req);
  const db = getFirestore();
  const defaultCurrency = getCurrency();

  let charge;
  try {
    const type = normalizeType(body.type);
    charge = await resolveCharge(db, { type, userId, body });
  } catch (error) {
    if (error instanceof PricingError) {
      json(res, error.statusCode, {
        status: 'error',
        code: error.code,
        message: error.message,
      });
      return;
    }
    throw error;
  }

  // Catalog prices are major units of the product currency (credit packs = USD).
  // Never force a USD major amount through PKR zero-decimal (5 → Rs0.05 on Stripe).
  const money = resolveStripeMoney({
    amount: charge.amount,
    sourceCurrency: charge.sourceCurrency,
    defaultCurrency,
  });
  charge = { ...charge, amount: money.amount };
  const currency = money.currency;

  if (money.converted) {
    console.info(
      `[stripe] converted catalog ${money.sourceCurrency} → ${money.amount} ${currency} ` +
        `(STRIPE_USD_TO_PKR=${money.rate})`,
    );
  } else if (
    money.sourceCurrency &&
    String(money.sourceCurrency).toLowerCase() !== defaultCurrency
  ) {
    console.info(
      `[stripe] catalog currency ${money.sourceCurrency}; charging in ${currency}.`,
    );
  }

  const marketplaceRate = await resolveMarketplaceRate(db, charge.type);
  const { intent, fee } = await createStripeIntent(db, {
    userId,
    email,
    charge,
    currency,
    role: String(body.role || '').trim() || null,
    customerMobile: body.customerMobile || null,
    marketplaceRate,
  });

  const destination = await resolveDestination(db, {
    sellerUserId: charge.sellerUserId,
    sellerRole: charge.sellerRole,
  });

  const unitAmount = toStripeAmount(fee.subtotal, currency);
  if (unitAmount <= 0) {
    await markIntentFailed(db, db.collection('paymentIntents').doc(intent.intentId), intent, {
      errorMessage: 'Resolved amount is zero after currency normalization.',
      failureReason: 'invalid_amount',
    });
    json(res, 400, {
      status: 'error',
      code: 'invalid-amount',
      message: 'Resolved amount is too small to charge.',
    });
    return;
  }

  const applicationFeeAmount = toStripeAmount(fee.platformFee, currency);
  const useConnect =
    destination.connected &&
    Boolean(destination.accountId) &&
    applicationFeeAmount > 0 &&
    applicationFeeAmount < unitAmount;

  const clientReturnUrl = sanitizeClientReturnUrl(body.returnUrl);
  const params = buildSessionParams({
    intent,
    charge,
    currency,
    unitAmount,
    email,
    clientReturnUrl,
    connect: useConnect
      ? { accountId: destination.accountId, applicationFeeAmount }
      : null,
  });

  let session;
  let chargeMode = useConnect ? 'destination' : 'platform';
  const stripe = getStripe();
  try {
    session = await stripe.checkout.sessions.create(params, {
      idempotencyKey: `sf_checkout_${intent.intentId}`,
    });
  } catch (error) {
    // Only retry when Stripe rejected the request outright (no session created),
    // so a network error can never produce two payable sessions.
    if (useConnect && error?.type === 'StripeInvalidRequestError') {
      // Connect misconfiguration must never block the sale: retry platform-only.
      console.warn(
        '[stripe] destination charge rejected, retrying platform-only',
        error?.raw?.message || error?.message,
      );
      try {
        session = await stripe.checkout.sessions.create(
          buildSessionParams({
            intent,
            charge,
            currency,
            unitAmount,
            email,
            clientReturnUrl,
            connect: null,
          }),
          { idempotencyKey: `sf_checkout_platform_${intent.intentId}` },
        );
        chargeMode = 'platform';
      } catch (retryError) {
        await failIntent(db, intent, retryError);
        respondStripeError(res, retryError);
        return;
      }
    } else {
      await failIntent(db, intent, error);
      respondStripeError(res, error);
      return;
    }
  }

  await attachStripeSession(db, intent.intentId, {
    stripeSessionId: session.id,
    stripePaymentIntentId:
      typeof session.payment_intent === 'string' ? session.payment_intent : null,
    stripeChargeMode: chargeMode,
    stripeConnectAccountId: chargeMode === 'destination' ? destination.accountId : null,
    applicationFeeAmount: chargeMode === 'destination' ? applicationFeeAmount : null,
    checkoutUrl: session.url || null,
    checkoutPageUrl: session.url || null,
    stripeSessionExpiresAt: session.expires_at || null,
  });

  json(res, 200, {
    ok: true,
    provider: STRIPE_GATEWAY,
    gateway: STRIPE_GATEWAY,
    mode: 'test',
    label: 'Stripe Test (sandbox)',
    environment: STRIPE_ENVIRONMENT,
    isDemo: false,
    isTestMode: true,
    checkoutUrl: session.url,
    // Alias kept so existing Flutter checkout code paths can reuse their field name.
    checkoutPageUrl: session.url,
    sessionId: session.id,
    intentId: intent.intentId,
    basketId: intent.basketId,
    paymentId: intent.paymentId,
    transactionId: intent.transactionId,
    status: 'pending',
    type: charge.type,
    amount: fee.subtotal,
    currency: intent.currency,
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    platformFeeRate: fee.platformFeeRate,
    chargeMode,
    publishableKey: getPublishableKey() || null,
    merchantDisplayName: getMerchantDisplayName(),
    expiresAt: session.expires_at || null,
    connect: {
      connected: chargeMode === 'destination',
      accountId: chargeMode === 'destination' ? destination.accountId : null,
      sellerRole: charge.sellerRole,
      status: destination.status || null,
      reason: chargeMode === 'destination' ? null : fallbackReason(destination),
      message:
        chargeMode === 'destination'
          ? null
          : connectFallbackMessage(charge.sellerRole, fallbackReason(destination)),
    },
  });
}

function buildSessionParams({
  intent,
  charge,
  currency,
  unitAmount,
  email,
  clientReturnUrl,
  connect,
}) {
  const metadata = stripeMetadata({
    intentId: intent.intentId,
    userId: intent.userId,
    type: charge.type,
    paymentId: intent.paymentId,
    transactionId: intent.transactionId,
    courseId: charge.courseId,
    planId: charge.planId,
    creditPackId: charge.creditPackId,
    orderId: charge.orderId,
    teacherId: charge.teacherId,
    sellerUserId: charge.sellerUserId,
    platformFee: intent.platformFee,
    platform: 'skillforge-ai',
    environment: STRIPE_ENVIRONMENT,
  });

  const expiresAt =
    Math.floor(Date.now() / 1000) + getSessionExpiryMinutes() * 60;

  return {
    mode: 'payment',
    client_reference_id: intent.intentId,
    ...(email && /.+@.+\..+/.test(String(email)) ? { customer_email: String(email) } : {}),
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency,
          unit_amount: unitAmount,
          product_data: {
            name: truncate(charge.productName || charge.description, 250),
            description: truncate(charge.description, 500),
          },
        },
      },
    ],
    metadata,
    payment_intent_data: {
      description: truncate(charge.description, 350),
      metadata,
      ...(connect
        ? {
            application_fee_amount: connect.applicationFeeAmount,
            transfer_data: { destination: connect.accountId },
          }
        : {}),
    },
    expires_at: expiresAt,
    success_url: successUrl(intent.intentId, clientReturnUrl),
    cancel_url: cancelUrl(intent.intentId, clientReturnUrl),
  };
}

function successUrl(intentId, clientReturnUrl) {
  const template = getSuccessUrlTemplate();
  if (template) return applyTemplate(template, intentId, 'success');
  if (clientReturnUrl) return appendParams(clientReturnUrl, intentId, 'success');
  return `${getGatewayBaseUrl()}/api/stripe/return?status=success&intentId=${encodeURIComponent(
    intentId,
  )}&session_id={CHECKOUT_SESSION_ID}`;
}

function cancelUrl(intentId, clientReturnUrl) {
  const template = getCancelUrlTemplate();
  if (template) return applyTemplate(template, intentId, 'cancel');
  if (clientReturnUrl) return appendParams(clientReturnUrl, intentId, 'cancel');
  return `${getGatewayBaseUrl()}/api/stripe/return?status=cancel&intentId=${encodeURIComponent(
    intentId,
  )}`;
}

function applyTemplate(template, intentId, status) {
  return template
    .replace(/\{intentId\}/g, encodeURIComponent(intentId))
    .replace(/\{status\}/g, status);
}

function appendParams(url, intentId, status) {
  const separator = url.includes('?') ? '&' : '?';
  const sessionPart = status === 'success' ? '&session_id={CHECKOUT_SESSION_ID}' : '';
  return `${url}${separator}stripeStatus=${status}&intentId=${encodeURIComponent(intentId)}${sessionPart}`;
}

/** Only origins on ALLOWED_ORIGINS may be used as a post-checkout redirect. */
function sanitizeClientReturnUrl(raw) {
  const value = String(raw || '').trim();
  if (!value) return null;
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    return null;
  }
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return null;
  const allowed = (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  if (allowed.includes('*') || allowed.includes(parsed.origin)) {
    return value;
  }
  const devLocalhost =
    String(process.env.DEV_ALLOW_LOCALHOST || 'false').toLowerCase() === 'true' &&
    /^(localhost|127\.0\.0\.1|\[::1\])$/i.test(parsed.hostname);
  return devLocalhost ? value : null;
}

/** Distinguishes "seller not onboarded" from "this type is platform-only anyway". */
function fallbackReason(destination) {
  if (destination.connected) return 'platform-only-charge';
  return destination.reason || 'platform-only-charge';
}

function connectFallbackMessage(sellerRole, reason) {
  if (reason === 'connect-disabled-or-no-seller' || reason === 'platform-only-charge') {
    return null;
  }
  const who = sellerRole === 'freelancer' ? 'freelancer' : 'teacher';
  return `Payment is collected by SkillForge (test mode). The ${who} must complete Stripe onboarding to receive direct payouts.`;
}

/** POST /api/stripe/connect/onboard */
export async function handleConnectOnboard(req, res, { userId, email }) {
  if (!userId) {
    json(res, 401, { status: 'error', code: 'unauthenticated', message: 'Sign in required.' });
    return;
  }
  if (!isAvailable()) {
    json(res, 503, {
      status: 'error',
      code: 'stripe-unavailable',
      message: pausedMessage() || 'Stripe test mode unavailable.',
    });
    return;
  }

  const body = await readBody(req);
  const db = getFirestore();
  const role = String(body.role || '').toLowerCase() === 'freelancer' ? 'freelancer' : 'teacher';

  try {
    const snapshot = await ensureConnectAccount(db, {
      userId,
      email: body.email || email || null,
      role,
      country: body.country || null,
    });

    if (snapshot.status === 'active' && body.forceOnboarding !== true) {
      // Already onboarded: send the seller to their Express dashboard instead of
      // a second onboarding flow, and keep `onboardingUrl` populated so clients
      // that always open it still land somewhere useful.
      const dashboardUrl = await createDashboardLink(snapshot.accountId);
      const link = dashboardUrl
        ? { url: dashboardUrl, expiresAt: null }
        : await createOnboardingLink(snapshot.accountId, {
            returnUrl: sanitizeClientReturnUrl(body.returnUrl) || undefined,
          });
      json(res, 200, {
        ok: true,
        provider: STRIPE_GATEWAY,
        mode: 'test',
        alreadyActive: true,
        accountId: snapshot.accountId,
        status: snapshot.status,
        chargesEnabled: snapshot.chargesEnabled,
        payoutsEnabled: snapshot.payoutsEnabled,
        requirementsDue: snapshot.requirementsDue,
        onboardingUrl: link.url,
        expiresAt: link.expiresAt,
        dashboardUrl,
        role,
        message: 'Stripe test payouts are already active for this account.',
      });
      return;
    }

    const link = await createOnboardingLink(snapshot.accountId, {
      returnUrl: sanitizeClientReturnUrl(body.returnUrl) || undefined,
      refreshUrl: sanitizeClientReturnUrl(body.refreshUrl) || undefined,
    });

    json(res, 200, {
      ok: true,
      provider: STRIPE_GATEWAY,
      mode: 'test',
      accountId: snapshot.accountId,
      status: snapshot.status,
      chargesEnabled: snapshot.chargesEnabled,
      payoutsEnabled: snapshot.payoutsEnabled,
      requirementsDue: snapshot.requirementsDue,
      onboardingUrl: link.url,
      expiresAt: link.expiresAt,
      role,
      message: 'Open the onboarding URL to finish Stripe test onboarding.',
    });
  } catch (error) {
    respondStripeError(res, error);
  }
}

/** GET|POST /api/stripe/connect/status */
export async function handleConnectStatus(req, res, { userId }, url) {
  if (!userId) {
    json(res, 401, { status: 'error', code: 'unauthenticated', message: 'Sign in required.' });
    return;
  }

  const db = getFirestore();
  const cached = await readCachedConnect(db, userId);
  if (!cached?.accountId) {
    json(res, 200, {
      ok: true,
      provider: STRIPE_GATEWAY,
      mode: 'test',
      connected: false,
      accountId: null,
      status: 'not_started',
      chargesEnabled: false,
      payoutsEnabled: false,
      requirementsDue: [],
      message: 'No Stripe test Connect account yet. Call /api/stripe/connect/onboard to start.',
    });
    return;
  }

  const wantsRefresh =
    String(url?.searchParams?.get('refresh') || 'true').toLowerCase() !== 'false';
  let snapshot = {
    accountId: cached.accountId,
    status: cached.status,
    chargesEnabled: cached.chargesEnabled,
    payoutsEnabled: cached.payoutsEnabled,
    detailsSubmitted: cached.detailsSubmitted,
    requirementsDue: cached.requirementsDue,
  };

  if (wantsRefresh && isAvailable()) {
    try {
      snapshot = await refreshConnectStatus(db, userId, cached.accountId);
    } catch (error) {
      console.warn('[stripe] connect status refresh failed', error.message);
    }
  }

  json(res, 200, {
    ok: true,
    provider: STRIPE_GATEWAY,
    mode: 'test',
    connected: snapshot.chargesEnabled === true,
    accountId: snapshot.accountId,
    status: snapshot.status,
    chargesEnabled: snapshot.chargesEnabled,
    payoutsEnabled: snapshot.payoutsEnabled,
    detailsSubmitted: snapshot.detailsSubmitted,
    requirementsDue: snapshot.requirementsDue || [],
    dashboardUrl:
      snapshot.status === 'active' ? await createDashboardLink(snapshot.accountId) : null,
  });
}

/** GET /api/stripe/config — safe, public flags for the Flutter method chooser. */
export function handleStripeConfig(res) {
  json(res, 200, { ok: true, ...publicStatus() });
}

/** GET /api/stripe/return — browser landing page after hosted Checkout. */
export function handleStripeReturn(res, url) {
  const status = String(url.searchParams.get('status') || 'unknown');
  const intentId = String(url.searchParams.get('intentId') || '');
  const success = status === 'success';
  const deepLink = `${getAppReturnUrl()}?status=${encodeURIComponent(status)}&intentId=${encodeURIComponent(intentId)}&provider=stripe`;
  html(
    res,
    200,
    page({
      title: success ? 'Payment submitted' : 'Checkout cancelled',
      heading: success ? 'Stripe test payment submitted' : 'Checkout cancelled',
      body: success
        ? 'SkillForge is confirming this sandbox payment through the Stripe webhook. Your purchase unlocks as soon as it is verified.'
        : 'No charge was made. You can return to SkillForge and try again.',
      note: 'Stripe Test (sandbox) — no real money moved.',
      deepLink,
    }),
  );
}

/** GET /api/stripe/connect/return — browser landing page after onboarding. */
export function handleConnectReturn(res, url) {
  const status = String(url.searchParams.get('status') || 'done');
  const refresh = status === 'refresh';
  html(
    res,
    200,
    page({
      title: 'Stripe onboarding',
      heading: refresh ? 'Onboarding link expired' : 'Stripe onboarding submitted',
      body: refresh
        ? 'This onboarding link expired. Return to SkillForge and tap "Connect with Stripe" again.'
        : 'Return to SkillForge and refresh your payouts card. Stripe finishes verification in test mode within a few seconds.',
      note: 'Stripe Test (sandbox) Connect — no real payouts.',
      deepLink: `${getAppReturnUrl()}?status=${encodeURIComponent(status)}&provider=stripe&flow=connect`,
    }),
  );
}

async function failIntent(db, intent, error) {
  try {
    await markIntentFailed(db, db.collection('paymentIntents').doc(intent.intentId), intent, {
      errorMessage:
        error?.raw?.message || error?.message || 'Unable to create the Stripe Checkout Session.',
      failureReason: 'session_create_failed',
    });
  } catch (writeError) {
    console.warn('[stripe] unable to mark intent failed', writeError.message);
  }
}

function respondStripeError(res, error) {
  const normalized = error?.statusCode ? error : toGatewayError(error);
  const statusCode = Number(normalized.statusCode) || 502;
  json(res, statusCode >= 400 && statusCode < 600 ? statusCode : 502, {
    status: 'error',
    code: normalized.code || 'stripe-error',
    message: normalized.message || 'Stripe request failed.',
  });
}

function stripeMetadata(source) {
  const out = {};
  for (const [key, value] of Object.entries(source)) {
    if (value == null || value === '') continue;
    out[key] = truncate(String(value), 480);
  }
  return out;
}

function truncate(value, max) {
  const text = String(value ?? '');
  return text.length > max ? text.slice(0, max) : text;
}

function page({ title, heading, body, note, deepLink }) {
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>${title}</title>
<style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;background:#0b1220;color:#e8eefc;margin:0}
.card{padding:32px;border-radius:18px;background:#121a2e;text-align:center;max-width:460px;box-shadow:0 18px 50px rgba(0,0,0,.35)}
h1{font-size:22px;margin:0 0 12px}p{line-height:1.5;color:#b9c6e6}
.badge{display:inline-block;margin-bottom:16px;padding:6px 12px;border-radius:999px;background:#1d2a4a;color:#8da3ff;font-size:12px;font-weight:600}
a{color:#8da3ff;font-weight:600;text-decoration:none}</style></head>
<body><div class="card">
<span class="badge">${note}</span>
<h1>${heading}</h1>
<p>${body}</p>
<p><a href="${deepLink}">Open SkillForge</a></p>
<script>try{setTimeout(function(){window.close()},4000)}catch(e){}</script>
</div></body></html>`;
}

function json(res, statusCode, payload) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload));
}

function html(res, statusCode, body) {
  res.writeHead(statusCode, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(body);
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
