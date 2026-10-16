const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { createHash, randomBytes } = require("node:crypto");

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const MAX_VALUE_LENGTH = 200;
const SCHEMA_VERSION = 1;

function canonicalFingerprint(event) {
  // Fixed-key projection prevents caller-controlled fields and JSON key order
  // from changing the fingerprint semantics.
  const canonical = JSON.stringify({
    schemaVersion: event.schemaVersion,
    storeId: event.storeId,
    eventId: event.eventId,
    entityType: event.entityType,
    entityId: event.entityId,
    operation: event.operation,
    localVersion: event.localVersion,
    payload: { value: event.payload.value },
  });
  return createHash("sha256").update(canonical, "utf8").digest("hex");
}

function validateEvent(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Event must be an object.");
  }
  const allowed = [
    "schemaVersion", "storeId", "eventId", "entityType",
    "entityId", "operation", "localVersion", "payload",
  ];
  if (Object.keys(data).some((key) => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", "Event contains unsupported fields.");
  }
  if (data.schemaVersion !== SCHEMA_VERSION
      || typeof data.storeId !== "string" || !/^[A-Za-z0-9_-]{1,80}$/.test(data.storeId)
      || typeof data.eventId !== "string" || !/^[A-Za-z0-9_-]{1,120}$/.test(data.eventId)
      || data.entityType !== "syntheticTestValue"
      || typeof data.entityId !== "string" || !/^[A-Za-z0-9_-]{1,120}$/.test(data.entityId)
      || data.operation !== "set"
      || !Number.isSafeInteger(data.localVersion) || data.localVersion < 1
      || !data.payload || typeof data.payload !== "object"
      || Array.isArray(data.payload)
      || Object.keys(data.payload).length !== 1
      || typeof data.payload.value !== "string"
      || data.payload.value.length > MAX_VALUE_LENGTH) {
    throw new HttpsError("invalid-argument", "Event failed synthetic schema validation.");
  }
  return data;
}

