import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, test } from 'node:test';

import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
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

test('allows a user to list only their own active store memberships', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = db.batch();
    const timestamp = new Date();
    for (const [storeId, uid, status] of [
      ['store-a', 'user-a', 'active'],
      ['store-b', 'user-a', 'active'],
      ['store-c', 'user-b', 'active'],
      ['store-d', 'user-a', 'revoked'],
    ]) {
      batch.set(doc(db, `stores/${storeId}/members/${uid}`), {
        uid,
        role: 'owner',
        status,
        createdAt: timestamp,
      });
    }
    await batch.commit();
  });

  const db = testEnv.authenticatedContext('user-a').firestore();
  const ownMemberships = query(
    collectionGroup(db, 'members'),
    where('uid', '==', 'user-a'),
    where('status', '==', 'active'),
  );
  const result = await getDocs(ownMemberships);
  assert.equal(result.size, 2);
  assert.deepEqual(
    result.docs.map((membership) => membership.data().uid),
    ['user-a', 'user-a'],
  );
});

test('denies unbounded collection-group membership queries', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'stores/store-a/members/user-a'), {
      uid: 'user-a', role: 'owner', status: 'active', createdAt: new Date(),
    });
  });

  const db = testEnv.authenticatedContext('user-a').firestore();
  await assertFails(getDocs(collectionGroup(db, 'members')));
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


test('denies clients direct access to remote sync events and idempotency receipts', async () => {
  const storeId = 'sync-receipt-boundary-store';
  const uid = 'sync-receipt-boundary-owner';
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = db.batch();
    const timestamp = new Date();
    batch.set(doc(db, `stores/${storeId}`), {
      name: 'Tienda sintética',
      ownerUid: uid,
      schemaVersion: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    batch.set(doc(db, `stores/${storeId}/members/${uid}`), {
      uid, role: 'owner', status: 'active', createdAt: timestamp,
    });
    batch.set(doc(db, `stores/${storeId}/syncReceipts/event-1`), {
      eventId: 'event-1', fingerprint: 'synthetic-fingerprint', result: 'applied',
    });
    batch.set(doc(db, `stores/${storeId}/syncEvents/event-1`), {
      eventId: 'event-1', status: 'applied',
    });
    await batch.commit();
  });

  const db = testEnv.authenticatedContext(uid).firestore();
  await assertFails(getDoc(doc(db, `stores/${storeId}/syncReceipts/event-1`)));
  await assertFails(setDoc(doc(db, `stores/${storeId}/syncReceipts/event-2`), {
    eventId: 'event-2', fingerprint: 'forged', result: 'applied',
  }));
  await assertFails(getDoc(doc(db, `stores/${storeId}/syncEvents/event-1`)));
  await assertFails(setDoc(doc(db, `stores/${storeId}/syncEvents/event-2`), {
    eventId: 'event-2', status: 'applied',
  }));
});

test('denies invitation creation and access until a trusted acceptance flow exists', async () => {
  const db = testEnv.authenticatedContext('owner-a').firestore();
  await assertFails(setDoc(
    doc(db, 'stores/store-a/invitations/invite-a'),
    {
      tokenHash: 'synthetic-hash',
      status: 'pending',
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 60_000),
    },
  ));
  await assertFails(getDoc(doc(db, 'stores/store-a/invitations/invite-a')));
});

test('denies store metadata changes and membership role escalation', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = db.batch();
    const timestamp = new Date();
    batch.set(doc(db, 'stores/store-a'), {
      name: 'Tienda protegida',
      ownerUid: 'owner-a',
      schemaVersion: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    batch.set(doc(db, 'stores/store-a/members/owner-a'), {
      uid: 'owner-a',
      role: 'owner',
      status: 'active',
      createdAt: timestamp,
    });
    await batch.commit();
  });

  const ownerDb = testEnv.authenticatedContext('owner-a').firestore();
  await assertFails(updateDoc(doc(ownerDb, 'stores/store-a'), {
    name: 'Nombre alterado',
  }));
  await assertFails(updateDoc(doc(ownerDb, 'stores/store-a/members/owner-a'), {
    role: 'admin',
  }));
  await assertFails(deleteDoc(doc(ownerDb, 'stores/store-a/members/owner-a')));
});

