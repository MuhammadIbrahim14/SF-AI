const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { Timestamp } = require("firebase-admin/firestore");

const {
  isConfigured,
  getCurrency,
  getFunctionsBaseUrl,
} = require("./config");
const { computePlatformFee } = require("./fees");
const {
  fetchAccessToken,
  buildCheckoutFormFields,
  renderAutoPostHtml,
} = require("./client");
const { finalizePaidIntent, isSuccessStatus, id } = require("./finalize");

function db() {
  return admin.firestore();
}

async function resolveMarketplaceRate(type) {
  if (type !== "course") return null;
  const snap = await db().collection("settings").doc("marketplace").get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  return data.platformCommissionPercent ?? null;
}

/**
 * Callable: createPayFastCheckout
 * data: { type, amount, currency?, description, paymentMethod, planId?, creditPackId?,
 *         teacherId?, orderId?, metadata? }
 */
const createPayFastCheckout = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isConfigured()) {
    throw new HttpsError(
      "failed-precondition",
      "PayFast gateway is not configured. Add PAYFAST_MERCHANT_ID and PAYFAST_SECURED_KEY, then redeploy Functions.",
    );
  }

  const uid = request.auth.uid;
  const data = request.data || {};
  const type = String(data.type || "").trim();
  const amount = Number(data.amount);
  const paymentMethod = String(data.paymentMethod || "card").trim();
  const description = String(data.description || "SkillForge payment").trim();
  const currency = String(data.currency || getCurrency()).trim() || "PKR";

  if (!type) {
    throw new HttpsError("invalid-argument", "Payment type is required.");
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Amount must be greater than zero.");
  }

  const marketplaceRate = await resolveMarketplaceRate(type);
  const fee = computePlatformFee({
    amount,
    type,
    marketplaceCommissionPercent: marketplaceRate,
  });

  const intentId = id("pi");
  const basketId = intentId;
  const paymentId = id("pay");
  const transactionId = id("txn");
  const now = Timestamp.now();

  const intent = {
    intentId,
    basketId,
    paymentId,
    transactionId,
    userId: uid,
    role: String(data.role || "").trim() || null,
    type,
    status: "pending",
    amount: fee.subtotal,
    currency,
    description,
    paymentMethod,
    planId: data.planId || null,
    creditPackId: data.creditPackId || null,
    teacherId: data.teacherId || null,
    orderId: data.orderId || null,
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    platformFeeRate: fee.platformFeeRate,
    gateway: "payfast",
    metadata: data.metadata && typeof data.metadata === "object" ? data.metadata : {},
    customerEmail: data.customerEmail || request.auth.token?.email || null,
    customerMobile: data.customerMobile || null,
    createdAt: now,
    updatedAt: now,
  };

  await db().collection("paymentIntents").doc(intentId).set(intent);

  await db()
    .collection("payments")
    .doc(paymentId)
    .set({
      paymentId,
      transactionId,
      userId: uid,
      type,
      status: "Pending",
      amount: fee.subtotal,
      currency,
      gateway: "payfast",
      cardLast4: "",
      planId: intent.planId,
      creditPackId: intent.creditPackId,
      teacherId: intent.teacherId,
      description,
      metadata: {
        ...intent.metadata,
        intentId,
        platformFee: fee.platformFee,
        paymentMethod,
      },
      platformFee: fee.platformFee,
      sellerNet: fee.sellerNet,
      createdAt: now,
      updatedAt: now,
    });

  let accessToken;
  try {
    accessToken = await fetchAccessToken();
  } catch (error) {
    logger.error("PayFast token error", { message: error.message });
    await db()
      .collection("paymentIntents")
      .doc(intentId)
      .set(
        {
          status: "failed",
          errorMessage: error.message,
          updatedAt: Timestamp.now(),
        },
        { merge: true },
      );
    throw new HttpsError(
      "unavailable",
      error.message || "Unable to reach PayFast.",
    );
  }

  const form = buildCheckoutFormFields({
    accessToken,
    amount: fee.subtotal,
    basketId,
    description,
    customerEmail: intent.customerEmail,
    customerMobile: intent.customerMobile,
    paymentMethod,
  });

  await db()
    .collection("paymentIntents")
    .doc(intentId)
    .set(
      {
        checkoutActionUrl: form.actionUrl,
        updatedAt: Timestamp.now(),
      },
      { merge: true },
    );

  const checkoutPageUrl = `${getFunctionsBaseUrl()}/payfastCheckoutPage?intentId=${encodeURIComponent(intentId)}`;

  return {
    intentId,
    basketId,
    paymentId,
    transactionId,
    status: "pending",
    amount: fee.subtotal,
    currency,
    platformFee: fee.platformFee,
    sellerNet: fee.sellerNet,
    platformFeeRate: fee.platformFeeRate,
    checkoutPageUrl,
    checkoutActionUrl: form.actionUrl,
    formFields: form.fields,
  };
});

