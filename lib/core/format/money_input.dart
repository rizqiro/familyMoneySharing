import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'money.dart';

/// Makes a text field behave like a money field.
///
/// =============================================================================
/// WHAT A TextInputFormatter IS
/// =============================================================================
/// Flutter hands every keystroke to a chain of formatters before the field
/// shows anything. Each one gets the value before the edit and the value after
/// it, and returns what should actually appear. Returning [oldValue] rejects
/// the keystroke outright; returning something else rewrites the field.
///
/// That is more powerful than it first looks: it is not a validator that
/// complains afterwards, it is the only thing that ever reaches the field. A
/// letter typed into one of these never appears at all - not typed and then
/// erased, simply never shown.
///
/// =============================================================================
/// WHY NOT JUST FilteringTextInputFormatter.digitsOnly
/// =============================================================================
/// Because digits alone read terribly. `12000000` and `1200000` are one glance
/// apart and an order of magnitude different, and that is exactly the mistake
/// this is here to prevent. So the digits are regrouped as you type:
/// `12.000.000`, in whatever grouping the household's currency uses.
///
/// A number keypad is not enough on its own either. Some Android keyboards
/// show letters on the number pad anyway, hardware keyboards ignore the hint
/// completely, and pasting bypasses the keyboard altogether. The keyboard type
/// is a convenience; this is the rule.
///
/// =============================================================================
/// THE CURSOR
/// =============================================================================
/// Rewriting the text moves everything after the edit, so the cursor has to be
/// put back by hand. Naively parking it at the end works right up until someone
/// corrects a digit in the middle, at which point the caret jumps away and the
/// rest of the number gets typed backwards.
///
/// The fix is to count in DIGITS rather than characters: remember how many
/// digits sat before the cursor, reformat, then walk forward until that many
/// digits have been passed. Separators shifting around underneath no longer
/// matter.
class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter(this.money);

  final Money money;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final symbols = NumberFormat.decimalPattern(money.locale).symbols;
    final group = symbols.GROUP_SEP;
    final decimal = symbols.DECIMAL_SEP;
    final allowDecimal = money.decimals > 0;

    // Clearing the field is always allowed. Without this the empty string would
    // fall through and come back as "0", which you would then have to delete.
    if (newValue.text.isEmpty) return newValue;

    // Step 1: throw away everything that is not a digit or the one decimal
    // separator this currency allows. This is where letters die.
    final buffer = StringBuffer();
    var seenDecimal = false;
    for (final char in newValue.text.split('')) {
      if (_isDigit(char)) {
        buffer.write(char);
      } else if (allowDecimal && char == decimal && !seenDecimal) {
        // Only the first one. A second separator is a typo, not a number.
        seenDecimal = true;
        buffer.write(char);
      }
      // A typed grouping separator is dropped rather than kept: grouping is
      // this formatter's job, and honouring a hand-typed one would let you
      // build `1.2.3`.
    }

    final cleaned = buffer.toString();
    if (cleaned.isEmpty) {
      // Everything they typed was rubbish. Keep the field as it was rather
      // than blanking what was already there.
      return oldValue;
    }

    // Step 2: split off the fractional part, which is never grouped and is
    // capped at the currency's precision.
    final parts = cleaned.split(decimal);
    var whole = parts.first;
    final fraction = parts.length > 1
        ? parts[1].substring(
            0,
            parts[1].length > money.decimals ? money.decimals : parts[1].length,
          )
        : null;

    // Leading zeros go, so `007` reads as `7` - but a lone `0` stays, because
    // someone is probably about to type `0.5`.
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    // Step 3: regroup the whole part, three digits at a time from the right.
    final grouped = _group(whole, group);
    final formatted = fraction == null
        ? grouped
        // The separator is kept even with no digits after it yet, so typing
        // `1.` does not have the dot swallowed before you can type `50`.
        : '$grouped$decimal$fraction';

    // Step 4: put the cursor back where it belongs, counted in digits.
    final digitsBeforeCursor = _countDigits(
      newValue.text.substring(0, newValue.selection.end.clamp(0, newValue.text.length)),
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetAfterDigits(formatted, digitsBeforeCursor),
      ),
    );
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static int _countDigits(String text) {
    var count = 0;
    for (final char in text.split('')) {
      if (_isDigit(char)) count++;
    }
    return count;
  }

  /// The index just past the [wanted]-th digit of [text].
  static int _offsetAfterDigits(String text, int wanted) {
    if (wanted <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (_isDigit(text[i])) {
        seen++;
        if (seen == wanted) return i + 1;
      }
    }
    return text.length;
  }

  /// `1250000` -> `1.250.000`.
  ///
  /// Walked from the right, because that is where the grouping is anchored:
  /// a separator goes after every third digit counting back from the end.
  static String _group(String digits, String separator) {
    if (digits.length <= 3 || separator.isEmpty) return digits;

    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      // The number of digits still to come after this one.
      final remaining = digits.length - i - 1;
      out.write(digits[i]);
      if (remaining > 0 && remaining % 3 == 0) out.write(separator);
    }
    return out.toString();
  }
}

/// The formatters every money field in the app uses.
///
/// A single list so the four sheets cannot drift apart - one of them missing
/// the grouping while the others have it would be worse than none of them
/// having it, because you would stop trusting the ones that do.
List<TextInputFormatter> moneyInputFormatters(Money money) => [
      MoneyInputFormatter(money),
    ];
