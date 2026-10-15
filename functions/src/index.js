const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { createHash } = require("node:crypto");

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
