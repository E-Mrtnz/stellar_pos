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
  const cursorRef = db.doc(`stores/${event.storeId}/syncMetadata/cursor`);
  const changeRef = db.doc(`stores/${event.storeId}/syncTestChanges/${event.eventId}`);
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
    const cursorSnap = await transaction.get(cursorRef);
    const currentVersion = effectSnap.exists ? effectSnap.get("version") : 0;
    if (event.localVersion !== currentVersion + 1) {
      throw new HttpsError("failed-precondition", "Version conflict.", {
        expectedVersion: currentVersion + 1,
        receivedVersion: event.localVersion,
      });
    }

    const remoteVersion = cursorSnap.exists ? cursorSnap.get("version") + 1 : 1;
    const result = {
      eventId: event.eventId,
      status: "applied",
      remoteVersion,
    };
    transaction.set(effectRef, {
      value: event.payload.value,
      version: event.localVersion,
      updatedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(cursorRef, {
      storeId: event.storeId,
      version: remoteVersion,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(changeRef, {
      storeId: event.storeId,
      eventId: event.eventId,
      entityType: event.entityType,
      entityId: event.entityId,
      operation: event.operation,
      localVersion: event.localVersion,
      version: remoteVersion,
      payload: { value: event.payload.value },
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(receiptRef, {
      eventId: event.eventId,
      fingerprint,
      remoteVersion,
      result,
      createdAt: FieldValue.serverTimestamp(),
    });
    return result;
  });
});


/**
 * Returns a bounded page of synthetic changes after a per-store cursor.
 * This callable never returns sales, products, inventory, payments, or debts.
 */
exports.pullSyntheticSyncChanges = onCall(async (request) => {
  const uid = requireAuthenticatedUid(request);
  const data = request.data;
  if (!data || typeof data !== "object" || Array.isArray(data)
      || Object.keys(data).some((key) => !["storeId", "afterVersion", "limit"].includes(key))) {
    throw new HttpsError("invalid-argument", "Pull request contains unsupported fields.");
  }
  validateStoreId(data.storeId);
  const afterVersion = data.afterVersion === undefined ? 0 : data.afterVersion;
  const limit = data.limit === undefined ? 50 : data.limit;
  if (!Number.isSafeInteger(afterVersion) || afterVersion < 0
      || !Number.isSafeInteger(limit) || limit < 1 || limit > 100) {
    throw new HttpsError("invalid-argument", "Cursor or page size is out of range.");
  }

  const memberSnap = await db.doc(`stores/${data.storeId}/members/${uid}`).get();
  if (!memberSnap.exists || memberSnap.get("uid") !== uid
      || memberSnap.get("status") !== "active") {
    throw new HttpsError("permission-denied", "Active store membership is required.");
  }

  const snapshot = await db.collection(`stores/${data.storeId}/syncTestChanges`)
    .where("version", ">", afterVersion)
    .orderBy("version", "asc")
    .limit(limit)
    .get();
  const changes = snapshot.docs.map((document) => {
    const change = document.data();
    return {
      storeId: change.storeId,
      eventId: change.eventId,
      entityType: change.entityType,
      entityId: change.entityId,
      operation: change.operation,
      localVersion: change.localVersion,
      version: change.version,
      payload: change.payload,
    };
  });
  return {
    storeId: data.storeId,
    afterVersion,
    changes,
    nextCursor: changes.length === 0 ? afterVersion : changes[changes.length - 1].version,
    hasMore: changes.length === limit,
  };
});


const SALE_FIELDS = [
  "id", "ticketNumber", "saleNumber", "createdAt", "clientId", "clientName",
  "paymentMethod", "items", "subtotal", "discountPercent", "discountAmount",
  "cardFeeAmount", "total", "received", "change", "status", "operations", "metadata",
];
const SALE_ITEM_FIELDS = [
  "id", "productId", "productName", "unit", "brand", "barcode", "cost",
  "unitPrice", "quantity", "lineSubtotal", "discount", "lineTotal", "imageData",
  "isElectronicBalance", "hasGroupPricing", "isPrepared", "preparationExtra",
  "electronicBalanceAccountId", "electronicBalanceCategory", "metadata",
];
const SALE_OPERATION_FIELDS = [
  "id", "type", "createdAt", "itemsOut", "itemsIn", "amountDelta", "note",
];
const SYNC_METADATA_FIELDS = [
  "createdAt", "updatedAt", "version", "schemaVersion", "syncState",
  "lastSyncedAt", "deletedAt", "deviceId", "storeId",
];

function onlyAllowedKeys(value, allowed, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)
      || Object.keys(value).some((key) => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", label + " contains unsupported fields.");
  }
}

function finiteNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function validateSaleMetadata(metadata, label) {
  onlyAllowedKeys(metadata, SYNC_METADATA_FIELDS, label);
  if (typeof metadata.createdAt !== "string"
      || Number.isNaN(Date.parse(metadata.createdAt))
      || typeof metadata.updatedAt !== "string"
      || Number.isNaN(Date.parse(metadata.updatedAt))
      || !Number.isSafeInteger(metadata.version) || metadata.version < 1
      || metadata.schemaVersion !== 1
      || !["pending", "updated", "synced", "deleted"].includes(metadata.syncState)) {
    throw new HttpsError("invalid-argument", label + " is invalid.");
  }
  for (const key of ["lastSyncedAt", "deletedAt", "deviceId", "storeId"]) {
    if (metadata[key] !== undefined && metadata[key] !== null
        && typeof metadata[key] !== "string") {
      throw new HttpsError("invalid-argument", label + " contains invalid metadata.");
    }
  }
}

function validateSaleItem(item, label) {
  onlyAllowedKeys(item, SALE_ITEM_FIELDS, label);
  for (const key of ["id", "productId", "productName", "unit", "brand", "barcode", "imageData"]) {
    if (typeof item[key] !== "string") {
      throw new HttpsError("invalid-argument", label + " contains invalid text fields.");
    }
  }
  for (const key of ["electronicBalanceAccountId", "electronicBalanceCategory"]) {
    if (item[key] !== undefined && item[key] !== null && typeof item[key] !== "string") {
      throw new HttpsError("invalid-argument", label + " contains invalid optional fields.");
    }
  }
  for (const key of ["cost", "unitPrice", "lineSubtotal", "discount", "lineTotal", "preparationExtra"]) {
    if (!finiteNumber(item[key]) || item[key] < 0) {
      throw new HttpsError("invalid-argument", label + " contains invalid amounts.");
    }
  }
  if (!Number.isSafeInteger(item.quantity) || item.quantity < 1
      || typeof item.isElectronicBalance !== "boolean"
      || typeof item.hasGroupPricing !== "boolean"
      || typeof item.isPrepared !== "boolean") {
    throw new HttpsError("invalid-argument", label + " contains invalid quantity or flags.");
  }
  validateSaleMetadata(item.metadata, label + ".metadata");
}

function validateSaleRecord(sale, saleId) {
  onlyAllowedKeys(sale, SALE_FIELDS, "Sale");
  if (sale.id !== saleId || typeof sale.id !== "string"
      || !/^[A-Za-z0-9_-]{1,120}$/.test(saleId)
      || typeof sale.ticketNumber !== "string"
      || (sale.saleNumber !== null && sale.saleNumber !== "")
      || typeof sale.createdAt !== "string" || Number.isNaN(Date.parse(sale.createdAt))
      || (sale.clientId !== null && typeof sale.clientId !== "string")
      || typeof sale.clientName !== "string"
      || typeof sale.paymentMethod !== "string" || sale.paymentMethod.length > 80
      || !["completed", "annulled"].includes(sale.status)
      || !Array.isArray(sale.items) || sale.items.length > 500
      || !Array.isArray(sale.operations) || sale.operations.length > 100) {
    throw new HttpsError("invalid-argument", "Sale identity or schema is invalid.");
  }
  for (const key of ["subtotal", "discountPercent", "discountAmount", "cardFeeAmount", "total", "received", "change"]) {
    if (!finiteNumber(sale[key]) || sale[key] < 0) {
      throw new HttpsError("invalid-argument", "Sale contains invalid amounts.");
    }
  }
  if (sale.discountPercent > 100) {
    throw new HttpsError("invalid-argument", "Sale discount percentage is out of range.");
  }
  sale.items.forEach((item, index) => validateSaleItem(item, "Sale item " + index));
  sale.operations.forEach((operation, index) => {
    const label = "Sale operation " + index;
    onlyAllowedKeys(operation, SALE_OPERATION_FIELDS, label);
    if (typeof operation.id !== "string"
        || !["returnItem", "change"].includes(operation.type)
        || typeof operation.createdAt !== "string"
        || Number.isNaN(Date.parse(operation.createdAt))
        || !finiteNumber(operation.amountDelta)
        || typeof operation.note !== "string"
        || !Array.isArray(operation.itemsOut)
        || !Array.isArray(operation.itemsIn)
        || operation.itemsOut.length > 500 || operation.itemsIn.length > 500) {
      throw new HttpsError("invalid-argument", label + " is invalid.");
    }
    operation.itemsOut.forEach((item, itemIndex) =>
      validateSaleItem(item, label + ".itemsOut " + itemIndex));
    operation.itemsIn.forEach((item, itemIndex) =>
      validateSaleItem(item, label + ".itemsIn " + itemIndex));
  });
  validateSaleMetadata(sale.metadata, "Sale metadata");
  // Validate serializability and keep payload size safely below Firestore's limit.
  if (Buffer.byteLength(JSON.stringify(sale), "utf8") > 700000) {
    throw new HttpsError("invalid-argument", "Sale payload is too large.");
  }
}

function stableJson(value) {
  if (Array.isArray(value)) return "[" + value.map(stableJson).join(",") + "]";
  if (value && typeof value === "object") {
    return "{" + Object.keys(value).sort()
      .map((key) => JSON.stringify(key) + ":" + stableJson(value[key])).join(",") + "}";
  }
  return JSON.stringify(value);
}

function saleFingerprint(sale) {
  const businessData = { ...sale };
  delete businessData.ticketNumber;
  delete businessData.saleNumber;
  delete businessData.metadata;
  return createHash("sha256").update(stableJson(businessData), "utf8").digest("hex");
}

/**
 * Accepts one immutable sale by stable local saleId and assigns its sequential
 * cloud number in the same transaction as the sale and idempotency receipt.
 * This endpoint is emulator-tested and intentionally not wired to the client.
 */
exports.acceptCloudSale = onCall(async (request) => {
  const uid = requireAuthenticatedUid(request);
  const data = request.data;
  if (!data || typeof data !== "object" || Array.isArray(data)
      || Object.keys(data).some((key) => !["storeId", "saleId", "sale"].includes(key))) {
    throw new HttpsError("invalid-argument", "Sale request contains unsupported fields.");
  }
  validateStoreId(data.storeId);
  if (typeof data.saleId !== "string" || !/^[A-Za-z0-9_-]{1,120}$/.test(data.saleId)) {
    throw new HttpsError("invalid-argument", "Sale ID is invalid.");
  }
  validateSaleRecord(data.sale, data.saleId);
  const fingerprint = saleFingerprint(data.sale);
  const storeRef = db.doc("stores/" + data.storeId);
  const memberRef = db.doc("stores/" + data.storeId + "/members/" + uid);
  const saleRef = db.doc("stores/" + data.storeId + "/sales/" + data.saleId);
  const receiptRef = db.doc("stores/" + data.storeId + "/saleSyncReceipts/" + data.saleId);
  const sequenceRef = db.doc("stores/" + data.storeId + "/metadata/saleSequence");

  return db.runTransaction(async (transaction) => {
    const [storeSnap, memberSnap, receiptSnap, saleSnap, sequenceSnap] = await Promise.all([
      transaction.get(storeRef),
      transaction.get(memberRef),
      transaction.get(receiptRef),
      transaction.get(saleRef),
      transaction.get(sequenceRef),
    ]);
    if (!storeSnap.exists || !memberSnap.exists
        || memberSnap.get("uid") !== uid
        || memberSnap.get("status") !== "active"
        || !["owner", "manager", "cashier"].includes(memberSnap.get("role"))) {
      throw new HttpsError("permission-denied", "Active business-data membership is required.");
    }
    if (receiptSnap.exists) {
      if (receiptSnap.get("fingerprint") !== fingerprint) {
        throw new HttpsError("already-exists", "Sale ID collision: business data differs.");
      }
      return {
        saleId: data.saleId,
        saleNumber: receiptSnap.get("saleNumber"),
        ticketNumber: receiptSnap.get("ticketNumber"),
        status: "duplicate",
      };
    }
    if (saleSnap.exists) {
      throw new HttpsError("already-exists", "Sale exists without an idempotency receipt.");
    }
    const lastNumber = sequenceSnap.exists ? sequenceSnap.get("lastNumber") : 0;
    if (!Number.isSafeInteger(lastNumber) || lastNumber < 0 || lastNumber >= Number.MAX_SAFE_INTEGER) {
      throw new HttpsError("failed-precondition", "Sale sequence is invalid or exhausted.");
    }
    const nextNumber = lastNumber + 1;
    const saleNumber = String(nextNumber);
    const ticketNumber = data.sale.ticketNumber.trim().length === 0
      ? saleNumber : data.sale.ticketNumber;
    const acceptedSale = {
      ...data.sale,
      saleNumber,
      ticketNumber,
      metadata: {
        ...data.sale.metadata,
        storeId: data.storeId,
        syncState: "synced",
        lastSyncedAt: new Date().toISOString(),
      },
    };
    const result = {
      saleId: data.saleId,
      saleNumber,
      ticketNumber,
      status: "applied",
    };
    transaction.set(saleRef, {
      ...acceptedSale,
      acceptedByUid: uid,
      acceptedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(sequenceRef, {
      storeId: data.storeId,
      lastNumber: nextNumber,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(receiptRef, {
      saleId: data.saleId,
      fingerprint,
      saleNumber,
      ticketNumber,
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


/** Revokes an invitation before it has been exhausted. */
exports.revokeStoreInvitation = onCall(async (request) => {
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
  const memberRef = db.doc(`stores/${data.storeId}/members/${uid}`);
  const invitationRef = db.doc(`stores/${data.storeId}/invitations/${tokenHash}`);

  await db.runTransaction(async (transaction) => {
    const [storeSnap, memberSnap, invitationSnap] = await Promise.all([
      transaction.get(storeRef),
      transaction.get(memberRef),
      transaction.get(invitationRef),
    ]);
    if (!storeSnap.exists || !invitationSnap.exists) {
      throw new HttpsError("not-found", "Invitation is invalid or unavailable.");
    }
    if (!memberSnap.exists || memberSnap.get("uid") !== uid
        || memberSnap.get("status") !== "active"
        || memberSnap.get("role") !== "owner"
        || storeSnap.get("ownerUid") !== uid) {
      throw new HttpsError("permission-denied", "Only the active store owner can revoke invitations.");
    }
    if (invitationSnap.get("tokenHash") !== tokenHash) {
      throw new HttpsError("not-found", "Invitation is invalid or unavailable.");
    }
    transaction.update(invitationRef, {
      revoked: true,
      revokedAt: FieldValue.serverTimestamp(),
      revokedByUid: uid,
    });
  });
  return { storeId: data.storeId, revoked: true };
});
