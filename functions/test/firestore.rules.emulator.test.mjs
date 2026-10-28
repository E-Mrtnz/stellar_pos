import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { after, before, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from "firebase/firestore";

const projectId = "demo-stellar-pos";
const rulesUrl = new URL("../../firestore.rules", import.meta.url);
let env;

async function seedStore(storeId, ownerUid) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `stores/${storeId}`), {
      name: "Security test store",
      ownerUid,
      schemaVersion: 1,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(db, `stores/${storeId}/members/${ownerUid}`), {
      uid: ownerUid,
      role: "owner",
      status: "active",
      createdAt: new Date(),
    });
  });
}

before(async () => {
  const rules = await readFile(rulesUrl, "utf8");
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

after(async () => {
  await env?.cleanup();
});

test("authenticated owner can create a store and owner membership atomically", async () => {
  const uid = "owner-atomic-create";
  const storeId = "store-atomic-create";
  const db = env.authenticatedContext(uid).firestore();
  const batch = writeBatch(db);

  batch.set(doc(db, `stores/${storeId}`), {
    name: "Tienda de prueba",
    ownerUid: uid,
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(db, `stores/${storeId}/members/${uid}`), {
    uid,
    role: "owner",
    status: "active",
    createdAt: serverTimestamp(),
  });

  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(db, `stores/${storeId}`)));
});

test("store creation without paired owner membership is denied", async () => {
  const uid = "owner-unpaired-create";
  const db = env.authenticatedContext(uid).firestore();

  await assertFails(setDoc(doc(db, "stores/store-unpaired"), {
    name: "Tienda sin membresía",
    ownerUid: uid,
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
});

test("non-members cannot read another store or its membership list", async () => {
  await seedStore("store-private-read", "store-private-owner");
  const strangerDb = env.authenticatedContext("store-private-stranger").firestore();

  await assertFails(getDoc(doc(strangerDb, "stores/store-private-read")));
  await assertFails(getDocs(collection(strangerDb, "stores/store-private-read/members")));
});

test("active members can read store metadata but cannot directly write business or invitation data", async () => {
  await seedStore("store-closed-data", "store-closed-owner");
  const db = env.authenticatedContext("store-closed-owner").firestore();

  await assertSucceeds(getDoc(doc(db, "stores/store-closed-data")));
  await assertFails(setDoc(doc(db, "stores/store-closed-data/products/product-1"), {
    name: "Producto",
  }));
  await assertFails(setDoc(doc(db, "stores/store-closed-data/sales/sale-1"), {
    total: 10,
  }));
  await assertFails(setDoc(doc(db, "stores/store-closed-data/invitations/invite-1"), {
    role: "cashier",
  }));
});

test("members cannot promote themselves or reactivate a revoked membership", async () => {
  await seedStore("store-membership-immutable", "store-membership-owner");
  const db = env.authenticatedContext("store-membership-owner").firestore();
  const membership = doc(db, "stores/store-membership-immutable/members/store-membership-owner");

  await assertFails(updateDoc(membership, { role: "owner" }));
  await assertFails(updateDoc(membership, { status: "revoked" }));
});

test("unauthenticated users cannot read store metadata", async () => {
  await seedStore("store-no-anonymous", "store-no-anonymous-owner");
  const db = env.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(db, "stores/store-no-anonymous")));
});
