import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";

const projectId = "demo-stellar-pos";
const authBase = "http://127.0.0.1:9099";
const functionBase = "http://127.0.0.1:5001/demo-stellar-pos/us-central1";
let env;
let counter = 0;

async function createUser() {
  const response = await fetch(`${authBase}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  const body = await response.json();
  assert.equal(response.ok, true, JSON.stringify(body));
  return body;
}

async function seedMembership(storeId, uid, status = "active") {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `stores/${storeId}/members/${uid}`), {
      uid, role: "owner", status, createdAt: new Date(),
    });
  });
}

function event(storeId, overrides = {}) {
  counter += 1;
  return {
    schemaVersion: 1,
    storeId,
    eventId: `event-${counter}`,
    entityType: "syntheticTestValue",
    entityId: "counter-a",
    operation: "set",
    localVersion: 1,
    payload: { value: "synthetic-value" },
    ...overrides,
  };
}

async function invoke(idToken, data, functionName = "acceptSyntheticSyncEvent") {
  const response = await fetch(`${functionBase}/${functionName}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  return { status: response.status, body: await response.json() };
}

function salePayload(saleId, overrides = {}) {
  const createdAt = "2026-10-15T10:00:00.000Z";
  return {
    id: saleId,
    ticketNumber: "",
    saleNumber: null,
    createdAt,
    clientId: null,
    clientName: "",
    paymentMethod: "Efectivo",
    items: [],
    subtotal: 10,
    discountPercent: 0,
    discountAmount: 0,
    cardFeeAmount: 0,
    total: 10,
    received: 10,
    change: 0,
    status: "completed",
    operations: [],
    metadata: {
      createdAt,
      updatedAt: createdAt,
      version: 1,
      schemaVersion: 1,
      syncState: "pending",
      lastSyncedAt: null,
      deletedAt: null,
      deviceId: "device-test",
      storeId: null,
    },
    ...overrides,
  };
}

async function seedStore(storeId, ownerUid) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `stores/${storeId}`), {
      name: "Sale receiver test store",
      ownerUid,
      schemaVersion: 1,
    });
  });
}


before(async () => {
  env = await initializeTestEnvironment({ projectId });
});

after(async () => {
  await env?.cleanup();
});

test("cloud sale acceptance assigns sequential numbers and is idempotent", async () => {
  const user = await createUser();
  const storeId = "sale-numbering-idempotency";
  await seedMembership(storeId, user.localId);
  await seedStore(storeId, user.localId);

  const firstPayload = salePayload("sale-local-1");
  const first = await invoke(user.idToken, {
    storeId, saleId: "sale-local-1", sale: firstPayload,
  }, "acceptCloudSale");
  assert.equal(first.body.result.status, "applied");
  assert.equal(first.body.result.saleNumber, "1");
  assert.equal(first.body.result.ticketNumber, "1");

  const replayPayload = salePayload("sale-local-1", {
    saleNumber: "1",
    ticketNumber: "1",
    metadata: {
      ...firstPayload.metadata,
      syncState: "synced",
      lastSyncedAt: "2026-10-15T10:01:00.000Z",
      storeId,
    },
  });
  const replay = await invoke(user.idToken, {
    storeId, saleId: "sale-local-1", sale: replayPayload,
  }, "acceptCloudSale");
  assert.equal(replay.body.result.status, "duplicate");
  assert.equal(replay.body.result.saleNumber, "1");

  const second = await invoke(user.idToken, {
    storeId,
    saleId: "sale-local-2",
    sale: salePayload("sale-local-2"),
  }, "acceptCloudSale");
  assert.equal(second.body.result.saleNumber, "2");
});

