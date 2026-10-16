import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";

const projectId = "demo-stellar-pos";
const authBase = "http://127.0.0.1:9099";
const functionUrl = "http://127.0.0.1:5001/demo-stellar-pos/us-central1/acceptSyntheticSyncEvent";
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

async function invoke(idToken, data) {
  const response = await fetch(functionUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  return { status: response.status, body: await response.json() };
}

before(async () => {
  env = await initializeTestEnvironment({ projectId });
});

after(async () => {
  await env?.cleanup();
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
