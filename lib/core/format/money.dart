import 'package:intl/intl.dart';

/// Currency presets the household can choose from. `decimals: 0` matters for
/// IDR/JPY/VND where fractional units are not used in practice.
class CurrencyOption {
  const CurrencyOption(this.code, this.symbol, this.locale, this.decimals);

  final String code;
  final String symbol;
  final String locale;
  final int decimals;

  static const idr = CurrencyOption('IDR', 'Rp', 'id_ID', 0);

  static const all = <CurrencyOption>[
    idr,
    CurrencyOption('USD', r'$', 'en_US', 2),
    CurrencyOption('EUR', '€', 'de_DE', 2),
    CurrencyOption('GBP', '£', 'en_GB', 2),
    CurrencyOption('SGD', r'S$', 'en_SG', 2),
    CurrencyOption('MYR', 'RM', 'ms_MY', 2),
    CurrencyOption('AUD', r'A$', 'en_AU', 2),
    CurrencyOption('JPY', '¥', 'ja_JP', 0),
  ];

  static CurrencyOption byCode(String code) {
    return all.firstWhere(
      (o) => o.code == code.toUpperCase(),
      orElse: () => idr,
    );
  }
}

/// Formats amounts for one currency. Built once per household and passed down,
/// so a currency change updates every figure at once.
class Money {
  Money(this.currencyCode) : _option = CurrencyOption.byCode(currencyCode);

  final String currencyCode;
  final CurrencyOption _option;

  String get symbol => _option.symbol;

  /// How many decimal places this currency actually uses - 0 for IDR, JPY and
  /// VND, 2 for most others. The input formatter needs it to decide whether a
  /// decimal separator is allowed at all.
  int get decimals => _option.decimals;

  /// The locale whose grouping and decimal separators this currency is written
  /// with. `1.250.000` in id_ID, `1,250,000` in en_US.
  String get locale => _option.locale;

  /// `Rp 1.250.000` - the default for anything the user reads as an amount.
  String format(num amount) {
    final f = NumberFormat.currency(
      locale: _option.locale,
      symbol: '${_option.symbol} ',
      decimalDigits: _option.decimals,
    );
    return f.format(amount).trim();
  }

  /// Bare grouped digits, no symbol - for axis ticks and dense table columns.
  String plain(num amount) {
    return NumberFormat.decimalPatternDigits(
      locale: _option.locale,
      decimalDigits: _option.decimals,
    ).format(amount);
  }

  /// `Rp 1,2 jt` - for axis labels and chips where the full figure would wrap.
  String compact(num amount) {
    final f = NumberFormat.compactCurrency(
      locale: _option.locale,
      symbol: '${_option.symbol} ',
      decimalDigits: amount.abs() >= 1000 ? 1 : 0,
    );
    return f.format(amount).trim();
  }

  /// Always carries an explicit sign - used for deltas and ledger rows.
  String signed(num amount) {
    final prefix = amount > 0 ? '+' : (amount < 0 ? '−' : '');
    return '$prefix${format(amount.abs())}';
  }

  /// Parses user input tolerantly: strips the symbol, spaces and whichever of
  /// `.`/`,` acts as the grouping separator for this currency's locale.
  static double? parseInput(String raw, String currencyCode) {
    final option = CurrencyOption.byCode(currencyCode);
    var s = raw.trim();
    if (s.isEmpty) return null;

    s = s.replaceAll(RegExp(r'[^0-9.,\-]'), '');
    if (s.isEmpty) return null;

    final symbols = NumberFormat.decimalPattern(option.locale).symbols;
    final group = symbols.GROUP_SEP;
    final decimal = symbols.DECIMAL_SEP;

    s = s.replaceAll(group, '');
    if (decimal != '.') s = s.replaceAll(decimal, '.');

    // A currency with no fractional unit: a stray separator is grouping.
    if (option.decimals == 0) s = s.replaceAll('.', '');

    return double.tryParse(s);
  }
}
