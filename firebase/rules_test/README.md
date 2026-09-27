# Firestore rules tests

`flutter test` cannot reach these. A security rule runs on Google's servers, so
the only way to find out what it does is to run it — and a rule that is wrong
fails at the worst possible moment, on a real person's phone, as
`permission denied` with no further explanation.

This suite exists because of one such bug. Creating a saving pot also creates
its three default categories, and all four documents went in a single batch. A
batched write is evaluated against the database **as it stands before the batch
is applied**, so `controlsBudget()`'s `get()` found no budget, reading
`.controllerId` off null failed the rule, and the whole commit was rejected.
Every saving pot was impossible to create. Monthly budgets, which seed no
categories, were fine — which is what made it look like a savings feature bug
rather than a rules one.

Ninety-five Dart tests passed throughout.

## Running it

Needs Node and a JDK (the emulator is a Java process).

```bash
cd firebase/rules_test
npm install
npm test
```

It starts the Firestore emulator, loads `../firestore.rules`, and exits
non-zero if any case fails. Nothing touches the real project: the emulator runs
against a throwaway `demo-` project id and stores nothing.

## What it covers

- a monthly budget, which writes one document, is allowed;
- a budget and its categories in **one batch** is refused — this is the bug
  above, asserted so that if Firestore ever changes the semantics the test
  says so rather than the app quietly depending on it;
- the same writes **split in two**, which is what `BudgetRepository.create`
  now does, are allowed;
- a category filed against a budget you do not control is still refused, so
  the fix did not buy its way out by loosening the rule.

## Adding a case

Append a `check(...)` to `rules.test.mjs`. `assertSucceeds` and `assertFails`
come from `@firebase/rules-unit-testing`; `env.withSecurityRulesDisabled` seeds
fixtures without going through the rules.

Worth adding whenever a rule gets a new condition, and especially before
changing one — these rules are the only thing standing between one member and
the other's money.
