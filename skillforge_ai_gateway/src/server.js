import http from 'node:http';
import path from 'node:path';
import { URL } from 'node:url';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

import { authorizeTask, verifyFirebaseTokenIfRequired, bindRoleFromAuth } from './security/auth.js';
import { mockProvider } from './providers/mockProvider.js';
import { geminiProvider } from './providers/geminiProvider.js';
import { openaiProvider } from './providers/openaiProvider.js';
import {
  aiUnavailableResponse,
  validateRequest,
  safeResponse,
} from './schemas/responseSchema.js';
import {
  isConfigured as payfastConfigured,
  isEnabled as payfastEnabled,
  isAvailable as payfastAvailable,
} from './payfast/config.js';
import {
  isEnabled as demoGatewayEnabled,
  isAvailable as demoGatewayAvailable,
} from './demo/config.js';
import {
  assertTestOnlyKeys as stripeAssertTestOnlyKeys,
  connectEnabled as stripeConnectEnabled,
  getCurrency as stripeCurrency,
  hasWebhookSecret as stripeWebhookConfigured,
  isAvailable as stripeAvailable,
  isConfigured as stripeConfigured,
  isEnabled as stripeEnabled,
} from './stripe/config.js';

// Payment handlers are loaded lazily so Demo/PayFast/Stripe never block /api/copilot.

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const envPath = loadEnv();

// Sandbox-only guard: refuse to boot when live Stripe keys are configured.
try {
  stripeAssertTestOnlyKeys();
} catch (error) {
  console.error(`[SkillForge AI Gateway] ${error.message}`);
  console.error(
    '[SkillForge AI Gateway] Stripe is test/sandbox only in this project. Remove live keys from .env and restart.',
  );
  process.exit(1);
}

const port = Number(process.env.PORT || 3001);
const host = process.env.HOST || '0.0.0.0';
const providerName = (process.env.AI_PROVIDER || 'openai').trim().toLowerCase();
const requestTimeoutMs = Number(process.env.REQUEST_TIMEOUT_MS || 120000);
const maxPromptChars = Number(process.env.MAX_PROMPT_CHARS || 8000);
const providerFailoverEnabled =
  String(process.env.ENABLE_PROVIDER_FAILOVER || 'true').toLowerCase() !== 'false';
const templateFallbackEnabled =
  String(process.env.ENABLE_TEMPLATE_FALLBACK || 'false').toLowerCase() === 'true';

