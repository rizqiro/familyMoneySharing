import 'package:intl/intl.dart';

/// A budgeting month, keyed as `YYYY-MM`.
///
/// Households can start their month on a day other than the 1st (pay-day
/// budgeting), so the key is derived from [monthStartDay] rather than from the
/// calendar month alone.
class Period {
  const Period(this.year, this.month);

  final int year;
  final int month;

  /// The period a given date falls into for a household starting its month on
  /// [monthStartDay]. With a start day of 25, the 26th of March belongs to the
  /// April period.
  static Period of(DateTime date, {int monthStartDay = 1}) {
    if (monthStartDay <= 1 || date.day < monthStartDay) {
      return Period(date.year, date.month);
    }
    return Period(date.year, date.month).next();
  }

  static Period current({int monthStartDay = 1}) =>
      Period.of(DateTime.now(), monthStartDay: monthStartDay);

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  Period next() => month == 12 ? Period(year + 1, 1) : Period(year, month + 1);

  Period previous() =>
      month == 1 ? Period(year - 1, 12) : Period(year, month - 1);

  /// First instant belonging to this period.
  DateTime start({int monthStartDay = 1}) {
    if (monthStartDay <= 1) return DateTime(year, month);
    final prev = previous();
    final lastDayOfPrev = DateTime(prev.year, prev.month + 1, 0).day;
    return DateTime(prev.year, prev.month, monthStartDay.clamp(1, lastDayOfPrev));
  }

  /// Exclusive upper bound.
  DateTime end({int monthStartDay = 1}) =>
      next().start(monthStartDay: monthStartDay);

  /// Total days in the period, and how many have elapsed - drives the
  /// "on pace / overspending" readout.
  int lengthInDays({int monthStartDay = 1}) =>
      end(monthStartDay: monthStartDay)
          .difference(start(monthStartDay: monthStartDay))
          .inDays;

  int elapsedDays({int monthStartDay = 1}) {
    final from = start(monthStartDay: monthStartDay);
    final total = lengthInDays(monthStartDay: monthStartDay);
    final days = DateTime.now().difference(from).inDays + 1;
    return days.clamp(0, total);
  }

  bool get isCurrent => this == Period.current();

  /// Follows `Intl.defaultLocale`, which `main` sets from the device.
  String label() => DateFormat.yMMMM().format(DateTime(year, month));

  @override
  bool operator ==(Object other) =>
      other is Period && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => key;
}
