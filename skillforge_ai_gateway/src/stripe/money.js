/**
 * Stripe amount conversion.
 *
 * PKR is treated as a ZERO-DECIMAL currency for this project (locked decision):
 * send whole rupees, never rupees x 100. A PKR 1500 course is `unit_amount: 1500`.
 *
 * Catalog prices may be USD major units (credit packs / plans default to USD).
 * `resolveStripeMoney` picks the charge currency so a $5 pack is not sent as
 * PKR `unit_amount: 5` (which Stripe presents as Rs0.05).
 */

import { env, getUsdToPkrRate } from './config.js';

const BUILT_IN_ZERO_DECIMAL = [
  'bif', 'clp', 'djf', 'gnf', 'jpy', 'kmf', 'krw', 'mga', 'pyg', 'rwf',
  'ugx', 'vnd', 'vuv', 'xaf', 'xof', 'xpf',
  // Project decision: PKR is charged in whole rupees.
  'pkr',
];

function zeroDecimalSet() {
  const override = env('STRIPE_ZERO_DECIMAL_CURRENCIES');
  const extra = override
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
  return new Set([...BUILT_IN_ZERO_DECIMAL, ...extra]);
}

export function isZeroDecimal(currency) {
  return zeroDecimalSet().has(String(currency || '').toLowerCase());
}

/** Rounds a display amount to the smallest chargeable unit of the currency. */
export function normalizeChargeAmount(amount, currency) {
  const value = Number(amount) || 0;
  if (isZeroDecimal(currency)) {
    return Math.round(value);
  }
  return Math.round(value * 100) / 100;
}

/** Display amount -> Stripe minor-unit integer. */
export function toStripeAmount(amount, currency) {
  const value = Number(amount) || 0;
  if (isZeroDecimal(currency)) {
    // Major units → whole currency units. Never divide (e.g. 5 PKR → 5, not 0.05).
    return Math.max(0, Math.round(value));
  }
  return Math.max(0, Math.round(value * 100));
}

/** Stripe minor-unit integer -> display amount. */
export function fromStripeAmount(minorAmount, currency) {
  const value = Number(minorAmount) || 0;
  if (isZeroDecimal(currency)) {
    return value;
  }
  return Math.round(value) / 100;
}

/**
 * Resolve what Stripe should charge from a catalog major-unit price.
 *
 * - Product currency present → charge in that currency (major units), unless
 *   USD catalog + PKR default and STRIPE_USD_TO_PKR is set (then FX to PKR).
 * - No product currency → price is major units of STRIPE_CURRENCY.
 */
export function resolveStripeMoney({ amount, sourceCurrency, defaultCurrency }) {
  const rawAmount = Number(amount) || 0;
  const catalog = String(sourceCurrency || '').trim().toLowerCase();
  const fallback = String(defaultCurrency || 'pkr').trim().toLowerCase() || 'pkr';

  if (catalog && catalog !== fallback) {
    if (catalog === 'usd' && fallback === 'pkr') {
      const rate = getUsdToPkrRate();
      if (rate > 0) {
        const converted = rawAmount * rate;
        return {
          amount: normalizeChargeAmount(converted, 'pkr'),
          currency: 'pkr',
          converted: true,
          sourceCurrency: catalog,
          rate,
        };
      }
    }
    return {
      amount: normalizeChargeAmount(rawAmount, catalog),
      currency: catalog,
      converted: false,
      sourceCurrency: catalog,
      rate: 0,
    };
  }

  const currency = catalog || fallback;
  return {
    amount: normalizeChargeAmount(rawAmount, currency),
    currency,
    converted: false,
    sourceCurrency: catalog || null,
    rate: 0,
  };
}
