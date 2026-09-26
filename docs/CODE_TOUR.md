# Code tour

Written for someone who has not used Dart or Flutter before, so you can change
this app yourself. It explains the ideas once, properly, and says which file to
open for what. The files themselves carry the detail in comments.

Read it in order the first time. After that, jump to the section you need.

---

## 1. The shape of the thing

```
lib/
  main.dart        starts the app
  app.dart         decides which screen you are on
  core/            things every screen uses: theme, money, dates, language
  models/          the shape of each kind of document in the database
  data/            every database query, one file per collection
  state/           the glue, and the arithmetic
  features/        one folder per screen area
firebase/          security rules and database indexes
```

The rule to hold onto: **data flows up, events flow down.**

```
Firestore  ->  data/ (queries)  ->  state/ (combine + calculate)  ->  features/ (draw)
                                                                          |
                    a button press calls back down into data/  <----------+
```

A screen never talks to Firestore directly. It reads from `state/`, and calls a
repository in `data/` when you tap something.

---

## 2. Dart in ten minutes

Enough to read this codebase.

**Variables.** `final` means assigned once. Use it by default; `var` only when
something genuinely changes.

```dart
final name = 'Rizqi';     // type inferred as String
var count = 0;            // can be reassigned
count = count + 1;
```

**Null safety.** A `String` can never be null. A `String?` might be.

```dart
String  definitely = 'here';
String? maybe;                    // starts null

maybe?.length                     // null if maybe is null, no crash
maybe ?? 'fallback'               // use the right side when the left is null
maybe!.length                     // "I promise it is not null" - crashes if wrong
```

You will see `?.` and `??` constantly. `!` is rare and deliberate.

**Functions.** Named parameters in `{}`, `required` when they must be supplied.

```dart
void greet({required String name, String greeting = 'Halo'}) {
  print('$greeting, $name');      // $name inserts a variable into a string
}
greet(name: 'Nadia');
```

Named parameters are why Flutter code reads like `Text('hi', style: ...)`.

**Classes.**

```dart
class Budget {
  const Budget({required this.name, required this.amount});
  final String name;
  final double amount;

  bool get isEmpty => amount == 0;   // a computed property, not stored
}
```

`get` defines something that looks like a field but is worked out each time.
`BudgetView.remaining` in `state/period_summary.dart` is one.

**async / await.** Anything touching the network returns a `Future`.

```dart
Future<void> save() async {
  await repository.add(expense);   // pauses here, UI keeps drawing
  print('saved');                  // runs after
}
```

`await` does *not* freeze the app. It parks the rest of the function and lets
Flutter carry on painting.

**Future vs Stream.** A `Future` is one value later. A `Stream` is many values
over time. Firestore's `.snapshots()` returns a Stream, which is why this app
updates live when your partner does something on their phone.

**Collections.**

```dart
final names = items.map((i) => i.name).toList();          // transform
final mine  = items.where((i) => i.isMine).toList();      // filter
final total = items.fold(0.0, (sum, i) => sum + i.amount);// add up
```

`fold` is the one worth staring at: it walks the list carrying a running value.
`period_summary.dart` uses it for every total.

**Records and patterns** (Dart 3, used lightly here):

```dart
final (colour, icon) = switch (status) {
  Status.pending  => (Colors.orange, Icons.schedule),
  Status.approved => (Colors.green,  Icons.check),
};
```

---

## 3. Flutter in ten minutes

**Everything is a widget.** Text, padding, a whole screen. They nest into a
tree.

```dart
Scaffold(                      // the page frame
  appBar: AppBar(title: Text('Budgets')),
  body: Column(                // stack children vertically
    children: [
      Text('Hello'),
      SizedBox(height: 16),    // an empty box = spacing
    ],
  ),
)
```

**`build` runs often, and that is fine.** It returns a *description* of the
screen. Flutter compares it with the previous description and changes only what
differs. Never do slow work in `build`; never worry about calling it.

**Three kinds of widget in this app:**

| Kind | When | Example |
|---|---|---|
| `ConsumerWidget` | draws from shared state, keeps nothing of its own | `DashboardPage` |
| `ConsumerStatefulWidget` | also remembers something local, like what you typed | `ExpenseEditor` |
| `StatelessWidget` | pure drawing, all input passed in | `Meter` |

`setState(() { ... })` is how a stateful widget says "I changed, redraw me".
Change a field without it and the screen will not update.

**Layout you will meet constantly:**

- `Column` / `Row` - stack children down / across.
- `Expanded` - "give me the leftover space". Without it, long text overflows
  and Flutter paints yellow-and-black stripes.
- `Padding`, `SizedBox` - space.
- `Stack` - overlap children, used by the progress meter.

