import { buildSystemPrompt } from '../prompts/systemPrompts.js';
import { normalizeAiResponse, safeResponse } from '../schemas/responseSchema.js';

export const geminiProvider = {
  async generate(request, options = {}) {
    const apiKey = process.env.GEMINI_API_KEY;
    const model = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
    if (!apiKey) {
      return safeResponse(request, {
        status: 'unavailable',
        title: 'Gemini Not Configured',
        message: 'Set GEMINI_API_KEY in the gateway environment.',
        blockedReason: 'Missing GEMINI_API_KEY.',
        provider: 'gemini',
      });
    }

    try {
      let response = await callGemini({
        apiKey,
        model,
        request,
        timeoutMs: options.timeoutMs || 30000,
        useResponseMimeType: true,
      });
      if (response.status === 400) {
        await logGeminiDebug(response, 'retrying without responseMimeType');
        response = await callGemini({
          apiKey,
          model,
          request,
          timeoutMs: options.timeoutMs || 30000,
          useResponseMimeType: false,
        });
      }

      if (!response.ok) {
        await logGeminiDebug(response, 'non-200 response');
        if (response.status === 429) {
          return safeResponse(request, {
            status: 'rateLimited',
            title: 'Gemini quota is busy',
            message: 'Gemini is temporarily rate-limited. Please retry in a moment.',
            structuredData: {},
            suggestions: [
              'Try Gemini again after a short wait.',
              'Try again with a shorter prompt.',
            ],
            retryAfterSeconds: retryAfterSeconds(response),
            blockedReason: 'Gemini rate limit reached.',
            provider: 'gemini',
            source: 'providerError',
            safeErrorCode: 'providerRateLimited',
          });
        }
        return safeResponse(request, {
          status: 'unavailable',
          title: 'Gemini Unavailable',
          message: `Gemini returned HTTP ${response.status}. Check gateway provider configuration.`,
          blockedReason: 'Gemini provider request failed.',
          provider: 'gemini',
          source: 'providerError',
          safeErrorCode: response.status === 408 ? 'providerTimeout' : 'providerError',
        });
      }

      const json = await response.json();
      const rawText =
        json?.candidates?.[0]?.content?.parts
          ?.map((part) => part?.text || '')
          .join('\n')
          .trim() || '';

      return normalizeAiResponse({
        request,
        provider: 'gemini',
        source: 'gemini',
        rawText,
        fallbackTitle: 'Gemini AI Draft',
        fallbackMessage: 'Gemini returned an empty response.',
        usage: usageFrom(json, model),
        model,
      });
    } catch (error) {
      return safeResponse(request, {
        status: 'unavailable',
        title: 'Gemini Unavailable',
        message:
          error?.name === 'AbortError'
            ? 'Gemini request timed out.'
            : 'Gemini provider is temporarily unavailable.',
        blockedReason: 'Gemini gateway call failed.',
        provider: 'gemini',
        source: 'providerError',
        safeErrorCode:
          error?.name === 'AbortError' ? 'providerTimeout' : 'providerError',
      });
    }
  },
};

function userPayload(request) {
  return JSON.stringify({
    requestId: request.requestId,
    role: request.role,
    accountType: request.accountType,
    taskType: request.taskType,
    userMessage: request.userMessage,
    languageHint: request.languageHint,
    constraints: request.constraints,
    safeAppContext: request.safeAppContext,
    pageContext: request.pageContext,
  });
}

async function callGemini({ apiKey, model, request, timeoutMs, useResponseMimeType }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/${modelPath(
      model,
    )}:generateContent`;
    return await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      signal: controller.signal,
      body: JSON.stringify(geminiBody(request, useResponseMimeType)),
    });
  } finally {
    clearTimeout(timeout);
  }
}

function geminiBody(request, useResponseMimeType) {
  return {
    systemInstruction: {
      parts: [{ text: buildSystemPrompt(request) }],
    },
    contents: [
      {
        role: 'user',
        parts: [{ text: userPayload(request) }],
      },
    ],
    generationConfig: {
      temperature: 0.4,
      maxOutputTokens: 4096,
      ...(useResponseMimeType ? { responseMimeType: 'application/json' } : {}),
    },
  };
}

function modelPath(model) {
  const clean = String(model || 'gemini-2.0-flash').trim();
  return clean.startsWith('models/') ? clean : `models/${clean}`;
}

async function logGeminiDebug(response, context) {
  if (String(process.env.DEBUG_GEMINI_ERRORS || 'false').toLowerCase() !== 'true') {
    return;
  }
  try {
    const text = await response.clone().text();
    console.warn(
      `[SkillForge AI Gateway] Gemini ${context}: status=${response.status} body=${text.slice(
        0,
        1000,
      )}`,
    );
  } catch {
    console.warn(`[SkillForge AI Gateway] Gemini ${context}: status=${response.status}`);
  }
}

function usageFrom(json, model) {
  const usage = json?.usageMetadata;
  if (!usage) return { model };
  return {
    model,
    promptTokens: usage.promptTokenCount || null,
    completionTokens: usage.candidatesTokenCount || null,
    totalTokens: usage.totalTokenCount || null,
  };
}

function retryAfterSeconds(response) {
  const retryAfter = response.headers.get('retry-after');
  if (!retryAfter) return null;
  const seconds = Number(retryAfter);
  return Number.isFinite(seconds) ? seconds : null;
}
