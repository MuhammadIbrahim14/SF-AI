/**
 * Platform fee rates by payment type.
 * Commerce: 10%. Courses: marketplace % (default 20%).
 * Plan / credit packs / wallet top-up: 100% platform SaaS revenue.
 */

export const COMMERCE_FEE_RATE = 0.1;
export const DEFAULT_COURSE_FEE_RATE = 0.2;

export function roundMoney(value) {
  return Math.round((Number(value) || 0) * 100) / 100;
}

export function feeRateForType(type, marketplaceCommissionPercent) {
  switch (String(type || '')) {
    case 'commerce_order':
      return COMMERCE_FEE_RATE;
    case 'course':
      if (
        marketplaceCommissionPercent != null &&
        !Number.isNaN(Number(marketplaceCommissionPercent))
      ) {
        const pct = Number(marketplaceCommissionPercent);
        return pct > 1 ? pct / 100 : pct;
      }
      return DEFAULT_COURSE_FEE_RATE;
    case 'plan':
    case 'credit_pack':
    case 'wallet_topup':
      return 1;
    default:
      return 0;
  }
}

export function computePlatformFee({ amount, type, marketplaceCommissionPercent }) {
  const subtotal = roundMoney(amount);
  const rate = feeRateForType(type, marketplaceCommissionPercent);
  const platformFee = roundMoney(subtotal * rate);
  const sellerNet = roundMoney(Math.max(0, subtotal - platformFee));
  return {
    subtotal,
    platformFee,
    sellerNet,
    platformFeeRate: rate,
  };
}
