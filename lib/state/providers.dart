import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/money.dart';
import '../core/format/period.dart';
import '../core/i18n/app_language.dart';
import '../core/i18n/app_text.dart';
import '../data/approval_repository.dart';
import '../data/auth_repository.dart';
import '../data/budget_repository.dart';
import '../data/category_repository.dart';
import '../data/expense_repository.dart';
import '../data/firestore_refs.dart';
import '../data/household_repository.dart';
import '../data/money_request_repository.dart';
import '../models/app_user.dart';
import '../models/approval.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/money_request.dart';
import '../models/spend_category.dart';
import 'period_summary.dart';

/// Every piece of shared state in the app, in dependency order.
///
/// =============================================================================
/// RIVERPOD IN FIVE MINUTES
/// =============================================================================
/// The package is `flutter_riverpod`. It answers one question: how does a widget
/// deep in the tree get hold of something - the signed-in user, the database -
/// without every widget above it passing it down by hand?
///
/// A **provider** is a named recipe for a value:
///
///   final moneyProvider = Provider<Money>((ref) => Money('IDR'));
///
/// A widget reads it with `ref.watch(moneyProvider)`. Two things follow:
///
///   1. The recipe runs once and the result is cached. Ten widgets watching it
///      share one instance.
///   2. "watch" also subscribes. If the value changes, every watcher rebuilds -
///      and nothing else does.
///
/// The three kinds used here:
///
///   * `Provider`        - a plain computed value.
///   * `StreamProvider`  - wraps a Stream. Its value is an `AsyncValue<T>`,
///                         which is either loading, an error, or data. That
///                         forces you to decide what a screen shows while the
///                         network is still thinking.
///   * `NotifierProvider`- state someone can change from the UI (the month you
///                         are looking at).
///
/// **watch vs read.** Inside `build`, use `ref.watch` - you want to rebuild when
/// the value changes. Inside a button callback, use `ref.read` - you want the
/// value once, and a callback cannot rebuild anyway.
///
/// Providers may watch each other, and the chain re-runs automatically. Here the
/// chain is: signed-in user -> their profile -> their household -> that
/// household's budgets -> the month's summary. Sign out and the whole chain
/// tears itself down.
// -----------------------------------------------------------------------------

// --------------------------------------------------------------- Firebase

/// The Firebase SDK objects, wrapped in providers so a test can swap them for
/// fakes without any other file knowing.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final refsProvider = Provider<FirestoreRefs>(
  (ref) => FirestoreRefs(ref.watch(firestoreProvider)),
);

// ------------------------------------------------------------ Repositories

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(refsProvider),
  ),
);

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(
    ref.watch(firestoreProvider),
    ref.watch(refsProvider),
  ),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(
    ref.watch(firestoreProvider),
    ref.watch(refsProvider),
  ),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(
    ref.watch(firestoreProvider),
    ref.watch(refsProvider),
  ),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    ref.watch(firestoreProvider),
    ref.watch(refsProvider),
  ),
);

final approvalRepositoryProvider = Provider<ApprovalRepository>(
  (ref) => ApprovalRepository(
    ref.watch(firestoreProvider),
    ref.watch(refsProvider),
  ),
);

final moneyRequestRepositoryProvider = Provider<MoneyRequestRepository>(
  (ref) => MoneyRequestRepository(
    ref.watch(firestoreProvider),
    ref.watch(refsProvider),
  ),
);

// --------------------------------------------------------------- Identity

/// Emits a `User` when signed in and null when signed out. The app's root
/// listens to this and swaps between the sign-in screen and the main shell.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// `valueOrNull` reads the data out of an AsyncValue, giving null while it is
/// still loading or if it failed. Convenient where "not yet" and "nobody" can
/// be treated the same.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

/// The signed-in user's profile document, live.
final profileProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});

final householdIdProvider = Provider<String?>(
  (ref) => ref.watch(profileProvider).valueOrNull?.householdId,
);

final householdProvider = StreamProvider<Household?>((ref) {
  final id = ref.watch(householdIdProvider);
  if (id == null || id.isEmpty) return Stream.value(null);
  return ref.watch(householdRepositoryProvider).watch(id);
});

