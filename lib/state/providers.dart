import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/money.dart';
import '../core/format/period.dart';
import '../data/approval_repository.dart';
import '../data/auth_repository.dart';
import '../data/budget_repository.dart';
import '../data/category_repository.dart';
import '../data/expense_repository.dart';
import '../data/firestore_refs.dart';
import '../data/household_repository.dart';
import '../models/app_user.dart';
import '../models/approval.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/spend_category.dart';
import 'period_summary.dart';

// ---------------------------------------------------------------- Firebase

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

// --------------------------------------------------------------- Identity

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

/// The signed-in user's profile document. Null while signed out or while the
/// document is still being created.
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

final moneyProvider = Provider<Money>((ref) {
  final code =
      ref.watch(householdProvider).valueOrNull?.currencyCode ?? 'IDR';
  return Money(code);
});

// ----------------------------------------------------------------- Period

/// Which month the app is showing. Starts on the household's current period
/// and only moves when the user pages through it.
class SelectedPeriod extends Notifier<Period> {
  @override
  Period build() {
    // Narrowed to the start day on purpose: any other household edit would
    // otherwise snap the user back to the current month mid-browse.
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

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  if (householdId == null) return Stream.value(const []);
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(budgetRepositoryProvider)
      .watchForPeriod(householdId, period.key);
});

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

/// Saving pots show a running total, so they need their entries from every
/// period rather than only the selected one.
final savingExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final householdId = ref.watch(householdIdProvider);
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? const [];
  final savingIds =
      budgets.where((b) => b.isSaving).map((b) => b.id).toList();
  if (householdId == null || savingIds.isEmpty) return Stream.value(const []);
  return ref
      .watch(expenseRepositoryProvider)
      .watchForBudgets(householdId, savingIds);
});

/// The single source every screen reads its figures from.
final summaryProvider = Provider<PeriodSummary>((ref) {
  final household = ref.watch(householdProvider).valueOrNull;
  if (household == null) return PeriodSummary.empty;

  return PeriodSummary.build(
    period: ref.watch(selectedPeriodProvider),
    household: household,
    budgets: ref.watch(budgetsProvider).valueOrNull ?? const [],
    categories: ref.watch(categoriesProvider).valueOrNull ?? const [],
    periodExpenses: ref.watch(periodExpensesProvider).valueOrNull ?? const [],
    savingExpenses: ref.watch(savingExpensesProvider).valueOrNull ?? const [],
  );
});

/// True until the first snapshot of each collection has landed - drives the
/// skeleton rather than a spinner over the whole page.
final summaryLoadingProvider = Provider<bool>((ref) {
  if (ref.watch(householdProvider).isLoading) return true;
  return ref.watch(budgetsProvider).isLoading ||
      ref.watch(periodExpensesProvider).isLoading;
});

// -------------------------------------------------------------- Approvals

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

final pendingApprovalCountProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider).valueOrNull?.length ?? 0,
);

// --------------------------------------------------------------- Lookups

/// Id-keyed views of the period's budgets and categories, so a ledger row can
/// label itself without each tile running its own query.
final budgetLookupProvider = Provider<Map<String, Budget>>((ref) {
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? const [];
  return {for (final b in budgets) b.id: b};
});

final categoryLookupProvider = Provider<Map<String, SpendCategory>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
  return {for (final c in categories) c.id: c};
});