const providers = {
  mock: mockProvider,
  gemini: geminiProvider,
  openai: openaiProvider,
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  setCors(req, res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    json(res, 200, {
      ok: true,
      provider: activeProviderName(),
      port,
      openaiModel: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      openaiPremiumModel: process.env.OPENAI_PREMIUM_MODEL || 'gpt-4o-mini',
      openaiFallbackModel: process.env.OPENAI_FALLBACK_MODEL || 'gpt-4o-mini',
      hasOpenAiKey: Boolean(process.env.OPENAI_API_KEY),
      hasOpenAIKey: Boolean(process.env.OPENAI_API_KEY),
      geminiModel: process.env.GEMINI_MODEL || 'gemini-2.0-flash',
      hasGeminiKey: Boolean(process.env.GEMINI_API_KEY),
      payfastEnabled: payfastEnabled(),
      payfastConfigured: payfastConfigured(),
      payfastAvailable: payfastAvailable(),
      demoGatewayEnabled: demoGatewayEnabled(),
      demoGatewayAvailable: demoGatewayAvailable(),
      stripeEnabled: stripeEnabled(),
      stripeConfigured: stripeConfigured(),
      stripeAvailable: stripeAvailable(),
      stripeMode: 'test',
      stripeCurrency: stripeCurrency(),
      stripeConnectEnabled: stripeConnectEnabled(),
      stripeWebhookConfigured: stripeWebhookConfigured(),
      firebaseProjectId: Boolean(process.env.FIREBASE_PROJECT_ID),
      devAllowLocalhost: devAllowLocalhost(),
      allowedOriginsCount: allowedOrigins().length,
      envLoaded: Boolean(envPath),
      requestTimeoutMs,
      mode: String(process.env.REQUIRE_AUTH ?? 'true').toLowerCase() !== 'false'
        ? 'auth-required'
        : 'local-dev',
    });
    return;
  }

  if (await routeStripe(req, res, url)) {
    return;
  }

  if (await routeDemoGateway(req, res, url)) {
    return;
  }

  if (await routePayFast(req, res, url)) {
    return;
  }

  if (req.method !== 'POST' || url.pathname !== '/api/copilot') {
    json(res, 404, { status: 'error', message: 'Not found' });
    return;
  }

  try {
    const authCheck = await verifyFirebaseTokenIfRequired(req);
    if (!authCheck.allowed) {
      json(res, 401, {
        status: 'blocked',
        title: 'Authentication Required',
        message: authCheck.reason,
        blockedReason: authCheck.reason,
        requiresManualReview: true,
        provider: providerName,
      });
      return;
    }

    const body = await readJson(req);
    const request = validateRequest(body);
    if (request.userMessage.length > maxPromptChars) {
      request.userMessage = request.userMessage.slice(0, maxPromptChars);
    }

    // When auth is required, role comes from token/Firestore — not the request body.
    const bound = await bindRoleFromAuth(authCheck, request);
    request.role = bound.role;
    request.accountType = bound.accountType;
    if (authCheck.userId) {
      request.userId = authCheck.userId;
    }

    const auth = authorizeTask(request, bound.capabilities);
    if (!auth.allowed) {
      json(res, 403, {
        ...safeResponse(request, {
          status: 'blocked',
          title: 'AI Task Blocked',
          message: auth.reason,
          blockedReason: auth.reason,
        }),
        boundRole: bound.role,
        boundAccountType: bound.accountType,
        roleSource: bound.source,
      });
      return;
    }

    const response = await generateWithFailover(request);
    json(res, 200, response);
  } catch (error) {
    json(res, 400, {
      status: 'error',
      title: 'Gateway Error',
      message: error instanceof Error ? error.message : 'Invalid request',
      requiresManualReview: true,
      provider: providerName,
    });
  }
});

server.listen(port, host, () => {
  console.log(`SkillForge AI Gateway listening on http://${host}:${port}`);
  startupSummary().forEach((line) => console.log(line));
});

async function routeStripe(req, res, url) {
  const pathname = url.pathname;
  if (!pathname.startsWith('/api/stripe/')) {
    return false;
  }

  // Webhook first: no Firebase auth, signature-verified raw body.
  if (req.method === 'POST' && pathname === '/api/stripe/webhook') {
    try {
      const { handleStripeWebhook } = await import('./stripe/webhook.js');
      await handleStripeWebhook(req, res);
    } catch (err) {
      console.error('[stripe/webhook]', err);
      res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('webhook error');
    }
    return true;
  }

  const handlers = await import('./stripe/handlers.js');

  if (req.method === 'GET' && pathname === '/api/stripe/config') {
    handlers.handleStripeConfig(res);
    return true;
  }

  if (req.method === 'GET' && pathname === '/api/stripe/return') {
    handlers.handleStripeReturn(res, url);
    return true;
  }

  if (req.method === 'GET' && pathname === '/api/stripe/connect/return') {
    handlers.handleConnectReturn(res, url);
    return true;
  }

  const authenticated =
    (req.method === 'POST' && pathname === '/api/stripe/checkout') ||
    (req.method === 'POST' && pathname === '/api/stripe/connect/onboard') ||
    ((req.method === 'GET' || req.method === 'POST') &&
      pathname === '/api/stripe/connect/status');
  if (!authenticated) {
    json(res, 404, { status: 'error', message: 'Not found' });
    return true;
  }

  const { requireFirebaseUser } = await import('./payfast/auth.js');
  const auth = await requireFirebaseUser(req);
  if (!auth.allowed) {
    json(res, 401, {
      status: 'error',
      code: 'unauthenticated',
      message: auth.reason,
    });
    return true;
  }

  const context = { userId: auth.userId, email: auth.email };
  try {
    if (pathname === '/api/stripe/checkout') {
      await handlers.handleStripeCheckout(req, res, context);
    } else if (pathname === '/api/stripe/connect/onboard') {
      await handlers.handleConnectOnboard(req, res, context);
    } else {
      await handlers.handleConnectStatus(req, res, context, url);
    }
  } catch (err) {
    console.error(`[stripe] ${pathname}`, err);
    json(res, Number(err?.statusCode) || 503, {
      status: 'error',
      code: err?.code || 'stripe-request-failed',
      message:
        err?.message ||
        'Stripe request failed. Check STRIPE_SECRET_KEY and FIREBASE_SERVICE_ACCOUNT_PATH, then restart the gateway.',
    });
  }
  return true;
}

