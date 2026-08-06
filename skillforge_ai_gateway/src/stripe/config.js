/**
 * Stripe Test/Sandbox configuration for the SkillForge gateway.
 *
 * Test mode only: `sk_test_…` / `pk_test_…`. Live keys are rejected on boot so a
 * misconfigured deployment can never move real money.
 */

export function env(name, fallback = '') {
  const value = process.env[name];
  if (value != null && String(value).trim() !== '') {
    return String(value).trim();
  }
  return fallback;
}

function flag(name, fallback = 'false') {
  const raw = env(name, fallback).toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

export function getSecretKey() {
  return env('STRIPE_SECRET_KEY');
}

export function getPublishableKey() {
  return env('STRIPE_PUBLISHABLE_KEY');
}

/** Supports several secrets (Stripe CLI + Dashboard endpoint) comma separated. */
export function getWebhookSecrets() {
  return env('STRIPE_WEBHOOK_SECRET')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export function hasWebhookSecret() {
  return getWebhookSecrets().length > 0;
}

export function getCurrency() {
  return (env('STRIPE_CURRENCY', 'pkr') || 'pkr').toLowerCase();
}

/**
 * Optional FX when a catalog price is USD but checkout should settle in PKR.
 * Example: STRIPE_USD_TO_PKR=280 turns a $5 pack into 1400 PKR.
 * Leave unset to charge USD-priced catalog items in USD (recommended for test).
 */
export function getUsdToPkrRate() {
  const raw = Number(env('STRIPE_USD_TO_PKR', ''));
  if (!Number.isFinite(raw) || raw <= 0) return 0;
  return raw;
}

/** Test mode is the only supported mode; kept as a field for docs/health output. */
export function getMode() {
  return 'test';
}

export function isEnabled() {
  return flag('STRIPE_ENABLED', 'true');
}

export function isConfigured() {
  return Boolean(getSecretKey());
}

export function isAvailable() {
  return isEnabled() && isConfigured() && isTestKey(getSecretKey());
}

export function pausedMessage() {
  if (!isEnabled()) {
    return 'Stripe test checkout is disabled. Set STRIPE_ENABLED=true in skillforge_ai_gateway/.env.';
  }
  if (!isConfigured()) {
    return 'Stripe is not configured. Add STRIPE_SECRET_KEY=sk_test_… to skillforge_ai_gateway/.env and restart the gateway.';
  }
  if (!isTestKey(getSecretKey())) {
    return 'Stripe secret key must be a test key (sk_test_…). Live keys are not supported.';
  }
  return '';
}

export function isTestKey(key) {
  const value = String(key || '');
  return value.startsWith('sk_test_') || value.startsWith('pk_test_') ||
    value.startsWith('rk_test_');
}

export function isLiveKey(key) {
  const value = String(key || '');
  return value.startsWith('sk_live_') || value.startsWith('pk_live_') ||
    value.startsWith('rk_live_');
}

/**
 * Hard gate for the "sandbox only" project decision.
 * Called from server startup; throws so the process refuses to boot on live keys.
 */
export function assertTestOnlyKeys() {
  const problems = [];
  const secret = getSecretKey();
  const publishable = getPublishableKey();

  if (secret && isLiveKey(secret)) {
    problems.push('STRIPE_SECRET_KEY is a LIVE key (sk_live_…). Only sk_test_… is allowed.');
  }
  if (publishable && isLiveKey(publishable)) {
    problems.push('STRIPE_PUBLISHABLE_KEY is a LIVE key (pk_live_…). Only pk_test_… is allowed.');
  }
  if (secret && !isLiveKey(secret) && !isTestKey(secret)) {
    problems.push('STRIPE_SECRET_KEY does not look like a Stripe secret key (expected sk_test_…).');
  }
  if (publishable && !publishable.startsWith('pk_test_')) {
    problems.push('STRIPE_PUBLISHABLE_KEY must start with pk_test_.');
  }
  if (env('STRIPE_MODE', 'test').toLowerCase() !== 'test') {
    problems.push('STRIPE_MODE must be "test". Live mode is out of scope for this project.');
  }
  for (const secretValue of getWebhookSecrets()) {
    if (!secretValue.startsWith('whsec_')) {
      problems.push('STRIPE_WEBHOOK_SECRET entries must start with whsec_.');
      break;
    }
  }

  if (problems.length) {
    const error = new Error(
      `Stripe test-mode guard failed:\n  - ${problems.join('\n  - ')}`,
    );
    error.code = 'stripe-live-keys-rejected';
    throw error;
  }
}

export function getApiVersion() {
  return env('STRIPE_API_VERSION') || null;
}

/** Public base URL of THIS gateway (no trailing slash). */
export function getGatewayBaseUrl() {
  return env(
    'STRIPE_GATEWAY_BASE_URL',
    env('PAYFAST_GATEWAY_BASE_URL', env('PUBLIC_GATEWAY_BASE_URL', 'http://localhost:3001')),
  ).replace(/\/+$/, '');
}

/** Deep link / web URL the return page offers to send the buyer back to. */
export function getAppReturnUrl() {
  return env('STRIPE_APP_RETURN_URL', 'skillforge://payment/return');
}

export function getSuccessUrlTemplate() {
  return env('STRIPE_SUCCESS_URL');
}

export function getCancelUrlTemplate() {
  return env('STRIPE_CANCEL_URL');
}

export function getMerchantDisplayName() {
  return env('STRIPE_MERCHANT_NAME', env('DEMO_GATEWAY_MERCHANT_NAME', 'SkillForge AI'));
}

export function getGatewayId() {
  return 'stripe';
}

export function connectEnabled() {
  return flag('STRIPE_CONNECT_ENABLED', 'true');
}

export function getConnectCountry() {
  return env('STRIPE_CONNECT_COUNTRY', 'PK').toUpperCase();
}

export function getSessionExpiryMinutes() {
  const raw = Number(env('STRIPE_SESSION_EXPIRY_MINUTES', '60'));
  if (!Number.isFinite(raw)) return 60;
  return Math.min(1440, Math.max(30, Math.round(raw)));
}

export function getWalletTopupLimits() {
  const min = Number(env('STRIPE_WALLET_TOPUP_MIN', '100'));
  const max = Number(env('STRIPE_WALLET_TOPUP_MAX', '500000'));
  return {
    min: Number.isFinite(min) && min > 0 ? min : 100,
    max: Number.isFinite(max) && max > 0 ? max : 500000,
  };
}

/** Safe status payload for /health and GET /api/stripe/config. */
export function publicStatus() {
  return {
    enabled: isEnabled(),
    configured: isConfigured(),
    available: isAvailable(),
    mode: getMode(),
    label: 'Stripe Test (sandbox)',
    currency: getCurrency(),
    publishableKey: getPublishableKey() || null,
    webhookConfigured: hasWebhookSecret(),
    connectEnabled: connectEnabled(),
    merchantDisplayName: getMerchantDisplayName(),
  };
}
