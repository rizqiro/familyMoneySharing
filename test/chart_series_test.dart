import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_money_sharing/core/format/period.dart';
import 'package:family_money_sharing/models/expense.dart';
import 'package:family_money_sharing/state/chart_series.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the numbers behind the charts.
///
/// =============================================================================
/// WHY THESE ARE WORTH HAVING AND WIDGET TESTS ARE NOT (YET)
/// =============================================================================
/// `SpendSeries` is plain Dart: give it expenses, get back points. No Flutter,
/// no Firestore, so a test runs in milliseconds and fails for exactly one
/// reason - the arithmetic changed.
///
/// The screens, by contrast, would need a fake Firebase and a fake signed-in
/// user before they would even build. That is worth doing one day; it is not
/// worth blocking this on.
///
/// Run them with `flutter test`.
void main() {
  /// Builds an expense on a given day of a month.
  ///
  /// A helper rather than a literal at every call site: the model has eight
  /// fields and only two of them matter here, so inlining it would bury the
  /// point of each test in noise.
  Expense on(
    int day,
    double amount, {
    int year = 2025,
    int month = 9,
    String budgetId = 'b1',
  }) =>
      Expense(
        id: 'e-$year-$month-$day-${amount.toInt()}',
        budgetId: budgetId,
        categoryId: '',
        amount: amount,
        note: '',
        spentBy: 'me',
        spentAt: DateTime(year, month, day),
        period: '$year-${month.toString().padLeft(2, '0')}',
        createdAt: null,
      );

  /// A month that is definitely over, whenever these tests are run.
  ///
  /// The builders behave differently for the month in progress - they stop at
  /// today and project forward - so a test that wants a whole month has to pick
  /// one in the past, or it starts failing on its own next month.
  const period = Period(2025, 9);

  group('SpendSeries.monthly', () {
    test('accumulates day by day and never goes down', () {
      final series = SpendSeries.monthly(
        period: period,
        monthStartDay: 1,
        expenses: [on(1, 100), on(3, 50), on(3, 25), on(5, 200)],
        planned: 1000,
      );

      // A past month runs to its full length, so September gives 30 points.
      expect(series.points.length, 30);
      expect(series.points[0].value, 100); // day 1
      expect(series.points[1].value, 100); // day 2, nothing spent
      expect(series.points[2].value, 175); // day 3, two entries
      expect(series.points[4].value, 375); // day 5
      expect(series.spent, 375);

      // The defining property of a burn-up: it only ever climbs.
      for (var i = 1; i < series.points.length; i++) {
        expect(
          series.points[i].value,
          greaterThanOrEqualTo(series.points[i - 1].value),
        );
      }
    });

    test('a finished month has no projection and no today marker', () {
      final series = SpendSeries.monthly(
        period: period,
        monthStartDay: 1,
        expenses: [on(1, 100)],
        planned: 1000,
      );

      // The month is over, so there is nothing to project toward.
      expect(series.projected, 0);
      expect(series.todayIndex, -1);
      expect(series.projectedOverspend, 0);
    });

    test('the month in progress stops at today and projects forward', () {
      final now = DateTime.now();
      final current = Period.current();
      final series = SpendSeries.monthly(
        period: current,
        monthStartDay: 1,
        expenses: [on(1, 1000, year: now.year, month: now.month)],
        planned: 100000,
      );

      // The line stops at today rather than running to the end of the month:
      // the empty space to the right is how much month is left.
      expect(series.points.length, current.elapsedDays());
      expect(series.todayIndex, series.points.length - 1);

      // Spent on day one and nothing since, so the projection is that one
      // amount stretched over the whole month.
      expect(series.projected, greaterThan(0));
      expect(
        series.projected,
        closeTo(1000 / series.points.length * current.lengthInDays(), 0.001),
      );
    });

    test('maxValue leaves room for the budget even when nothing was spent', () {
      final series = SpendSeries.monthly(
        period: period,
        monthStartDay: 1,
        expenses: const [],
        planned: 1000,
      );

      // Without this the chart would scale to zero and divide by it.
      expect(series.maxValue, 1000);
    });
  });

  group('SpendSeries.daily', () {
    test('buckets by day and keeps the requested window', () {
      final series = SpendSeries.daily(
        period: period,
        monthStartDay: 1,
        expenses: [on(20, 300), on(28, 100), on(28, 50)],
        planned: 3000,
        days: 7,
      );

      // The last seven days of September: the 24th to the 30th.
      expect(series.points.length, 7);
      expect(series.points.first.label, '24');
      expect(series.points.last.label, '30');

      // The 20th falls outside the window, so it is not drawn - but the total
      // still counts every expense handed in.
      final drawn = series.points.fold(0.0, (running, p) => running + p.value);
      expect(drawn, 150);
      expect(series.spent, 450);
    });

    test('the reference line is the budget spread evenly over the month', () {
      final series = SpendSeries.daily(
        period: period,
        monthStartDay: 1,
        expenses: const [],
        planned: 3000,
      );

      // September has 30 days.
      expect(series.reference, 100);
      expect(series.referenceIsCeiling, isFalse);
    });
  });

  group('SpendSeries.yearly', () {
    test('totals by month and marks the ones still to come', () {
      final series = SpendSeries.yearly(
        year: 2025,
        expenses: [
          on(5, 400),
          on(20, 600),
          on(2, 900, month: 3),
        ],
        monthlyBudget: 3000,
        locale: 'en_US',
      );

      expect(series.points.length, 12);
      expect(series.points[2].value, 900); // March
      expect(series.points[8].value, 1000); // September, both entries
      expect(series.spent, 1900);

      // 2025 is over, so no month is in the future and none is drawn hollow.
      expect(series.points.where((p) => p.isFuture), isEmpty);
      expect(series.todayIndex, -1);
    });

    test('a year still running marks the months to come', () {
      final now = DateTime.now();
      final series = SpendSeries.yearly(
        year: now.year,
        expenses: const [],
        monthlyBudget: 3000,
        locale: 'en_US',
      );

      // Every month after this one is still to come.
      expect(series.points.where((p) => p.isFuture).length, 12 - now.month);
      expect(series.todayIndex, now.month - 1);
    });

    test('ignores entries from another year', () {
      final series = SpendSeries.yearly(
        year: 2025,
        expenses: [
          on(1, 5000, year: 2024, month: 6),
        ],
        monthlyBudget: 3000,
        locale: 'en_US',
      );

      expect(series.spent, 0);
    });
  });

  group('projection', () {
    test('overspend is the part of the projection above the budget', () {
      // Built by hand rather than through a builder, because the builders only
      // project for a month that is still running and this needs a fixed one.
      const series = SpendSeries(
        range: ChartRange.month,
        points: [ChartPoint(value: 2480000, label: '22')],
        reference: 3000000,
        referenceIsCeiling: true,
        todayIndex: 0,
        projected: 3382000,
        spent: 2480000,
        planned: 3000000,
      );

      expect(series.projectedOverspend, 382000);
      // The chart has to fit the projection, not just the budget.
      expect(series.maxValue, closeTo(3382000 * 1.0, 0.001));
    });

    test('there is no overspend when the projection lands inside', () {
      const series = SpendSeries(
        range: ChartRange.month,
        points: [ChartPoint(value: 100, label: '1')],
        reference: 1000,
        referenceIsCeiling: true,
        todayIndex: 0,
        projected: 800,
        spent: 100,
        planned: 1000,
      );

      expect(series.projectedOverspend, 0);
    });

    test('a bar chart never reports an overspend', () {
      // referenceIsCeiling is false for daily bars: a day over the allowance is
      // normal, and calling it an overspend would cry wolf every week.
      const series = SpendSeries(
        range: ChartRange.day,
        points: [ChartPoint(value: 500, label: '1')],
        reference: 100,
        referenceIsCeiling: false,
        todayIndex: 0,
        projected: 500,
        spent: 500,
        planned: 3000,
      );

      expect(series.projectedOverspend, 0);
    });
  });

  test('Timestamp round-trips through the Expense model', () {
    // A guard on the one place the chart code touches Firestore's own types:
    // if `spentAt` ever stops being a DateTime, every bucket above breaks.
    final stamp = Timestamp.fromDate(DateTime(2026, 9, 22, 14, 30));
    expect(stamp.toDate().day, 22);
  });
}
