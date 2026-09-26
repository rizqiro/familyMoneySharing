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

**After pulling new code, redeploy the rules**
`firebase/firestore.rules` changes whenever a feature needs a new permission,
and the console copy does not follow along. Recent changes:

| Feature | What the rules gained | Breaks without it? |
|---|---|---|
| Asking your partner for money | the whole `moneyRequests` block | Yes - asking is refused |
| Naming the category a transfer comes out of | `fromCategoryId`, `fromCategoryName` on the decision | **Yes - every approve and decline is refused** |
| Income | `kind` must be `spending` or `income` | No - it only tightens an existing rule |

The middle one is worth understanding, because it is the trap: approving a
request now always writes those two extra fields, and the old rule allows
exactly three keys and no more. So on a stale copy of the rules, tapping
"Send money" fails - even though asking worked a moment earlier.

**`permission-denied` on ONE thing, when everything else works**
The rules ARE deployed, but an older copy of them. Every time
`firebase/firestore.rules` changes in the repo, the copy in the console has to
be replaced - it does not update itself, and nothing warns you.

The symptom is specific: the app works, right up until you touch the feature
whose rules are missing. A collection with no matching rule is denied by
default, so it fails on the very first write.

Known instance: asking your partner for money ("Minta uang") fails with
permission-denied if the deployed rules predate the `moneyRequests` block.

The fix is the same paste as the first time:

1. Firebase Console -> **Firestore Database** -> **Rules**.
2. Select everything in the editor and delete it.
3. Paste the whole of `firebase/firestore.rules` from the repo.
4. **Publish**.

To check before you paste: press Ctrl+F in the rules editor and search for
`moneyRequests`. No match means the deployed copy is out of date.

**"The query requires an index" with a console link**
Either click the link, or run the index deploy in step 6.

**Sign-up fails: "Email sign-in is not enabled"**
Step 2 was skipped.

**Google sign-in: "Google did not return an ID token"**
Three things have to line up, and this error means one of them does not.

1. **Enable Google** as a sign-in provider: Firebase Console -> Authentication
   -> Sign-in method -> Google -> Enable. Set a support email while you are
   there; it will not save without one.
2. **Add your SHA-1 fingerprint** (Android): Project settings -> your Android
   app -> Add fingerprint. Get it with:

   ```
   cd android && ./gradlew signingReport
   ```

   Use the SHA-1 from the `debug` variant while developing. **The release
   fingerprint is different** - when you publish, add the one from Play
   Console -> Setup -> App signing, or Google sign-in will work for you and
   fail for every one of your users.
3. **Download `google-services.json` again** after adding the fingerprint and
   replace `android/app/google-services.json`. The old file does not contain
   the new client and nothing will tell you so.

**Google sign-in opens and immediately closes**
Almost always the SHA-1. See above - it is step 2 that people miss.

**The QR scanner is a blank box**
Camera permission was declined, or the permission strings in step 5 are
missing. The typed invite code works either way.

**She scanned the code but nothing happened**
Codes are single-use and last 24 hours. Tap the refresh icon on the invite
screen for a fresh one.