async function routeDemoGateway(req, res, url) {
  const path = url.pathname;
  if (
    !(req.method === 'POST' &&
      (path === '/api/demo/checkout' ||
        path === '/api/demo/confirm' ||
        path === '/api/demo/subscription/cancel' ||
        path === '/api/demo/subscription/finalize-expiry'))
  ) {
    return false;
  }

  const [{ requireFirebaseUser }, demoHandlers] = await Promise.all([
    import('./payfast/auth.js'),
    import('./demo/handlers.js'),
  ]);

  const auth = await requireFirebaseUser(req);
  if (!auth.allowed) {
    json(res, 401, {
      status: 'error',
      code: 'unauthenticated',
      message: auth.reason,
    });
    return true;
  }

  if (path === '/api/demo/checkout') {
    try {
      await demoHandlers.handleDemoCheckout(req, res, {
        userId: auth.userId,
        email: auth.email,
      });
    } catch (err) {
      console.error('[demo/checkout]', err);
      json(res, 503, {
        status: 'error',
        code: err?.code || 'demo-checkout-failed',
        message:
          err?.message ||
          'Demo checkout failed. Check FIREBASE_SERVICE_ACCOUNT_PATH and restart the gateway.',
      });
    }
    return true;
  }

  if (path === '/api/demo/confirm') {
    try {
      await demoHandlers.handleDemoConfirm(req, res, {
        userId: auth.userId,
        email: auth.email,
      });
    } catch (err) {
      console.error('[demo/confirm]', err);
      json(res, 503, {
        status: 'error',
        code: err?.code || 'demo-confirm-failed',
        message:
          err?.message ||
          'Demo confirm failed. Check Firebase Admin config and try again.',
      });
    }
    return true;
  }

  if (path === '/api/demo/subscription/cancel') {
    try {
      await demoHandlers.handleSubscriptionCancel(req, res, {
        userId: auth.userId,
        email: auth.email,
      });
    } catch (err) {
      console.error('[demo/subscription/cancel]', err);
      json(res, 503, {
        status: 'error',
        code: err?.code || 'demo-cancel-failed',
        message: err?.message || 'Subscription cancel failed.',
      });
    }
    return true;
  }

  try {
    await demoHandlers.handleSubscriptionFinalizeExpiry(req, res, {
      userId: auth.userId,
      email: auth.email,
    });
  } catch (err) {
    console.error('[demo/subscription/finalize-expiry]', err);
    json(res, 503, {
      status: 'error',
      code: err?.code || 'demo-expiry-failed',
      message: err?.message || 'Subscription expiry finalize failed.',
    });
  }
  return true;
}