exports.acceptSyntheticSyncEvent = onCall(async (request) => {
  if (!request.auth || typeof request.auth.uid !== "string") {
    throw new HttpsError("unauthenticated", "A signed-in user is required.");
  }

  const event = validateEvent(request.data);
  const uid = request.auth.uid;
  const memberRef = db.doc(`stores/${event.storeId}/members/${uid}`);
  const receiptRef = db.doc(`stores/${event.storeId}/syncReceipts/${event.eventId}`);
  const effectRef = db.doc(`stores/${event.storeId}/syncTestEffects/${event.entityId}`);
  const fingerprint = canonicalFingerprint(event);

  return db.runTransaction(async (transaction) => {
    // All reads precede writes. Membership is checked server-side, not from
    // client-provided role/UID fields.
    const memberSnap = await transaction.get(memberRef);
    if (!memberSnap.exists || memberSnap.get("uid") !== uid
        || memberSnap.get("status") !== "active") {
      throw new HttpsError("permission-denied", "Active store membership is required.");
    }

    const receiptSnap = await transaction.get(receiptRef);
    if (receiptSnap.exists) {
      if (receiptSnap.get("fingerprint") !== fingerprint) {
        throw new HttpsError("already-exists", "Event ID collision: payload differs.");
      }
      return {
        eventId: event.eventId,
        status: "duplicate",
        remoteVersion: receiptSnap.get("remoteVersion"),
      };
    }

    const effectSnap = await transaction.get(effectRef);
    const currentVersion = effectSnap.exists ? effectSnap.get("version") : 0;
    if (event.localVersion !== currentVersion + 1) {
      throw new HttpsError("failed-precondition", "Version conflict.", {
        expectedVersion: currentVersion + 1,
        receivedVersion: event.localVersion,
      });
    }

    const result = {
      eventId: event.eventId,
      status: "applied",
      remoteVersion: event.localVersion,
    };
    transaction.set(effectRef, {
      value: event.payload.value,
      version: event.localVersion,
      updatedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(receiptRef, {
      eventId: event.eventId,
      fingerprint,
      remoteVersion: event.localVersion,
      result,
      createdAt: FieldValue.serverTimestamp(),
    });
    return result;
  });
});


const INVITATION_ROLES = new Set(["manager", "cashier", "viewer"]);
const DEFAULT_INVITATION_HOURS = 24;
const MAX_INVITATION_HOURS = 168;
const MAX_INVITATION_USES = 10;

function validateStoreId(storeId) {
  if (typeof storeId !== "string" || !/^[A-Za-z0-9_-]{1,80}$/.test(storeId)) {
    throw new HttpsError("invalid-argument", "Invalid store ID.");
  }
}

function hashInvitationCode(code) {
  return createHash("sha256").update(code, "utf8").digest("hex");
}

function requireAuthenticatedUid(request) {
  if (!request.auth || typeof request.auth.uid !== "string") {
    throw new HttpsError("unauthenticated", "A signed-in user is required.");
  }
  return request.auth.uid;
}

/**
 * Creates a high-entropy bearer invitation. Only its SHA-256 hash is stored.
 * The invitation code is returned once and is never readable from Firestore.
 */
exports.createStoreInvitation = onCall(async (request) => {
  const uid = requireAuthenticatedUid(request);
  const data = request.data;
  if (!data || typeof data !== "object" || Array.isArray(data)
      || Object.keys(data).some((key) => !["storeId", "role", "expiresInHours", "maxUses"].includes(key))) {
    throw new HttpsError("invalid-argument", "Invitation request contains unsupported fields.");
  }
  validateStoreId(data.storeId);
  if (!INVITATION_ROLES.has(data.role)) {
    throw new HttpsError("invalid-argument", "Invitation role is not allowed.");
  }
  const expiresInHours = data.expiresInHours === undefined
    ? DEFAULT_INVITATION_HOURS : data.expiresInHours;
  const maxUses = data.maxUses === undefined ? 1 : data.maxUses;
  if (!Number.isSafeInteger(expiresInHours) || expiresInHours < 1
      || expiresInHours > MAX_INVITATION_HOURS
      || !Number.isSafeInteger(maxUses) || maxUses < 1
      || maxUses > MAX_INVITATION_USES) {
    throw new HttpsError("invalid-argument", "Invitation expiry or use limit is out of range.");
  }

  const code = randomBytes(24).toString("base64url");
  const tokenHash = hashInvitationCode(code);
  const storeRef = db.doc(`stores/${data.storeId}`);
  const memberRef = db.doc(`stores/${data.storeId}/members/${uid}`);
  const invitationRef = db.doc(`stores/${data.storeId}/invitations/${tokenHash}`);
  const expiresAt = new Date(Date.now() + expiresInHours * 60 * 60 * 1000);

  await db.runTransaction(async (transaction) => {
    const [storeSnap, memberSnap] = await Promise.all([
      transaction.get(storeRef),
      transaction.get(memberRef),
    ]);
    if (!storeSnap.exists || !memberSnap.exists
        || memberSnap.get("uid") !== uid
        || memberSnap.get("status") !== "active"
        || memberSnap.get("role") !== "owner"
        || storeSnap.get("ownerUid") !== uid) {
      throw new HttpsError("permission-denied", "Only the active store owner can create invitations.");
    }
    transaction.create(invitationRef, {
      tokenHash,
      createdByUid: uid,
      role: data.role,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
      maxUses,
      usesCount: 0,
      revoked: false,
      schemaVersion: 1,
    });
  });

  return {
    storeId: data.storeId,
    invitationCode: code,
    role: data.role,
    expiresAt: expiresAt.toISOString(),
    maxUses,
  };
});

/**
 * Accepts a bearer invitation atomically. The callable, not the client,
 * validates expiry/usage and creates the member document.
 */
exports.acceptStoreInvitation = onCall(async (request) => {
  const uid = requireAuthenticatedUid(request);
  const data = request.data;
  if (!data || typeof data !== "object" || Array.isArray(data)
      || Object.keys(data).some((key) => !["storeId", "invitationCode"].includes(key))
      || typeof data.invitationCode !== "string"
      || !/^[A-Za-z0-9_-]{32}$/.test(data.invitationCode)) {
    throw new HttpsError("invalid-argument", "Invitation request is invalid.");
  }
  validateStoreId(data.storeId);
  const tokenHash = hashInvitationCode(data.invitationCode);
  const storeRef = db.doc(`stores/${data.storeId}`);
  const invitationRef = db.doc(`stores/${data.storeId}/invitations/${tokenHash}`);
  const memberRef = db.doc(`stores/${data.storeId}/members/${uid}`);

  return db.runTransaction(async (transaction) => {
    const [storeSnap, invitationSnap, memberSnap] = await Promise.all([
      transaction.get(storeRef),
      transaction.get(invitationRef),
      transaction.get(memberRef),
    ]);
    if (!storeSnap.exists || !invitationSnap.exists) {
      throw new HttpsError("not-found", "Invitation is invalid or unavailable.");
    }
    if (memberSnap.exists) {
      throw new HttpsError("already-exists", "This account already has a membership record for the store.");
    }
    const invitation = invitationSnap.data();
    if (invitation.tokenHash !== tokenHash || invitation.revoked !== false
        || !invitation.expiresAt
        || typeof invitation.expiresAt.toMillis !== "function"
        || invitation.expiresAt.toMillis() <= Date.now()
        || !Number.isSafeInteger(invitation.maxUses)
        || !Number.isSafeInteger(invitation.usesCount)
        || invitation.usesCount < 0
        || invitation.usesCount >= invitation.maxUses
        || !INVITATION_ROLES.has(invitation.role)) {
      throw new HttpsError("failed-precondition", "Invitation is expired, revoked, exhausted, or invalid.");
    }

    transaction.create(memberRef, {
      uid,
      role: invitation.role,
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
      joinedViaInvitation: true,
    });
    transaction.update(invitationRef, {
      usesCount: invitation.usesCount + 1,
      lastUsedAt: FieldValue.serverTimestamp(),
    });
    return { storeId: data.storeId, role: invitation.role, status: "active" };
  });
});
