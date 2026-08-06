import { buildSystemPrompt } from '../prompts/systemPrompts.js';
import {
  aiUnavailableResponse,
  normalizeAiResponse,
  safeResponse,
} from '../schemas/responseSchema.js';

const OPENAI_RESPONSES_URL = 'https://api.openai.com/v1/responses';
const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';

const HEAVY_TASKS = new Set([
  'teacherCourseBlueprint',
  'teacherProjectAssignmentBuilder',
  'teacherGrandTestBuilder',
  'adminResolutionSummary',
  'adminEvidenceSummary',
  'companyCandidateRubric',
  'companyApplicationSummary',
]);

export const openaiProvider = {
  async generate(request, options = {}) {
    const apiKey = process.env.OPENAI_API_KEY;
    const defaultModel = modelName(process.env.OPENAI_MODEL, 'gpt-4o-mini');
    const premiumModel = modelName(process.env.OPENAI_PREMIUM_MODEL, defaultModel);
    const fallbackModel = modelName(process.env.OPENAI_FALLBACK_MODEL, 'gpt-4o-mini');
    const usePremium = HEAVY_TASKS.has(String(request.taskType || ''));
    const timeoutMs = Number(options.timeoutMs || process.env.REQUEST_TIMEOUT_MS || 120000);

    if (!apiKey) {
      return safeResponse(request, {
        status: 'unavailable',
        title: 'OpenAI Not Configured',
        message: 'OpenAI is not configured in the gateway environment.',
        blockedReason: 'Missing OPENAI_API_KEY.',
        provider: 'openai',
        source: 'providerError',
        safeErrorCode: 'providerAuthError',
      });
    }

    const models = modelQueue({
      usePremium,
      premiumModel,
      defaultModel,
      fallbackModel,
    });
    let lastResult = null;

    for (const model of models) {
      let result = await callOpenAIResponses({
        apiKey,
        model,
        request,
        timeoutMs,
        jsonMode: true,
      });

      if (!result.ok && isJsonModeFailure(result)) {
        await logOpenAiDebug(result, `JSON mode failed, retrying ${model} without JSON mode`);
        result = await callOpenAIResponses({
          apiKey,
          model,
          request,
          timeoutMs,
          jsonMode: false,
        });
      }

      // Transient Responses API failures: short retry, then Chat Completions.
      if (!result.ok && isTransientOpenAiFailure(result)) {
        await sleep(700);
        await logOpenAiDebug(result, `transient failure, retrying Responses ${model}`);
        result = await callOpenAIResponses({
          apiKey,
          model,
          request,
          timeoutMs,
          jsonMode: true,
        });
      }

      if (!result.ok && isTransientOpenAiFailure(result)) {
        await logOpenAiDebug(result, `Responses failed, falling back to Chat Completions ${model}`);
        result = await callOpenAIChatCompletions({
          apiKey,
          model,
          request,
          timeoutMs,
          jsonMode: true,
        });
        if (!result.ok && isJsonModeFailure(result)) {
          result = await callOpenAIChatCompletions({
            apiKey,
            model,
            request,
            timeoutMs,
            jsonMode: false,
          });
        }
      }

      if (result.ok) {
        return responseForSuccess({ result, request, model });
      }

      lastResult = result;
      await logOpenAiDebug(result, 'non-200 response');
      if (result.status === 408) {
        logOpenAiTimeout({ model, timeoutMs });
      }

      if (shouldTryNextModel(result)) {
        continue;
      }

      return responseForFailure({ result, request });
    }

    return responseForFailure({ result: lastResult, request });
  },
};

