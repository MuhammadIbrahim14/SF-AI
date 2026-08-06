/**
 * Phase 4 — Stripe Connect (Express, TEST mode only).
 *
 * Teachers (course sales) and freelancers (service orders) onboard an Express
 * account. When onboarded, Checkout charges use `application_fee_amount` (the
 * platform fee from fees.js) plus `transfer_data.destination`. When not
 * onboarded, the charge stays platform-only and Firestore keeps the existing
 * wallet/escrow behaviour.
 */

import { Timestamp } from 'firebase-admin/firestore';
import { getStripe, toGatewayError } from './client.js';
import { connectEnabled, getConnectCountry, getGatewayBaseUrl } from './config.js';

export const CONNECT_ACCOUNTS_COLLECTION = 'stripeConnectAccounts';

/** not_started | pending | restricted | active */
export function deriveStatus(account) {
  if (!account) return 'not_started';
  if (account.charges_enabled && account.payouts_enabled) return 'active';
  if (!account.details_submitted) return 'pending';
  const due = requirementsDue(account);
  return due.length ? 'restricted' : 'pending';
}

function requirementsDue(account) {
  const req = account?.requirements || {};
  return [
    ...(req.currently_due || []),
    ...(req.past_due || []),
  ].filter(Boolean);
}

export function connectSnapshot(account) {
  return {
    accountId: account?.id || null,
    status: deriveStatus(account),
    chargesEnabled: Boolean(account?.charges_enabled),
    payoutsEnabled: Boolean(account?.payouts_enabled),
    detailsSubmitted: Boolean(account?.details_submitted),
    requirementsDue: requirementsDue(account),
    country: account?.country || null,
    defaultCurrency: account?.default_currency || null,
  };
}

/** Reads the cached Connect state from `users/{uid}` without calling Stripe. */
export async function readCachedConnect(db, userId) {
  if (!userId) return null;
  const snap = await db.collection('users').doc(String(userId)).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  if (!data.stripeConnectAccountId) return null;
  return {
    accountId: String(data.stripeConnectAccountId),
    status: data.stripeConnectStatus || 'pending',
    chargesEnabled: data.stripeConnectChargesEnabled === true,
    payoutsEnabled: data.stripeConnectPayoutsEnabled === true,
    detailsSubmitted: data.stripeConnectDetailsSubmitted === true,
    requirementsDue: Array.isArray(data.stripeConnectRequirementsDue)
      ? data.stripeConnectRequirementsDue
      : [],
  };
}

async function persistConnect(db, userId, snapshot, extra = {}) {
  const now = Timestamp.now();
  const patch = {
    stripeConnectAccountId: snapshot.accountId,
    stripeConnectStatus: snapshot.status,
    stripeConnectChargesEnabled: snapshot.chargesEnabled,
    stripeConnectPayoutsEnabled: snapshot.payoutsEnabled,
    stripeConnectDetailsSubmitted: snapshot.detailsSubmitted,
    stripeConnectRequirementsDue: snapshot.requirementsDue,
    stripeConnectEnvironment: 'test',
    stripeConnectUpdatedAt: now,
    ...extra,
  };

  await Promise.all([
    db.collection('users').doc(String(userId)).set(patch, { merge: true }),
    db
      .collection(CONNECT_ACCOUNTS_COLLECTION)
      .doc(String(snapshot.accountId))
      .set(
        {
          accountId: snapshot.accountId,
          userId: String(userId),
          status: snapshot.status,
          chargesEnabled: snapshot.chargesEnabled,
          payoutsEnabled: snapshot.payoutsEnabled,
          detailsSubmitted: snapshot.detailsSubmitted,
          requirementsDue: snapshot.requirementsDue,
          country: snapshot.country || null,
          defaultCurrency: snapshot.defaultCurrency || null,
          environment: 'test',
          updatedAt: now,
        },
        { merge: true },
      ),
  ]);

  return patch;
}

/** Live status straight from Stripe, persisted back to Firestore. */
export async function refreshConnectStatus(db, userId, accountId) {
  const stripe = getStripe();
  try {
    const account = await stripe.accounts.retrieve(accountId);
    const snapshot = connectSnapshot(account);
    await persistConnect(db, userId, snapshot);
    return snapshot;
  } catch (error) {
    throw toGatewayError(error, 'Unable to read the Stripe Connect account.');
  }
}

