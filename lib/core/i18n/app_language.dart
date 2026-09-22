/// The languages the app speaks.
///
/// =============================================================================
/// WHY NOT FLUTTER'S BUILT-IN LOCALIZATION?
/// =============================================================================
/// Flutter's official approach uses `.arb` files plus a code generator
/// (`flutter gen-l10n`). It is the right choice for a big team: translators get
/// a standard file format and the compiler catches a missing string.
///
/// This app uses plain Dart maps instead, for one reason: you said you want to
/// edit this yourself. A map is a file you can open and change, and the app
/// picks it up on the next run. No codegen step, no build runner, no tooling to
/// install. Add a line, hot restart, done.
///
/// The trade-off is that a typo in a key is not a compile error - it shows the
/// key on screen instead. That is deliberate: a missing translation is loud and
/// obvious rather than silently blank. See `app_text.dart`.
///
/// =============================================================================
/// DART NOTE: ENHANCED ENUMS
/// =============================================================================
/// Since Dart 3, an enum can carry fields and methods like a normal class. So
/// each language below is a single value you can switch on, AND it knows its
/// own code and display name. Before Dart 3 this needed a separate class plus a
/// map from enum to data.
library;

enum AppLanguage {
  /// The default. Most of the app was written in Indonesian first.
  indonesian(
    code: 'id',
    intlLocale: 'id_ID',
    endonym: 'Bahasa Indonesia',
    englishName: 'Indonesian',
  ),

  english(
    code: 'en',
    intlLocale: 'en_US',
    endonym: 'English',
    englishName: 'English',
  ),

  /// Banjar, spoken in South Kalimantan.
  ///
  /// `intl` has no date data for it, so dates fall back to Indonesian - see
  /// [intlLocale]. Month names will read as Indonesian while the interface
  /// reads as Banjar, which is normal for regional languages in Indonesia.
  banjar(
    code: 'bjn',
    intlLocale: 'id_ID',
    endonym: 'Bahasa Banjar',
    englishName: 'Banjarese',
  ),

  javanese(
    code: 'jv',
    intlLocale: 'id_ID',
    endonym: 'Basa Jawa',
    englishName: 'Javanese',
  ),

  sundanese(
    code: 'su',
    intlLocale: 'id_ID',
    endonym: 'Basa Sunda',
    englishName: 'Sundanese',
  );

  /// `const` constructor so each value is built once, at compile time.
  const AppLanguage({
    required this.code,
    required this.intlLocale,
    required this.endonym,
    required this.englishName,
  });

  /// What is stored in Firestore on the user document. Short and stable - never
  /// rename these, or everyone's saved choice stops matching.
  final String code;

  /// Which locale the `intl` package should format dates and numbers with.
  ///
  /// Only Indonesian and English have their own; the three regional languages
  /// borrow Indonesian, because `intl` ships no date symbols for them and
  /// asking for one it does not have throws at runtime.
  final String intlLocale;

  /// The language's name in that language - what a speaker expects to see in a
  /// list. "Basa Sunda", not "Sundanese".
  final String endonym;

  /// The English name, shown underneath, so someone who does not read the
  /// script can still find their way back.
  final String englishName;

  /// Turns a stored code back into a value.
  ///
  /// Unknown or missing codes fall back to Indonesian rather than throwing: a
  /// user document written by a newer version of the app should not crash an
  /// older one.
  static AppLanguage fromCode(String? code) {
    for (final language in AppLanguage.values) {
      if (language.code == code) return language;
    }
    return AppLanguage.indonesian;
  }

  /// Best guess from the phone's own language, used the very first time before
  /// the user has chosen anything.
  ///
  /// [tag] is what `Locale.toLanguageTag()` gives, like `id-ID` or `en-GB`, so
  /// only the part before the dash is compared.
  static AppLanguage fromDeviceTag(String tag) {
    final primary = tag.toLowerCase().split(RegExp('[-_]')).first;
    for (final language in AppLanguage.values) {
      if (language.code == primary) return language;
    }
    return AppLanguage.indonesian;
  }
}
