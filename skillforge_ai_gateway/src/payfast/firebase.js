import admin from 'firebase-admin';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

let initialized = false;

/**
 * Initializes firebase-admin once.
 * Supports:
 * - GOOGLE_APPLICATION_CREDENTIALS (path to service account JSON)
 * - FIREBASE_SERVICE_ACCOUNT_PATH
 * - FIREBASE_SERVICE_ACCOUNT_JSON (raw JSON string)
 * - Application Default Credentials when none of the above are set
 */
export function getFirestore() {
  ensureFirebaseApp();
  return admin.firestore();
}

export function ensureFirebaseApp() {
  if (initialized || admin.apps.length) {
    initialized = true;
    return admin.app();
  }

  const projectId = process.env.FIREBASE_PROJECT_ID || undefined;
  const jsonInline = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const pathEnv =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS;

  try {
    if (jsonInline && jsonInline.trim()) {
      const credentials = JSON.parse(jsonInline);
      admin.initializeApp({
        credential: admin.credential.cert(credentials),
        projectId: projectId || credentials.project_id,
      });
    } else if (pathEnv && pathEnv.trim()) {
      const resolved = path.resolve(pathEnv.trim());
      if (!existsSync(resolved)) {
        throw new Error(
          `Firebase service account file not found at "${resolved}". ` +
            `Set FIREBASE_SERVICE_ACCOUNT_PATH to your Admin SDK JSON ` +
            `(e.g. ./skillforge-ai-*-firebase-adminsdk-*.json).`,
        );
      }
      const credentials = JSON.parse(readFileSync(resolved, 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(credentials),
        projectId: projectId || credentials.project_id,
      });
    } else {
      admin.initializeApp({
        ...(projectId ? { projectId } : {}),
      });
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const wrapped = new Error(
      `Firebase Admin init failed: ${message}. Demo payments and enrollment require a valid service account.`,
    );
    wrapped.code = 'firebase-admin-init';
    throw wrapped;
  }

  initialized = true;
  return admin.app();
}
