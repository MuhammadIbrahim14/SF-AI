/**
 * Server-side price resolution for Stripe checkout.
 *
 * The client never decides what it pays: every payment type except wallet top-up
 * reads its amount from Firestore (paid_courses / credit_packs / plans /
 * serviceOrders). Wallet top-up is buyer-chosen by definition and is only
 * range-checked.
 */

import { getWalletTopupLimits } from './config.js';

export class PricingError extends Error {
  constructor(code, message, statusCode = 400) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
  }
}

const TYPE_ALIASES = {
  course: 'course',
  courses: 'course',
  credit_pack: 'credit_pack',
  creditpack: 'credit_pack',
  credits: 'credit_pack',
  plan: 'plan',
  plans: 'plan',
  subscription: 'plan',
  commerce_order: 'commerce_order',
  commerceorder: 'commerce_order',
  service_order: 'commerce_order',
  order: 'commerce_order',
  wallet_topup: 'wallet_topup',
  wallettopup: 'wallet_topup',
  wallet_top_up: 'wallet_topup',
  wallet: 'wallet_topup',
  topup: 'wallet_topup',
};

export function normalizeType(rawType) {
  const key = String(rawType || '').trim().toLowerCase().replace(/[\s-]+/g, '_');
  const resolved = TYPE_ALIASES[key] || TYPE_ALIASES[key.replace(/_/g, '')];
  if (!resolved) {
    throw new PricingError(
      'invalid-argument',
      `Unsupported payment type "${rawType}". Use course, credit_pack, plan, commerce_order or wallet_topup.`,
    );
  }
  return resolved;
}

