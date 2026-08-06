/**
 * PayFast Pakistan configuration from gateway environment variables.
 * Set PAYFAST_MERCHANT_ID and PAYFAST_SECURED_KEY in skillforge_ai_gateway/.env
 * Pause live checkout with PAYFAST_ENABLED=false (keys can stay in .env).
 */

export function env(name, fallback = '') {
  const value = process.env[name];
  if (value != null && String(value).trim() !== '') {
    return String(value).trim();
  }
  return fallback;
}

/** Master switch. false/0/no/off = payments paused for everyone. */
export function isEnabled() {
  const raw = env('PAYFAST_ENABLED', 'false').toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

export function isConfigured() {
  return Boolean(getMerchantId() && getSecuredKey());
}

/** Ready to accept real checkouts. */
export function isAvailable() {
  return isEnabled() && isConfigured();
}

export function pausedMessage() {
  if (!isEnabled()) {
    return 'Payments temporarily unavailable.';
  }
  if (!isConfigured()) {
    return 'PayFast gateway is not configured. Add PAYFAST_MERCHANT_ID and PAYFAST_SECURED_KEY, then set PAYFAST_ENABLED=true.';
  }
  return '';
}

export function getMerchantId() {
  return env('PAYFAST_MERCHANT_ID');
}

export function getSecuredKey() {
  return env('PAYFAST_SECURED_KEY');
}

export function getMerchantName() {
  return env('PAYFAST_MERCHANT_NAME', 'SkillForge AI');
}

export function getCurrency() {
  return env('PAYFAST_CURRENCY', 'PKR');
}

export function isSandbox() {
  const raw = env('PAYFAST_SANDBOX', 'false').toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'yes';
}

export function getTokenUrl() {
  return (
    env('PAYFAST_TOKEN_URL') ||
    (isSandbox()
      ? 'https://ipguat.apps.net.pk/Ecommerce/api/Transaction/GetAccessToken'
      : 'https://ipg1.apps.net.pk/Ecommerce/api/Transaction/GetAccessToken')
  );
}

export function getPostTransactionUrl() {
  return (
    env('PAYFAST_CHECKOUT_URL') ||
    (isSandbox()
      ? 'https://ipguat.apps.net.pk/Ecommerce/api/Transaction/PostTransaction'
      : 'https://ipg1.apps.net.pk/Ecommerce/api/Transaction/PostTransaction')
  );
}

/** Public base URL of this gateway (no trailing slash). Used for IPN / return URLs. */
export function getGatewayBaseUrl() {
  return env(
    'PAYFAST_GATEWAY_BASE_URL',
    env('PUBLIC_GATEWAY_BASE_URL', 'http://localhost:3001'),
  );
}
