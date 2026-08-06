/**
 * Always verifies Firebase ID token for payment endpoints.
 * Project ID may come from env or from the token audience (aud).
 */
export async function requireFirebaseUser(req) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) {
    return { allowed: false, reason: 'Authorization token required.' };
  }

  let projectId = String(process.env.FIREBASE_PROJECT_ID || '').trim();
  if (!projectId) {
    try {
      const payload = decodeJwtPayload(token);
      const aud = payload?.aud;
      if (typeof aud === 'string' && aud.trim()) {
        projectId = aud.trim();
      }
    } catch {
      // fall through
    }
  }

  if (!projectId) {
    return {
      allowed: false,
      reason:
        'FIREBASE_PROJECT_ID is required for checkout. Set it in skillforge_ai_gateway/.env (e.g. skillforge-ai-4f2da).',
    };
  }

  // Keep env in sync for Firestore admin when only token aud was available.
  if (!process.env.FIREBASE_PROJECT_ID) {
    process.env.FIREBASE_PROJECT_ID = projectId;
  }

  try {
    const { verifyFirebaseIdToken } = await import('../security/firebaseTokenVerifier.js');
    const payload = await verifyFirebaseIdToken(token, projectId);
    return {
      allowed: true,
      userId: payload.sub || payload.user_id || null,
      email: payload.email || null,
    };
  } catch {
    return { allowed: false, reason: 'Invalid or expired authorization token.' };
  }
}

function decodeJwtPayload(token) {
  const parts = String(token || '').split('.');
  if (parts.length < 2) return null;
  const padded = parts[1].replace(/-/g, '+').replace(/_/g, '/').padEnd(
    Math.ceil(parts[1].length / 4) * 4,
    '=',
  );
  return JSON.parse(Buffer.from(padded, 'base64').toString('utf8'));
}
