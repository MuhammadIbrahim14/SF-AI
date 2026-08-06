/**
 * PayFast Pakistan configuration from environment / Firebase params.
 * Plug merchant credentials later via:
 *   firebase functions:config:set payfast.merchant_id="..." payfast.secured_key="..."
 * or process.env when using .env with a loader.
 */

function env(name, fallback = "") {
  const value = process.env[name];
  if (value != null && String(value).trim() !== "") {
    return String(value).trim();
  }
  return fallback;
}

function isConfigured() {
  return Boolean(getMerchantId() && getSecuredKey());
}

function getMerchantId() {
  return env("PAYFAST_MERCHANT_ID");
}

function getSecuredKey() {
  return env("PAYFAST_SECURED_KEY");
}

function getMerchantName() {
  return env("PAYFAST_MERCHANT_NAME", "SkillForge AI");
}

function getCurrency() {
  return env("PAYFAST_CURRENCY", "PKR");
}

function isSandbox() {
  const raw = env("PAYFAST_SANDBOX", "true").toLowerCase();
  return raw === "1" || raw === "true" || raw === "yes";
}

function getTokenUrl() {
  return (
    env("PAYFAST_TOKEN_URL") ||
    (isSandbox()
      ? "https://ipguat.apps.net.pk/Ecommerce/api/Transaction/GetAccessToken"
      : "https://ipg1.apps.net.pk/Ecommerce/api/Transaction/GetAccessToken")
  );
}

function getPostTransactionUrl() {
  return (
    env("PAYFAST_CHECKOUT_URL") ||
    (isSandbox()
      ? "https://ipguat.apps.net.pk/Ecommerce/api/Transaction/PostTransaction"
      : "https://ipg1.apps.net.pk/Ecommerce/api/Transaction/PostTransaction")
  );
}

/** Public base URL of deployed Functions (no trailing slash). */
function getFunctionsBaseUrl() {
  return env(
    "PAYFAST_FUNCTIONS_BASE_URL",
    "https://us-central1-YOUR_PROJECT.cloudfunctions.net",
  );
}

module.exports = {
  env,
  isConfigured,
  getMerchantId,
  getSecuredKey,
  getMerchantName,
  getCurrency,
  isSandbox,
  getTokenUrl,
  getPostTransactionUrl,
  getFunctionsBaseUrl,
};