test("cloud sale receiver rejects client-chosen numbers and changed payload collisions", async () => {
  const user = await createUser();
  const storeId = "sale-numbering-validation";
  await seedMembership(storeId, user.localId);
  await seedStore(storeId, user.localId);

  const chosenNumber = await invoke(user.idToken, {
    storeId,
    saleId: "sale-client-number",
    sale: salePayload("sale-client-number", { saleNumber: "999" }),
  }, "acceptCloudSale");
  assert.equal(chosenNumber.body.error.status, "INVALID_ARGUMENT");

  const payload = salePayload("sale-collision");
  const accepted = await invoke(user.idToken, {
    storeId, saleId: "sale-collision", sale: payload,
  }, "acceptCloudSale");
  assert.equal(accepted.body.result.status, "applied");
  const collision = await invoke(user.idToken, {
    storeId,
    saleId: "sale-collision",
    sale: salePayload("sale-collision", { total: 99, subtotal: 99, received: 99 }),
  }, "acceptCloudSale");
  assert.equal(collision.body.error.status, "ALREADY_EXISTS");
});

test("cloud sale receiver requires active business-data membership", async () => {
  const owner = await createUser();
  const stranger = await createUser();
  const storeId = "sale-numbering-permissions";
  await seedMembership(storeId, owner.localId);
  await seedStore(storeId, owner.localId);

  const denied = await invoke(stranger.idToken, {
    storeId,
    saleId: "sale-unauthorized",
    sale: salePayload("sale-unauthorized"),
  }, "acceptCloudSale");
  assert.equal(denied.body.error.status, "PERMISSION_DENIED");
});

test("concurrent duplicate sale submissions allocate only one number", async () => {
  const user = await createUser();
  const storeId = "sale-numbering-concurrent";
  await seedMembership(storeId, user.localId);
  await seedStore(storeId, user.localId);
  const payload = salePayload("sale-concurrent");
  const request = {
    storeId, saleId: "sale-concurrent", sale: payload,
  };
  const results = await Promise.all([
    invoke(user.idToken, request, "acceptCloudSale"),
    invoke(user.idToken, request, "acceptCloudSale"),
  ]);
  const statuses = results.map((result) => result.body.result?.status).sort();
  assert.deepEqual(statuses, ["applied", "duplicate"]);
  assert.deepEqual(
    results.map((result) => result.body.result?.saleNumber),
    ["1", "1"],
  );
});


test("applies once and returns the original result on duplicate replay", async () => {
  const user = await createUser();
  const storeId = "receiver-idempotency";
  await seedMembership(storeId, user.localId);
  const payload = event(storeId);
  const first = await invoke(user.idToken, payload);
  const second = await invoke(user.idToken, payload);
  assert.equal(first.body.result.status, "applied");
  assert.equal(second.body.result.status, "duplicate");
  assert.equal(second.body.result.remoteVersion, 1);
});

test("concurrent identical requests produce one effect and a duplicate result", async () => {
  const user = await createUser();
  const storeId = "receiver-concurrent";
  await seedMembership(storeId, user.localId);
  const payload = event(storeId);
  const [first, second] = await Promise.all([
    invoke(user.idToken, payload),
    invoke(user.idToken, payload),
  ]);
  const statuses = [first.body.result?.status, second.body.result?.status].sort();
  assert.deepEqual(statuses, ["applied", "duplicate"]);
});

test("rejects a reused event ID with a different payload", async () => {
  const user = await createUser();
  const storeId = "receiver-collision";
  await seedMembership(storeId, user.localId);
  const payload = event(storeId);
  assert.equal((await invoke(user.idToken, payload)).body.result.status, "applied");
  const collision = await invoke(user.idToken, {
    ...payload, payload: { value: "different-value" },
  });
  assert.equal(collision.body.error.status, "ALREADY_EXISTS");
});

test("isolates identical event IDs across stores", async () => {
  const user = await createUser();
  await seedMembership("receiver-store-a", user.localId);
  await seedMembership("receiver-store-b", user.localId);
  const shared = event("receiver-store-a", { eventId: "shared-id" });
  const otherStore = { ...shared, storeId: "receiver-store-b" };
  assert.equal((await invoke(user.idToken, shared)).body.result.status, "applied");
  assert.equal((await invoke(user.idToken, otherStore)).body.result.status, "applied");
});

