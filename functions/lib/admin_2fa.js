"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyAdmin2FACode = exports.verifyAndEnable2FA = exports.generate2FASecret = void 0;
const crypto_1 = require("crypto");
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const otpauth_1 = __importDefault(require("otpauth"));
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const ISSUER = 'GETREADYJOB';
const LABEL = 'Admin';
function normalizeOtpCode(input) {
    return String(input ?? '')
        .replace(/\s+/g, '')
        .replace(/-/g, '');
}
function normalizeRecoveryCode(input) {
    return String(input ?? '')
        .trim()
        .toUpperCase();
}
function hashRecoveryCode(code) {
    const pepper = process.env.RECOVERY_CODE_PEPPER ?? 'jobready-default-pepper-change-me';
    return (0, crypto_1.createHash)('sha256').update(`${pepper}:${code}`).digest('hex');
}
function generateRecoveryCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const raw = (0, crypto_1.randomBytes)(10);
    let left = '';
    let right = '';
    for (let i = 0; i < 5; i += 1) {
        left += alphabet[raw[i] % alphabet.length];
        right += alphabet[raw[i + 5] % alphabet.length];
    }
    return `${left}-${right}`;
}
async function assertAdminCaller(uid) {
    const adminDoc = await db.collection('admins').doc(uid).get();
    if (!adminDoc.exists) {
        throw new https_1.HttpsError('permission-denied', 'Admin profile not found.');
    }
    const data = adminDoc.data() ?? {};
    const role = String(data.role ?? '').toLowerCase();
    const isAdmin = data.isAdmin === true || role === 'admin';
    if (!isAdmin) {
        throw new https_1.HttpsError('permission-denied', 'Caller is not an admin.');
    }
}
exports.generate2FASecret = (0, https_1.onCall)(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    await assertAdminCaller(uid);
    const secret = new otpauth_1.default.Secret({ size: 20 });
    const totp = new otpauth_1.default.TOTP({
        issuer: ISSUER,
        label: `${LABEL}-${uid}`,
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
        secret,
    });
    const recoveryCodes = Array.from({ length: 5 }, () => generateRecoveryCode());
    const recoveryCodeHashes = recoveryCodes.map((code) => hashRecoveryCode(code));
    await db.collection('admin_secrets').doc(uid).set({
        adminUid: uid,
        secretBase32: secret.base32,
        otpauthUri: totp.toString(),
        recoveryCodeHashes,
        twoFactorEnabled: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        otpauthUri: totp.toString(),
        secret: secret.base32,
        recoveryCodes,
    };
});
exports.verifyAndEnable2FA = (0, https_1.onCall)(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    await assertAdminCaller(uid);
    const otpCode = normalizeOtpCode(request.data?.otpCode);
    if (!/^\d{6}$/.test(otpCode)) {
        throw new https_1.HttpsError('invalid-argument', 'Enter a valid 6-digit code.');
    }
    const secretDocRef = db.collection('admin_secrets').doc(uid);
    const secretDoc = await secretDocRef.get();
    if (!secretDoc.exists) {
        throw new https_1.HttpsError('failed-precondition', '2FA secret is not initialized.');
    }
    const secretData = secretDoc.data() ?? {};
    const secretBase32 = String(secretData.secretBase32 ?? '');
    if (!secretBase32) {
        throw new https_1.HttpsError('failed-precondition', 'Stored 2FA secret is missing.');
    }
    const totp = new otpauth_1.default.TOTP({
        issuer: ISSUER,
        label: `${LABEL}-${uid}`,
        algorithm: 'SHA1',
        digits: 6,
        period: 30,
        secret: otpauth_1.default.Secret.fromBase32(secretBase32),
    });
    const delta = totp.validate({ token: otpCode, window: 1 });
    if (delta === null) {
        throw new https_1.HttpsError('permission-denied', 'Invalid authenticator code.');
    }
    await Promise.all([
        db.collection('admins').doc(uid).set({
            is2FAEnabled: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true }),
        secretDocRef.set({
            twoFactorEnabled: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true }),
    ]);
    return { success: true };
});
exports.verifyAdmin2FACode = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    await assertAdminCaller(callerUid);
    const adminUid = String(request.data?.adminUid ?? '').trim();
    if (!adminUid) {
        throw new https_1.HttpsError('invalid-argument', 'adminUid is required.');
    }
    if (adminUid != callerUid) {
        throw new https_1.HttpsError('permission-denied', 'Cannot verify another admin account.');
    }
    const otpCode = normalizeOtpCode(request.data?.otpCode);
    const recoveryCode = normalizeRecoveryCode(request.data?.recoveryCode);
    const secretDocRef = db.collection('admin_secrets').doc(adminUid);
    const secretDoc = await secretDocRef.get();
    if (!secretDoc.exists) {
        throw new https_1.HttpsError('failed-precondition', '2FA secret is not initialized.');
    }
    const secretData = secretDoc.data() ?? {};
    const secretBase32 = String(secretData.secretBase32 ?? '');
    if (!secretBase32) {
        throw new https_1.HttpsError('failed-precondition', 'Stored 2FA secret is missing.');
    }
    let verified = false;
    if (/^\d{6}$/.test(otpCode)) {
        const totp = new otpauth_1.default.TOTP({
            issuer: ISSUER,
            label: `${LABEL}-${adminUid}`,
            algorithm: 'SHA1',
            digits: 6,
            period: 30,
            secret: otpauth_1.default.Secret.fromBase32(secretBase32),
        });
        verified = totp.validate({ token: otpCode, window: 1 }) !== null;
    }
    if (!verified && recoveryCode.length > 0) {
        const existingHashes = (secretData.recoveryCodeHashes ?? [])
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
        throw new https_1.HttpsError('permission-denied', 'Invalid 2FA code.');
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
