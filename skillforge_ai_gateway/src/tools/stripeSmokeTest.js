/**
 * Offline smoke test for the Stripe module.
 * No network, no Firestore, no charges. Run: npm run stripe:smoke
 */

import assert from 'node:assert/strict';

const failures = [];

function check(name, fn) {
  try {
    fn();
    console.log(`  ok  ${name}`);
  } catch (error) {
    failures.push(name);
    console.error(`  FAIL ${name}: ${error.message}`);
  }
}

const money = await import('../stripe/money.js');
const config = await import('../stripe/config.js');
const pricing = await import('../stripe/pricing.js');

// Imported for module resolution / syntax validation only.
await import('../stripe/intents.js');
await import('../stripe/connect.js');
await import('../stripe/handlers.js');
await import('../stripe/webhook.js');

console.log('PKR zero-decimal amounts');
check('PKR is zero-decimal', () => {
  assert.equal(money.isZeroDecimal('pkr'), true);
  assert.equal(money.isZeroDecimal('PKR'), true);
});
check('PKR 1500 charges as 1500 minor units', () => {
  assert.equal(money.toStripeAmount(1500, 'pkr'), 1500);
  assert.equal(money.fromStripeAmount(1500, 'pkr'), 1500);
});
check('PKR fractions round to whole rupees', () => {
  assert.equal(money.normalizeChargeAmount(1499.6, 'pkr'), 1500);
  assert.equal(money.toStripeAmount(1499.4, 'pkr'), 1499);
});
check('USD still uses cents', () => {
  assert.equal(money.toStripeAmount(19.99, 'usd'), 1999);
  assert.equal(money.fromStripeAmount(1999, 'usd'), 19.99);
});

console.log('Catalog currency resolution');
check('USD credit pack price 5 charges as USD cents, not PKR 5', () => {
  const previous = process.env.STRIPE_USD_TO_PKR;
  delete process.env.STRIPE_USD_TO_PKR;
  const resolved = money.resolveStripeMoney({
    amount: 5,
    sourceCurrency: 'USD',
    defaultCurrency: 'pkr',
  });
  assert.equal(resolved.currency, 'usd');
  assert.equal(resolved.amount, 5);
  assert.equal(resolved.converted, false);
  assert.equal(money.toStripeAmount(resolved.amount, resolved.currency), 500);
  restore('STRIPE_USD_TO_PKR', previous);
});
check('STRIPE_USD_TO_PKR converts $5 → PKR major units', () => {
  const previous = process.env.STRIPE_USD_TO_PKR;
  process.env.STRIPE_USD_TO_PKR = '280';
  const resolved = money.resolveStripeMoney({
    amount: 5,
    sourceCurrency: 'usd',
    defaultCurrency: 'pkr',
  });
  assert.equal(resolved.currency, 'pkr');
  assert.equal(resolved.amount, 1400);
  assert.equal(resolved.converted, true);
  assert.equal(money.toStripeAmount(resolved.amount, resolved.currency), 1400);
  restore('STRIPE_USD_TO_PKR', previous);
});
check('missing catalog currency uses STRIPE_CURRENCY major units', () => {
  const resolved = money.resolveStripeMoney({
    amount: 1500,
    sourceCurrency: null,
    defaultCurrency: 'pkr',
  });
  assert.equal(resolved.currency, 'pkr');
  assert.equal(resolved.amount, 1500);
  assert.equal(money.toStripeAmount(resolved.amount, resolved.currency), 1500);
});

