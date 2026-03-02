import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

let initialized = false;
let firebaseAvailable = false;

export function isFirebaseAvailable(): boolean {
  return firebaseAvailable;
}

export function initFirebase(): void {
  if (initialized) return;
  initialized = true;

  const serviceAccountPath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './firebase-service-account.json';
  const resolvedPath = path.resolve(serviceAccountPath);

  try {
    if (fs.existsSync(resolvedPath)) {
      const raw = fs.readFileSync(resolvedPath, 'utf8');
      const serviceAccount = JSON.parse(raw);

      // Validate minimum required fields
      if (!serviceAccount.project_id || !serviceAccount.private_key) {
        console.warn(
          '⚠️  Firebase service account JSON is missing required fields (project_id, private_key). Auth will be unavailable.'
        );
        return;
      }

      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      firebaseAvailable = true;
      console.log('✅ Firebase Admin initialized');
    } else {
      console.warn(
        `⚠️  Firebase service account not found at ${resolvedPath}. Auth will be unavailable.`
      );
    }
  } catch (error) {
    console.warn('⚠️  Failed to initialize Firebase Admin:', error);
  }
}

export async function verifyFirebaseToken(
  idToken: string
): Promise<admin.auth.DecodedIdToken> {
  if (!firebaseAvailable) {
    throw new Error('Firebase Auth is not configured on this server');
  }
  return admin.auth().verifyIdToken(idToken);
}