test("rejects a user who is not a member of the requested store", async () => {
  const user = await createUser();
  await seedMembership("receiver-member-store", user.localId);
  const unauthorized = await invoke(
    user.idToken,
    event("receiver-other-store"),
  );
  assert.equal(unauthorized.body.error.status, "PERMISSION_DENIED");
});

test("rejects unauthenticated calls and inactive membership", async () => {
  const anonymous = await invoke(null, event("receiver-no-auth"));
  assert.equal(anonymous.body.error.status, "UNAUTHENTICATED");

  const user = await createUser();
  await seedMembership("receiver-inactive", user.localId, "revoked");
  const inactive = await invoke(user.idToken, event("receiver-inactive"));
  assert.equal(inactive.body.error.status, "PERMISSION_DENIED");
});

test("requires strictly sequential versions for each synthetic entity", async () => {
  const user = await createUser();
  const storeId = "receiver-version-sequence";
  await seedMembership(storeId, user.localId);

  const first = event(storeId, { eventId: "version-one", localVersion: 1 });
  assert.equal((await invoke(user.idToken, first)).body.result.status, "applied");

  const skipped = event(storeId, { eventId: "version-three", localVersion: 3 });
  assert.equal(
    (await invoke(user.idToken, skipped)).body.error.status,
    "FAILED_PRECONDITION",
  );

  const second = event(storeId, {
    eventId: "version-two",
    localVersion: 2,
    payload: { value: "second-version" },
  });
  assert.equal((await invoke(user.idToken, second)).body.result.status, "applied");
});

test("rejects stale versions without writing a receipt", async () => {
  const user = await createUser();
  const storeId = "receiver-version-conflict";
  await seedMembership(storeId, user.localId);
  const stale = event(storeId, { localVersion: 2 });
  const result = await invoke(user.idToken, stale);
  assert.equal(result.body.error.status, "FAILED_PRECONDITION");
  const replay = await invoke(user.idToken, { ...stale, localVersion: 1 });
  assert.equal(replay.body.result.status, "applied");
});

test("rejects unsupported entity types and oversized synthetic values", async () => {
  const user = await createUser();
  const storeId = "receiver-payload-bounds";
  await seedMembership(storeId, user.localId);

  const unsupportedEntity = await invoke(user.idToken, event(storeId, {
    entityType: "sales",
  }));
  assert.equal(unsupportedEntity.body.error.status, "INVALID_ARGUMENT");

  const oversizedValue = await invoke(user.idToken, event(storeId, {
    payload: { value: "x".repeat(201) },
  }));
  assert.equal(oversizedValue.body.error.status, "INVALID_ARGUMENT");
});

test("rejects client-controlled identity and unsupported payload fields", async () => {
  const user = await createUser();
  const storeId = "receiver-schema";
  await seedMembership(storeId, user.localId);
  const payload = event(storeId, { uid: "attacker" });
  const result = await invoke(user.idToken, payload);
  assert.equal(result.body.error.status, "INVALID_ARGUMENT");
});