const payfastCheckoutPage = onRequest(async (req, res) => {
  try {
    const intentId = String(req.query.intentId || "").trim();
    if (!intentId) {
      res.status(400).send("Missing intentId");
      return;
    }
    if (!isConfigured()) {
      res
        .status(503)
        .send("PayFast gateway is not configured on the server.");
      return;
    }

    const snap = await db().collection("paymentIntents").doc(intentId).get();
    if (!snap.exists) {
      res.status(404).send("Payment intent not found");
      return;
    }
    const intent = snap.data();
    if (intent.status === "paid") {
      res
        .status(200)
        .send("<html><body><h1>Already paid</h1><p>You can close this window.</p></body></html>");
      return;
    }

    const accessToken = await fetchAccessToken();
    const form = buildCheckoutFormFields({
      accessToken,
      amount: intent.amount,
      basketId: intent.basketId || intentId,
      description: intent.description,
      customerEmail: intent.customerEmail,
      customerMobile: intent.customerMobile,
      paymentMethod: intent.paymentMethod,
    });

    res.set("Content-Type", "text/html; charset=utf-8");
    res.status(200).send(renderAutoPostHtml(form));
  } catch (error) {
    logger.error("payfastCheckoutPage failed", { message: error.message });
    res.status(500).send(`Checkout error: ${error.message}`);
  }
});

const payfastIpn = onRequest(async (req, res) => {
  try {
    const payload = {
      ...(typeof req.body === "object" && req.body ? req.body : {}),
      ...req.query,
    };
    const basketId = String(
      payload.basket_id ||
        payload.BASKET_ID ||
        payload.order_no ||
        payload.ORDER_NO ||
        "",
    ).trim();
    const statusCode =
      payload.err_code ||
      payload.ERR_CODE ||
      payload.status ||
      payload.STATUS ||
      payload.code ||
      payload.CODE ||
      "";

    logger.info("PayFast IPN", { basketId, statusCode });

    if (!basketId) {
      res.status(400).send("missing basket");
      return;
    }

    const intentRef = db().collection("paymentIntents").doc(basketId);
    const snap = await intentRef.get();
    if (!snap.exists) {
      res.status(404).send("intent not found");
      return;
    }

    if (!isSuccessStatus(statusCode)) {
      await intentRef.set(
        {
          status: "failed",
          updatedAt: Timestamp.now(),
          ipn: payload,
          errorMessage: `PayFast status ${statusCode}`,
        },
        { merge: true },
      );
      res.status(200).send("FAILED_RECORDED");
      return;
    }

    await finalizePaidIntent(db(), intentRef, { ...snap.data(), intentId: basketId }, payload);
    res.status(200).send("OK");
  } catch (error) {
    logger.error("payfastIpn failed", { message: error.message });
    res.status(500).send("ERROR");
  }
});

const payfastReturn = onRequest(async (req, res) => {
  const status = String(req.query.status || "unknown");
  const basketId = String(req.query.basket_id || req.query.BASKET_ID || "");
  const deepLink = `skillforge://payment/return?status=${encodeURIComponent(status)}&intentId=${encodeURIComponent(basketId)}`;
  res.set("Content-Type", "text/html; charset=utf-8");
  res.status(200).send(`<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>Payment ${status}</title>
<style>body{font-family:system-ui;display:flex;align-items:center;justify-content:center;min-height:100vh;background:#0b1220;color:#e8eefc;margin:0}
.card{padding:28px;border-radius:16px;background:#121a2e;text-align:center;max-width:440px}</style></head>
<body><div class="card">
<h1>Payment ${status === "success" ? "submitted" : "returned"}</h1>
<p>You can return to SkillForge. Status updates when PayFast confirms the payment.</p>
<p><a href="${deepLink}" style="color:#8da3ff">Open SkillForge</a></p>
<script>try{window.close()}catch(e){}</script>
</div></body></html>`);
});

module.exports = {
  createPayFastCheckout,
  payfastCheckoutPage,
  payfastIpn,
  payfastReturn,
};
