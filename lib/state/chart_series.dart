import 'package:intl/intl.dart';

import '../core/format/period.dart';
import '../models/expense.dart';

/// The numbers behind every chart in the app, worked out away from any widget.
///
/// =============================================================================
/// WHY THIS IS A SEPARATE FILE FROM THE CHART WIDGET
/// =============================================================================
/// A chart is two jobs stuck together: deciding *what the numbers are*, and
/// deciding *where the ink goes*. They change for completely different reasons
/// - the first when the budgeting rules change, the second when the design
/// does - so they live in different files.
///
/// Everything here is plain Dart: no Flutter, no Firestore. You can read it top
/// to bottom and check the arithmetic by hand, and a test can call it without
/// starting an app.
///
/// `core/widgets/spend_chart.dart` takes what this produces and paints it.

/// The three ways of looking at the same spending.
///
/// Each one answers a different question, which is why each is drawn as a
/// different *shape* rather than the same line over a longer axis:
///
///   * [day]   - "which day leaked?"          -> one bar per day
///   * [month] - "will I make it to the end?" -> a rising cumulative line
///   * [year]  - "which month is heavy?"      -> one bar per month
///
/// This is a Dart *enhanced enum*: an enum that carries fields and a
/// constructor. [labelKey] is the i18n key for the filter pill, so the pills
/// translate along with everything else.
enum ChartRange {
  day('chart.range_day'),
  month('chart.range_month'),
  year('chart.range_year');

  const ChartRange(this.labelKey);

  final String labelKey;
}

/// One column or vertex of a chart.
class ChartPoint {
  const ChartPoint({
    required this.value,
    required this.label,
    this.isFuture = false,
  });

  /// The money this point represents. For [ChartRange.month] it is the running
  /// total *so far*, not that day's own spending.
  final double value;

  /// What goes under the axis - a day number, or a month's short name. Only
  /// some points get their label drawn; the painter thins them out.
  final String label;

  /// A month that has not happened yet. Drawn as a hollow outline so an empty
  /// future is never mistaken for a month where nothing was spent.
  final bool isFuture;
}

/// A whole chart's worth of numbers.
class SpendSeries {
  const SpendSeries({
    required this.range,
    required this.points,
    required this.reference,
    required this.referenceIsCeiling,
    required this.todayIndex,
    required this.projected,
    required this.spent,
    required this.planned,
  });

  final ChartRange range;
  final List<ChartPoint> points;

  /// The dashed line across the chart.
  ///
  /// For [ChartRange.day] it is the daily allowance; for the other two it is
  /// the budget. Drawn dashed rather than in a second colour on purpose - see
  /// the note at the top of `core/theme/app_colors.dart`.
  final double reference;

  /// True when [reference] is a ceiling the cumulative line is climbing toward
  /// (month, year) rather than a level individual bars sit around (day).
  final bool referenceIsCeiling;

  /// Index of "now" in [points], or -1 when looking at a month that has
  /// already finished. Drives the highlight band and the dot.
  final int todayIndex;

  /// Where today's pace lands by the end of the period. Zero when there is
  /// nothing to project from (a past month, or no spending yet).
  ///
  /// The arithmetic is deliberately the simplest thing that could work:
  /// `spent so far / days so far * days in total`. No smoothing, no weighting
  /// of weekends. A cleverer forecast would be harder to argue with when it is
  /// wrong, and this one is easy to explain in a sentence: "keep going at this
  /// rate and you land here".
  final double projected;

  /// Totals, carried alongside so the caption under the chart does not have to
  /// re-add the points.
  final double spent;
  final double planned;

  bool get isEmpty => points.isEmpty;

  /// The tallest thing the chart has to fit, including the reference line and
  /// the projection - so nothing is ever drawn outside the box.
  double get maxValue {
    var top = reference;
    for (final p in points) {
      if (p.value > top) top = p.value;
    }
    if (projected > top) top = projected;
    // A flat zero chart still needs a height, or every division below blows up.
    return top <= 0 ? 1 : top;
  }

  /// Projected overspend, or zero when the projection lands inside the budget.
  double get projectedOverspend =>
      referenceIsCeiling && projected > reference ? projected - reference : 0;

  /// What could still be spent per day and land exactly on budget.
  ///
  /// This is the number the warning sentence quotes, and it is the only
  /// actionable thing on the whole screen: "spend at most this much a day".
  double dailyAllowanceLeft(Period period, int monthStartDay) {
    final total = period.lengthInDays(monthStartDay: monthStartDay);
    final left = (total - period.elapsedDays(monthStartDay: monthStartDay))
        .clamp(1, total);
    final remaining = reference - spent;
    return remaining <= 0 ? 0 : remaining / left;
  }

  static const empty = SpendSeries(
    range: ChartRange.month,
    points: [],
    reference: 0,
    referenceIsCeiling: true,
    todayIndex: -1,
    projected: 0,
    spent: 0,
    planned: 0,
  );

  // ------------------------------------------------------------- builders