test("pulls synthetic changes incrementally using a monotonic store cursor", async () => {
  const user = await createUser();
  const storeId = "receiver-pull-cursor";
  await seedMembership(storeId, user.localId);
  const first = event(storeId, {
    eventId: "pull-event-1",
    entityId: "entity-one",
    localVersion: 1,
    payload: { value: "one" },
  });
  const second = event(storeId, {
    eventId: "pull-event-2",
    entityId: "entity-two",
    localVersion: 1,
    payload: { value: "two" },
  });
  assert.equal((await invoke(user.idToken, first)).body.result.status, "applied");
  assert.equal((await invoke(user.idToken, second)).body.result.status, "applied");

  const pageOne = await invoke(user.idToken, {
    storeId, afterVersion: 0, limit: 1,
  }, "pullSyntheticSyncChanges");
  assert.equal(pageOne.body.result.changes.length, 1);
  assert.equal(pageOne.body.result.changes[0].eventId, "pull-event-1");
  assert.equal(pageOne.body.result.nextCursor, 1);
  assert.equal(pageOne.body.result.hasMore, true);

  const pageTwo = await invoke(user.idToken, {
    storeId, afterVersion: pageOne.body.result.nextCursor, limit: 1,
  }, "pullSyntheticSyncChanges");
  assert.equal(pageTwo.body.result.changes.length, 1);
  assert.equal(pageTwo.body.result.changes[0].eventId, "pull-event-2");
  assert.equal(pageTwo.body.result.nextCursor, 2);
});

test("synthetic pull rejects anonymous and non-member callers", async () => {
  const user = await createUser();
  const anonymous = await invoke(null, {
    storeId: "receiver-pull-denied", afterVersion: 0, limit: 10,
  }, "pullSyntheticSyncChanges");
  assert.equal(anonymous.body.error.status, "UNAUTHENTICATED");

  const denied = await invoke(user.idToken, {
    storeId: "receiver-pull-denied", afterVersion: 0, limit: 10,
  }, "pullSyntheticSyncChanges");
  assert.equal(denied.body.error.status, "PERMISSION_DENIED");
});


async function invokeInvitation(functionName, idToken, data) {
  return invoke(idToken, data, functionName);
}

test("only the active owner can create a short-lived invitation and code is not stored", async () => {
  const owner = await createUser();
  const storeId = "invitation-owner-only";
  await seedMembership(storeId, owner.localId, "active");
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `stores/${storeId}`), {
      name: "Invitation test store",
      ownerUid: owner.localId,
      schemaVersion: 1,
    });
  });
  const created = await invokeInvitation("createStoreInvitation", owner.idToken, {
    storeId, role: "cashier", expiresInHours: 24, maxUses: 1,
  });
  assert.equal(created.body.result.role, "cashier");
  const code = created.body.result.invitationCode;
  assert.equal(typeof code, "string");
  assert.equal(code.length, 32);

  const attacker = await createUser();
  await seedMembership(storeId, attacker.localId, "active");
  const denied = await invokeInvitation("createStoreInvitation", attacker.idToken, {
    storeId, role: "cashier",
  });
  assert.equal(denied.body.error.status, "PERMISSION_DENIED");
});

test("accepting an invitation creates membership atomically and a second use fails", async () => {
  const owner = await createUser();
  const joiner = await createUser();
  const storeId = "invitation-single-use";
  await seedMembership(storeId, owner.localId, "active");
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `stores/${storeId}`), {
      name: "Invitation test store",
      ownerUid: owner.localId,
      schemaVersion: 1,
    });
  });
  const created = await invokeInvitation("createStoreInvitation", owner.idToken, {
    storeId, role: "viewer", expiresInHours: 24, maxUses: 1,
  });
  const code = created.body.result.invitationCode;
  const accepted = await invokeInvitation("acceptStoreInvitation", joiner.idToken, {
    storeId, invitationCode: code,
  });
  assert.equal(accepted.body.result.role, "viewer");
  assert.equal(accepted.body.result.status, "active");

  const replay = await invokeInvitation("acceptStoreInvitation", joiner.idToken, {
    storeId, invitationCode: code,
  });
  assert.equal(replay.body.error.status, "ALREADY_EXISTS");
});

