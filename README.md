# Family Money

A shared budgeting app for two people. Plan the month together, log what you
spend, and both see the same picture of what is left.

Flutter + Firebase (Auth & Firestore). Minimalist interface: one ink colour,
flat surfaces, large figures, colour only where it carries meaning.

---

## What it does

**Connect the two accounts.** You each sign up on your own phone. One of you
creates the household and shows a QR code; the other scans it, or types the
8-character invite code. Codes are single-use and expire in 24 hours.

**Plan budgets.** Two kinds: *monthly* budgets that reset each month, and
*saving pots* that accumulate toward a target. Each budget names one
**controller** - the person who decides how it is split.

**Split into categories.** The controller carves a budget into categories with
an allocation each. The other person is asked to confirm, in their **Inbox**.
Changing an amount later re-opens confirmation; renaming does not.

**Log spending.** Either of you files an expense against any budget and
category. Every entry is visible to both, immediately.

**See where it went.** The overview answers "how much is left" first, then
shows pace against the month, who spent what, and a ranked breakdown by
category.

---

## Getting started

You need Flutter **3.27+**.

This repo holds the Dart source, not the generated platform folders. Create
them once, in the project root - `flutter create` fills in the missing
`android/`, `ios/` etc. without touching `lib/`:

```bash
flutter create . --org com.yourname --platforms=android,ios
flutter pub get
```

Then follow **[docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)** - it walks
through creating the Firebase project, enabling email sign-in, generating
`lib/firebase_options.dart`, and deploying the security rules. The app shows a
"One setup step left" screen until that is done.

```bash
flutter run
```

---

## Layout

```
lib/
  core/            theme, money & period formatting, shared widgets
  models/          Firestore document shapes
  data/            one repository per collection - all queries live here
  state/           Riverpod providers + PeriodSummary, the derived view model
  features/        one folder per screen area
firebase/          security rules and composite indexes
```

Two things are worth knowing before changing anything:

**`PeriodSummary` is the single source of figures.** The hero number, the
meters and the charts are all computed in `lib/state/period_summary.dart` from
the same inputs, so they cannot disagree with each other.

**The rules are the real permission check.** `firebase/firestore.rules`
enforces who controls a budget and who may confirm an allocation. The UI hides
the buttons; the rules are what actually stop it.

---

## Design notes

Colour does one job at a time. Ink and surface carry the layout; green and red
mean money in and money out; the chart slots are a validated, colourblind-safe
sequence used in fixed order. Dark mode is its own set of steps rather than an
inverted copy.

Where money went is a **ranked bar chart**, not a donut: the question is which
category is biggest and by how much, and that is a length comparison. It uses a
single hue - the category name is the identity, so colour has nothing to add -
and folds everything past the sixth row into "Other" rather than inventing more
colours.

The spend meter carries a **pace marker**: the tick shows how far through the
month you are, so "60% spent" can be read against "we're 40% through" without a
second chart.
