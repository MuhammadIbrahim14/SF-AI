export function validateRequest(body) {
  if (!body || typeof body !== 'object') throw new Error('Request body required');
  const request = {
    requestId: string(body.requestId, `gateway-${Date.now()}`),
    userId: string(body.userId, 'anonymous'),
    role: string(body.role, 'guest'),
    accountType: string(body.accountType, 'anonymous'),
    taskType: string(body.taskType, ''),
    userMessage: string(body.userMessage, ''),
    languageHint: string(body.languageHint, 'english_or_mixed'),
    constraints: Array.isArray(body.constraints) ? body.constraints.map(String) : [],
    safeAppContext: isObject(body.safeAppContext) ? body.safeAppContext : {},
    pageContext: isObject(body.pageContext) ? body.pageContext : {},
  };
  if (!request.taskType) throw new Error('taskType required');
  if (!request.userMessage) throw new Error('userMessage required');
  return request;
}

export function normalizeAiResponse({
  request,
  provider,
  source,
  rawText,
  parsedJson,
  fallbackTitle,
  fallbackMessage,
  usage,
  model,
  providerAttempts,
}) {
  const parsed = isObject(parsedJson) ? parsedJson : parseJsonObject(rawText);
  const hasUsableText = typeof rawText === 'string' && rawText.trim().length > 0;
  const base = isObject(parsed) ? parsed : {};

  return safeResponse(request, {
    status: string(base.status, hasUsableText ? 'success' : 'error'),
    title: string(base.title, fallbackTitle || 'SkillForge AI Draft'),
    message: string(base.message, hasUsableText ? cleanRawText(rawText) : fallbackMessage || ''),
    structuredData: isObject(base.structuredData)
      ? base.structuredData
      : extractStructuredData(base),
    suggestions: stringArray(base.suggestions),
    requiresManualReview: base.requiresManualReview !== false,
    proposedAction: isObject(base.proposedAction) ? base.proposedAction : null,
    blockedReason: nullableString(base.blockedReason),
    fallbackRecommended: false,
    retryAfterSeconds: numberOrNull(base.retryAfterSeconds),
    safetyNotes: stringArray(base.safetyNotes).length
      ? stringArray(base.safetyNotes)
      : [
          'Review before applying. AI can make mistakes.',
          'No data was changed by the gateway.',
        ],
    provider,
    source: source || provider,
    model: model || usage?.model || null,
    providerAttempts: Array.isArray(providerAttempts) ? providerAttempts : [],
    safeErrorCode: nullableString(base.safeErrorCode),
    usage: isObject(usage) ? usage : isObject(base.usage) ? base.usage : null,
  });
}

export function safeResponse(request, overrides = {}) {
  return {
    requestId: request.requestId,
    status: overrides.status || 'success',
    taskType: request.taskType,
    role: request.role,
    title: overrides.title || 'AI Response',
    message: overrides.message || '',
    structuredData: overrides.structuredData || {},
    suggestions: overrides.suggestions || [],
    requiresManualReview: overrides.requiresManualReview !== false,
    proposedAction: overrides.proposedAction || null,
    blockedReason: overrides.blockedReason || null,
    fallbackRecommended: false,
    retryAfterSeconds: numberOrNull(overrides.retryAfterSeconds),
    safetyNotes: overrides.safetyNotes || [
      'Review before applying. AI can make mistakes.',
      'No data was changed by the gateway.',
    ],
    provider: overrides.provider || null,
    source: overrides.source || overrides.provider || null,
    model: overrides.model || null,
    providerAttempts: Array.isArray(overrides.providerAttempts)
      ? overrides.providerAttempts
      : [],
    safeErrorCode: overrides.safeErrorCode || overrides.blockedReason || null,
    usage: overrides.usage || null,
  };
}

export function aiUnavailableResponse(request, overrides = {}) {
  return safeResponse(request, {
    status: 'error',
    title: overrides.title || 'AI is temporarily unavailable',
    message:
      overrides.message ||
      'SkillForge AI could not generate a response right now. Please retry in a moment.',
    structuredData: {},
    suggestions: overrides.suggestions || [
      'Check your internet connection.',
      'Retry the request.',
      'Try again with a shorter prompt.',
    ],
    requiresManualReview: false,
    proposedAction: null,
    blockedReason: overrides.blockedReason || 'aiUnavailable',
    safetyNotes: [],
    provider: null,
    model: null,
    source: overrides.source || 'aiUnavailable',
    providerAttempts: overrides.providerAttempts || [],
    safeErrorCode: overrides.safeErrorCode || 'aiUnavailable',
    usage: null,
  });
}

function string(value, fallback) {
  return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

function isObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value);
}

function nullableString(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function numberOrNull(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function stringArray(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => (typeof item === 'string' ? item.trim() : ''))
    .filter(Boolean)
    .slice(0, 12);
}

function extractStructuredData(base) {
  if (!isObject(base)) return {};
  const metaKeys = new Set([
    'status',
    'suggestions',
    'requiresManualReview',
    'proposedAction',
    'blockedReason',
    'fallbackRecommended',
    'retryAfterSeconds',
    'safetyNotes',
    'usage',
  ]);
  const structured = {};
  for (const [key, value] of Object.entries(base)) {
    if (!metaKeys.has(key)) structured[key] = value;
  }
  return Object.keys(structured).length ? structured : {};
}

function parseJsonObject(rawText) {
  if (typeof rawText !== 'string' || !rawText.trim()) return null;
  const trimmed = rawText.trim();
  try {
    return JSON.parse(trimmed);
  } catch {
    const match = trimmed.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try {
      return JSON.parse(match[0]);
    } catch {
      return null;
    }
  }
}

function cleanRawText(rawText) {
  return String(rawText || '')
    .replace(/```json/gi, '')
    .replace(/```/g, '')
    .trim()
    .slice(0, 6000);
}