async function routePayFast(req, res, url) {
  const path = url.pathname;
  const isPayFastRoute =
    (req.method === 'POST' &&
      (path === '/api/payfast/checkout' || path === '/api/payfast/ipn')) ||
    (req.method === 'GET' &&
      (path === '/api/payfast/checkout-page' || path === '/api/payfast/return'));
  if (!isPayFastRoute) {
    return false;
  }

  const [{ requireFirebaseUser }, payfastHandlers] = await Promise.all([
    import('./payfast/auth.js'),
    import('./payfast/handlers.js'),
  ]);

  if (req.method === 'POST' && path === '/api/payfast/checkout') {
    const auth = await requireFirebaseUser(req);
    if (!auth.allowed) {
      json(res, 401, {
        status: 'error',
        code: 'unauthenticated',
        message: auth.reason,
      });
      return true;
    }
    await payfastHandlers.handleCreateCheckout(req, res, {
      userId: auth.userId,
      email: auth.email,
    });
    return true;
  }

  if (req.method === 'GET' && path === '/api/payfast/checkout-page') {
    await payfastHandlers.handleCheckoutPage(req, res, url);
    return true;
  }

  if (req.method === 'POST' && path === '/api/payfast/ipn') {
    await payfastHandlers.handleIpn(req, res, url);
    return true;
  }

  if (req.method === 'GET' && path === '/api/payfast/return') {
    await payfastHandlers.handleReturn(req, res, url);
    return true;
  }

  return false;
}