test("invitation creation rejects invalid roles, overlong expiry, and unauthenticated callers", async () => {
  const owner = await createUser();
  const storeId = "invitation-validation";
  await seedMembership(storeId, owner.localId, "active");
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `stores/${storeId}`), {
      name: "Invitation test store", ownerUid: owner.localId, schemaVersion: 1,
    });
  });
  assert.equal((await invokeInvitation("createStoreInvitation", null, {
    storeId, role: "owner",
  })).body.error.status, "UNAUTHENTICATED");
  assert.equal((await invokeInvitation("createStoreInvitation", owner.idToken, {
    storeId, role: "owner",
  })).body.error.status, "INVALID_ARGUMENT");
  assert.equal((await invokeInvitation("createStoreInvitation", owner.idToken, {
    storeId, role: "cashier", expiresInHours: 999,
  })).body.error.status, "INVALID_ARGUMENT");
});

test("invitation cannot be accepted by an unauthenticated caller or another store", async () => {
  const owner = await createUser();
  const joiner = await createUser();
  const storeId = "invitation-store-binding";
  await seedMembership(storeId, owner.localId, "active");
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `stores/${storeId}`), {
      name: "Invitation test store", ownerUid: owner.localId, schemaVersion: 1,
    });
  });
  const created = await invokeInvitation("createStoreInvitation", owner.idToken, {
    storeId, role: "manager",
  });
  const code = created.body.result.invitationCode;
  assert.equal((await invokeInvitation("acceptStoreInvitation", null, {
    storeId, invitationCode: code,
  })).body.error.status, "UNAUTHENTICATED");
  assert.equal((await invokeInvitation("acceptStoreInvitation", joiner.idToken, {
    storeId: "different-store", invitationCode: code,
  })).body.error.status, "NOT_FOUND");
});


test("owner can revoke an invitation and the code can no longer be accepted", async () => {
  const owner = await createUser();
  const joiner = await createUser();
  const storeId = "invitation-revocation";
  await seedMembership(storeId, owner.localId, "active");
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `stores/${storeId}`), {
      name: "Invitation test store", ownerUid: owner.localId, schemaVersion: 1,
    });
  });
  const created = await invokeInvitation("createStoreInvitation", owner.idToken, {
    storeId, role: "cashier",
  });
  const code = created.body.result.invitationCode;
  const revoked = await invokeInvitation("revokeStoreInvitation", owner.idToken, {
    storeId, invitationCode: code,
  });
  assert.equal(revoked.body.result.revoked, true);
  const accepted = await invokeInvitation("acceptStoreInvitation", joiner.idToken, {
    storeId, invitationCode: code,
  });
  assert.equal(accepted.body.error.status, "FAILED_PRECONDITION");
});


test("single-use invitation cannot be consumed by two accounts concurrently", async () => {
  const owner = await createUser();
  const firstJoiner = await createUser();
  const secondJoiner = await createUser();
  const storeId = "invitation-concurrent-single-use";
  await seedMembership(storeId, owner.localId, "active");
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `stores/${storeId}`), {
      name: "Invitation concurrency test",
      ownerUid: owner.localId,
      schemaVersion: 1,
    });
  });

  const created = await invokeInvitation("createStoreInvitation", owner.idToken, {
    storeId, role: "cashier", expiresInHours: 24, maxUses: 1,
  });
  assert.equal(created.body.result.maxUses, 1);
  const code = created.body.result.invitationCode;
  const attempts = await Promise.all([
    invokeInvitation("acceptStoreInvitation", firstJoiner.idToken, {
      storeId, invitationCode: code,
    }),
    invokeInvitation("acceptStoreInvitation", secondJoiner.idToken, {
      storeId, invitationCode: code,
    }),
  ]);

  const accepted = attempts.filter((result) => result.body.result?.status === "accepted"
    || result.body.result?.role === "cashier");
  const rejected = attempts.filter((result) => result.body.error != null);
  assert.equal(accepted.length, 1, JSON.stringify(attempts));
  assert.equal(rejected.length, 1, JSON.stringify(attempts));
  assert.equal(rejected[0].body.error.status, "FAILED_PRECONDITION");
});