  /// One bar per day, for the last two weeks of the period.
  ///
  /// Two weeks rather than the whole month because thirty bars on a phone are
  /// 8px wide and tell you nothing. The question this view answers - "which day
  /// leaked?" - is about recent days anyway.
  static SpendSeries daily({
    required Period period,
    required int monthStartDay,
    required List<Expense> expenses,
    required double planned,
    int days = 14,
  }) {
    final start = period.start(monthStartDay: monthStartDay);
    final total = period.lengthInDays(monthStartDay: monthStartDay);
    final elapsed = period.elapsedDays(monthStartDay: monthStartDay);

    // How many days of this period have actually happened. For a finished
    // month that is all of them; for the current one it stops at today.
    final lastDay = period.isCurrent ? elapsed : total;
    final firstDay = (lastDay - days + 1).clamp(1, lastDay);

    // Bucket every expense by its day-of-period. `difference(...).inDays` on
    // two dates gives whole days between them; +1 makes the first day "day 1"
    // rather than "day 0", which matches how people count.
    final byDay = <int, double>{};
    for (final e in expenses) {
      final index = e.spentAt.difference(start).inDays + 1;
      byDay.update(index, (v) => v + e.amount, ifAbsent: () => e.amount);
    }

    final points = <ChartPoint>[];
    for (var day = firstDay; day <= lastDay; day++) {
      final date = start.add(Duration(days: day - 1));
      points.add(
        ChartPoint(value: byDay[day] ?? 0, label: '${date.day}'),
      );
    }

    return SpendSeries(
      range: ChartRange.day,
      points: points,
      // The allowance the budget implies if it were spread evenly. Bars over
      // the line are the days that ran hot.
      reference: total <= 0 ? 0 : planned / total,
      referenceIsCeiling: false,
      todayIndex: period.isCurrent ? points.length - 1 : -1,
      projected: 0,
      spent: expenses.fold(0.0, (sum, e) => sum + e.amount),
      planned: planned,
    );
  }

  /// A rising cumulative line across the month, with a projection to the end.
  ///
  /// Cumulative ("burn-up") rather than one bar per day because the question is
  /// not "what did I spend on the 14th", it is "am I going to make it". A
  /// climbing line against a flat ceiling answers that at a glance: if the line
  /// is going to hit the ceiling before the right-hand edge, you are in
  /// trouble.
  static SpendSeries monthly({
    required Period period,
    required int monthStartDay,
    required List<Expense> expenses,
    required double planned,
  }) {
    final start = period.start(monthStartDay: monthStartDay);
    final total = period.lengthInDays(monthStartDay: monthStartDay);
    final elapsed = period.elapsedDays(monthStartDay: monthStartDay);
    final lastDay = period.isCurrent ? elapsed.clamp(1, total) : total;

    final byDay = <int, double>{};
    for (final e in expenses) {
      final index = e.spentAt.difference(start).inDays + 1;
      byDay.update(index, (v) => v + e.amount, ifAbsent: () => e.amount);
    }

    // The running total. Each point carries every day's spending up to and
    // including itself, which is what makes the line only ever go up.
    final points = <ChartPoint>[];
    var running = 0.0;
    for (var day = 1; day <= lastDay; day++) {
      running += byDay[day] ?? 0;
      final date = start.add(Duration(days: day - 1));
      points.add(ChartPoint(value: running, label: '${date.day}'));
    }

    final projected = (period.isCurrent && lastDay > 0 && running > 0)
        ? running / lastDay * total
        : 0.0;

    return SpendSeries(
      range: ChartRange.month,
      points: points,
      reference: planned,
      referenceIsCeiling: true,
      todayIndex: period.isCurrent ? points.length - 1 : -1,
      projected: projected,
      spent: running,
      planned: planned,
    );
  }

  /// One bar per month across a calendar year.
  ///
  /// The reference line is *this* month's budget rather than each month's own.
  /// Budgets are set per month and a household that has not filled in next
  /// March yet would otherwise get a reference line that collapses to zero
  /// halfway across the chart. One honest line beats a jagged one made of
  /// missing data.
  static SpendSeries yearly({
    required int year,
    required List<Expense> expenses,
    required double monthlyBudget,
    required String locale,
  }) {
    final byMonth = List<double>.filled(12, 0);
    for (final e in expenses) {
      if (e.spentAt.year != year) continue;
      byMonth[e.spentAt.month - 1] += e.amount;
    }

    final now = DateTime.now();
    // `DateFormat.MMM` gives "Jan", "Feb"... in the interface language. The
    // locale is passed in rather than read from a global so the month names
    // always match the rest of the screen - see `dateLocaleProvider`.
    final month = DateFormat.MMM(locale);

    final points = <ChartPoint>[
      for (var i = 0; i < 12; i++)
        ChartPoint(
          value: byMonth[i],
          label: month.format(DateTime(year, i + 1)),
          isFuture: year > now.year || (year == now.year && i + 1 > now.month),
        ),
    ];

    return SpendSeries(
      range: ChartRange.year,
      points: points,
      reference: monthlyBudget,
      referenceIsCeiling: false,
      todayIndex: year == now.year ? now.month - 1 : -1,
      projected: 0,
      spent: byMonth.fold(0.0, (sum, v) => sum + v),
      planned: monthlyBudget * 12,
    );
  }
}
