import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/providers.dart';
import '../approvals/inbox_page.dart';
import '../budgets/budgets_page.dart';
import '../dashboard/dashboard_page.dart';
import '../expenses/expense_editor.dart';
import '../expenses/ledger_page.dart';

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

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showExpenseEditor(context),
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
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
