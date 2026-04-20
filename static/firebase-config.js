/**
 * ─── Firebase Setup Instructions ─────────────────────────────────────────────
 *
 * Fill in the values below to enable Google Sign-In and cross-device sync.
 *
 * Step 1 — Create a Firebase project
 *   → https://console.firebase.google.com
 *   → "Add project" → follow the wizard (disable Analytics if you want)
 *
 * Step 2 — Enable Google sign-in
 *   → Build → Authentication → Get started
 *   → Sign-in method → Google → Enable → Add your support email → Save
 *
 * Step 3 — Create Firestore database
 *   → Build → Firestore Database → Create database
 *   → Start in production mode → choose your nearest region → Done
 *
 * Step 4 — Set Firestore security rules (only you can read your data)
 *   → Firestore → Rules → paste this, then Publish:
 *
 *   rules_version = '2';
 *   service cloud.firestore {
 *     match /databases/{database}/documents {
 *       match /users/{userId}/{document=**} {
 *         allow read, write: if request.auth != null
 *                            && request.auth.uid == userId;
 *       }
 *     }
 *   }
 *
 * Step 5 — Register your web app and get your config
 *   → Project Settings (gear icon, top-left) → Your apps → Add app → Web (</>)
 *   → Give it a nickname → Register app
 *   → Copy the firebaseConfig object and paste the values below
 *
 * Step 6 — Add localhost as an authorized domain (for local dev)
 *   → Authentication → Settings → Authorized domains → Add domain → localhost
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */

export const FIREBASE_CONFIG = {
  apiKey:            "AIzaSyC4QQK9pru0LhJ03vK0enb73MGyicl-q8s",
  authDomain:        "calorie-tracker-42b2d.firebaseapp.com",
  projectId:         "calorie-tracker-42b2d",
  storageBucket:     "calorie-tracker-42b2d.firebasestorage.app",
  messagingSenderId: "445126569630",
  appId:             "1:445126569630:web:1c5e46b2af13d19a94158f",
};

// Set to false to disable Firebase entirely and use localStorage only
export const FIREBASE_ENABLED =
  typeof FIREBASE_CONFIG.apiKey === "string" &&
  !FIREBASE_CONFIG.apiKey.startsWith("YOUR_");
