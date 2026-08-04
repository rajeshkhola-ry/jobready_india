import { createHash, randomBytes } from 'crypto';

import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import OTPAuth from 'otpauth';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const ISSUER = 'GETREADYJOB';
const LABEL = 'Admin';

function normalizeOtpCode(input: unknown): string {
  return String(input ?? '')
    .replace(/\s+/g, '')
    .replace(/-/g, '');
}

function normalizeRecoveryCode(input: unknown): string {
  return String(input ?? '')
    .trim()
    .toUpperCase();
}

function hashRecoveryCode(code: string): string {
  const pepper = process.env.RECOVERY_CODE_PEPPER ?? 'jobready-default-pepper-change-me';
  return createHash('sha256').update(`${pepper}:${code}`).digest('hex');
}

function generateRecoveryCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const raw = randomBytes(10);
  let left = '';
  let right = '';

  for (let i = 0; i < 5; i += 1) {
    left += alphabet[raw[i] % alphabet.length];
    right += alphabet[raw[i + 5] % alphabet.length];
  }

  return `${left}-${right}`;
}

async function assertAdminCaller(uid: string): Promise<void> {
  const adminDoc = await db.collection('admins').doc(uid).get();
  if (!adminDoc.exists) {
    throw new HttpsError('permission-denied', 'Admin profile not found.');
  }

  const data = adminDoc.data() ?? {};
  const role = String(data.role ?? '').toLowerCase();
  const isAdmin = data.isAdmin === true || role === 'admin';
  if (!isAdmin) {
    throw new HttpsError('permission-denied', 'Caller is not an admin.');
  }
}

export const generate2FASecret = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  await assertAdminCaller(uid);

  const secret = new OTPAuth.Secret({ size: 20 });
  const totp = new OTPAuth.TOTP({
    issuer: ISSUER,
    label: `${LABEL}-${uid}`,
    algorithm: 'SHA1',
    digits: 6,
    period: 30,
    secret,
  });

  const recoveryCodes = Array.from({ length: 5 }, () => generateRecoveryCode());
  const recoveryCodeHashes = recoveryCodes.map((code) => hashRecoveryCode(code));

  await db.collection('admin_secrets').doc(uid).set(
    {
      adminUid: uid,
      secretBase32: secret.base32,
      otpauthUri: totp.toString(),
      recoveryCodeHashes,
      twoFactorEnabled: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    otpauthUri: totp.toString(),
    secret: secret.base32,
    recoveryCodes,
  };
});

export const verifyAndEnable2FA = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  await assertAdminCaller(uid);

  const otpCode = normalizeOtpCode(request.data?.otpCode);
  if (!/^\d{6}$/.test(otpCode)) {
    throw new HttpsError('invalid-argument', 'Enter a valid 6-digit code.');
  }

  const secretDocRef = db.collection('admin_secrets').doc(uid);
  const secretDoc = await secretDocRef.get();
  if (!secretDoc.exists) {
    throw new HttpsError('failed-precondition', '2FA secret is not initialized.');
  }

  const secretData = secretDoc.data() ?? {};
  const secretBase32 = String(secretData.secretBase32 ?? '');
  if (!secretBase32) {
    throw new HttpsError('failed-precondition', 'Stored 2FA secret is missing.');
  }

  const totp = new OTPAuth.TOTP({
    issuer: ISSUER,
    label: `${LABEL}-${uid}`,
    algorithm: 'SHA1',
    digits: 6,
    period: 30,
    secret: OTPAuth.Secret.fromBase32(secretBase32),
  });

  const delta = totp.validate({ token: otpCode, window: 1 });
  if (delta === null) {
    throw new HttpsError('permission-denied', 'Invalid authenticator code.');
  }

  await Promise.all([
    db.collection('admins').doc(uid).set(
      {
        is2FAEnabled: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    ),
    secretDocRef.set(
      {
        twoFactorEnabled: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    ),
  ]);

  return { success: true };
});

export const verifyAdmin2FACode = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  await assertAdminCaller(callerUid);

  const adminUid = String(request.data?.adminUid ?? '').trim();
  if (!adminUid) {
    throw new HttpsError('invalid-argument', 'adminUid is required.');
  }
  if (adminUid != callerUid) {
    throw new HttpsError('permission-denied', 'Cannot verify another admin account.');
  }

  const otpCode = normalizeOtpCode(request.data?.otpCode);
  const recoveryCode = normalizeRecoveryCode(request.data?.recoveryCode);

  const secretDocRef = db.collection('admin_secrets').doc(adminUid);
  const secretDoc = await secretDocRef.get();
  if (!secretDoc.exists) {
    throw new HttpsError('failed-precondition', '2FA secret is not initialized.');
  }

  const secretData = secretDoc.data() ?? {};
  const secretBase32 = String(secretData.secretBase32 ?? '');
  if (!secretBase32) {
    throw new HttpsError('failed-precondition', 'Stored 2FA secret is missing.');
  }

  let verified = false;

  if (/^\d{6}$/.test(otpCode)) {
    const totp = new OTPAuth.TOTP({
      issuer: ISSUER,
      label: `${LABEL}-${adminUid}`,
      algorithm: 'SHA1',
      digits: 6,
      period: 30,
      secret: OTPAuth.Secret.fromBase32(secretBase32),
    });

    verified = totp.validate({ token: otpCode, window: 1 }) !== null;
  }

  if (!verified && recoveryCode.length > 0) {
    const existingHashes = ((secretData.recoveryCodeHashes as unknown[] | undefined) ?? [])
      .map((value) => String(value));
    const recoveryHash = hashRecoveryCode(recoveryCode);

    if (existingHashes.includes(recoveryHash)) {
      verified = true;
      await secretDocRef.update({
        recoveryCodeHashes: existingHashes.filter((hash) => hash !== recoveryHash),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  if (!verified) {
    throw new HttpsError('permission-denied', 'Invalid 2FA code.');
  }

  const customToken = await admin.auth().createCustomToken(adminUid, {
    admin2faVerified: true,
    role: 'admin',
  });

  return {
    success: true,
    sessionApproved: true,
    customToken,
  };
});
