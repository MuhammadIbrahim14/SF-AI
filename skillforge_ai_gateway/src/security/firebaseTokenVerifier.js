import crypto from 'node:crypto';

const certUrl =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

let cachedCerts = null;
let cacheExpiresAt = 0;

export async function verifyFirebaseIdToken(token, projectId) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Invalid token shape');

  const header = parseBase64Json(parts[0]);
  const payload = parseBase64Json(parts[1]);
  if (header.alg !== 'RS256' || !header.kid) throw new Error('Unsupported token');

  const now = Math.floor(Date.now() / 1000);
  if (payload.aud !== projectId) throw new Error('Invalid audience');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error('Invalid issuer');
  }
  if (!payload.sub || typeof payload.sub !== 'string') throw new Error('Invalid subject');
  if (Number(payload.exp || 0) <= now) throw new Error('Token expired');
  if (Number(payload.iat || 0) > now + 60) throw new Error('Invalid issued-at');

  const certs = await getCerts();
  const cert = certs[header.kid];
  if (!cert) throw new Error('Unknown key id');

  const verifier = crypto.createVerify('RSA-SHA256');
  verifier.update(`${parts[0]}.${parts[1]}`);
  verifier.end();
  const valid = verifier.verify(cert, fromBase64Url(parts[2]));
  if (!valid) throw new Error('Invalid signature');

  return payload;
}

async function getCerts() {
  if (cachedCerts && Date.now() < cacheExpiresAt) return cachedCerts;
  const response = await fetch(certUrl);
  if (!response.ok) throw new Error('Unable to fetch Firebase certs');
  cachedCerts = await response.json();
  cacheExpiresAt = Date.now() + 60 * 60 * 1000;
  return cachedCerts;
}

function parseBase64Json(value) {
  return JSON.parse(fromBase64Url(value).toString('utf8'));
}

function fromBase64Url(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/').padEnd(
    Math.ceil(value.length / 4) * 4,
    '=',
  );
  return Buffer.from(padded, 'base64');
}
