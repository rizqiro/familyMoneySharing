import 'package:family_money_sharing/core/format/money.dart';
import 'package:family_money_sharing/core/i18n/app_language.dart';
import 'package:family_money_sharing/core/i18n/app_text.dart';
import 'package:family_money_sharing/core/theme/app_colors.dart';
import 'package:family_money_sharing/core/theme/app_theme.dart';
import 'package:family_money_sharing/core/widgets/budget_tile.dart';
import 'package:family_money_sharing/core/widgets/range_pills.dart';
import 'package:family_money_sharing/core/widgets/spend_chart.dart';
import 'package:family_money_sharing/features/onboarding/splash_page.dart';
import 'package:family_money_sharing/models/budget.dart';
import 'package:family_money_sharing/state/chart_series.dart';
import 'package:family_money_sharing/state/period_summary.dart';
import 'package:family_money_sharing/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Does the new chart and card layout survive a real phone-sized screen?
///
/// =============================================================================
/// WHAT A WIDGET TEST CATCHES THAT THE ANALYZER CANNOT
/// =============================================================================
/// The analyzer checks types. It has no idea whether a `Row` is 12px too wide
/// for the screen it ends up on - that only shows up once something is laid
/// out, as the yellow-and-black overflow stripes.
///
/// In a test those stripes are an exception instead, which `tester.takeException()`
/// hands back. So "pump it and assert nothing was thrown" is a real check of
/// the two riskiest things here:
///
///   * [FullBleed], which deliberately makes a child WIDER than the space it
///     was given, and
///   * the fixed-height budget cards, whose content has to fit whatever the
///     numbers and the language are.
///
/// No Firebase is involved: the handful of providers these widgets read are
/// overridden with fixed values below.
void main() {
  /// A phone. 390x844 is an iPhone 14 / a mid-size Android.
  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Every provider these widgets touch, pinned. Without this the chain
          // walks back to FirebaseAuth.instance and throws.
          textProvider.overrideWithValue(const AppText(AppLanguage.indonesian)),
          moneyProvider.overrideWithValue(Money('IDR')),
          currentUidProvider.overrideWithValue('me'),
          householdProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  Budget budget(String id, {double amount = 8000000, bool saving = false}) =>
      Budget(
        id: id,
        name: 'Belanja Bulanan',
        kind: saving ? BudgetKind.saving : BudgetKind.monthly,
        amount: amount,
        controllerId: 'me',
        period: '2026-09',
        targetDate: null,
        note: '',
        archived: false,
        createdBy: 'me',
        createdAt: null,
      );

  BudgetView view(String id, {double spent = 4760000}) => BudgetView(
        budget: budget(id),
        categories: const [],
        spent: spent,
        uncategorisedSpend: 0,
        transferredIn: 0,
        transferredOut: 0,
      );

  /// A month-shaped series with a projection that overshoots, which exercises
  /// every branch of the burn-up painter at once: the area, the line, the
  /// projection, the shaded overshoot, the dot and the call-out pill.
  const overshooting = SpendSeries(
    range: ChartRange.month,
    points: [
      ChartPoint(value: 180000, label: '1'),
      ChartPoint(value: 760000, label: '5'),
      ChartPoint(value: 1718000, label: '11'),
      ChartPoint(value: 3050000, label: '17'),
      ChartPoint(value: 4760000, label: '22'),
    ],
    reference: 4000000,
    referenceIsCeiling: true,
    todayIndex: 4,
    projected: 6490000,
    spent: 4760000,
    planned: 4000000,
  );

  testWidgets('the burn-up chart lays out full bleed without overflowing',
      (tester) async {
    await pumpPhone(
      tester,
      ListView(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        children: [
          FullBleed(
            height: 212,
            child: SpendChart(
              series: overshooting,
              money: Money('IDR'),
              height: 212,
              semanticLabel: 'chart',
              referenceLabel: 'Anggaran Rp 4 jt',
              calloutLabel: 'Rp 4.760.000',
            ),
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);

    // The whole point of FullBleed: the chart is wider than the padded slot it
    // sits in, and exactly as wide as the screen.
    expect(tester.getSize(find.byType(SpendChart)).width, 390);
  });

  testWidgets('the pace line and legend fit on the detail chart',
      (tester) async {
    await pumpPhone(
      tester,
      ListView(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        children: [
          FullBleed(
            height: 200,
            child: SpendChart(
              series: overshooting,
              money: Money('IDR'),
              height: 200,
              showPaceLine: true,
              semanticLabel: 'chart',
              referenceLabel: 'Anggaran Rp 4 jt',
              calloutLabel: 'Rp 4.760.000',
            ),
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a bar chart with an empty day and a huge day survives',
      (tester) async {
    const bars = SpendSeries(
      range: ChartRange.day,
      points: [
        ChartPoint(value: 0, label: '9'),
        ChartPoint(value: 120000, label: '10'),
        ChartPoint(value: 0, label: '11'),
        ChartPoint(value: 9000000, label: '12'),
      ],
      reference: 267000,
      referenceIsCeiling: false,
      todayIndex: 3,
      projected: 0,
      spent: 9120000,
      planned: 8000000,
    );

    await pumpPhone(
      tester,
      FullBleed(
        height: 176,
        child: SpendChart(
          series: bars,
          money: Money('IDR'),
          height: 176,
          semanticLabel: 'chart',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty series draws nothing rather than dividing by zero',
      (tester) async {
    await pumpPhone(
      tester,
      FullBleed(
        height: 212,
        child: SpendChart(
          series: SpendSeries.empty,
          money: Money('IDR'),
          height: 212,
          semanticLabel: 'chart',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the budget strip fits its fixed height', (tester) async {
    await pumpPhone(
      tester,
      SizedBox(
        height: 178,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Insets.page),
          children: [
            for (final id in ['a', 'bb', 'ccc'])
              Padding(
                padding: const EdgeInsets.only(right: Insets.md),
                child: BudgetMiniCard(view: view(id), onTap: () {}),
              ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(BudgetMiniCard), findsNWidgets(3));
  });

  testWidgets('a full-width tile survives a long name and five chips',
      (tester) async {
    await pumpPhone(
      tester,
      Padding(
        padding: const EdgeInsets.all(Insets.page),
        child: BudgetTile(
          view: view('long-budget-identifier'),
          onTap: () {},
          trailing: const [
            TintChip(label: '5 kategori'),
            TintChip(label: 'Rp 600rb belum dibagi'),
            TintChip(label: '1 menunggu persetujuan'),
            TintChip(label: 'Pembagian melebihi rencana', emphasis: true),
            TintChip(label: 'Sudah lewat anggaran', emphasis: true),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the filter pills render and report the selection',
      (tester) async {
    await pumpPhone(tester, const Padding(
      padding: EdgeInsets.all(Insets.page),
      child: RangePills(),
    ),);

    expect(tester.takeException(), isNull);
    // One segment per range, labelled in the interface language.
    expect(find.text('Harian'), findsOneWidget);
    expect(find.text('Bulanan'), findsOneWidget);
    expect(find.text('Tahunan'), findsOneWidget);

    await tester.tap(find.text('Tahunan'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the splash screen fits a small phone', (tester) async {
    // 320x568 is about the smallest screen still in use. The splash has two
    // Spacers and a fixed block between them, which is exactly the shape that
    // overflows when the screen shrinks.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textProvider.overrideWithValue(const AppText(AppLanguage.indonesian)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SplashPage()),
      ),
    );
    // A single pump, not pumpAndSettle: the progress bar animates forever, so
    // settling would never finish and the test would time out.
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Family Money'), findsOneWidget);
  });

  testWidgets('tints are stable and spread across the ramp', (tester) async {
    const colors = AppColors.light;

    // The same id always gives the same tint - that is what makes a budget's
    // colour something you can learn.
    expect(colors.tintFor('abc123'), same(colors.tintFor('abc123')));

    // And different ids do not all land on one tint.
    final used = {
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'])
        colors.tintFor(id).fill,
    };
    expect(used.length, greaterThan(1));
  });
}