function setCors(req, res) {
  const origins = allowedOrigins();
  const origin = req.headers.origin || '';
  const allowed = allowedOrigin(origin, origins);
  if (allowed) {
    res.setHeader('Access-Control-Allow-Origin', allowed);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
}

function json(res, statusCode, payload) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 64_000) {
        reject(new Error('Request too large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(new Error('Invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

function supportedProvider(value) {
  return Object.prototype.hasOwnProperty.call(providers, value);
}

function activeProviderName() {
  return supportedProvider(providerName) ? providerName : 'mock';
}

async function generateWithFailover(request) {
  const active = activeProviderName();
  if (active === 'mock') {
    if (templateFallbackEnabled) {
      return mockProvider.generate(request, { timeoutMs: requestTimeoutMs });
    }
    return aiUnavailableResponse(request, {
      providerAttempts: [
        {
          provider: 'mock',
          model: 'template-disabled',
          status: 'skipped',
          safeErrorCode: 'realProviderRequired',
        },
      ],
      safeErrorCode: 'realProviderRequired',
    });
  }

  const attempts = [];
  const chain = providerChain(active);
  for (const item of chain) {
    if (!item.enabled) {
      attempts.push({
        provider: item.provider,
        model: item.model,
        status: 'skipped',
        safeErrorCode: item.skipReason,
      });
      continue;
    }
    const provider = providers[item.provider];
    const response = await provider.generate(request, {
      timeoutMs: requestTimeoutMs,
    });
    attempts.push({
      provider: item.provider,
      model: response?.model || response?.usage?.model || item.model,
      status: response?.status || 'error',
      safeErrorCode: response?.safeErrorCode || response?.blockedReason || null,
    });
    if (response?.status === 'success') {
      return {
        ...response,
        providerAttempts: attempts,
        source: response.source || item.source,
      };
    }
    if (!providerFailoverEnabled) break;
  }

  return aiUnavailableResponse(request, {
    providerAttempts: attempts,
    safeErrorCode: attempts.at(-1)?.safeErrorCode || 'aiUnavailable',
  });
}

function providerChain(active) {
  const chain = [];
  if (active === 'openai') {
    chain.push({
      provider: 'openai',
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      source: 'openai',
      enabled: Boolean(process.env.OPENAI_API_KEY),
      skipReason: 'providerAuthError',
    });
    if (process.env.GEMINI_API_KEY) {
      chain.push({
        provider: 'gemini',
        model: process.env.GEMINI_MODEL || 'gemini-2.0-flash',
        source: 'gemini',
        enabled: true,
      });
    }
  } else if (active === 'gemini') {
    chain.push({
      provider: 'gemini',
      model: process.env.GEMINI_MODEL || 'gemini-2.0-flash',
      source: 'gemini',
      enabled: Boolean(process.env.GEMINI_API_KEY),
      skipReason: 'providerAuthError',
    });
    if (process.env.OPENAI_API_KEY) {
      chain.push({
        provider: 'openai',
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        source: 'openai',
        enabled: true,
      });
    }
  }
  return chain;
}

function startupSummary() {
  const provider = activeProviderName();
  const model =
    provider === 'gemini'
      ? process.env.GEMINI_MODEL || 'gemini-2.0-flash'
      : provider === 'openai'
      ? process.env.OPENAI_MODEL || 'gpt-4o-mini'
      : 'mock';
  const hasGeminiKey = Boolean(process.env.GEMINI_API_KEY);
  const hasOpenAiKey = Boolean(process.env.OPENAI_API_KEY);
  return [
    `[SkillForge AI Gateway] cwd=${process.cwd()}`,
    `[SkillForge AI Gateway] envLoaded=${Boolean(envPath)} envPath=${envPath || 'none'}`,
    `[SkillForge AI Gateway] provider=${provider}`,
    `[SkillForge AI Gateway] openaiModel=${process.env.OPENAI_MODEL || 'gpt-4o-mini'}`,
    `[SkillForge AI Gateway] openaiPremiumModel=${process.env.OPENAI_PREMIUM_MODEL || 'gpt-4o-mini'}`,
    `[SkillForge AI Gateway] openaiFallbackModel=${process.env.OPENAI_FALLBACK_MODEL || 'gpt-4o-mini'}`,
    `[SkillForge AI Gateway] geminiModel=${process.env.GEMINI_MODEL || 'gemini-2.0-flash'}`,
    `[SkillForge AI Gateway] model=${model}`,
    `[SkillForge AI Gateway] hasGeminiKey=${hasGeminiKey}`,
    `[SkillForge AI Gateway] hasOpenAIKey=${hasOpenAiKey}`,
    `[SkillForge AI Gateway] requestTimeoutMs=${requestTimeoutMs}`,
    `[SkillForge AI Gateway] port=${port}`,
    `[SkillForge AI Gateway] devAllowLocalhost=${devAllowLocalhost()}`,
    `[SkillForge AI Gateway] allowedOrigins=${allowedOrigins().join(',') || 'none'}`,
    `[SkillForge AI Gateway] demoGatewayEnabled=${demoGatewayEnabled()}`,
    `[SkillForge AI Gateway] demoGatewayAvailable=${demoGatewayAvailable()}`,
    `[SkillForge AI Gateway] stripeEnabled=${stripeEnabled()}`,
    `[SkillForge AI Gateway] stripeConfigured=${stripeConfigured()}`,
    `[SkillForge AI Gateway] stripeAvailable=${stripeAvailable()} mode=test currency=${stripeCurrency()}`,
    `[SkillForge AI Gateway] stripeWebhookConfigured=${stripeWebhookConfigured()}`,
    `[SkillForge AI Gateway] stripeConnectEnabled=${stripeConnectEnabled()}`,
    `[SkillForge AI Gateway] payfastEnabled=${payfastEnabled()}`,
    `[SkillForge AI Gateway] payfastConfigured=${payfastConfigured()}`,
    `[SkillForge AI Gateway] payfastAvailable=${payfastAvailable()}`,
    `[SkillForge AI Gateway] firebaseProjectId=${process.env.FIREBASE_PROJECT_ID || 'unset'}`,
    `[SkillForge AI Gateway] requireAuth=${String(process.env.REQUIRE_AUTH ?? 'true').toLowerCase() !== 'false'}`,
  ];
}

function loadEnv() {
  const candidates = [
    path.resolve(process.cwd(), '.env'),
    path.resolve(__dirname, '../.env'),
  ];
  for (const candidate of candidates) {
    const result = dotenv.config({ path: candidate, quiet: true });
    if (!result.error) return candidate;
  }
  return null;
}

function allowedOrigin(origin, origins) {
  if (!origin) return null;
  if (origins.includes('*') || origins.includes(origin)) return origin;
  if (
    devAllowLocalhost() &&
    /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i.test(origin)
  ) {
    return origin;
  }
  return null;
}

function devAllowLocalhost() {
  return String(process.env.DEV_ALLOW_LOCALHOST || 'false').toLowerCase() === 'true';
}

function allowedOrigins() {
  return (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}
