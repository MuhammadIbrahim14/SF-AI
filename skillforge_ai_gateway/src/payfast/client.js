import crypto from 'node:crypto';
import {
  isConfigured,
  getMerchantId,
  getSecuredKey,
  getMerchantName,
  getCurrency,
  getTokenUrl,
  getPostTransactionUrl,
  getGatewayBaseUrl,
} from './config.js';

export async function fetchAccessToken() {
  if (!isConfigured()) {
    const err = new Error(
      'PayFast is not configured. Set PAYFAST_MERCHANT_ID and PAYFAST_SECURED_KEY.',
    );
    err.code = 'gateway-not-configured';
    throw err;
  }

  const body = new URLSearchParams({
    MERCHANT_ID: getMerchantId(),
    SECURED_KEY: getSecuredKey(),
  });

  const response = await fetch(getTokenUrl(), {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = {};
  }

  const token =
    data.ACCESS_TOKEN ||
    data.access_token ||
    data.token ||
    data.Token ||
    '';

  if (!token) {
    const err = new Error(
      `PayFast token request failed: ${text.slice(0, 240) || response.status}`,
    );
    err.code = 'token-failed';
    throw err;
  }
  return String(token);
}

export function buildSignature({ amount, basketId }) {
  const merchantId = getMerchantId();
  const merchantName = getMerchantName();
  const raw = `${merchantId}:${merchantName}:${Number(amount).toFixed(2)}:${basketId}`;
  return crypto.createHash('md5').update(raw).digest('hex');
}

/**
 * Verifies PayFast IPN authenticity.
 * Accepts SIGNATURE / signature matching the checkout hash, and optional
 * amount / merchant cross-checks against the stored payment intent.
 */
export function verifyIpnSignature(payload, intent) {
  const basketId = String(
    payload.basket_id ||
      payload.BASKET_ID ||
      payload.order_no ||
      payload.ORDER_NO ||
      intent?.basketId ||
      intent?.intentId ||
      '',
  ).trim();

  if (!basketId) {
    return { ok: false, reason: 'missing basket id' };
  }

  const merchantFromPayload = String(
    payload.merchant_id || payload.MERCHANT_ID || '',
  ).trim();
  const expectedMerchant = getMerchantId();
  if (
    merchantFromPayload &&
    expectedMerchant &&
    merchantFromPayload !== expectedMerchant
  ) {
    return { ok: false, reason: 'merchant mismatch' };
  }

  const amountRaw =
    payload.txnamt ||
    payload.TXNAMT ||
    payload.amount ||
    payload.AMOUNT ||
    intent?.amount;
  const amount = Number(amountRaw);
  if (!Number.isFinite(amount) || amount <= 0) {
    return { ok: false, reason: 'invalid amount' };
  }

  const intentAmount = Number(intent?.amount);
  if (Number.isFinite(intentAmount) && Math.abs(intentAmount - amount) > 0.009) {
    return { ok: false, reason: 'amount mismatch vs intent' };
  }

  const provided = String(
    payload.signature || payload.SIGNATURE || payload.hash || payload.HASH || '',
  )
    .trim()
    .toLowerCase();

  if (!provided) {
    return { ok: false, reason: 'missing signature' };
  }

  const expected = buildSignature({ amount, basketId }).toLowerCase();
  const providedBuf = Buffer.from(provided, 'utf8');
  const expectedBuf = Buffer.from(expected, 'utf8');
  if (
    providedBuf.length !== expectedBuf.length ||
    !crypto.timingSafeEqual(providedBuf, expectedBuf)
  ) {
    return { ok: false, reason: 'signature mismatch' };
  }

  return { ok: true, basketId, amount };
}

export function buildCheckoutFormFields({
  accessToken,
  amount,
  basketId,
  description,
  customerEmail,
  customerMobile,
  paymentMethod,
}) {
  const base = getGatewayBaseUrl();
  const successUrl = `${base}/api/payfast/return?status=success&basket_id=${encodeURIComponent(basketId)}`;
  const failureUrl = `${base}/api/payfast/return?status=failure&basket_id=${encodeURIComponent(basketId)}`;
  const checkoutUrl = `${base}/api/payfast/ipn`;

  const fields = {
    MERCHANT_ID: getMerchantId(),
    MERCHANT_NAME: getMerchantName(),
    TOKEN: accessToken,
    PROCCODE: '00',
    TXNAMT: Number(amount).toFixed(2),
    CUSTOMER_MOBILE_NO: customerMobile || '03000000000',
    CUSTOMER_EMAIL_ADDRESS: customerEmail || 'billing@skillforge.ai',
    SIGNATURE: buildSignature({ amount, basketId }),
    VERSION: 'SKILLFORGE-PAYFAST-1.0',
    TXNDESC: (description || 'SkillForge payment').slice(0, 120),
    SUCCESS_URL: encodeURIComponent(successUrl),
    FAILURE_URL: encodeURIComponent(failureUrl),
    BASKET_ID: basketId,
    ORDER_DATE: new Date().toISOString().replace('T', ' ').slice(0, 19),
    CHECKOUT_URL: encodeURIComponent(checkoutUrl),
    CURRENCY_CODE: getCurrency(),
  };

  if (paymentMethod) {
    fields.PAYMENT_METHOD = String(paymentMethod);
  }

  return {
    actionUrl: getPostTransactionUrl(),
    fields,
  };
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export function renderAutoPostHtml({ actionUrl, fields }) {
  const inputs = Object.entries(fields)
    .map(
      ([key, value]) =>
        `<input type="hidden" name="${escapeHtml(key)}" value="${escapeHtml(value)}" />`,
    )
    .join('\n');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Redirecting to PayFast…</title>
  <style>
    body { font-family: system-ui, sans-serif; display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; background:#0b1220; color:#e8eefc; }
    .card { text-align:center; padding:32px; border-radius:16px; background:#121a2e; max-width:420px; }
    .spinner { width:40px; height:40px; border:3px solid #334; border-top-color:#5b7cff; border-radius:50%; margin:0 auto 16px; animation:spin 0.8s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h1>Secure checkout</h1>
    <p>Redirecting you to PayFast to complete payment…</p>
  </div>
  <form id="payfast" method="POST" action="${escapeHtml(actionUrl)}">
    ${inputs}
  </form>
  <script>document.getElementById('payfast').submit();</script>
</body>
</html>`;
}