function num(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function pickMetadata(body) {
  return body.metadata && typeof body.metadata === 'object' ? body.metadata : {};
}

/**
 * @returns {Promise<{
 *   type: string, amount: number, description: string, productName: string,
 *   courseId: string|null, planId: string|null, creditPackId: string|null,
 *   orderId: string|null, teacherId: string|null, sellerUserId: string|null,
 *   sellerRole: string|null, amountSource: string, sourceCurrency: string|null,
 *   metadata: Record<string, unknown>
 * }>}
 */
export async function resolveCharge(db, { type, userId, body }) {
  switch (type) {
    case 'course':
      return resolveCourse(db, userId, body);
    case 'credit_pack':
      return resolveCreditPack(db, body);
    case 'plan':
      return resolvePlan(db, body);
    case 'commerce_order':
      return resolveCommerceOrder(db, userId, body);
    case 'wallet_topup':
      return resolveWalletTopup(body);
    default:
      throw new PricingError('invalid-argument', `Unsupported payment type "${type}".`);
  }
}

function discountedPrice(config) {
  const price = num(config.price);
  const discount = num(config.discount);
  if (String(config.discountType || 'percentage') === 'percentage') {
    return Math.max(0, price * (1 - discount / 100));
  }
  return Math.max(0, price - discount);
}

async function resolveCourse(db, userId, body) {
  const metadata = pickMetadata(body);
  const courseId = String(body.courseId || metadata.courseId || '').trim();
  if (!courseId) {
    throw new PricingError('invalid-argument', 'courseId is required for a course purchase.');
  }

  const [paidSnap, courseSnap, purchaseSnap] = await Promise.all([
    db.collection('paid_courses').doc(courseId).get(),
    db.collection('courses').doc(courseId).get(),
    db.collection('course_purchases').doc(`${userId}_${courseId}`).get(),
  ]);

  if (purchaseSnap.exists) {
    throw new PricingError('already-purchased', 'You already own this course.', 409);
  }
  if (!courseSnap.exists && !paidSnap.exists) {
    throw new PricingError('not-found', 'Course not found.', 404);
  }

  const course = courseSnap.exists ? courseSnap.data() || {} : {};
  const paid = paidSnap.exists ? paidSnap.data() || {} : {};

  if (paidSnap.exists && paid.isPaid === false) {
    throw new PricingError(
      'failed-precondition',
      'This course is currently free, so it cannot be paid for.',
    );
  }

  let amount = 0;
  let sourceCurrency = null;
  if (paidSnap.exists) {
    amount = discountedPrice(paid);
    sourceCurrency = paid.currency || null;
  }
  if (amount <= 0) {
    amount = num(course.price);
    sourceCurrency = sourceCurrency || course.currency || null;
  }
  if (amount <= 0) {
    throw new PricingError(
      'failed-precondition',
      'This course is free or has no published price, so it cannot be paid for.',
    );
  }
  // Flutter / admin course pricing defaults to USD major units when unset.
  sourceCurrency = sourceCurrency || 'USD';

  const teacherId =
    paid.teacherId ||
    course.teacherId ||
    course.ownerId ||
    course.createdBy ||
    course.authorId ||
    body.teacherId ||
    metadata.teacherId ||
    null;
  const courseTitle = String(
    course.title || metadata.courseTitle || paid.title || 'Course',
  );

  return {
    type: 'course',
    amount,
    description: `Course: ${courseTitle}`,
    productName: courseTitle,
    courseId,
    planId: null,
    creditPackId: null,
    orderId: null,
    teacherId: teacherId ? String(teacherId) : null,
    sellerUserId: teacherId ? String(teacherId) : null,
    sellerRole: 'teacher',
    amountSource: 'paid_courses',
    sourceCurrency,
    metadata: {
      ...metadata,
      courseId,
      courseTitle,
      ...(teacherId ? { teacherId: String(teacherId) } : {}),
    },
  };
}

async function resolveCreditPack(db, body) {
  const metadata = pickMetadata(body);
  const creditPackId = String(body.creditPackId || metadata.creditPackId || '').trim();
  if (!creditPackId) {
    throw new PricingError('invalid-argument', 'creditPackId is required for a credit pack purchase.');
  }

  const snap = await db.collection('credit_packs').doc(creditPackId).get();
  if (!snap.exists) {
    throw new PricingError('not-found', 'Credit pack not found.', 404);
  }
  const pack = snap.data() || {};
  if (pack.isActive === false) {
    throw new PricingError('failed-precondition', 'This credit pack is no longer available.');
  }
  const amount = num(pack.price);
  if (amount <= 0) {
    throw new PricingError('failed-precondition', 'This credit pack has no price configured.');
  }

  const name = String(pack.name || 'AI credit pack');
  return {
    type: 'credit_pack',
    amount,
    description: `Credit pack: ${name}`,
    productName: name,
    courseId: null,
    planId: null,
    creditPackId,
    orderId: null,
    teacherId: null,
    sellerUserId: null,
    sellerRole: null,
    amountSource: 'credit_packs',
    // Flutter / admin credit packs default to USD major units (e.g. 5 = $5).
    sourceCurrency: pack.currency || 'USD',
    metadata: {
      ...metadata,
      creditPackId,
      credits: num(pack.credits) + num(pack.bonusCredits),
    },
  };
}

async function resolvePlan(db, body) {
  const metadata = pickMetadata(body);
  const planId = String(body.planId || metadata.planId || '').trim();
  if (!planId) {
    throw new PricingError('invalid-argument', 'planId is required for a plan purchase.');
  }

  const snap = await db.collection('plans').doc(planId).get();
  if (!snap.exists) {
    throw new PricingError('not-found', 'Plan not found.', 404);
  }
  const plan = snap.data() || {};
  if (plan.isActive === false) {
    throw new PricingError('failed-precondition', 'This plan is no longer available.');
  }
  const amount = num(plan.price);
  if (amount <= 0) {
    throw new PricingError('failed-precondition', 'This plan has no price configured.');
  }

  const name = String(plan.name || 'SkillForge plan');
  return {
    type: 'plan',
    amount,
    description: `Plan: ${name}`,
    productName: name,
    courseId: null,
    planId,
    creditPackId: null,
    orderId: null,
    teacherId: null,
    sellerUserId: null,
    sellerRole: null,
    amountSource: 'plans',
    // Flutter / admin plans default to USD major units when unset.
    sourceCurrency: plan.currency || 'USD',
    metadata: {
      ...metadata,
      planId,
      planName: name,
    },
  };
}

async function resolveCommerceOrder(db, userId, body) {
  const metadata = pickMetadata(body);
  const orderId = String(body.orderId || metadata.orderId || '').trim();
  if (!orderId) {
    throw new PricingError('invalid-argument', 'orderId is required for a service order payment.');
  }

  const snap = await db.collection('serviceOrders').doc(orderId).get();
  if (!snap.exists) {
    throw new PricingError('not-found', 'Service order not found.', 404);
  }
  const order = snap.data() || {};
  if (order.clientId && String(order.clientId) !== String(userId)) {
    throw new PricingError('permission-denied', 'This service order belongs to another buyer.', 403);
  }
  const paymentStatus = String(order.paymentStatus || '').toLowerCase();
  if (paymentStatus === 'paid' || paymentStatus === 'demopaid') {
    throw new PricingError('already-paid', 'This service order is already paid.', 409);
  }
  const amount = num(order.totalAmount);
  if (amount <= 0) {
    throw new PricingError('failed-precondition', 'This service order has no payable total.');
  }

  const title = String(order.serviceTitle || 'Service order');
  const freelancerId = order.freelancerId ? String(order.freelancerId) : null;
  return {
    type: 'commerce_order',
    amount,
    description: `Service order: ${title}`,
    productName: title,
    courseId: null,
    planId: null,
    creditPackId: null,
    orderId,
    teacherId: null,
    sellerUserId: freelancerId,
    sellerRole: 'freelancer',
    amountSource: 'serviceOrders',
    // Marketplace orders default to USD in Flutter models.
    sourceCurrency: order.currency || 'USD',
    metadata: {
      ...metadata,
      orderId,
      serviceRequestId: order.serviceRequestId || null,
      serviceTitle: title,
      ...(freelancerId ? { freelancerId } : {}),
    },
  };
}

function resolveWalletTopup(body) {
  const metadata = pickMetadata(body);
  const amount = num(body.amount);
  const { min, max } = getWalletTopupLimits();
  if (amount <= 0) {
    throw new PricingError('invalid-argument', 'Top-up amount must be greater than zero.');
  }
  if (amount < min || amount > max) {
    throw new PricingError(
      'out-of-range',
      `Top-up amount must be between ${min} and ${max}.`,
    );
  }

  const role = String(body.role || metadata.walletRole || 'customer').toLowerCase() ===
    'freelancer'
    ? 'freelancer'
    : 'customer';

  return {
    type: 'wallet_topup',
    amount,
    description: 'SkillForge wallet top-up',
    productName: 'Wallet top-up',
    courseId: null,
    planId: null,
    creditPackId: null,
    orderId: null,
    teacherId: null,
    sellerUserId: null,
    sellerRole: null,
    // The only buyer-chosen amount; bounded by STRIPE_WALLET_TOPUP_MIN/MAX.
    amountSource: 'client-bounded',
    sourceCurrency: null,
    metadata: {
      ...metadata,
      walletRole: role,
    },
  };
}