/// The other member, or null while the household is still a party of one.
final partnerProvider = Provider<HouseholdMember?>((ref) {
  final household = ref.watch(householdProvider).valueOrNull;
  final uid = ref.watch(currentUidProvider);
  if (household == null || uid == null) return null;
  return household.partnerOf(uid);
});

// --------------------------------------------------------------- Language

/// What the phone itself is set to, used before anyone has chosen.
///
/// Set once at startup in `main.dart` - reading it from a provider rather than
/// a global keeps it swappable in tests.
final deviceLanguageProvider = Provider<AppLanguage>(
  (ref) => AppLanguage.indonesian,
);

/// The language the interface is drawn in.
///
/// It comes off the signed-in user's own profile, so the two partners can read
/// the app in different languages. Before sign-in, or while the profile is
/// still loading, the device's own setting stands in.
///
/// Because it is a provider, changing it in Settings writes to Firestore, the
/// profile stream emits, this recomputes, and every screen watching
/// [textProvider] rebuilds in the new language. No restart, no manual refresh.
final languageProvider = Provider<AppLanguage>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  return profile?.language ?? ref.watch(deviceLanguageProvider);
});

/// The text lookup. `final t = ref.watch(textProvider);` then `t('some.key')`.
final textProvider = Provider<AppText>(
  (ref) => AppText(ref.watch(languageProvider)),
);

/// Which locale `intl` should format dates with.
///
/// Passed explicitly to every `DateFormat` call rather than set as a global,
/// so the date language can never drift out of step with the interface
/// language. The three regional languages borrow Indonesian here, because
/// `intl` ships no month names for them.
final dateLocaleProvider = Provider<String>(
  (ref) => ref.watch(languageProvider).intlLocale,
);

/// The number formatter for the household's currency. Because it is derived
/// from the household document, changing the currency in Settings reformats
/// every figure in the app at once.
final moneyProvider = Provider<Money>((ref) {
  final code = ref.watch(householdProvider).valueOrNull?.currencyCode ?? 'IDR';
  return Money(code);
});

// ----------------------------------------------------------------- Period

/// Which month the app is showing.
///
/// A `Notifier` is Riverpod's class for state with methods that change it.
/// `build()` returns the starting value; assigning to `state` notifies every
/// watcher.
class SelectedPeriod extends Notifier<Period> {
  @override
  Period build() {
    // Narrowed with `.select` on purpose: this rebuilds only when the start day
    // changes, not on every household edit. Without it, renaming the household
    // would snap the user back to the current month mid-browse.
    final startDay = ref.watch(
      householdProvider.select((h) => h.valueOrNull?.monthStartDay ?? 1),
    );
    return Period.current(monthStartDay: startDay);
  }

  void next() => state = state.next();

  void previous() => state = state.previous();

  void today() {
    final startDay =
        ref.read(householdProvider).valueOrNull?.monthStartDay ?? 1;
    state = Period.current(monthStartDay: startDay);
  }
}

final selectedPeriodProvider =
    NotifierProvider<SelectedPeriod, Period>(SelectedPeriod.new);

// ------------------------------------------------------------------- Data

/// This month's budgets. Re-queries whenever the selected month changes,
/// because it watches [selectedPeriodProvider].
final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  if (householdId == null) return Stream.value(const []);
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(budgetRepositoryProvider)
      .watchForPeriod(householdId, period.key);
});

/// Categories for this month's budgets.
///
/// Depends on [budgetsProvider] because Firestore has no joins: you cannot ask
/// for "categories of this month's budgets" in one query, so the budget ids are
/// fetched first and fed into a second query.
final categoriesProvider = StreamProvider<List<SpendCategory>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? const [];
  if (householdId == null || budgets.isEmpty) return Stream.value(const []);
  return ref.watch(categoryRepositoryProvider).watchForBudgets(
        householdId,
        budgets.map((b) => b.id).toList(),
      );
});

final periodExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  if (householdId == null) return Stream.value(const []);
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(expenseRepositoryProvider)
      .watchForPeriod(householdId, period.key);
});

/// Saving pots show a running total, so they need every month's entries rather
/// than only the selected one.
final savingExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? const [];
  final savingIds = budgets.where((b) => b.isSaving).map((b) => b.id).toList();
  if (householdId == null || savingIds.isEmpty) return Stream.value(const []);
  return ref
      .watch(expenseRepositoryProvider)
      .watchForBudgets(householdId, savingIds);
});