test('denies a user from creating their own elevated or additional membership', async () => {
  const db = testEnv.authenticatedContext('user-a').firestore();
  await assertFails(setDoc(doc(db, 'stores/store-a/members/user-a'), {
    uid: 'user-a',
    role: 'owner',
    status: 'active',
    createdAt: new Date(),
  }));
  await assertFails(setDoc(doc(db, 'stores/store-a/members/user-b'), {
    uid: 'user-b',
    role: 'admin',
    status: 'active',
    createdAt: new Date(),
  }));
});


test('an active member cannot read another store without membership', async () => {
  const ownStoreId = 'boundary-own-store';
  const foreignStoreId = 'boundary-foreign-store';
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const timestamp = new Date();
    const batch = db.batch();
    batch.set(doc(db, `stores/${ownStoreId}`), {
      name: 'Tienda propia sintética',
      ownerUid: 'user-a',
      schemaVersion: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    batch.set(doc(db, `stores/${ownStoreId}/members/user-a`), {
      uid: 'user-a', role: 'owner', status: 'active', createdAt: timestamp,
    });
    batch.set(doc(db, `stores/${foreignStoreId}`), {
      name: 'Tienda ajena sintética',
      ownerUid: 'user-b',
      schemaVersion: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    batch.set(doc(db, `stores/${foreignStoreId}/members/user-b`), {
      uid: 'user-b', role: 'owner', status: 'active', createdAt: timestamp,
    });
    await batch.commit();
  });

  const db = testEnv.authenticatedContext('user-a').firestore();
  assert.equal((await getDoc(doc(db, `stores/${ownStoreId}`))).data().name, 'Tienda propia sintética');
  await assertFails(getDoc(doc(db, `stores/${foreignStoreId}`)));
});

test('an active member cannot read another store\'s membership document', async () => {
  const ownStoreId = 'membership-boundary-own-store';
  const foreignStoreId = 'membership-boundary-foreign-store';
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const timestamp = new Date();
    const batch = db.batch();
    for (const [storeId, uid] of [[ownStoreId, 'user-a'], [foreignStoreId, 'user-b']]) {
      batch.set(doc(db, `stores/${storeId}`), {
        name: storeId,
        ownerUid: uid,
        schemaVersion: 1,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
      batch.set(doc(db, `stores/${storeId}/members/${uid}`), {
        uid, role: 'owner', status: 'active', createdAt: timestamp,
      });
    }
    await batch.commit();
  });

  const db = testEnv.authenticatedContext('user-a').firestore();
  await assertFails(getDoc(doc(db, `stores/${foreignStoreId}/members/user-b`)));
});

test('active membership does not enable writes to synthetic sync-event documents', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const timestamp = new Date();
    const batch = db.batch();
    batch.set(doc(db, 'stores/store-a'), {
      name: 'Tienda de prueba',
      ownerUid: 'owner-a',
      schemaVersion: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    batch.set(doc(db, 'stores/store-a/members/owner-a'), {
      uid: 'owner-a', role: 'owner', status: 'active', createdAt: timestamp,
    });
    await batch.commit();
  });

  const db = testEnv.authenticatedContext('owner-a').firestore();
  await assertFails(setDoc(doc(db, 'stores/store-a/syncEvents/event-1'), {
    eventId: 'event-1',
    storeId: 'store-a',
    entityType: 'synthetic',
    entityId: 'synthetic-1',
    operation: 'create',
    createdAt: new Date(),
  }));
});

test('a revoked member cannot read store metadata or its own membership', async () => {
  const storeId = 'revoked-membership-boundary';
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const timestamp = new Date();
    const batch = db.batch();
    batch.set(doc(db, `stores/${storeId}`), {
      name: 'Tienda con acceso revocado',
      ownerUid: 'user-a',
      schemaVersion: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    batch.set(doc(db, `stores/${storeId}/members/user-a`), {
      uid: 'user-a',
      role: 'owner',
      status: 'revoked',
      createdAt: timestamp,
    });
    await batch.commit();
  });

  const db = testEnv.authenticatedContext('user-a').firestore();
  await assertFails(getDoc(doc(db, `stores/${storeId}`)));
  await assertFails(getDoc(doc(db, `stores/${storeId}/members/user-a`)));
});