async function callOpenAIResponses({ apiKey, model, request, timeoutMs, jsonMode }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const body = {
    model,
    instructions: jsonInstructions(request),
    input: userPayload(request),
  };

  if (jsonMode) {
    body.text = { format: { type: 'json_object' } };
  }

  try {
    const response = await fetch(OPENAI_RESPONSES_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      signal: controller.signal,
      body: JSON.stringify(body),
    });
    const parsed = await safeJson(response);
    return {
      ok: response.ok,
      status: response.status,
      json: parsed.json,
      errorBody: parsed.text,
      model,
      jsonMode,
      api: 'responses',
      retryAfterSeconds: retryAfterSeconds(response),
    };
  } catch (error) {
    return {
      ok: false,
      status: error?.name === 'AbortError' ? 408 : 0,
      errorBody: error?.name === 'AbortError' ? 'timeout' : 'network',
      model,
      jsonMode,
      api: 'responses',
      retryAfterSeconds: null,
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function callOpenAIChatCompletions({
  apiKey,
  model,
  request,
  timeoutMs,
  jsonMode,
}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const body = {
    model,
    messages: [
      { role: 'system', content: jsonInstructions(request) },
      { role: 'user', content: userPayload(request) },
    ],
    temperature: 0.4,
  };
  if (jsonMode) {
    body.response_format = { type: 'json_object' };
  }

  try {
    const response = await fetch(OPENAI_CHAT_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      signal: controller.signal,
      body: JSON.stringify(body),
    });
    const parsed = await safeJson(response);
    return {
      ok: response.ok,
      status: response.status,
      json: parsed.json,
      errorBody: parsed.text,
      model,
      jsonMode,
      api: 'chat.completions',
      retryAfterSeconds: retryAfterSeconds(response),
    };
  } catch (error) {
    return {
      ok: false,
      status: error?.name === 'AbortError' ? 408 : 0,
      errorBody: error?.name === 'AbortError' ? 'timeout' : 'network',
      model,
      jsonMode,
      api: 'chat.completions',
      retryAfterSeconds: null,
    };
  } finally {
    clearTimeout(timeout);
  }
}

function responseForSuccess({ result, request, model }) {
  const rawText = extractResponseText(result.json);
  const parsedJson = parseJsonObject(rawText);
  if (request.taskType === 'teacherCourseBlueprint' && !parsedJson) {
    return safeResponse(request, {
      status: 'unavailable',
      title: 'OpenAI JSON Parse Failed',
      message:
        'OpenAI returned non-JSON course content. Please retry the AI request.',
      blockedReason: 'OpenAI response was not valid JSON.',
      provider: 'openai',
      source: 'validationFailed',
      safeErrorCode: 'parserFailed',
      usage: usageFrom(result.json, model),
    });
  }
  return normalizeAiResponse({
    request,
    provider: 'openai',
    source: model === modelName(process.env.OPENAI_FALLBACK_MODEL, '') ? 'openaiBackup' : 'openai',
    rawText,
    parsedJson,
    fallbackTitle: 'OpenAI AI Draft',
    fallbackMessage: 'OpenAI returned an empty response.',
    usage: usageFrom(result.json, model),
    model,
  });
}

function responseForFailure({ result, request }) {
  if (!result) {
    return aiUnavailableResponse(request, {
      status: 'unavailable',
      title: 'OpenAI Unavailable',
      message: 'OpenAI did not return a usable response from the gateway.',
      blockedReason: 'OpenAI provider request failed.',
      source: 'providerError',
      safeErrorCode: 'providerError',
    });
  }

  if (result.status === 429) {
    return safeResponse(request, {
      status: 'rateLimited',
      title: 'OpenAI Rate Limited',
      message: 'OpenAI is temporarily rate-limited. Please retry in a moment.',
      blockedReason: 'OpenAI rate limit reached.',
      retryAfterSeconds: result.retryAfterSeconds,
      provider: 'openai',
      source: 'providerError',
      safeErrorCode: 'providerRateLimited',
    });
  }

  if (result.status === 401 || result.status === 403) {
    return safeResponse(request, {
      status: 'unavailable',
      title: 'OpenAI Authentication Issue',
      message:
        'OpenAI authentication, project access, or billing is not available in the gateway environment.',
      blockedReason: 'OpenAI authentication failed.',
      provider: 'openai',
      source: 'providerError',
      safeErrorCode: 'providerAuthError',
    });
  }

  if (isModelFailure(result.status, result.errorBody)) {
    return safeResponse(request, {
      status: 'unavailable',
      title: 'OpenAI Model Unavailable',
      message:
        'The configured OpenAI models are unavailable. Check OPENAI_MODEL, OPENAI_PREMIUM_MODEL, and OPENAI_FALLBACK_MODEL.',
      blockedReason: 'OpenAI model unavailable.',
      provider: 'openai',
      source: 'providerError',
      safeErrorCode: 'providerModelUnavailable',
    });
  }

  if (result.status === 500 || result.status === 503 || result.status === 408 || result.status === 0) {
    const timedOut = result.status === 408;
    return safeResponse(request, {
      status: 'unavailable',
      title: timedOut ? 'OpenAI Timed Out' : 'OpenAI Temporarily Unavailable',
      message: timedOut
        ? 'OpenAI took too long to respond. Please retry in a moment.'
        : 'OpenAI is temporarily unavailable from the gateway.',
      blockedReason: timedOut ? 'OpenAI provider timed out.' : 'OpenAI provider request failed.',
      provider: 'openai',
      source: 'providerError',
      safeErrorCode: timedOut ? 'providerTimeout' : 'providerError',
    });
  }

  return safeResponse(request, {
    status: 'unavailable',
    title: 'OpenAI Request Rejected',
    message:
      'OpenAI rejected the request. SkillForge AI could not generate a response right now.',
    blockedReason: 'OpenAI provider request failed.',
    provider: 'openai',
    source: 'providerError',
    safeErrorCode: 'providerError',
  });
}

function jsonInstructions(request) {
  return `${buildSystemPrompt(request)}

JSON CONTRACT:
You must return valid JSON only. Do not use markdown.
The response must be a JSON object.
For taskType=${request.taskType}, keep every field machine-readable JSON.`;
}

function extractResponseText(json) {
  if (typeof json?.output_text === 'string' && json.output_text.trim()) {
    return json.output_text.trim();
  }

  const chunks = [];
  if (Array.isArray(json?.output)) {
    for (const item of json.output) {
      if (!Array.isArray(item?.content)) continue;
      for (const content of item.content) {
        if (typeof content?.text === 'string' && content.text.trim()) {
          chunks.push(content.text.trim());
        } else if (
          content?.type === 'output_text' &&
          typeof content?.text === 'string' &&
          content.text.trim()
        ) {
          chunks.push(content.text.trim());
        }
      }
    }
  }

  const chatContent = json?.choices?.[0]?.message?.content;
  if (!chunks.length && typeof chatContent === 'string' && chatContent.trim()) {
    chunks.push(chatContent.trim());
  }

  if (!chunks.length && json && typeof json === 'object') {
    return JSON.stringify(json);
  }

  return stripMarkdownFences(chunks.join('\n').trim());
}

function userPayload(request) {
  return `Return JSON only for this request. Do not use markdown.
The following payload is JSON input for the gateway task:
${JSON.stringify({
    requestId: request.requestId,
    role: request.role,
    accountType: request.accountType,
    taskType: request.taskType,
    userMessage: request.userMessage,
    languageHint: request.languageHint,
    constraints: request.constraints,
    safeAppContext: request.safeAppContext,
    pageContext: request.pageContext,
  })}`;
}

async function safeJson(response) {
  const text = await response.text();
  try {
    return { json: text ? JSON.parse(text) : null, text };
  } catch {
    return { json: null, text };
  }
}

function usageFrom(json, model) {
  const usage = json?.usage;
  return {
    model,
    promptTokens: usage?.input_tokens ?? usage?.prompt_tokens ?? null,
    completionTokens: usage?.output_tokens ?? usage?.completion_tokens ?? null,
    totalTokens: usage?.total_tokens ?? null,
  };
}

function modelQueue({ usePremium, premiumModel, defaultModel, fallbackModel }) {
  const queue = [];
  if (usePremium) queue.push(premiumModel);
  queue.push(defaultModel);
  queue.push(fallbackModel);
  return [...new Set(queue.map((model) => modelName(model, '')).filter(Boolean))];
}

function modelName(value, fallback) {
  const clean = String(value || '').trim();
  return clean || fallback;
}

function isModelFailure(status, body = '') {
  const text = String(body || '').toLowerCase();
  return (
    status === 404 ||
    text.includes('model_not_found') ||
    text.includes('does not exist') ||
    text.includes('invalid model') ||
    text.includes('unsupported model') ||
    text.includes('model is not supported') ||
    text.includes('model_not_supported')
  );
}

function shouldTryNextModel(result) {
  return (
    isModelFailure(result.status, result.errorBody) ||
    result.status === 408 ||
    result.status === 0 ||
    result.status === 500 ||
    result.status === 503
  );
}

function isTransientOpenAiFailure(result) {
  return (
    result?.status === 500 ||
    result?.status === 502 ||
    result?.status === 503 ||
    result?.status === 0
  );
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isJsonModeFailure(result) {
  const text = String(result?.errorBody || '').toLowerCase();
  return (
    result?.status === 400 &&
    (text.includes('unsupported_parameter') ||
      text.includes('invalid_response_format') ||
      text.includes('json_object') ||
      text.includes('text.format') ||
      text.includes('response_format'))
  );
}

function parseJsonObject(rawText) {
  if (typeof rawText !== 'string' || !rawText.trim()) return null;
  const trimmed = stripMarkdownFences(rawText);
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

function stripMarkdownFences(value) {
  return String(value || '')
    .replace(/```json/gi, '')
    .replace(/```/g, '')
    .trim();
}

function retryAfterSeconds(response) {
  const value = response.headers.get('retry-after');
  if (!value) return null;
  const numeric = Number(value);
  if (Number.isFinite(numeric)) return numeric;
  const date = Date.parse(value);
  if (!Number.isNaN(date)) {
    return Math.max(0, Math.ceil((date - Date.now()) / 1000));
  }
  return null;
}

async function logOpenAiDebug(result, context) {
  const debugOn =
    String(process.env.DEBUG_OPENAI_ERRORS || 'false').toLowerCase() === 'true';
  const alwaysLogTransient = isTransientOpenAiFailure(result);
  if (!debugOn && !alwaysLogTransient) {
    return;
  }
  const body = String(result?.errorBody || '').replace(/sk-[A-Za-z0-9_-]+/g, 'sk-***');
  console.warn(
    `[SkillForge AI Gateway] OpenAI ${context}: status=${result?.status} api=${result?.api || 'responses'} model=${result?.model} jsonMode=${result?.jsonMode} body=${body.slice(
      0,
      1000,
    )}`,
  );
}

function logOpenAiTimeout({ model, timeoutMs }) {
  console.warn(`[OpenAI] timeout model=${model} timeoutMs=${timeoutMs}`);
}