/// Approved transfers for the month - what moves money between the two members.
final approvedTransfersProvider = StreamProvider<List<MoneyRequest>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  if (householdId == null) return Stream.value(const []);
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(moneyRequestRepositoryProvider)
      .watchApprovedForPeriod(householdId, period.key);
});

/// The single object every screen reads its figures from.
///
/// A plain `Provider`, not a StreamProvider: it has no stream of its own, it
/// just combines the five above. Riverpod re-runs it whenever any of them
/// emits, so it always reflects the latest of everything.
final summaryProvider = Provider<PeriodSummary>((ref) {
  final household = ref.watch(householdProvider).valueOrNull;
  if (household == null) return PeriodSummary.empty;

  return PeriodSummary.build(
    period: ref.watch(selectedPeriodProvider),
    household: household,
    viewerUid: ref.watch(currentUidProvider),
    budgets: ref.watch(budgetsProvider).valueOrNull ?? const [],
    categories: ref.watch(categoriesProvider).valueOrNull ?? const [],
    periodExpenses: ref.watch(periodExpensesProvider).valueOrNull ?? const [],
    savingExpenses: ref.watch(savingExpensesProvider).valueOrNull ?? const [],
    approvedTransfers:
        ref.watch(approvedTransfersProvider).valueOrNull ?? const [],
  );
});

/// True until the first snapshot of each collection has landed. Drives a
/// skeleton placeholder rather than a spinner over the whole page.
final summaryLoadingProvider = Provider<bool>((ref) {
  if (ref.watch(householdProvider).isLoading) return true;
  return ref.watch(budgetsProvider).isLoading ||
      ref.watch(periodExpensesProvider).isLoading;
});

/// Whether the viewer controls any budget they could spend from.
///
/// The add button and the expense sheet both read this: no budget of your own
/// means nothing to file an expense against.
final canSpendProvider = Provider<bool>(
  (ref) => !ref.watch(summaryProvider).hasNothingToSpend,
);

// -------------------------------------------------------------- Approvals

/// Category allocations waiting on the viewer.
final inboxProvider = StreamProvider<List<Approval>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  final uid = ref.watch(currentUidProvider);
  if (householdId == null || uid == null) return Stream.value(const []);
  return ref.watch(approvalRepositoryProvider).watchInbox(householdId, uid);
});

final outboxProvider = StreamProvider<List<Approval>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  final uid = ref.watch(currentUidProvider);
  if (householdId == null || uid == null) return Stream.value(const []);
  return ref.watch(approvalRepositoryProvider).watchOutbox(householdId, uid);
});

/// Money requests waiting on the viewer to approve or decline.
final moneyInboxProvider = StreamProvider<List<MoneyRequest>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  final uid = ref.watch(currentUidProvider);
  if (householdId == null || uid == null) return Stream.value(const []);
  return ref.watch(moneyRequestRepositoryProvider).watchInbox(householdId, uid);
});

/// Money requests the viewer has sent and not heard back on.
final moneyOutboxProvider = StreamProvider<List<MoneyRequest>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  final uid = ref.watch(currentUidProvider);
  if (householdId == null || uid == null) return Stream.value(const []);
  return ref.watch(moneyRequestRepositoryProvider).watchOutbox(householdId, uid);
});

/// The badge on the Inbox tab: both kinds of pending decision.
final pendingApprovalCountProvider = Provider<int>((ref) {
  final categories = ref.watch(inboxProvider).valueOrNull?.length ?? 0;
  final money = ref.watch(moneyInboxProvider).valueOrNull?.length ?? 0;
  return categories + money;
});

// --------------------------------------------------------------- Lookups

/// Id-keyed views of the month's budgets and categories, so a ledger row can
/// label itself without every tile running its own query.
final budgetLookupProvider = Provider<Map<String, Budget>>((ref) {
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? const [];
  // A "collection for" - builds a map by walking a list. Equivalent to a loop
  // that does `map[b.id] = b` for each entry.
  return {for (final b in budgets) b.id: b};
});

final categoryLookupProvider = Provider<Map<String, SpendCategory>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
  return {for (final c in categories) c.id: c};
});
