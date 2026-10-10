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