export async function ensureConnectAccount(db, { userId, email, role, country }) {
  if (!connectEnabled()) {
    const error = new Error(
      'Stripe Connect is disabled on this gateway (STRIPE_CONNECT_ENABLED=false).',
    );
    error.code = 'connect-disabled';
    error.statusCode = 503;
    throw error;
  }

  const cached = await readCachedConnect(db, userId);
  if (cached?.accountId) {
    return refreshConnectStatus(db, userId, cached.accountId);
  }

  const stripe = getStripe();
  try {
    const account = await stripe.accounts.create({
      type: 'express',
      country: (country || getConnectCountry()).toUpperCase(),
      ...(email ? { email } : {}),
      business_type: 'individual',
      capabilities: {
        transfers: { requested: true },
        card_payments: { requested: true },
      },
      business_profile: {
        product_description:
          role === 'teacher'
            ? 'Online course sales on SkillForge AI'
            : 'Freelance services on SkillForge AI',
      },
      metadata: {
        userId: String(userId),
        role: role || 'seller',
        platform: 'skillforge-ai',
        environment: 'test',
      },
    });
    const snapshot = connectSnapshot(account);
    await persistConnect(db, userId, snapshot, {
      stripeConnectRole: role || 'seller',
    });
    return snapshot;
  } catch (error) {
    throw toGatewayError(
      error,
      'Unable to create the Stripe Express account. Enable Connect on your Stripe test account first.',
    );
  }
}

export async function createOnboardingLink(accountId, { returnUrl, refreshUrl } = {}) {
  const stripe = getStripe();
  const base = getGatewayBaseUrl();
  try {
    const link = await stripe.accountLinks.create({
      account: accountId,
      type: 'account_onboarding',
      refresh_url:
        refreshUrl ||
        `${base}/api/stripe/connect/return?status=refresh&account=${encodeURIComponent(accountId)}`,
      return_url:
        returnUrl ||
        `${base}/api/stripe/connect/return?status=done&account=${encodeURIComponent(accountId)}`,
    });
    return { url: link.url, expiresAt: link.expires_at || null };
  } catch (error) {
    throw toGatewayError(error, 'Unable to create the Stripe onboarding link.');
  }
}

/** Express dashboard link; only valid once the account is active. */
export async function createDashboardLink(accountId) {
  const stripe = getStripe();
  try {
    const link = await stripe.accounts.createLoginLink(accountId);
    return link.url || null;
  } catch {
    return null;
  }
}

/** Webhook handler for `account.updated`. */
export async function applyAccountUpdate(db, account) {
  const snapshot = connectSnapshot(account);
  let userId = account?.metadata?.userId || null;
  if (!userId && account?.id) {
    const snap = await db.collection(CONNECT_ACCOUNTS_COLLECTION).doc(account.id).get();
    userId = snap.exists ? snap.data()?.userId || null : null;
  }
  if (!userId) {
    console.warn('[stripe] account.updated without a mapped user', account?.id);
    return { updated: false };
  }
  await persistConnect(db, userId, snapshot);
  return { updated: true, userId, snapshot };
}

/**
 * Decides whether a charge can be split to the seller.
 * Returns platform-only params when the seller has not finished onboarding.
 */
export async function resolveDestination(db, { sellerUserId, sellerRole }) {
  if (!connectEnabled() || !sellerUserId) {
    return { connected: false, accountId: null, reason: 'connect-disabled-or-no-seller' };
  }
  const cached = await readCachedConnect(db, sellerUserId);
  if (!cached?.accountId) {
    return { connected: false, accountId: null, reason: 'seller-not-onboarded', sellerRole };
  }
  if (!cached.chargesEnabled) {
    return {
      connected: false,
      accountId: cached.accountId,
      reason: 'seller-charges-disabled',
      status: cached.status,
      sellerRole,
    };
  }
  return {
    connected: true,
    accountId: cached.accountId,
    status: cached.status,
    sellerRole,
  };
}
