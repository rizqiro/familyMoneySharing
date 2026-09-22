import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../state/providers.dart';
import '../approvals/inbox_page.dart';
import '../budgets/budgets_page.dart';
import '../dashboard/dashboard_page.dart';
import '../expenses/expense_editor.dart';
import '../expenses/ledger_page.dart';

/// The four-tab frame the app lives in once you are signed in and paired.
///
/// The tabs are held in an `IndexedStack` rather than swapped out: it builds all
/// four and shows one, so switching tabs keeps each page's scroll position and
/// filter selection. Swapping widgets instead would reset them every time.
///
/// `ConsumerStatefulWidget` because the selected tab is local state (nobody else
/// needs to know about it) while the badge count comes from a provider.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardPage(),
    BudgetsPage(),
    LedgerPage(),
    InboxPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pending = ref.watch(pendingApprovalCountProvider);

    // No budget of your own means nothing to file an expense against, so the
    // add button is disabled rather than opening a sheet that can only say no.
    // Tapping it still explains why - a dead control with no feedback is worse
    // than no control.
    final canSpend = ref.watch(canSpendProvider);

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (canSpend) {
            showExpenseEditor(context);
          } else {
            showToast(
              context,
              'Create a budget of your own first, or ask for money.',
            );
          }
        },
        backgroundColor: canSpend ? colors.accent : colors.track,
        foregroundColor: canSpend ? colors.onAccent : colors.inkMuted,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.hairline)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          // setState tells Flutter this widget's state changed, so it should
          // rebuild. Without it the field changes but the screen does not.
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: 'Overview',
            ),
            const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Budgets',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Ledger',
            ),
            NavigationDestination(
              // Counts both kinds of pending decision: category allocations and
              // money requests.
              icon: Badge.count(
                count: pending,
                isLabelVisible: pending > 0,
                backgroundColor: colors.negative,
                child: const Icon(Icons.inbox_outlined),
              ),
              selectedIcon: Badge.count(
                count: pending,
                isLabelVisible: pending > 0,
                backgroundColor: colors.negative,
                child: const Icon(Icons.inbox),
              ),
              label: 'Inbox',
            ),
          ],
        ),
      ),
    );
  }
}