**`const`.** `const Text('Hi')` is built once at compile time and reused
forever. You cannot mark something `const` if any part of it is worked out at
runtime - including `t('some.key')`. If you translate a string inside a `const`
widget, delete the `const`.

**Controllers need disposing.** A `TextEditingController` holds resources:

```dart
final _amount = TextEditingController();

@override
void dispose() {
  _amount.dispose();       // forgetting this leaks memory
  super.dispose();
}
```

---

## 4. Riverpod: how state gets around

Package: `flutter_riverpod`. It answers one question - how does a widget deep
in the tree get hold of the signed-in user, or the database, without every
widget above it passing them down by hand?

A **provider** is a named recipe for a value. All of them live in
`lib/state/providers.dart`.

```dart
final moneyProvider = Provider<Money>((ref) => Money('IDR'));
```

A widget reads it:

```dart
final money = ref.watch(moneyProvider);
```

Two things follow. The recipe runs once and the result is cached, so ten
widgets watching it share one instance. And `watch` subscribes: if the value
changes, every watcher rebuilds, and nothing else does.

**watch vs read.** In `build`, use `watch` - you want to rebuild on change. In
a button callback, use `read` - you want the value once, and a callback cannot
rebuild anyway.

**The three kinds used here:**

- `Provider` - a plain computed value.
- `StreamProvider` - wraps a Stream. Its value is an `AsyncValue<T>`: loading,
  error, or data. `.valueOrNull` grabs the data and gives null otherwise.
- `NotifierProvider` - state the UI changes, like which month you are viewing.

**Providers can watch each other**, and the chain re-runs automatically:

```
authStateProvider        who is signed in
  -> profileProvider     their user document
    -> householdProvider their household
      -> budgetsProvider that household's budgets, for the selected month
        -> summaryProvider  everything added up
```

Sign out and the whole chain tears itself down. This is the single most
important thing to understand about the app.

---

## 5. Firebase and Firestore

Two products in use:

- **Auth** - email and password. Gives every person a permanent `uid`.
- **Firestore** - a document database. Documents live in collections and hold
  JSON-ish data.

The layout is in `firebase/firestore.rules` and `docs/FIREBASE_SETUP.md`.
Household data nests *under* the household document, so membership is the only
access check a rule has to make.

**Queries live in `lib/data/`**, one repository per collection. Screens call
repositories; repositories call Firestore. Keeping it this way means that when
a query needs a database index, you know exactly where to look.

**The security rules are the real permission check.** The UI hides buttons you
may not press; the rules are what actually stop the write. Anyone can modify a
phone app - nobody can modify the rules. Every important restriction in this
app is enforced in both places, on purpose:

| Rule | Where in the UI | Where in the rules |
|---|---|---|
| Only spend from a budget you control | budgets you do not control are not offered | `expenses` create/update |
| Only the controller carves up a budget | the add button is hidden | `categories` create |
| Only the other member confirms an allocation | the inbox only shows yours | `approvals` update |

**Two Firestore quirks worth knowing.** There are no joins - to get "categories
of this month's budgets" you fetch the budgets, then query by their ids (see
`categoriesProvider`). And a query filtering on one field while sorting by
another needs a composite index, declared in `firebase/firestore.indexes.json`.

---

## 6. Where the arithmetic happens

`lib/state/period_summary.dart` is the most important file in the app after the
providers.

Firestore hands over four flat lists: budgets, categories, expenses, money
requests. No screen wants that. The dashboard wants "how much is left in the
budget I control"; a budget card wants "how much of this category is spent".

If each screen added things up itself, two screens would eventually disagree -
one would forget to subtract transfers, or count savings twice - and you would
have a bug that only appears on one tab. So the raw lists are turned into one
`PeriodSummary` object, once, and every screen reads from it.

It touches neither Firestore nor Flutter, so you can reason about it on its
own.

**The one surprising piece.** An approved money request does not edit either
budget. `BudgetView.planned` works out the usable total each time:

```
planned = the amount its controller set
        + transfers in
        - transfers out
```

The reason is permissions: the approver controls the source budget but not the
destination, so a design that edited both would need someone to write a
document they are not allowed to touch. Keeping the transfer as a record both
sides read avoids that entirely. `lib/models/money_request.dart` says the same
thing at length.

---

## 7. Languages

Five: Indonesian (the default), English, Banjar, Javanese, Sundanese.

- `lib/core/i18n/app_language.dart` - the list itself.
- `lib/core/i18n/app_text.dart` - the lookup, plus the complete Indonesian and
  English maps.
- `lib/core/i18n/translations_regional.dart` - Banjar, Javanese, Sundanese.

In a screen:

```dart
final t = ref.watch(textProvider);
Text(t('common.save'))
Text(t('dashboard.spent_of', {'spent': 'Rp 100', 'planned': 'Rp 500'}))
```

