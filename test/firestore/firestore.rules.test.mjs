import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, test } from 'node:test';

import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-stellar-pos';
let testEnv;

before(async () => {
  const rules = await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

test('denies reads to unauthenticated clients', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'stores/store-a/products/product-a')));
});

test('denies reads to authenticated clients without a membership policy', async () => {
  const db = testEnv.authenticatedContext('user-a').firestore();
  await assertFails(getDoc(doc(db, 'stores/store-a/products/product-a')));
});

test('denies document creation even for authenticated clients', async () => {
  const db = testEnv.authenticatedContext('user-a').firestore();
  await assertFails(
    setDoc(doc(db, 'stores/store-a/products/product-a'), {
      name: 'Synthetic test product',
    }),
  );
});

test('denies updates and deletes even for authenticated clients', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'stores/store-a/products/product-a'),
      { name: 'Synthetic test product' },
    );
  });

  const db = testEnv.authenticatedContext('user-a').firestore();
  const product = doc(db, 'stores/store-a/products/product-a');
  await assertFails(updateDoc(product, { name: 'Modified test product' }));
  await assertFails(deleteDoc(product));
});


test('allows an atomic store and owner-membership creation for its creator', async () => {
  const db = testEnv.authenticatedContext('owner-a').firestore();
  const store = doc(db, 'stores/store-a');
  const member = doc(db, 'stores/store-a/members/owner-a');
  const batch = db.batch();
  const timestamp = new Date('2026-10-14T12:00:00.000Z');

  batch.set(store, {
    name: 'Tienda de prueba',
    ownerUid: 'owner-a',
    schemaVersion: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
  });
  batch.set(member, {
    uid: 'owner-a',
    role: 'owner',
    status: 'active',
    createdAt: timestamp,
  });

  await batch.commit();
  assert.equal((await getDoc(store)).data().name, 'Tienda de prueba');
  assert.equal((await getDoc(member)).data().role, 'owner');
});

test('denies creating a store without its paired owner membership', async () => {
  const db = testEnv.authenticatedContext('owner-a').firestore();
  await assertFails(setDoc(doc(db, 'stores/store-a'), {
    name: 'Tienda sin membresía',
    ownerUid: 'owner-a',
    schemaVersion: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
  }));
});

test('denies claiming a store with another user as owner', async () => {
  const db = testEnv.authenticatedContext('attacker').firestore();
  const batch = db.batch();
  const timestamp = new Date();
  batch.set(doc(db, 'stores/store-a'), {
    name: 'Tienda ajena',
    ownerUid: 'owner-a',
    schemaVersion: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
  });
  batch.set(doc(db, 'stores/store-a/members/attacker'), {
    uid: 'attacker',
    role: 'owner',
    status: 'active',
    createdAt: timestamp,
  });
  await assertFails(batch.commit());
});

test('does not allow store owners to create arbitrary business records yet', async () => {
  const db = testEnv.authenticatedContext('owner-a').firestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    const batch = adminDb.batch();
    const timestamp = new Date();
    batch.set(doc(adminDb, 'stores/store-a'), {
      name: 'Tienda de prueba',
      ownerUid: 'owner-a',
      schemaVersion: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    batch.set(doc(adminDb, 'stores/store-a/members/owner-a'), {
      uid: 'owner-a',
      role: 'owner',
      status: 'active',
      createdAt: timestamp,
    });
    await batch.commit();
  });

  await assertFails(setDoc(
    doc(db, 'stores/store-a/products/product-a'),
    { name: 'Producto sintético' },
  ));
});
