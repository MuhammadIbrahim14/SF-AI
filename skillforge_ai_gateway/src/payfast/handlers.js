import { Timestamp } from 'firebase-admin/firestore';
import {
  isConfigured,
  isEnabled,
  isAvailable,
  pausedMessage,
  getCurrency,
  getGatewayBaseUrl,
} from './config.js';
import { computePlatformFee } from './fees.js';
import {
  fetchAccessToken,
  buildCheckoutFormFields,
  renderAutoPostHtml,
  verifyIpnSignature,
} from './client.js';
import { finalizePaidIntent, isSuccessStatus, id } from './finalize.js';
import { getFirestore } from './firebase.js';

async function resolveMarketplaceRate(type) {
  if (type !== 'course') return null;
  const snap = await getFirestore().collection('settings').doc('marketplace').get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  return data.platformCommissionPercent ?? null;
}

/**
 * POST /api/payfast/checkout — create pending intent + checkout page URL.
 * Requires authenticated Firebase user (Bearer token).
 */
export async function handleCreateCheckout(req, res, { userId, email }) {
  if (!userId) {
    json(res, 401, { status: 'error', code: 'unauthenticated', message: 'Sign in required.' });
    return;
  }
  if (!isAvailable()) {
    json(res, 503, {
      status: 'error',
      code: isEnabled() ? 'failed-precondition' : 'payments-paused',
      message: pausedMessage() || 'Payments temporarily unavailable.',
    });
    return;
  }

  const data = await readBody(req);
  const type = String(data.type || '').trim();
  const amount = Number(data.amount);
  const paymentMethod = String(data.paymentMethod || 'card').trim();
  const description = String(data.description || 'SkillForge payment').trim();
  const currency = String(data.currency || getCurrency()).trim() || 'PKR';

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
    teacherId: data.teacherId || null,
    orderId: data.orderId || null,
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    platformFeeRate: fee.platformFeeRate,
    gateway: 'payfast',
    metadata: data.metadata && typeof data.metadata === 'object' ? data.metadata : {},
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
    gateway: 'payfast',
    cardLast4: '',
    planId: intent.planId,
    creditPackId: intent.creditPackId,
    teacherId: intent.teacherId,
    description,
    metadata: {
      ...intent.metadata,
      intentId,
      platformFee: fee.platformFee,
      paymentMethod,
    },
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    createdAt: now,
    updatedAt: now,
  });

  let accessToken;
  try {
    accessToken = await fetchAccessToken();
  } catch (error) {
    console.error('[PayFast] token error', error.message);
    await db.collection('paymentIntents').doc(intentId).set(
      {
        status: 'failed',
        errorMessage: error.message,
        updatedAt: Timestamp.now(),
      },
      { merge: true },
    );
    json(res, 502, {
      status: 'error',
      code: 'unavailable',
      message: error.message || 'Unable to reach PayFast.',
    });
    return;
  }

  const form = buildCheckoutFormFields({
    accessToken,
    amount: fee.subtotal,
    basketId,
    description,
    customerEmail: intent.customerEmail,
    customerMobile: intent.customerMobile,
    paymentMethod,
  });

  await db.collection('paymentIntents').doc(intentId).set(
    {
      checkoutActionUrl: form.actionUrl,
      updatedAt: Timestamp.now(),
    },
    { merge: true },
  );

  const checkoutPageUrl = `${getGatewayBaseUrl()}/api/payfast/checkout-page?intentId=${encodeURIComponent(intentId)}`;

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
    checkoutActionUrl: form.actionUrl,
    formFields: form.fields,
  });
}

/** GET /api/payfast/checkout-page?intentId=… */
export async function handleCheckoutPage(req, res, url) {
  try {
    const intentId = String(url.searchParams.get('intentId') || '').trim();
    if (!intentId) {
      html(res, 400, 'Missing intentId');
      return;
    }
    if (!isAvailable()) {
      html(res, 503, pausedMessage() || 'Payments temporarily unavailable.');
      return;
    }

    const snap = await getFirestore().collection('paymentIntents').doc(intentId).get();
    if (!snap.exists) {
      html(res, 404, 'Payment intent not found');
      return;
    }
    const intent = snap.data();
    if (intent.status === 'paid') {
      html(
        res,
        200,
        '<html><body><h1>Already paid</h1><p>You can close this window.</p></body></html>',
      );
      return;
    }

    const accessToken = await fetchAccessToken();
    const form = buildCheckoutFormFields({
      accessToken,
      amount: intent.amount,
      basketId: intent.basketId || intentId,
      description: intent.description,
      customerEmail: intent.customerEmail,
      customerMobile: intent.customerMobile,
      paymentMethod: intent.paymentMethod,
    });

    html(res, 200, renderAutoPostHtml(form));
  } catch (error) {
    console.error('[PayFast] checkout-page failed', error.message);
    html(res, 500, `Checkout error: ${error.message}`);
  }
}

