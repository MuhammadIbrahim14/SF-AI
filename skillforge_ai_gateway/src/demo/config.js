/**
 * SkillForge Demo Gateway — no merchant ID, no real money.
 * Master switch: DEMO_GATEWAY_ENABLED (default true).
 */

export function env(name, fallback = '') {
  const value = process.env[name];
  if (value != null && String(value).trim() !== '') {
    return String(value).trim();
  }
  return fallback;
}

export function isEnabled() {
  const raw = env('DEMO_GATEWAY_ENABLED', 'true').toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

export function isAvailable() {
  return isEnabled();
}

export function pausedMessage() {
  return 'Demo payments temporarily unavailable.';
}

export function getGatewayId() {
  return 'skillforge_demo';
}

export function getCurrency() {
  return env('DEMO_GATEWAY_CURRENCY', env('PAYFAST_CURRENCY', 'PKR'));
}

export function getMerchantDisplayName() {
  return env('DEMO_GATEWAY_MERCHANT_NAME', 'SkillForge AI');
}

export function getGatewayBaseUrl() {
  return env(
    'DEMO_GATEWAY_BASE_URL',
    env('PAYFAST_GATEWAY_BASE_URL', env('PUBLIC_GATEWAY_BASE_URL', 'http://localhost:3001')),
  );
}
