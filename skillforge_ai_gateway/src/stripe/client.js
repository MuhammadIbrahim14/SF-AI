/**
 * Lazily constructed Stripe SDK client (test keys only).
 */

import Stripe from 'stripe';
import {
  getApiVersion,
  getSecretKey,
  isAvailable,
  isLiveKey,
  pausedMessage,
} from './config.js';

let cached = null;
let cachedKey = '';

export function getStripe() {
  const key = getSecretKey();
  if (!key) {
    throw stripeConfigError(
      pausedMessage() || 'STRIPE_SECRET_KEY is missing.',
    );
  }
  if (isLiveKey(key)) {
    throw stripeConfigError(
      'Refusing to use a live Stripe key. Configure sk_test_… instead.',
    );
  }
  if (!isAvailable()) {
    throw stripeConfigError(pausedMessage() || 'Stripe checkout unavailable.');
  }

  if (cached && cachedKey === key) return cached;

  const apiVersion = getApiVersion();
  cached = new Stripe(key, {
    ...(apiVersion ? { apiVersion } : {}),
    appInfo: {
      name: 'SkillForge AI Gateway',
      version: '0.1.0',
    },
    maxNetworkRetries: 2,
  });
  cachedKey = key;
  return cached;
}

function stripeConfigError(message) {
  const error = new Error(message);
  error.code = 'stripe-unavailable';
  error.statusCode = 503;
  return error;
}

/** Normalizes Stripe SDK errors into gateway-shaped errors. */
export function toGatewayError(error, fallbackMessage) {
  const message =
    error?.raw?.message || error?.message || fallbackMessage || 'Stripe request failed.';
  const wrapped = new Error(message);
  wrapped.code = error?.code || error?.raw?.code || 'stripe-error';
  wrapped.statusCode = Number(error?.statusCode) || 502;
  wrapped.stripeType = error?.type || null;
  return wrapped;
}
