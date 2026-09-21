# Firebase setup

Everything the app stores lives in **one Firebase project shared by you and
your wife**. You create it once; she just signs up in the app.

Budget about 20 minutes for the first run.

---

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com> and sign in with a Google
   account. Use an account you are happy to own the project long-term.
2. **Add project** → name it (e.g. `family-money`) → Continue.
3. Google Analytics is not used by this app. Turn it off unless you want it.
4. Wait for "Your new project is ready" → Continue.

> Cost: this app fits comfortably in the free **Spark** plan. Two users writing
> a few dozen documents a day is far below the free daily quota.

---

## 2. Turn on Email/Password sign-in

1. In the left sidebar: **Build → Authentication → Get started**.
2. **Sign-in method** tab → **Email/Password** → enable the first toggle
   (leave "Email link / passwordless" off) → **Save**.

That is the only provider the app uses. If you skip this step, sign-up fails
with *"Email sign-in is not enabled for this Firebase project yet."*

### Optional: let people reset their own password

Nothing to configure - `Forgot password` on the sign-in screen uses Firebase's
built-in reset email. You can reword that email under
**Authentication → Templates**.

---

## 3. Create the Firestore database

1. **Build → Firestore Database → Create database**.
2. Choose a location close to you (for Indonesia, `asia-southeast1` or
   `asia-southeast2`). **This cannot be changed later.**
3. Start in **production mode** - the rules in this repo replace the defaults
   in step 6, and production mode means nothing is publicly readable in the
   meantime.

---

## 4. Register the apps and generate `firebase_options.dart`

First make sure the platform folders exist - this repo ships only the Dart
source, so generate them once in the project root:

```bash
flutter create . --org com.yourname --platforms=android,ios
```

That writes `android/`, `ios/` and the build files without touching `lib/`.

The FlutterFire CLI then does the Firebase side for every platform in one
command.

```bash
# One-time tooling install
npm install -g firebase-tools
dart pub global activate flutterfire_cli

firebase login

# From the project root
flutterfire configure
```

Pick your project, then select the platforms you want (Android and iOS at
minimum). The command:

- creates the Android / iOS / web apps inside the Firebase project,
- writes `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist`,
- **overwrites `lib/firebase_options.dart`** - the placeholder in this repo
  throws a "not configured yet" message until you run it.

> Those API keys are *not* secrets. They identify the project; access is
> controlled by the security rules in step 6. Committing `firebase_options.dart`
> is fine and is what this repo does.

If you add a platform later, re-run `flutterfire configure`.

### If the CLI will not write the file

`flutterfire configure` can run, print nothing alarming, and still leave
`lib/firebase_options.dart` untouched - usually because no platform was ticked
at the checklist (it needs **space**, not Enter).

You do not need the CLI. The file only carries five public identifiers, so
fill them in by hand:

1. Firebase console → **Project settings** (gear icon) → **General**.
2. Under **Your apps**, add an Android app if none is listed. The package name
   must match `applicationId` in `android/app/build.gradle` - by default
   `com.example.family_money_sharing` unless you passed `--org` to
   `flutter create`.
3. Copy these into the constants at the top of `lib/firebase_options.dart`:

   | Constant | Where |
   |---|---|
   | `_projectId` | "Project ID" |
   | `_messagingSenderId` | "Project number" |
   | `_apiKey` | "Web API key" |
   | `_androidAppId` | Your apps → Android app → "App ID" (`1:…:android:…`) |

Then `flutter clean && flutter run`. If anything is still a placeholder the
setup screen names the exact field.

Passing options this way means Auth and Firestore need neither
`google-services.json` nor the Google Services Gradle plugin - the identifiers
go straight from Dart to `Firebase.initializeApp`.

---

## 5. Platform prerequisites

### Android

`android/app/build.gradle` must have a `minSdkVersion` of **23** or higher
(firebase_auth requires it):

```gradle
defaultConfig {
    minSdkVersion 23
}
```

The camera is used for QR pairing. Add to
`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS

In `ios/Podfile`, the platform line must be **12.0** or higher:

```ruby
platform :ios, '13.0'
```

Add the camera usage string to `ios/Runner/Info.plist` - iOS rejects the app
without it:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan your partner's invite code.</string>
```

---

## 6. Deploy the security rules and indexes

**Do not skip this.** Until you deploy them, production mode denies every
read and write and the app will look broken.

```bash
firebase login
firebase use --add          # pick the project you just made, alias it "default"
firebase deploy --only firestore:rules,firestore:indexes
```

`firebase.json` already points at `firebase/firestore.rules` and
`firebase/firestore.indexes.json`.

### What the rules enforce

| Rule | Why |
|---|---|
| A household document is readable only by the uids in its `memberIds` | The whole app is scoped to the household, so membership is the single read gate. |
| Budgets, categories, expenses and approvals inherit that check | One `get()` per request decides access for everything nested under the household. |
| Only a budget's `controllerId` may create, edit or delete its categories | This is feature "who controls each budget", enforced server-side and not just hidden in the UI. |
| Only the member an approval was sent to may decide it, and only by writing `status`, `decisionNote`, `decidedAt` | Stops either side from quietly rewriting what was agreed. |
| Expenses are writable by both members | The ledger is deliberately symmetric; it also lets a deleted category detach entries the other person wrote. |
| Invites are readable by code but **never listable** | The 8-character code is the credential, so codes must not be enumerable. |
| A non-member may add *only themselves* to a household, and only while holding a live invite for it | This is the pairing handshake. The joiner is not a member yet, so the invite code is the proof. |
| A user document is private to its owner | Partner names come from the household's `members` map, so nobody needs read access to anyone else's profile. |