/** POST /api/payfast/ipn — PayFast server callback */
export async function handleIpn(req, res, url) {
  try {
    const body = await readBody(req);
    const payload = {
      ...body,
      ...Object.fromEntries(url.searchParams.entries()),
    };
    const basketId = String(
      payload.basket_id ||
        payload.BASKET_ID ||
        payload.order_no ||
        payload.ORDER_NO ||
        '',
    ).trim();
    const statusCode =
      payload.err_code ||
      payload.ERR_CODE ||
      payload.status ||
      payload.STATUS ||
      payload.code ||
      payload.CODE ||
      '';

    console.log('[PayFast] IPN', { basketId, statusCode });

    if (!basketId) {
      text(res, 400, 'missing basket');
      return;
    }

    const db = getFirestore();
    const intentRef = db.collection('paymentIntents').doc(basketId);
    const snap = await intentRef.get();
    if (!snap.exists) {
      text(res, 404, 'intent not found');
      return;
    }

    const intent = { ...snap.data(), intentId: basketId };
    const signatureCheck = verifyIpnSignature(payload, intent);
    if (!signatureCheck.ok) {
      console.warn('[PayFast] IPN rejected', signatureCheck.reason, {
        basketId,
      });
      await intentRef.set(
        {
          ipnRejectedAt: Timestamp.now(),
          ipnRejectReason: signatureCheck.reason,
          updatedAt: Timestamp.now(),
        },
        { merge: true },
      );
      text(res, 403, 'invalid signature');
      return;
    }

    if (!isSuccessStatus(statusCode)) {
      await intentRef.set(
        {
          status: 'failed',
          updatedAt: Timestamp.now(),
          ipn: payload,
          errorMessage: `PayFast status ${statusCode}`,
        },
        { merge: true },
      );
      text(res, 200, 'FAILED_RECORDED');
      return;
    }

    await finalizePaidIntent(db, intentRef, intent, payload);
    text(res, 200, 'OK');
  } catch (error) {
    console.error('[PayFast] IPN failed', error.message);
    text(res, 500, 'ERROR');
  }
}

/** GET /api/payfast/return — browser return page after PayFast */
export async function handleReturn(req, res, url) {
  const status = String(url.searchParams.get('status') || 'unknown');
  const basketId = String(
    url.searchParams.get('basket_id') || url.searchParams.get('BASKET_ID') || '',
  );
  const deepLink = `skillforge://payment/return?status=${encodeURIComponent(status)}&intentId=${encodeURIComponent(basketId)}`;
  html(
    res,
    200,
    `<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>Payment ${status}</title>
<style>body{font-family:system-ui;display:flex;align-items:center;justify-content:center;min-height:100vh;background:#0b1220;color:#e8eefc;margin:0}
.card{padding:28px;border-radius:16px;background:#121a2e;text-align:center;max-width:440px}</style></head>
<body><div class="card">
<h1>Payment ${status === 'success' ? 'submitted' : 'returned'}</h1>
<p>You can return to SkillForge. Status updates when PayFast confirms the payment.</p>
<p><a href="${deepLink}" style="color:#8da3ff">Open SkillForge</a></p>
<script>try{window.close()}catch(e){}</script>
</div></body></html>`,
  );
}

function json(res, statusCode, payload) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload));
}

function html(res, statusCode, body) {
  res.writeHead(statusCode, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(body);
}

function text(res, statusCode, body) {
  res.writeHead(statusCode, { 'Content-Type': 'text/plain; charset=utf-8' });
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
      const contentType = String(req.headers['content-type'] || '');
      if (contentType.includes('application/x-www-form-urlencoded')) {
        resolve(Object.fromEntries(new URLSearchParams(raw).entries()));
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
