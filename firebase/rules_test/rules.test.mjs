import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, setDoc, writeBatch, collection } from 'firebase/firestore';

const HID = 'h1', ME = 'me', HER = 'her';

const env = await initializeTestEnvironment({
  projectId: 'demo-fms',
  firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
});

// Seed a household with me in it, bypassing rules.
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'households', HID), {
    name: 'Home', memberIds: [ME, HER], members: {}, currencyCode: 'IDR',
    monthStartDay: 1, createdBy: ME,
  });
});

const db = env.authenticatedContext(ME).firestore();
const budgets = collection(db, `households/${HID}/budgets`);
const cats = collection(db, `households/${HID}/categories`);

let pass = 0, fail = 0;
const check = async (name, fn) => {
  try { await fn(); console.log('  PASS  ' + name); pass++; }
  catch (e) { console.log('  FAIL  ' + name + '\n        ' + String(e).split('\n')[0]); fail++; }
};

// 1. A monthly budget on its own: one document, no categories.
await check('monthly budget alone is allowed', async () => {
  const ref = doc(budgets);
  await assertSucceeds(setDoc(ref, {
    name: 'Biaya hidup', kind: 'monthly', amount: 5000000,
    controllerId: ME, createdBy: ME, periodKey: '2026-09', archived: false,
  }));
});

// 2. Why BudgetRepository.create does NOT use one batch. A batched write is
//    evaluated against the database as it stands before the batch lands, so
//    controlsBudget()'s get() finds no budget and the rule errors on null.
//    This asserts the refusal, so if Firestore ever changes the semantics the
//    test says so instead of the app silently relying on it.
await check('one batch is refused: the rule cannot see the budget yet', async () => {
  const b = doc(budgets);
  const batch = writeBatch(db);
  batch.set(b, {
    name: 'Tabungan', kind: 'saving', amount: 20000000,
    controllerId: ME, createdBy: ME, periodKey: 'saving', archived: false,
  });
  for (const n of ['Pendidikan', 'Dana darurat', 'Lainnya']) {
    batch.set(doc(cats), {
      budgetId: b.id, name: n, emoji: 'X', allocated: 0, status: 'approved',
      createdBy: ME, confirmedBy: '', decisionNote: '',
    });
  }
  await assertFails(batch.commit());
});

// 3. What the app actually does: budget committed first, then the categories.
await check('budget first, categories second', async () => {
  const b = doc(budgets);
  await setDoc(b, {
    name: 'Tabungan 2', kind: 'saving', amount: 20000000,
    controllerId: ME, createdBy: ME, periodKey: 'saving', archived: false,
  });
  const batch = writeBatch(db);
  for (const n of ['Pendidikan', 'Dana darurat', 'Lainnya']) {
    batch.set(doc(cats), {
      budgetId: b.id, name: n, emoji: 'X', allocated: 0, status: 'approved',
      createdBy: ME, confirmedBy: '', decisionNote: '',
    });
  }
  await assertSucceeds(batch.commit());
});

// 4. The rule still has to refuse a category on someone else's budget.
await check('a category on a budget you do not control is refused', async () => {
  const b = doc(budgets);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `households/${HID}/budgets/${b.id}`), {
      name: 'Hers', kind: 'monthly', amount: 1, controllerId: HER,
      createdBy: HER, periodKey: '2026-09', archived: false,
    });
  });
  await assertFails(setDoc(doc(cats), {
    budgetId: b.id, name: 'Nope', emoji: 'X', allocated: 0, status: 'approved',
    createdBy: ME, confirmedBy: '', decisionNote: '',
  }));
});

console.log(`\n${pass} passed, ${fail} failed`);
await env.cleanup();
process.exit(fail ? 1 : 0);