console.log('Test-mode key guard');
check('live secret key is rejected', () => {
  const previous = process.env.STRIPE_SECRET_KEY;
  process.env.STRIPE_SECRET_KEY = 'sk_live_abc123';
  assert.throws(() => config.assertTestOnlyKeys(), /LIVE key/);
  if (previous == null) delete process.env.STRIPE_SECRET_KEY;
  else process.env.STRIPE_SECRET_KEY = previous;
});
check('live publishable key is rejected', () => {
  const previous = process.env.STRIPE_PUBLISHABLE_KEY;
  process.env.STRIPE_PUBLISHABLE_KEY = 'pk_live_abc123';
  assert.throws(() => config.assertTestOnlyKeys(), /LIVE key/);
  if (previous == null) delete process.env.STRIPE_PUBLISHABLE_KEY;
  else process.env.STRIPE_PUBLISHABLE_KEY = previous;
});
check('test keys pass the guard', () => {
  const previousSecret = process.env.STRIPE_SECRET_KEY;
  const previousPublishable = process.env.STRIPE_PUBLISHABLE_KEY;
  const previousWebhook = process.env.STRIPE_WEBHOOK_SECRET;
  process.env.STRIPE_SECRET_KEY = 'sk_test_abc123';
  process.env.STRIPE_PUBLISHABLE_KEY = 'pk_test_abc123';
  process.env.STRIPE_WEBHOOK_SECRET = 'whsec_abc123';
  config.assertTestOnlyKeys();
  assert.equal(config.isConfigured(), true);
  assert.equal(config.getMode(), 'test');
  restore('STRIPE_SECRET_KEY', previousSecret);
  restore('STRIPE_PUBLISHABLE_KEY', previousPublishable);
  restore('STRIPE_WEBHOOK_SECRET', previousWebhook);
});
check('non-whsec webhook secret is rejected', () => {
  const previous = process.env.STRIPE_WEBHOOK_SECRET;
  process.env.STRIPE_WEBHOOK_SECRET = 'not_a_secret';
  assert.throws(() => config.assertTestOnlyKeys(), /whsec_/);
  restore('STRIPE_WEBHOOK_SECRET', previous);
});
check('public status never leaks the secret key', () => {
  const previous = process.env.STRIPE_SECRET_KEY;
  process.env.STRIPE_SECRET_KEY = 'sk_test_supersecret';
  const status = JSON.stringify(config.publicStatus());
  assert.equal(status.includes('sk_test_supersecret'), false);
  restore('STRIPE_SECRET_KEY', previous);
});

console.log('Payment type mapping');
check('all Flutter payment types normalize', () => {
  assert.equal(pricing.normalizeType('course'), 'course');
  assert.equal(pricing.normalizeType('credit_pack'), 'credit_pack');
  assert.equal(pricing.normalizeType('creditPack'), 'credit_pack');
  assert.equal(pricing.normalizeType('plan'), 'plan');
  assert.equal(pricing.normalizeType('commerce_order'), 'commerce_order');
  assert.equal(pricing.normalizeType('wallet_topup'), 'wallet_topup');
});
check('unknown type is rejected', () => {
  assert.throws(() => pricing.normalizeType('bitcoin'), /Unsupported payment type/);
});

console.log('Platform fee parity with fees.js');
const { computePlatformFee } = await import('../payfast/fees.js');
check('course fee stays 20% by default', () => {
  const fee = computePlatformFee({ amount: 1000, type: 'course' });
  assert.equal(fee.platformFee, 200);
  assert.equal(fee.sellerNet, 800);
  assert.equal(money.toStripeAmount(fee.platformFee, 'pkr'), 200);
});
check('commerce fee stays 10%', () => {
  const fee = computePlatformFee({ amount: 5000, type: 'commerce_order' });
  assert.equal(fee.platformFee, 500);
  assert.equal(fee.sellerNet, 4500);
});
check('plans, credits and top-ups stay 100% platform', () => {
  for (const type of ['plan', 'credit_pack', 'wallet_topup']) {
    const fee = computePlatformFee({ amount: 2500, type });
    assert.equal(fee.platformFee, 2500);
    assert.equal(fee.sellerNet, 0);
  }
});

function restore(key, value) {
  if (value == null) delete process.env[key];
  else process.env[key] = value;
}

if (failures.length) {
  console.error(`\n${failures.length} check(s) failed.`);
  process.exit(1);
}
console.log('\nAll Stripe smoke checks passed.');