**Lookup order:** the chosen language, then Indonesian, then the key itself. So
the regional maps only need the lines someone has actually translated -
everything else quietly reads Indonesian, and nothing is ever blank. If you see
`dashboard.yuor_budgets` on screen, the key is misspelled.

**To fix or add a translation:** find the key in the Indonesian map, add it to
the other language's map, hot restart. No code generation, no build step.

The regional translations were drafted by an AI and need a native speaker's
eye. Lines it was unsure of were left out rather than guessed.

**Dates** follow the chosen language too, via `dateLocaleProvider`. The three
regional languages borrow Indonesian month names, because the `intl` package
ships none for them.

**Known gap:** error messages thrown by `data/` repositories ("That invite has
expired") are still English. To finish the job, have them carry a key the way
`AllocationStatus.labelKey` does, and translate at the point of display.

---

## 8. The design system

- `lib/core/theme/app_colors.dart` - the palette, light and dark.
- `lib/core/theme/app_theme.dart` - how Flutter's widgets are styled, plus the
  `Insets` and `Radii` spacing scales.

The palette is warm: a cream page, a warm near-black ink, one terracotta
accent, and five card tints running butter to rose.

Colour does one job at a time. The tints are **identity** - a budget keeps the
same one forever, picked from its id by `AppColors.tintFor`, so nothing
reshuffles when you add a budget. Meaning is carried separately: the accent is
your money and your spending line, grey is your partner's, green is money put
aside.

The charts break the warm rule on purpose. Two warm hues are the same colour to
a colourblind eye, so any two series that must be told apart are red against
near-black - a lightness difference - and a budget is never a second colour at
all, it is a dashed line. The reasoning is written out at the top of
`app_colors.dart`.

Dark mode is its own set of values rather than an inverted copy.
`context.colors` reaches the palette from any widget.

Reusable pieces live in `lib/core/widgets/`:

- `SoftCard` - the plain container.
- `BudgetTile` / `BudgetMiniCard` - the tinted budget cards, plus `TintChip`
  for chips that sit on a tint.
- `Meter` - the progress bar with its pace tick.
- `RangePills` - the Day / Month / Year filter.
- `SpendChart` and `FullBleed` - the charts. See below.
- `SectionHeader`, `Tag`, `EmptyState`, `Stat` and friends in `common.dart`.

**Money fields.** Every amount input passes `moneyInputFormatters(money)` from
`core/format/money_input.dart`. It keeps the field to digits and groups them as
you type - `12.000.000`, in whatever grouping the household's currency uses.

A numeric keyboard is not enough on its own: some Android keypads show letters
anyway, hardware keyboards ignore the hint, and pasting skips the keyboard
entirely. The formatter is the rule; the keyboard type is a convenience.

The fiddly part is the cursor, which is counted in *digits* rather than
characters - otherwise correcting a digit in the middle throws the caret to the
end as the separators shift underneath. `test/money_input_test.dart` pins all of
it, including that whatever the field shows still parses back to the same
number.

---

## 8b. The charts

Two files, split by what they change for:

- `lib/state/chart_series.dart` - **what the numbers are.** Plain Dart, no
  Flutter, no Firestore. `SpendSeries.daily`, `.monthly` and `.yearly` turn a
  list of expenses into points, a reference line and a projection. Testable on
  its own.
- `lib/core/widgets/spend_chart.dart` - **where the ink goes.** A
  `CustomPainter` per shape. No chart package: these are three shapes and a
  dashed line, and drawing them directly is less code than configuring somebody
  else's defaults.

The filter changes the chart's *shape*, not just its range, because each range
asks a different question:

| Filter | Question | Shape |
|---|---|---|
| Day | which day leaked? | one bar per day, dashed daily allowance |
| Month | will I make it? | cumulative line, dashed ceiling, dotted projection |
| Year | which month was heavy? | one bar per month, hollow bars for months to come |

The budget-detail chart adds a third line: the pace that would land exactly on
budget. Where the projection crosses the ceiling, the overshoot is shaded and a
sentence names the daily figure that would fix it.

**Full bleed.** Charts run edge to edge, through the page's 20px gutter. Flutter
has no negative margins - `Padding` asserts its insets are non-negative - so
`FullBleed` uses an `OverflowBox` to hand the child the full screen width. It
needs an explicit height, because an `OverflowBox` in a scrolling list is
otherwise allowed to be infinitely tall.

**Where a range gets its data.** Day and Month read the month already in
memory, so they cost nothing. Year opens a separate Firestore listener
(`yearExpensesProvider`), and only while the Yearly filter is selected - watch
`chartRangeProvider` before adding anything else that queries a year.

---

## 8c. Money in, money out, and money moved

Three rules decide every figure in the app. All three live in
`lib/state/period_summary.dart`, and the tests for them are in
`test/period_summary_test.dart`.

**1. A ledger entry has a direction.** `Expense.kind` is `spending` or
`income`. One collection, one set of queries, one screen - the direction is the
only thing that differs, so it is one field rather than a second collection.

The field is *nullable*, and that is deliberate. Before income existed, the
only way to put money INTO a saving pot was to file an expense against it. So
an entry with no `kind` means a deposit on a saving pot and an expense
everywhere else, and `Expense.kindIn(saving:)` resolves it. Every entry written
from now on sets the field; this only ever applies to old rows.

That gives each budget two raw totals, `spending` and `income`, and two derived
ones:

| | monthly budget | saving pot |
|---|---|---|
| `available` | plan + income | the target |
| `spent` (what the meter reads) | money out | paid in, less taken back out |
| `remaining` | available − spent | target − saved |

**2. Categories may not add up to more than the budget holds.** The cap is
`BudgetView.headroomExcluding(categoryId)`, and the category editor both shows
it live and refuses to save past it.

Note what is *not* capped: spending. Going over a category's allocation is
recorded exactly as it happened. The limit is on the plan, never on reality - a
budget that refuses to record an overspend is just wrong.

**3. An approved money request is a record, not two edits.** Approving flips
one document's `status`; the transfer is applied when the month is added up.
The approver controls the source budget but not the destination, so a design
that edited both would need somebody to write a document they are not allowed
to touch.

When the source budget has nothing unallocated, the approver also names a
category (`fromCategoryId`), and that category's allocation shrinks by the
amount. Without it, granting from a fully carved budget would leave the
categories adding up to more than the budget holds - exactly the state rule 2
refuses to create.

`PeriodSummary.transfers` carries the whole month's requests, decided and
pending, which is what `TransferHistory` renders in both directions and all
three outcomes.

---

## 9. Recipes

**Add a field to a budget.**
1. `lib/models/budget.dart` - add the field, read it in `fromDoc`, write it in
   `toJson`, add it to `copyWith`.
2. `lib/features/budgets/budget_editor.dart` - add the input.
3. Rules only if it needs protecting.

**Add a screen.**
1. New file under `lib/features/<area>/`.
2. `ConsumerWidget` if it only draws, `ConsumerStatefulWidget` if it has a form.
3. Navigate with
   `Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyPage()))`.

**Add a query.**
1. The method goes in the matching repository in `lib/data/`.
2. Wrap it in a provider in `lib/state/providers.dart`.
3. If Firestore complains about an index, add it to
   `firebase/firestore.indexes.json` and deploy.

**Change a permission.** Edit `firebase/firestore.rules`, then
`firebase deploy --only firestore:rules` - or paste it into the Rules tab in
the console. Until you deploy, nothing changes.

**Add a field that changes the money.** It goes in `PeriodSummary` as a getter,
never in a screen. Two screens doing their own arithmetic is how they come to
disagree, and a disagreement about money looks exactly like a working app.
Then add a test to `test/period_summary_test.dart` - that file is the spec.

**Delete a user's data.** Two pieces, deliberately apart:
`AuthRepository.deleteAccount` erases the profile and the sign-in, and
`HouseholdRepository.departForDeletion` decides what happens to the shared
records. Deleting your own account is always unilateral - an app-store
requirement, and the right default: requiring a partner's approval to leave
would hand them a veto over it. Erasing the SHARED records is a request the
remaining member accepts or refuses, because those are their records too.
Firestore has no cascade, so `eraseEverything` pages through each collection
by hand - "delete my data" has to actually mean it.

**Add a chart.** Add a builder to `SpendSeries` in `state/chart_series.dart`,
a painter in `core/widgets/spend_chart.dart`, and a provider that feeds one to
the other. Keep the arithmetic out of the painter - that split is the only
reason either file is readable.

**Add a language.** Add a value to the `AppLanguage` enum, a map in
`translations_regional.dart`, and a branch in `AppText._tableFor`. The picker
in Settings builds itself from the enum, so it appears automatically.

---

## 10. When something breaks

**Red screen with an exception.** Read the first line; it usually names the
file and line. `setState() called after dispose` means an `await` finished
after the screen closed - guard it with `if (!mounted) return;`.

**`permission-denied`.** The rules rejected the write. Check
`firebase/firestore.rules` for the collection, and confirm the deployed version
matches the file.

**"The query requires an index".** Click the link in the error, or add the
index to `firebase/firestore.indexes.json` and deploy.

**A screen does not update.** Either you used `read` where you needed `watch`,
or you changed a field without `setState`.

**Text shows as a raw key** like `budgets.none_title`. The key is missing from
the Indonesian map, or misspelled at the call site.

Build problems specific to this project - the Windows cross-drive Kotlin
failure, `flutterfire` not being on `PATH` - are in
[docs/FIREBASE_SETUP.md](FIREBASE_SETUP.md) under Troubleshooting.