### Testing the rules locally (optional)

```bash
firebase emulators:start --only auth,firestore
```

Then point the app at the emulator by adding this to `main.dart` right after
`Firebase.initializeApp`:

```dart
await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

Remove it before shipping.

---

## 7. Run it

```bash
flutter pub get
flutter run
```

Then, on your phone:

1. **Create an account** - name, email, password.
2. **Start our household** - name it, pick the currency (IDR is the default).
3. **Invite your partner** - the dashboard shows a "Connect your partner" card,
   or use Settings → Partner. A QR code and an 8-character code appear.
4. On your wife's phone: create her own account → **Join my partner** → scan the
   QR, or type the code.

The invite screen closes itself the moment she joins. From then on both phones
see the same budgets, categories and ledger in real time.

---

## Data model

```
users/{uid}
  displayName, email, householdId, createdAt

households/{householdId}
  name, memberIds[], members{uid: {displayName, email}},
  currencyCode, monthStartDay, activeInviteCode, createdBy, createdAt

  budgets/{budgetId}
    name, kind (monthly|saving), amount, controllerId,
    period ("2026-09"), periodKey, targetDate, archived, createdBy

  categories/{categoryId}
    budgetId, name, emoji, allocated,
    status (pending|approved|rejected), createdBy, confirmedBy, decidedAt

  expenses/{expenseId}
    budgetId, categoryId, amount, note, spentBy, spentAt, period

  approvals/{approvalId}
    kind, budgetId, categoryId, title, summary, amount, previousAmount,
    requestedBy, requestedFor, status, decisionNote, decidedAt

invites/{CODE}          <- the document id is the invite code
  householdId, householdName, createdBy, createdByName,
  expiresAt, acceptedBy
```

`periodKey` is `period` for monthly budgets and the literal `saving` for saving
pots, so one query per month picks up both.

---

## Troubleshooting

**"One setup step left" on launch**
`lib/firebase_options.dart` is still the placeholder. Run `flutterfire configure`.

**`permission-denied` everywhere**
The rules were never deployed. Run the `firebase deploy` command in step 6.

**`'firebase' is not recognized` - no CLI, or it is not on PATH**

The Firebase CLI is a separate npm tool (`npm install -g firebase-tools`,
which needs Node.js); being signed in to the console in a browser is not the
same thing.

You can skip it entirely and publish from the console:

1. **Firestore Database → Rules** tab.
2. Copy the whole of `firebase/firestore.rules` from this repo and paste it in,
   replacing what is there.
3. **Publish**.

The indexes have no console paste equivalent, but only one is actually
required - the ledger's month-plus-date query. Either let it fail once and
click the "create index" link in the error, or add it by hand under
**Firestore → Indexes → Composite**: collection `expenses`, `period`
Ascending, `spentAt` Descending, scope Collection.

**"The query requires an index" with a console link**
Either click the link, or run the index deploy in step 6.

**Sign-up fails: "Email sign-in is not enabled"**
Step 2 was skipped.

**Windows: `Could not close incremental caches` / `this and base files have
different roots`**

The project and the Dart pub cache are on different drive letters (say the app
on `G:` and the cache in `C:\Users\<you>\AppData\Local\Pub\Cache`). Kotlin's
incremental compiler stores plugin sources as paths relative to the project,
and Windows has no relative path across drives, so it crashes while writing its
cache. Whichever plugin compiles first takes the blame - usually
`mobile_scanner` - but any Kotlin plugin would do the same.

Fix it properly by putting both on one drive: either move the project to `C:`,
or set a `PUB_CACHE` environment variable to something like `G:\pub-cache` and
run `flutter pub get` to repopulate it.

To just get building now, switch the incremental compiler off in
`android/gradle.properties`:

```properties
kotlin.incremental=false
```

Then `flutter clean && flutter pub get && flutter run`. Rebuilds get slower;
nothing else changes.

**`flutterfire: command not found`**

It installed; it is just not on `PATH`. `dart pub global activate` puts the
executable in the pub cache's `bin` folder and leaves adding it to you.

Run it without `PATH` at all:

```bash
dart pub global run flutterfire_cli:flutterfire configure
```

Or add the folder - on Windows that is
`%LOCALAPPDATA%\Pub\Cache\bin`, or `<PUB_CACHE>\bin` if you moved the cache:

```
setx PATH "%PATH%;%LOCALAPPDATA%\Pub\Cache\bin"
```

Reopen the terminal afterwards. `dart pub global list` confirms whether
`flutterfire_cli` is activated in the first place.

**`Plugin with id 'com.google.gms.google-services' was already requested`**

`flutterfire configure` appends the plugin line to the Gradle files without
checking whether it is already there, so running it more than once leaves
duplicates.

Open `android/app/build.gradle.kts` and delete the repeated
`id("com.google.gms.google-services")` lines until exactly one remains. Check
`android/settings.gradle.kts` for duplicates of its `... version "..." apply
false` line too.

Since this app passes its options from Dart, that plugin is optional: if it
keeps getting in the way - complaining about a missing `google-services.json`,
for instance - delete every `com.google.gms.google-services` line from both
files. Auth and Firestore do not need it.

**Windows: `migrate your plugin to Built-in Kotlin` notice**
A deprecation warning from the plugin, not an error. Harmless - it does not
stop the build.

**The QR scanner is a blank box**
Camera permission was declined, or the permission strings in step 5 are
missing. The typed invite code works either way.

**She scanned the code but nothing happened**
Codes are single-use and last 24 hours. Tap the refresh icon on the invite
screen for a fresh one.
