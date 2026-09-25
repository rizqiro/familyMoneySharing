import 'package:family_money_sharing/core/format/money.dart';
import 'package:family_money_sharing/core/format/money_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the money field's behaviour as you type.
///
/// =============================================================================
/// WHY THIS IS WORTH TESTING PROPERLY
/// =============================================================================
/// A formatter runs on every keystroke and rewrites the field underneath the
/// person typing. Get the cursor maths wrong and the caret jumps somewhere
/// unexpected on the third digit - which does not crash, does not fail to
/// build, and is maddening to use. That class of bug is only ever caught here.
///
/// The last group is the one that matters most: whatever this produces has to
/// survive `Money.parseInput`. A field that looks right and parses to the wrong
/// number is worse than no formatting at all.
void main() {
  final idr = Money('IDR'); // id_ID: '.' groups, no decimals
  final usd = Money('USD'); // en_US: ',' groups, two decimals

  /// Simulates typing: what the field held, and what it would hold if the
  /// keystroke went through untouched.
  TextEditingValue type(
    MoneyInputFormatter formatter, {
    required String from,
    required String to,
    int? cursor,
  }) {
    return formatter.formatEditUpdate(
      TextEditingValue(
        text: from,
        selection: TextSelection.collapsed(offset: from.length),
      ),
      TextEditingValue(
        text: to,
        selection: TextSelection.collapsed(offset: cursor ?? to.length),
      ),
    );
  }

  group('only numbers get in', () {
    final f = MoneyInputFormatter(idr);

    test('letters never appear at all', () {
      expect(type(f, from: '', to: 'a').text, '');
      expect(type(f, from: '12', to: '12a').text, '12');
      expect(type(f, from: '', to: 'abc').text, '');
    });

    test('pasted rubbish keeps only the digits', () {
      // Pasting skips the keyboard entirely, so a numeric keypad would not
      // have stopped this.
      expect(type(f, from: '', to: 'Rp 1500 only').text, '1.500');
      expect(type(f, from: '', to: r'$1,234').text, '1.234');
    });

    test('a currency with no decimals refuses a decimal point', () {
      // There is no such thing as half a rupiah in practice, and letting one
      // through would silently divide the amount by a hundred somewhere.
      expect(type(f, from: '1000', to: '1000.5').text, '10.005');
    });

    test('symbols and spaces are dropped', () {
      expect(type(f, from: '', to: '1 000').text, '1.000');
      expect(type(f, from: '', to: '1-000').text, '1.000');
    });

    test('clearing the field is allowed', () {
      // Without this the empty string would come back as "0", which you would
      // then have to delete before typing anything.
      expect(type(f, from: '1.000', to: '').text, '');
    });
  });

  group('digits get grouped as you type', () {
    final f = MoneyInputFormatter(idr);

    test('the separator appears at the right places', () {
      expect(type(f, from: '', to: '1').text, '1');
      expect(type(f, from: '99', to: '999').text, '999');
      expect(type(f, from: '999', to: '9999').text, '9.999');
      expect(type(f, from: '', to: '1250000').text, '1.250.000');
      expect(type(f, from: '', to: '12000000').text, '12.000.000');
    });

    test('a hand-typed separator does not survive', () {
      // Grouping is the formatter's job. Honouring a typed one would let you
      // build nonsense like 1.2.3.
      expect(type(f, from: '', to: '1.2.3').text, '123');
    });

    test('leading zeros go, but a lone zero stays', () {
      expect(type(f, from: '0', to: '007').text, '7');
      expect(type(f, from: '', to: '0').text, '0');
    });
  });

  group('a currency with decimals', () {
    final f = MoneyInputFormatter(usd);

    test('groups with a comma and allows one point', () {
      expect(type(f, from: '', to: '1234').text, '1,234');
      expect(type(f, from: '1234', to: '1234.5').text, '1,234.5');
    });

    test('a trailing point is kept so you can carry on typing', () {
      // Swallowing it would mean the next keystroke lands in the whole part.
      expect(type(f, from: '12', to: '12.').text, '12.');
    });

    test('the second point is ignored and extra places are cut', () {
      expect(type(f, from: '1.5', to: '1.5.2').text, '1.52');
      expect(type(f, from: '1.99', to: '1.999').text, '1.99');
    });
  });

  group('the cursor stays where you put it', () {
    final f = MoneyInputFormatter(idr);

    test('typing at the end leaves the caret at the end', () {
      final result = type(f, from: '1.000', to: '1.0005');
      expect(result.text, '10.005');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('correcting a digit in the middle does not throw the caret', () {
      // The caret sits after "1.2"; typing 9 should leave it right after the
      // 9, not at the end of the field. Counting in digits rather than
      // characters is what makes this work while separators shift underneath.
      final result = type(
        f,
        from: '1.250.000',
        to: '1.2950.000',
        cursor: 4,
      );

      expect(result.text, '12.950.000');
      // Three digits typed so far: 1, 2, 9.
      expect(result.text.substring(0, result.selection.baseOffset), '12.9');
    });

    test('a caret at the very start stays at the start', () {
      final result = type(f, from: '250', to: '250', cursor: 0);
      expect(result.selection.baseOffset, 0);
    });
  });

  group('what it produces parses back to the same number', () {
    test('rupiah', () {
      final f = MoneyInputFormatter(idr);
      for (final raw in ['5', '500', '12500', '1250000', '999999999']) {
        final shown = type(f, from: '', to: raw).text;
        expect(
          Money.parseInput(shown, 'IDR'),
          double.parse(raw),
          reason: 'typed $raw, field showed $shown',
        );
      }
    });

    test('dollars, including the fractional part', () {
      final f = MoneyInputFormatter(usd);
      final shown = type(f, from: '', to: '1234.56').text;

      expect(shown, '1,234.56');
      expect(Money.parseInput(shown, 'USD'), 1234.56);
    });

    test('the amount a sheet pre-fills is already in this shape', () {
      // Editing an existing budget puts `money.plain(...)` in the field. If
      // that disagreed with the formatter, the first keystroke would reshuffle
      // the whole number under the person's finger.
      expect(idr.plain(1250000), '1.250.000');
      expect(MoneyInputFormatter(idr).formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '1250000',
          selection: TextSelection.collapsed(offset: 7),
        ),
      ).text, '1.250.000',);
    });
  });
}
