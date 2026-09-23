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
    final t = ref.watch(textProvider);
    final pending = ref.watch(pendingApprovalCountProvider);

    // No budget of your own means nothing to file an expense against, so the
    // add button is disabled rather than opening a sheet that can only say no.
    // Tapping it still explains why - a dead control with no feedback is worse
    // than no control.
    final canSpend = ref.watch(canSpendProvider);

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),

      // `centerDocked` parks the button on the middle of the bar's top edge.
      // The bar below leaves a gap there for it - the two are set up to match,
      // so changing one means changing the other.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _AddButton(
        enabled: canSpend,
        onPressed: () {
          if (canSpend) {
            showExpenseEditor(context);
          } else {
            // A dead control that does nothing when tapped is worse than no
            // control. It cannot open the sheet, so it explains itself instead.
            showToast(context, t('shell.need_budget'));
          }
        },
        label: t('shell.add_expense'),
      ),

      bottomNavigationBar: _BottomBar(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        pending: pending,
      ),
    );
  }
}

/// The four-tab bar, with a gap in the middle for the add button.
///
/// =============================================================================
/// WHY NOT NavigationBar
/// =============================================================================
/// Material's `NavigationBar` spreads its destinations evenly and has no way to
/// leave a hole in the middle, so the add button would land on top of an icon.
/// Four `Expanded` items either side of a fixed-width spacer is the whole trick.
///
/// `SafeArea(top: false)` keeps the icons clear of the home indicator on
/// phones that have one, without padding the top of the bar as well.
class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.index,
    required this.onSelect,
    required this.pending,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final int pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // Watched rather than read, so switching language in Settings relabels the
    // tabs without a restart.
    final t = ref.watch(textProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _BarItem(
                icon: Icons.pie_chart_outline,
                activeIcon: Icons.pie_chart,
                label: t('shell.tab_overview'),
                selected: index == 0,
                onTap: () => onSelect(0),
              ),
              _BarItem(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet,
                label: t('shell.tab_budgets'),
                selected: index == 1,
                onTap: () => onSelect(1),
              ),
              // The hole the add button sits in.
              const SizedBox(width: 76),
              _BarItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: t('shell.tab_ledger'),
                selected: index == 2,
                onTap: () => onSelect(2),
              ),
              _BarItem(
                icon: Icons.inbox_outlined,
                activeIcon: Icons.inbox,
                label: t('shell.tab_inbox'),
                selected: index == 3,
                badge: pending,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = selected ? colors.accent : colors.inkMuted;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge.count(
                count: badge,
                isLabelVisible: badge > 0,
                backgroundColor: colors.accent,
                textColor: colors.onAccent,
                child: Icon(selected ? activeIcon : icon, size: 21, color: tone),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tone,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round add button, with a ring of page colour around it.
///
/// The ring is what makes the button look like it is punched through the bar
/// rather than stuck on top of it: it hides the bar's hairline where the two
/// overlap. It is drawn as a padded circle behind the button rather than as a
/// border on it, so the button keeps its full size.
class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.enabled,
    required this.onPressed,
    required this.label,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: colors.page, shape: BoxShape.circle),
      child: Material(
        color: enabled ? colors.accent : colors.track,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 62,
            height: 62,
            child: Semantics(
              button: true,
              label: label,
              child: Icon(
                Icons.add,
                size: 26,
                color: enabled ? colors.onAccent : colors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
