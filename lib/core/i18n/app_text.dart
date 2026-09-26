import 'app_language.dart';
import 'translations_regional.dart';

/// Looks up a piece of interface text in the chosen language.
///
/// =============================================================================
/// HOW TO USE IT IN A SCREEN
/// =============================================================================
/// ```dart
/// final t = ref.watch(textProvider);      // in a ConsumerWidget's build
/// Text(t('common.save'))                  // -> "Simpan" / "Save"
/// Text(t('dashboard.of_amount', {'amount': 'Rp 8.000.000'}))
/// ```
///
/// The object is callable: writing `t('key')` runs the [call] method below.
/// That is a Dart feature - any class defining `call` can be used like a
/// function.
///
/// =============================================================================
/// HOW A MISSING TRANSLATION BEHAVES
/// =============================================================================
/// Three steps, in order:
///
///   1. the chosen language's map;
///   2. the Indonesian map, which is the complete one;
///   3. the key itself.
///
/// So the regional maps only need the lines someone has actually translated.
/// Everything else quietly reads Indonesian, and the app never shows a blank.
/// Reaching step 3 means the key is misspelled - you will see
/// `dashboard.yuor_budgets` on screen, which is the fastest possible bug report.
///
/// =============================================================================
/// ADDING OR FIXING A TRANSLATION
/// =============================================================================
/// 1. Find the key in [_id] below. That map is the source of truth and should
///    always be complete.
/// 2. Add the same key to the language's map with your wording.
///    Indonesian and English live in this file; Banjar, Javanese and Sundanese
///    live in `translations_regional.dart`.
/// 3. Hot restart. No code generation, no rebuild of anything else.
///
/// `{name}` and friends are placeholders. Keep them spelled the same in every
/// language - they are replaced with real values at runtime - but move them
/// wherever the grammar needs them.
///
/// =============================================================================
/// HOW THE APP IS MEANT TO SOUND
/// =============================================================================
/// Blunt, and slightly boring. Every line below was once longer and more
/// elegant, and that was the problem: well-turned interface copy reads as
/// written, and a person checking whether they can afford groceries does not
/// want to be read to. Concretely, when you add a line:
///
///   - One idea per line. If it needs two sentences, the second should carry a
///     fact, not a reason.
///   - No em dashes. Indonesian consumer apps do not use them; a comma, a full
///     stop or a colon always works.
///   - No lists of three. Two items, or one.
///   - No "not X, but Y". Say Y.
///   - No aphorisms, however good. "Uang itu dibagi, jadi aplikasinya juga"
///     was here, and it was the most AI-sounding sentence in the app.
///   - No metaphors translated out of English. "Where the money stands" became
///     "UANGNYA BERDIRI DI SINI", which is not a thing anyone says. It is now
///     just "RINCIAN".
///   - Contractions in English ("isn't", "you'll"). Their absence is itself a
///     tell.
///   - Nothing about Firebase, Firestore, rules or indexes. Those are notes to
///     the developer; they belong in comments, and the raw error code that
///     `describeFailure` appends is enough to debug from.
///
/// A label the user reads fifty times a day should be one word if one word will
/// do. 'dashboard.left_to_spend' is 'SISA', not 'SISA UNTUK DIBELANJAKAN'.
class AppText {
  const AppText(this.language);

  final AppLanguage language;

  /// Returns the text for [key], with any `{placeholders}` filled from [vars].
  ///
  /// [vars] is optional, hence the `?` and the square brackets - a positional
  /// optional parameter.
  String call(String key, [Map<String, String>? vars]) {
    final table = _tableFor(language);

    // `??` is the "if null, use this instead" operator, so this chains the
    // three fallback steps into one expression.
    final raw = table[key] ?? _id[key] ?? key;

    if (vars == null || vars.isEmpty) return raw;

    // `fold` walks the replacements, each one applied to the result of the last.
    return vars.entries.fold(
      raw,
      (text, entry) => text.replaceAll('{${entry.key}}', entry.value),
    );
  }

  /// Picks one of two wordings by count - "1 entry" versus "3 entries".
  ///
  /// Indonesian and the regional languages do not inflect for plural, so both
  /// arms usually hold the same string there. It exists for English, and for
  /// any language added later that needs it.
  String plural(int count, String oneKey, String manyKey,
      [Map<String, String>? vars,]) {
    final all = {'count': '$count', ...?vars};
    return call(count == 1 ? oneKey : manyKey, all);
  }

  static Map<String, String> _tableFor(AppLanguage language) {
    return switch (language) {
      AppLanguage.indonesian => _id,
      AppLanguage.english => _en,
      AppLanguage.banjar => banjarText,
      AppLanguage.javanese => javaneseText,
      AppLanguage.sundanese => sundaneseText,
    };
  }
}

// =============================================================================
// BAHASA INDONESIA - the complete map, and what everything else falls back to.
// =============================================================================
const Map<String, String> _id = {
  // ------------------------------------------------------------- common
  'common.save': 'Simpan',
  'common.save_changes': 'Simpan perubahan',
  'common.cancel': 'Batal',
  'common.delete': 'Hapus',
  'common.remove': 'Hapus',
  'common.edit': 'Ubah',
  'common.add': 'Tambah',
  'common.confirm': 'Setuju',
  'common.decline': 'Tolak',
  'common.retry': 'Coba lagi',
  'common.you': 'Kamu',
  'common.partner': 'Pasangan',
  'common.someone': 'Seseorang',
  'common.left': 'sisa',
  'common.over': 'lebih',
  'common.of': 'dari',

  // --------------------------------------------------------------- auth
  'auth.app_name': 'Family Money',
  'auth.tagline': 'Catat uang bareng pasangan.',
  'auth.welcome_back': 'Selamat datang kembali',
  'auth.name_hint': 'Nama kamu',
  'auth.email_hint': 'Email',
  'auth.password_hint': 'Kata sandi',
  'auth.forgot_password': 'Lupa kata sandi',
  'auth.sign_in': 'Masuk',
  'auth.create_account': 'Buat akun',
  'auth.have_account': 'Sudah punya akun',
  'auth.no_account': 'Buat akun baru',
  'auth.err_name': 'Isi nama kamu',
  'auth.err_email_empty': 'Isi email kamu',
  'auth.err_email_invalid': 'Format emailnya salah',
  'auth.err_password_empty': 'Isi kata sandi kamu',
  'auth.err_password_short': 'Minimal 6 karakter',
  'auth.reset_need_email': 'Isi emailnya dulu.',
  'auth.reset_sent': 'Link reset dikirim ke {email}',
  'auth.sign_out': 'Keluar',

  // --------------------------------------------------------- onboarding
  'onboarding.hi': 'Hai {name}',
  'onboarding.blurb':
      'Buat rumah tangga dan undang pasangan kamu, atau gabung ke yang sudah '
          'dia buat.',
  'onboarding.start': 'Mulai rumah tangga kami',
  'onboarding.start_blurb': 'Nanti tunjukkan kode QR-nya ke pasangan kamu.',
  'onboarding.join': 'Gabung dengan pasangan',
  'onboarding.join_blurb': 'Scan kode QR dia, atau ketik kodenya.',
  'onboarding.name_household': 'Beri nama rumah tangga',
  'onboarding.household_name_hint': 'Nama rumah tangga',
  'onboarding.currency': 'MATA UANG',
  'onboarding.create': 'Buat rumah tangga',
  'onboarding.default_name': 'Rumah tangga {name}',

  // ------------------------------------------------------------- invite
  'invite.title': 'Undang pasangan',
  'invite.blurb':
      'Minta dia buka Family Money, pilih "Gabung dengan pasangan", lalu '
          'arahkan kamera ke sini.',
  'invite.or_type': 'ATAU KETIK KODE INI',
  'invite.copy': 'Salin kode',
  'invite.copied': 'Kode disalin',
  'invite.new_code': 'Kode baru',
  'invite.expiry':
      'Sekali pakai, hangus dalam 24 jam. Kirim langsung ke dia saja.',
  'invite.connected': 'Sudah terhubung.',

  // --------------------------------------------------------------- join
  'join.title': 'Gabung dengan pasangan',
  'join.tap_to_scan': 'Ketuk untuk scan',
  'join.stop_camera': 'Matikan kamera',
  'join.or': 'ATAU',
  'join.enter_code': 'Masukkan kode undangan',
  'join.enter_code_blurb': 'Delapan karakter, ada di layar pasangan kamu.',
  'join.camera_unavailable': 'Kamera tidak bisa dipakai.',
  'join.still_type': '{message}\n\nKodenya bisa diketik di bawah.',
  'join.cta': 'Gabung rumah tangga',
  'join.confirm_title': 'Gabung ke rumah tangga ini?',
  'join.confirm_body':
      '{name} mengundang kamu ke "{household}". Kalian berdua bisa lihat '
          'semua anggaran dan pengeluaran di dalamnya.',
  'join.cta_short': 'Gabung',

  // -------------------------------------------------------------- shell
  'shell.tab_overview': 'Ringkasan',
  'shell.tab_budgets': 'Anggaran',
  'shell.tab_ledger': 'Catatan',
  'shell.tab_inbox': 'Kotak masuk',
  'shell.add_expense': 'Catat pengeluaran',
  'shell.need_budget':
      'Buat anggaran kamu sendiri dulu, atau minta uang ke pasangan.',

  // ---------------------------------------------------------- dashboard
  'dashboard.subtitle': 'Ringkasan bersama',
  'dashboard.connect': 'Hubungkan pasangan kamu',
  'dashboard.connect_blurb': 'Tunjukkan kode QR-nya biar angkanya sama.',
  'dashboard.your_budgets': 'Anggaran kamu',
  'dashboard.accumulated': 'Total anggaran',
  'dashboard.their_budgets': 'Anggaran {name}',
  'dashboard.who_spent': 'Siapa belanja apa',
  'dashboard.where_went': 'Uangnya ke mana',
  'dashboard.latest': 'Terbaru',
  'dashboard.other': 'Lainnya ({count})',
  'dashboard.left_to_spend': 'SISA',
  'dashboard.over_budget_by': 'LEWAT ANGGARAN',
  'dashboard.you_control': 'Kamu yang pegang ini',
  'dashboard.per_day_left': 'Sisa {amount}/hari',
  'dashboard.spent_of': '{spent} dari {planned}',
  'dashboard.spent_of_both': '{spent} kepakai dari {planned} berdua',
  'dashboard.spent_of_solo': '{spent} kepakai dari {planned}',
  'dashboard.yours': 'Punya kamu',
  'dashboard.theirs': 'Punya {name}',
  'dashboard.put_aside': 'Ditabung bulan ini',
  'dashboard.entries_one': '{count} catatan bulan ini',
  'dashboard.entries_many': '{count} catatan bulan ini',
  'dashboard.to_confirm': '{count} perlu disetujui',
  'dashboard.moved_in': '{amount} masuk · awalnya {base}',
  'dashboard.moved_out': '{amount} keluar · awalnya {base}',
  'dashboard.no_budget_title': 'Kamu belum pegang anggaran',
  'dashboard.no_budget_blurb':
      'Pengeluaran diambil dari anggaran yang kamu pegang. Anggaran {name} '
          'cuma bisa kamu lihat.',
  'dashboard.no_budget_blurb_solo':
      'Pengeluaran diambil dari anggaran yang kamu pegang. Buat satu dulu.',
  'dashboard.request_from': 'Minta uang ke {name}',
  'dashboard.create_my_budget': 'Buat anggaran saya sendiri',
  'dashboard.see_not_spend': 'Cuma bisa dilihat.',
  'dashboard.request_money': 'Minta uang',
  'dashboard.target_of': 'Target {amount}',
  'dashboard.left_of': '{amount} sisa dari {planned}',
  'dashboard.over_of': 'Lewat {amount} dari {planned}',
  'dashboard.saving_of': '{spent} dari target {planned}',

  // ------------------------------------------------------------ budgets
  'budgets.title': 'Anggaran',
  'budgets.this_month': 'Bulan ini',
  'budgets.saving_pots': 'Tabungan',
  'budgets.new_budget': 'Anggaran baru',
  'budgets.none_title': 'Belum ada anggaran untuk {month}',
  'budgets.none_blurb':
      'Tentukan rencana belanjanya, bagi ke kategori, lalu mulai catat.',
  'budgets.create': 'Buat anggaran',
  'budgets.copy_from': 'Salin dari {month}',
  'budgets.nothing_to_copy': 'Tidak ada anggaran kamu di {month}.',
  'budgets.copied_one': '{count} anggaran disalin.',
  'budgets.copied_many': '{count} anggaran disalin.',
  'budgets.categories_one': '{count} kategori',
  'budgets.categories_many': '{count} kategori',
  'budgets.awaiting': '{count} menunggu persetujuan',
  'budgets.over_allocated': 'Pembagiannya kelebihan',
  'budgets.unallocated': '{amount} belum dibagi',
  'budgets.over_spent': 'Sudah lewat anggaran',
  'budgets.you_control': 'Kamu yang pegang ini',
  'budgets.partner_controls': '{name} yang pegang ini',

  // ----------------------------------------------------- budget editor
  'budget_editor.new': 'Anggaran baru',
  'budget_editor.edit': 'Ubah anggaran',
  'budget_editor.name_hint': 'Nama, misalnya Biaya hidup',
  'budget_editor.type': 'JENIS',
  'budget_editor.monthly': 'Bulanan',
  'budget_editor.saving': 'Tabungan',
  'budget_editor.monthly_blurb': 'Diulang tiap bulan. Ini untuk {month}.',
  'budget_editor.saving_blurb': 'Dikumpulkan sampai targetnya tercapai.',
  'budget_editor.amount': 'JUMLAH',
  'budget_editor.target': 'TARGET',
  'budget_editor.add_target_date': 'Tambah tanggal target (opsional)',
  'budget_editor.by_date': 'Sebelum {date}',
  'budget_editor.who_controls': 'SIAPA YANG PEGANG',
  'budget_editor.who_controls_blurb':
      'Yang pegang menentukan kategorinya, dan cuma dia yang bisa belanja '
          'dari sini. Kalian berdua tetap bisa lihat.',
  'budget_editor.err_name': 'Beri nama anggarannya.',
  'budget_editor.err_amount': 'Jumlahnya harus lebih dari nol.',

  // --------------------------------------------------- category editor
  'category_editor.new': 'Kategori baru',
  'category_editor.edit': 'Ubah kategori',
  'category_editor.in_budget': 'Di dalam {budget}',
  'category_editor.name_hint': 'Nama kategori',
  'category_editor.allocation': 'PEMBAGIAN',
  'category_editor.will_ask': '{name} harus setuju dulu.',
  'category_editor.add': 'Tambah kategori',
  'category_editor.send': 'Kirim untuk disetujui',
  'category_editor.save_and_ask': 'Simpan dan minta lagi',
  'category_editor.sent_to': 'Sudah dikirim ke {name}.',
  'category_editor.err_name': 'Beri nama kategorinya.',
  'category_editor.err_amount': 'Jumlahnya harus lebih dari nol.',

  // ----------------------------------------------------- budget detail
  'status.pending': 'Menunggu persetujuan',
  'status.approved': 'Disetujui',
  'status.rejected': 'Ditolak',
  'detail.of_planned': 'dari {amount}',
  'detail.of_target': 'dari target {amount}',
  'detail.where_it_stands': 'RINCIAN',
  'detail.already_spent': 'Sudah dibelanjakan',
  'detail.in_categories': 'Masih di kategori',
  'detail.not_carved_up': 'Belum dibagi',
  'detail.spent': 'TERPAKAI',
  'detail.put_aside': 'DITABUNG',
  'detail.planned': 'Direncanakan',
  'detail.target': 'Target',
  'detail.left': 'Sisa',
  'detail.over_by': 'Lebih',
  'detail.unallocated': 'Belum dibagi',
  'detail.controls_here': '{name} yang menentukan kategori di sini',
  'detail.you_control_here': 'Kamu yang menentukan kategori di sini',
  'detail.categories': 'Kategori',
  'detail.over_allocated':
      'Total kategori {allocated}, padahal anggarannya {planned}.',
  'detail.no_categories': 'Belum ada kategori',
  'detail.no_categories_yours':
      'Bagi anggaran ini biar jelas uangnya untuk apa.',
  'detail.no_categories_theirs': '{name} belum membagi anggaran ini.',
  'detail.add_category': 'Tambah kategori',
  'detail.uncategorised': 'Pengeluaran tanpa kategori',
  'detail.activity': 'Aktivitas ({count})',
  'detail.nothing_spent': 'Belum ada yang dibelanjakan dari anggaran ini',
  'detail.nothing_spent_yours': 'Catatan yang kamu buat akan muncul di sini.',
  'detail.nothing_spent_theirs': 'Catatan yang dibuat {name} muncul di sini.',
  'detail.edit_budget': 'Ubah anggaran',
  'detail.delete_budget': 'Hapus anggaran',
  'detail.delete_title': 'Hapus {name}?',
  'detail.delete_body':
      'Kategori dan semua pengeluaran di dalamnya ikut terhapus, untuk kalian '
          'berdua. Tidak bisa dibatalkan.',
  'detail.remove_category_title': 'Hapus {name}?',
  'detail.remove_category_spent':
      'Pengeluarannya tetap ada di catatan, tapi tanpa kategori.',
  'detail.remove_category_empty':
      'Belum ada yang dibelanjakan dari kategori ini.',
  'detail.not_found': 'Anggaran tidak ditemukan',
  'detail.not_found_blurb': 'Mungkin sudah dihapus, atau ada di bulan lain.',

  // ---------------------------------------------------- expense editor
  'expense.new': 'Pengeluaran baru',
  'expense.edit': 'Ubah pengeluaran',
  'expense.budget': 'ANGGARAN',
  'expense.category': 'KATEGORI',
  'expense.note_hint': 'Untuk apa? (opsional)',
  'expense.add': 'Tambah pengeluaran',
  'expense.nothing_yours': 'Tidak ada milik kamu untuk dibelanjakan',
  'expense.nothing_yours_blurb':
      'Pengeluaran diambil dari anggaran yang kamu pegang. Buat satu, atau '
          'minta ke pasangan kamu.',
  'expense.delete_title': 'Hapus pengeluaran ini?',
  'expense.delete_body':
      'Catatan ini hilang untuk kalian berdua. Totalnya ikut turun.',
  'expense.err_amount': 'Jumlahnya harus lebih dari nol.',
  'expense.err_budget': 'Pilih anggaran mana yang dipakai.',

  // ------------------------------------------------------------- ledger
  'ledger.title': 'Catatan',
  'ledger.everyone': 'Semua',
  'ledger.entries_one': '{count} catatan',
  'ledger.entries_many': '{count} catatan',
  'ledger.empty': 'Belum ada yang dicatat',
  'ledger.empty_blurb':
      'Ketuk + untuk mencatat pengeluaran. Pasangan kamu langsung lihat.',
  'ledger.today': 'HARI INI',
  'ledger.yesterday': 'KEMARIN',

  // -------------------------------------------------------------- inbox
  'inbox.title': 'Kotak masuk',
  'inbox.empty': 'Tidak ada yang perlu disetujui',
  'inbox.empty_unpaired':
      'Kalau pasangan kamu sudah gabung, pembagian anggaran dan permintaan '
          'uang muncul di sini.',
  'inbox.empty_blurb':
      'Pembagian anggaran dan permintaan uang muncul di sini.',
  'inbox.waiting_on_you': 'Menunggu kamu',
  'inbox.waiting_on_partner': 'Menunggu pasangan',
  'inbox.money_request': 'Permintaan uang',
  'inbox.asking_for': '{name} minta uang dari {from}, masuk ke {to}.',
  'inbox.leaves': 'Sisa {amount}',
  'inbox.more_than_you_have': 'Lebih dari sisanya',
  'inbox.would_go_over': 'Kalau disetujui, {budget} jadi lewat anggaran.',
  'inbox.send_money': 'Kirim uang',
  'inbox.money_moved': 'Uang dipindahkan',
  'inbox.declined': 'Ditolak',
  'inbox.confirmed': 'Disetujui',
  'inbox.decline_title': 'Tolak',
  'inbox.decline_hint': 'Beri alasan (opsional)',
  'inbox.withdraw': 'Tarik',
  'inbox.editing_replaces':
      'Kalau kategorinya diubah, permintaan ini diganti.',
  'inbox.waiting_from': '{amount} dari {budget} · menunggu {name}',
  'inbox.waiting_amount': '{amount} · menunggu {name}',
  'inbox.vs_before': 'Sebelumnya {amount}',
  'inbox.note':
      'Pembagian yang belum disetujui sudah ikut dihitung. Uangnya baru '
          'pindah setelah disetujui.',

  // ------------------------------------------------------ request money
  'request.title': 'Minta uang',
  'request.subtitle': 'Dari anggaran yang dipegang {name}',
  'request.from': 'DARI',
  'request.amount': 'JUMLAH',
  'request.what_for': 'UNTUK APA',
  'request.what_for_hint': 'Sepatu sekolah, bensin…',
  'request.lands_in': 'MASUK KE',
  'request.name_budget_hint': 'Beri nama anggaran kamu sendiri',
  'request.creates_budget':
      'Kamu belum pegang anggaran, jadi dibuatkan satu untuk menampungnya.',
  'request.partner_confirms':
      '{name} menyetujuinya di kotak masuk. Kalau setuju, uangnya pindah ke '
          'anggaran kamu.',
  'request.send': 'Kirim permintaan',
  'request.left_in': '{amount} tersisa di {budget}',
  'request.err_source': 'Pilih mau minta dari anggaran mana.',
  'request.err_amount': 'Jumlahnya harus lebih dari nol.',
  'request.err_too_much': 'Di {budget} cuma sisa {amount}.',
  'request.err_name': 'Beri nama anggarannya.',
  'request.err_destination': 'Pilih uangnya mau masuk ke mana.',
  'request.sent_to': 'Dikirim ke {name}.',
  'request.none_title': 'Belum ada yang bisa diminta',
  'request.none_unpaired':
      'Hubungkan pasangan kamu dulu, baru bisa minta uang ke dia.',
  'request.none_blurb':
      '{name} belum punya anggaran bulanan untuk dipindahkan.',

  // ----------------------------------------------------------- settings
  'settings.title': 'Pengaturan',
  'settings.partner': 'Pasangan',
  'settings.invite_partner': 'Undang pasangan kamu',
  'settings.connected': 'Terhubung',
  'settings.household': 'Rumah tangga',
  'settings.name': 'Nama',
  'settings.currency': 'Mata uang',
  'settings.month_starts': 'Bulan dimulai tanggal',
  'settings.month_first': 'Tanggal 1 (bulan kalender)',
  'settings.month_day': 'Tanggal {day}',
  'settings.month_blurb':
      'Kalau anggaran kalian mulai dari tanggal gajian, pilih tanggalnya di '
          'sini. Pengeluaran otomatis masuk ke bulan yang benar.',
  'settings.language': 'Bahasa',
  'settings.preferences': 'Preferensi',
  'settings.account': 'Akun',
  'settings.leave': 'Keluar dari rumah tangga',
  'settings.leave_title': 'Keluar dari rumah tangga ini?',
  'settings.leave_body':
      'Kamu tidak bisa lihat anggaran dan catatan bersama lagi. Semuanya '
          'tetap ada di pasangan kamu, dan kamu bisa diundang lagi.',
  'settings.leave_cta': 'Keluar',
  'settings.your_name': 'Nama kamu',
  'settings.household_name': 'Nama rumah tangga',

  // -------------------------------------------------------------- chart
  'chart.range_day': 'Harian',
  'chart.range_month': 'Bulanan',
  'chart.range_year': 'Tahunan',
  'chart.left_in': 'Sisa di {name}, anggaran kamu',
  'chart.over_in': 'Lewat di {name}, anggaran kamu',
  'chart.left_household': 'Sisa semua anggaran rumah tangga',
  'chart.over_household': 'Lewat dari semua anggaran rumah tangga',
  'chart.budget_of': 'Anggaran {amount}',
  'chart.projection_ok':
      'Kalau segini terus, habisnya {amount}. Sisa {left}.',
  'chart.projection_over':
      'Kalau segini terus, habisnya {amount}. Lewat {over}.',
  'chart.projection_none': 'Belum ada yang dicatat bulan ini.',
  'chart.fix_daily': 'Turunkan ke {amount}/hari biar pas.',
  'chart.fix_stop': 'Anggarannya sudah habis.',
  'chart.daily_note_none': 'Jatah {amount}/hari. Belum ada yang lewat.',
  'chart.daily_note_one': 'Jatah {amount}/hari. {count} hari lewat jatah.',
  'chart.daily_note_many': 'Jatah {amount}/hari. {count} hari lewat jatah.',
  'chart.year_note': '{amount} terpakai sepanjang {year}.',
  'chart.legend_spent': 'Terpakai',
  'chart.legend_pace': 'Seharusnya',
  'chart.legend_projection': 'Perkiraan',
  'chart.a11y': 'Grafik {range}. {spent} terpakai dari anggaran {budget}.',

  // -------------------------------------------------------------- errors
  'error.permission_denied': 'Kamu tidak punya izin untuk ini.',
  'error.offline':
      'Tidak ada koneksi. Catatan yang sudah dibuat terkirim sendiri nanti.',
  'error.signed_out': 'Sesi kamu habis. Masuk lagi, ya.',
  'error.not_found': 'Datanya sudah tidak ada. Mungkin baru dihapus.',
  'error.already_exists': 'Datanya sudah ada.',
  'error.needs_index': 'Belum bisa menampilkan ini. Coba lagi nanti.',
  'error.quota': 'Server sedang penuh. Coba lagi besok.',
  'error.email_taken': 'Email itu sudah dipakai.',
  'error.email_invalid': 'Format emailnya salah.',
  'error.password_weak': 'Kata sandinya terlalu pendek. Minimal 6 karakter.',
  'error.credentials': 'Email atau kata sandinya salah.',
  'error.too_many': 'Terlalu banyak percobaan. Tunggu sebentar.',
  'error.unknown': 'Ada yang tidak beres. Coba lagi.',

  // ------------------------------------------------- income & transfers
  'expense.new_income': 'Pemasukan baru',
  'expense.add_income': 'Tambah pemasukan',
  'expense.edit_income': 'Ubah pemasukan',
  'expense.kind_spending': 'Keluar',
  'expense.kind_income': 'Masuk',

  'category_editor.headroom': 'Sisa {amount} dari {total} belum dibagi.',
  'category_editor.none_left':
      'Semua anggaran sudah dibagi. Kurangi kategori lain dulu.',
  'category_editor.err_over':
      'Kelebihan {over}. Di {budget} cuma sisa {headroom}. Kurangi kategori '
          'lain, atau naikkan anggarannya.',

  'detail.taken_out': 'Diambil lagi',
  'detail.income_added': '{amount} masuk ke anggaran ini.',
  'detail.record_income': 'Catat pemasukan',
  'detail.record_spending': 'Catat pengeluaran',
  'detail.record_deposit': 'Setor',
  'detail.record_withdrawal': 'Ambil',

  'inbox.all_allocated':
      '{budget} sudah dibagi habis. Nanti pilih kategori mana yang dikurangi.',
  'inbox.take_from_title': 'Ambil dari kategori mana?',
  'inbox.take_from_blurb':
      '{amount} akan dikurangi dari salah satu kategori di {budget}.',
  'inbox.only_has': 'Cuma ada {amount}',
  'inbox.no_categories_to_take_from':
      'Tidak ada kategori yang bisa dikurangi di anggaran ini.',

  'history.title': 'Riwayat uang',
  'history.on_this_budget': 'Uang yang pindah',
  'history.received_from': 'Terima dari {name}',
  'history.gave_to': 'Kasih ke {name}',
  'history.refused_by': '{name} menolak',
  'history.you_refused': 'Kamu tolak permintaan {name}',
  'history.out_of': 'dari {category}',

  'saving_seed.education': 'Pendidikan',
  'saving_seed.emergency': 'Dana darurat',
  'saving_seed.other': 'Lainnya',

  // --------------------------------------------- sign-in & account erase
  'auth.or': 'atau',
  'auth.continue_google': 'Lanjut dengan Google',

  'delete.title': 'Hapus akun',
  'delete.talk_title': 'Sebelum lanjut',
  'delete.talk_body':
      'Kalau ada yang berat antara kamu dan {name}, coba bicarakan dulu di '
          'waktu yang tenang. Sering kali soalnya bukan uang.\n\nTombol ini '
          'tetap ada kalau nanti memang itu yang kamu mau.',
  'delete.what_happens': 'Yang akan terjadi',
  'delete.point_profile': 'Nama, email, dan profil kamu dihapus.',
  'delete.point_signin': 'Kamu tidak bisa masuk lagi dengan akun ini.',
  'delete.point_fresh':
      'Nanti kamu bisa daftar lagi pakai email yang sama, tapi isinya kosong. '
          'Tidak ada yang kembali.',
  'delete.point_solo':
      'Semua anggaran, catatan, dan tabungan kamu ikut terhapus.',
  'delete.point_leave': 'Kamu keluar dari rumah tangga bersama {name}.',
  'delete.point_partner_keeps':
      '{name} tetap punya anggaran dan catatan bersama. Itu catatan dia juga.',
  'delete.point_forever': 'Tidak bisa dibatalkan.',
  'delete.shared_title': 'Catatan bersama',
  'delete.shared_blurb':
      'Anggaran dan catatan bersama bukan milik kamu sendiri. Kamu bisa minta '
          'semuanya dihapus, tapi {name} yang memutuskan.',
  'delete.ask_erase': 'Minta {name} menghapus semua catatan bersama',
  'delete.ask_erase_note':
      '{name} akan ditanya. Kalau dia tidak mau, catatannya tetap ada di dia.',
  'delete.confirm_title': 'Konfirmasi',
  'delete.confirm_blurb': 'Ketik {word} untuk melanjutkan.',
  'delete.confirm_word': 'HAPUS',
  'delete.err_word': 'Ketik {word} persis untuk melanjutkan.',
  'delete.final_title': 'Hapus akun kamu?',
  'delete.final_body':
      'Setelah ini akun kamu hilang dan tidak bisa dikembalikan.',
  'delete.confirm_cta': 'Ya, hapus',
  'delete.keep_account': 'Batal',
  'delete.cta': 'Hapus akun saya',

  'erase.title': '{name} sudah menghapus akunnya',
  'erase.body':
      '{name} minta semua catatan bersama kalian ikut dihapus: anggaran, '
          'kategori, dan semua pengeluaran. Kamu yang memutuskan.',
  'erase.keep': 'Simpan catatannya',
  'erase.erase': 'Hapus semuanya',
  'erase.kept': 'Catatan bersama tetap tersimpan.',
  'erase.confirm_title': 'Hapus semua catatan bersama?',
  'erase.confirm_body':
      'Semua anggaran, kategori, dan pengeluaran kalian hilang. Tidak bisa '
          'dibatalkan.',
  'erase.confirm_cta': 'Hapus semuanya',

  // ---------------------------------------------------------- app-level
  'splash.preparing': 'Sebentar…',

  'app.cannot_reach': 'Tidak bisa memuat data kamu',
  'app.setup_title': 'Tinggal satu langkah lagi',
};

// =============================================================================
// ENGLISH
// =============================================================================
const Map<String, String> _en = {
  'common.save': 'Save',
  'common.save_changes': 'Save changes',
  'common.cancel': 'Cancel',
  'common.delete': 'Delete',
  'common.remove': 'Remove',
  'common.edit': 'Edit',
  'common.add': 'Add',
  'common.confirm': 'Confirm',
  'common.decline': 'Decline',
  'common.retry': 'Retry',
  'common.you': 'You',
  'common.partner': 'Partner',
  'common.someone': 'Someone',
  'common.left': 'left',
  'common.over': 'over',
  'common.of': 'of',

  'auth.app_name': 'Family Money',
  'auth.tagline': 'Track money together.',
  'auth.welcome_back': 'Welcome back',
  'auth.name_hint': 'Your name',
  'auth.email_hint': 'Email',
  'auth.password_hint': 'Password',
  'auth.forgot_password': 'Forgot password',
  'auth.sign_in': 'Sign in',
  'auth.create_account': 'Create account',
  'auth.have_account': 'I already have an account',
  'auth.no_account': 'Create an account',
  'auth.err_name': 'Enter your name',
  'auth.err_email_empty': 'Enter your email',
  'auth.err_email_invalid': 'That email isn’t valid',
  'auth.err_password_empty': 'Enter your password',
  'auth.err_password_short': 'At least 6 characters',
  'auth.reset_need_email': 'Enter your email first.',
  'auth.reset_sent': 'Reset link sent to {email}',
  'auth.sign_out': 'Sign out',

  'onboarding.hi': 'Hi {name}',
  'onboarding.blurb':
      'Start a household and invite your partner, or join the one they already '
          'made.',
  'onboarding.start': 'Start our household',
  'onboarding.start_blurb': 'You’ll get a QR code to show your partner.',
  'onboarding.join': 'Join my partner',
  'onboarding.join_blurb': 'Scan their QR code, or type the code they send.',
  'onboarding.name_household': 'Name your household',
  'onboarding.household_name_hint': 'Household name',
  'onboarding.currency': 'CURRENCY',
  'onboarding.create': 'Create household',
  'onboarding.default_name': '{name}’s household',

  'invite.title': 'Invite your partner',
  'invite.blurb':
      'Have them open Family Money, choose "Join my partner", and point their '
          'camera at this.',
  'invite.or_type': 'OR TYPE THIS CODE',
  'invite.copy': 'Copy code',
  'invite.copied': 'Code copied',
  'invite.new_code': 'New code',
  'invite.expiry':
      'One use, expires in 24 hours. Send it straight to them.',
  'invite.connected': 'You’re connected.',

  'join.title': 'Join your partner',
  'join.tap_to_scan': 'Tap to scan',
  'join.stop_camera': 'Stop camera',
  'join.or': 'OR',
  'join.enter_code': 'Enter the invite code',
  'join.enter_code_blurb': 'Eight characters, on your partner’s screen.',
  'join.camera_unavailable': 'The camera isn’t available.',
  'join.still_type': '{message}\n\nYou can type the code below instead.',
  'join.cta': 'Join household',
  'join.confirm_title': 'Join this household?',
  'join.confirm_body':
      '{name} invited you to "{household}". You’ll both see every budget and '
          'expense in it.',
  'join.cta_short': 'Join',

  'shell.tab_overview': 'Overview',
  'shell.tab_budgets': 'Budgets',
  'shell.tab_ledger': 'Ledger',
  'shell.tab_inbox': 'Inbox',
  'shell.add_expense': 'Add an expense',
  'shell.need_budget': 'Create a budget of your own first, or ask for money.',

  'dashboard.subtitle': 'Shared overview',
  'dashboard.connect': 'Connect your partner',
  'dashboard.connect_blurb': 'Show them a QR code so your numbers match.',
  'dashboard.your_budgets': 'Your budgets',
  'dashboard.accumulated': 'Accumulated budget',
  'dashboard.their_budgets': '{name}’s budgets',
  'dashboard.who_spent': 'Who spent what',
  'dashboard.where_went': 'Where it went',
  'dashboard.latest': 'Latest',
  'dashboard.other': 'Other ({count})',
  'dashboard.left_to_spend': 'LEFT',
  'dashboard.over_budget_by': 'OVER BUDGET',
  'dashboard.you_control': 'You control this',
  'dashboard.per_day_left': '{amount}/day left',
  'dashboard.spent_of': '{spent} of {planned}',
  'dashboard.spent_of_both': '{spent} of {planned}, both of you',
  'dashboard.spent_of_solo': '{spent} of {planned}',
  'dashboard.yours': 'Yours',
  'dashboard.theirs': '{name}’s',
  'dashboard.put_aside': 'Put aside this month',
  'dashboard.entries_one': '{count} entry this month',
  'dashboard.entries_many': '{count} entries this month',
  'dashboard.to_confirm': '{count} to confirm',
  'dashboard.moved_in': '{amount} in · started at {base}',
  'dashboard.moved_out': '{amount} out · started at {base}',
  'dashboard.no_budget_title': 'You don’t control a budget yet',
  'dashboard.no_budget_blurb':
      'Spending comes out of a budget you control. You can only look at '
          '{name}’s.',
  'dashboard.no_budget_blurb_solo':
      'Spending comes out of a budget you control. Create one first.',
  'dashboard.request_from': 'Request money from {name}',
  'dashboard.create_my_budget': 'Create my own budget',
  'dashboard.see_not_spend': 'You can only look at this one.',
  'dashboard.request_money': 'Request money',
  'dashboard.target_of': 'Target {amount}',
  'dashboard.left_of': '{amount} left of {planned}',
  'dashboard.over_of': '{amount} over {planned}',
  'dashboard.saving_of': '{spent} of {planned} target',

  'budgets.title': 'Budgets',
  'budgets.this_month': 'This month',
  'budgets.saving_pots': 'Saving pots',
  'budgets.new_budget': 'New budget',
  'budgets.none_title': 'No budgets for {month}',
  'budgets.none_blurb':
      'Decide what you plan to spend, split it into categories, then start '
          'logging.',
  'budgets.create': 'Create a budget',
  'budgets.copy_from': 'Copy from {month}',
  'budgets.nothing_to_copy': 'None of your budgets are in {month}.',
  'budgets.copied_one': 'Copied {count} budget.',
  'budgets.copied_many': 'Copied {count} budgets.',
  'budgets.categories_one': '{count} category',
  'budgets.categories_many': '{count} categories',
  'budgets.awaiting': '{count} awaiting confirmation',
  'budgets.over_allocated': 'Split over plan',
  'budgets.unallocated': '{amount} unallocated',
  'budgets.over_spent': 'Over budget',
  'budgets.you_control': 'You control this',
  'budgets.partner_controls': '{name} controls this',

  'budget_editor.new': 'New budget',
  'budget_editor.edit': 'Edit budget',
  'budget_editor.name_hint': 'Name, e.g. Living costs',
  'budget_editor.type': 'TYPE',
  'budget_editor.monthly': 'Monthly',
  'budget_editor.saving': 'Saving',
  'budget_editor.monthly_blurb': 'Resets every month. This one is for {month}.',
  'budget_editor.saving_blurb': 'Builds up until it reaches the target.',
  'budget_editor.amount': 'AMOUNT',
  'budget_editor.target': 'TARGET',
  'budget_editor.add_target_date': 'Add a target date (optional)',
  'budget_editor.by_date': 'By {date}',
  'budget_editor.who_controls': 'WHO CONTROLS IT',
  'budget_editor.who_controls_blurb':
      'Whoever controls it sets the categories, and only they can spend from '
          'it. You both still see everything.',
  'budget_editor.err_name': 'Give the budget a name.',
  'budget_editor.err_amount': 'The amount has to be more than zero.',

  'category_editor.new': 'New category',
  'category_editor.edit': 'Edit category',
  'category_editor.in_budget': 'In {budget}',
  'category_editor.name_hint': 'Category name',
  'category_editor.allocation': 'ALLOCATION',
  'category_editor.will_ask': '{name} has to agree to this first.',
  'category_editor.add': 'Add category',
  'category_editor.send': 'Send for confirmation',
  'category_editor.save_and_ask': 'Save and ask again',
  'category_editor.sent_to': 'Sent to {name}.',
  'category_editor.err_name': 'Name the category.',
  'category_editor.err_amount': 'The amount has to be more than zero.',

  'status.pending': 'Awaiting confirmation',
  'status.approved': 'Confirmed',
  'status.rejected': 'Declined',
  'detail.of_planned': 'of {amount}',
  'detail.of_target': 'of a {amount} target',
  'detail.where_it_stands': 'BREAKDOWN',
  'detail.already_spent': 'Already spent',
  'detail.in_categories': 'Held in categories',
  'detail.not_carved_up': 'Not split yet',
  'detail.spent': 'SPENT',
  'detail.put_aside': 'PUT ASIDE',
  'detail.planned': 'Planned',
  'detail.target': 'Target',
  'detail.left': 'Left',
  'detail.over_by': 'Over by',
  'detail.unallocated': 'Unallocated',
  'detail.controls_here': '{name} controls the categories here',
  'detail.you_control_here': 'You control the categories here',
  'detail.categories': 'Categories',
  'detail.over_allocated':
      'The categories add up to {allocated}, but the budget is {planned}.',
  'detail.no_categories': 'No categories yet',
  'detail.no_categories_yours':
      'Split this budget so it’s clear what the money is for.',
  'detail.no_categories_theirs': '{name} hasn’t split this budget yet.',
  'detail.add_category': 'Add a category',
  'detail.uncategorised': 'Uncategorised spending',
  'detail.activity': 'Activity ({count})',
  'detail.nothing_spent': 'Nothing spent from this budget yet',
  'detail.nothing_spent_yours': 'Entries you add show up here.',
  'detail.nothing_spent_theirs': 'Entries {name} adds show up here.',
  'detail.edit_budget': 'Edit budget',
  'detail.delete_budget': 'Delete budget',
  'detail.delete_title': 'Delete {name}?',
  'detail.delete_body':
      'Its categories and every expense in it go too, for both of you. This '
          'can’t be undone.',
  'detail.remove_category_title': 'Remove {name}?',
  'detail.remove_category_spent':
      'The expenses stay in the ledger, just without a category.',
  'detail.remove_category_empty': 'Nothing has been spent from it yet.',
  'detail.not_found': 'Budget not found',
  'detail.not_found_blurb':
      'It may have been deleted, or it’s in another month.',

  'expense.new': 'New expense',
  'expense.edit': 'Edit expense',
  'expense.budget': 'BUDGET',
  'expense.category': 'CATEGORY',
  'expense.note_hint': 'What was it for? (optional)',
  'expense.add': 'Add expense',
  'expense.nothing_yours': 'Nothing of yours to spend from',
  'expense.nothing_yours_blurb':
      'An expense comes out of a budget you control. Create one, or ask your '
          'partner for some.',
  'expense.delete_title': 'Delete this expense?',
  'expense.delete_body':
      'It goes for both of you. The totals come back down.',
  'expense.err_amount': 'The amount has to be more than zero.',
  'expense.err_budget': 'Pick which budget this comes out of.',

  'ledger.title': 'Ledger',
  'ledger.everyone': 'Everyone',
  'ledger.entries_one': '{count} entry',
  'ledger.entries_many': '{count} entries',
  'ledger.empty': 'Nothing recorded yet',
  'ledger.empty_blurb':
      'Tap + to log what you spent. Your partner sees it straight away.',
  'ledger.today': 'TODAY',
  'ledger.yesterday': 'YESTERDAY',

  'inbox.title': 'Inbox',
  'inbox.empty': 'Nothing to confirm',
  'inbox.empty_unpaired':
      'Once your partner joins, budget splits and money requests turn up here.',
  'inbox.empty_blurb': 'Budget splits and money requests turn up here.',
  'inbox.waiting_on_you': 'Waiting on you',
  'inbox.waiting_on_partner': 'Waiting on your partner',
  'inbox.money_request': 'Money request',
  'inbox.asking_for': '{name} is asking for money out of {from}, into {to}.',
  'inbox.leaves': 'Leaves {amount}',
  'inbox.more_than_you_have': 'More than is left',
  'inbox.would_go_over': 'Approving this puts {budget} over budget.',
  'inbox.send_money': 'Send money',
  'inbox.money_moved': 'Money moved',
  'inbox.declined': 'Declined',
  'inbox.confirmed': 'Confirmed',
  'inbox.decline_title': 'Decline',
  'inbox.decline_hint': 'Say why (optional)',
  'inbox.withdraw': 'Withdraw',
  'inbox.editing_replaces':
      'Changing the category replaces this request.',
  'inbox.waiting_from': '{amount} from {budget} · waiting on {name}',
  'inbox.waiting_amount': '{amount} · waiting on {name}',
  'inbox.vs_before': 'Was {amount}',
  'inbox.note':
      'Splits that aren’t confirmed yet already count toward the plan. The '
          'money only moves once a request is approved.',

  'request.title': 'Request money',
  'request.subtitle': 'From a budget {name} controls',
  'request.from': 'FROM',
  'request.amount': 'AMOUNT',
  'request.what_for': 'WHAT FOR',
  'request.what_for_hint': 'School shoes, petrol…',
  'request.lands_in': 'LANDS IN',
  'request.name_budget_hint': 'Name a budget of your own',
  'request.creates_budget':
      'You don’t control a budget yet, so this makes one to hold it.',
  'request.partner_confirms':
      '{name} confirms this in their Inbox. If they agree, the money moves '
          'into your budget.',
  'request.send': 'Send request',
  'request.left_in': '{amount} left in {budget}',
  'request.err_source': 'Choose which budget to ask from.',
  'request.err_amount': 'The amount has to be more than zero.',
  'request.err_too_much': 'Only {amount} is left in {budget}.',
  'request.err_name': 'Give the budget a name.',
  'request.err_destination': 'Choose where it should land.',
  'request.sent_to': 'Sent to {name}.',
  'request.none_title': 'Nothing to ask for yet',
  'request.none_unpaired':
      'Connect your partner first, then you can ask them for money.',
  'request.none_blurb': '{name} has no monthly budget to move money out of.',

  'settings.title': 'Settings',
  'settings.partner': 'Partner',
  'settings.invite_partner': 'Invite your partner',
  'settings.connected': 'Connected',
  'settings.household': 'Household',
  'settings.name': 'Name',
  'settings.currency': 'Currency',
  'settings.month_starts': 'Month starts on',
  'settings.month_first': 'The 1st (calendar month)',
  'settings.month_day': 'Day {day}',
  'settings.month_blurb':
      'If your budget starts on payday, set that day here. Expenses land in '
          'the right month automatically.',
  'settings.language': 'Language',
  'settings.preferences': 'Preferences',
  'settings.account': 'Account',
  'settings.leave': 'Leave household',
  'settings.leave_title': 'Leave this household?',
  'settings.leave_body':
      'You stop seeing the shared budgets and ledger. It all stays with your '
          'partner, and you can be invited back.',
  'settings.leave_cta': 'Leave',
  'settings.your_name': 'Your name',
  'settings.household_name': 'Household name',

  'chart.range_day': 'Daily',
  'chart.range_month': 'Monthly',
  'chart.range_year': 'Yearly',
  'chart.left_in': 'Left in {name}, your budget',
  'chart.over_in': 'Over in {name}, your budget',
  'chart.left_household': 'Left across all the household budgets',
  'chart.over_household': 'Over all the household budgets',
  'chart.budget_of': 'Budget {amount}',
  'chart.projection_ok':
      'Keep this up and you finish at {amount}, {left} to spare.',
  'chart.projection_over':
      'Keep this up and you finish at {amount}, {over} over.',
  'chart.projection_none': 'Nothing recorded this month yet.',
  'chart.fix_daily': 'Drop to {amount} a day and you land on it.',
  'chart.fix_stop': 'The budget is already spent.',
  'chart.daily_note_none': '{amount} a day. No day has gone over.',
  'chart.daily_note_one': '{amount} a day. {count} day went over.',
  'chart.daily_note_many': '{amount} a day. {count} days went over.',
  'chart.year_note': '{amount} spent across {year}.',
  'chart.legend_spent': 'Spent',
  'chart.legend_pace': 'On track',
  'chart.legend_projection': 'Projection',
  'chart.a11y': '{range} chart. {spent} spent of a {budget} budget.',

  'splash.preparing': 'One moment…',

  'error.permission_denied': 'You don’t have permission for this.',
  'error.offline':
      'No connection. Anything you saved will go out on its own later.',
  'error.signed_out': 'Your session expired. Sign in again.',
  'error.not_found': 'That isn’t there any more. It may have just been '
      'deleted.',
  'error.already_exists': 'That already exists.',
  'error.needs_index': 'Can’t show this yet. Try again later.',
  'error.quota': 'The server is busy. Try again tomorrow.',
  'error.email_taken': 'That email is already in use.',
  'error.email_invalid': 'That email isn’t valid.',
  'error.password_weak': 'That password is too short. Six characters minimum.',
  'error.credentials': 'That email or password is wrong.',
  'error.too_many': 'Too many attempts. Wait a moment.',
  'error.unknown': 'Something went wrong. Try again.',

  'expense.new_income': 'New income',
  'expense.add_income': 'Add income',
  'expense.edit_income': 'Edit income',
  'expense.kind_spending': 'Out',
  'expense.kind_income': 'In',

  'category_editor.headroom': '{amount} of {total} still unallocated.',
  'category_editor.none_left':
      'All of it is allocated. Free some up from another category first.',
  'category_editor.err_over':
      'That is {over} too much. {budget} has only {headroom} left. Lower '
          'another category, or raise the budget.',

  'detail.taken_out': 'Taken back out',
  'detail.income_added': '{amount} paid into this budget.',
  'detail.record_income': 'Add income',
  'detail.record_spending': 'Add spending',
  'detail.record_deposit': 'Pay in',
  'detail.record_withdrawal': 'Take out',

  'inbox.all_allocated':
      '{budget} is fully split into categories. You’ll pick which one this '
          'comes out of.',
  'inbox.take_from_title': 'Take it out of which category?',
  'inbox.take_from_blurb':
      '{amount} comes off one of the categories in {budget}.',
  'inbox.only_has': 'Only has {amount}',
  'inbox.no_categories_to_take_from':
      'No category in this budget has anything to give.',

  'history.title': 'Money history',
  'history.on_this_budget': 'Money moved',
  'history.received_from': 'Got it from {name}',
  'history.gave_to': 'Gave it to {name}',
  'history.refused_by': '{name} said no',
  'history.you_refused': 'You turned {name} down',
  'history.out_of': 'out of {category}',

  'saving_seed.education': 'Education',
  'saving_seed.emergency': 'Emergency fund',
  'saving_seed.other': 'Other',

  'auth.or': 'or',
  'auth.continue_google': 'Continue with Google',

  'delete.title': 'Delete account',
  'delete.talk_title': 'Before you do',
  'delete.talk_body':
      'If something is hard between you and {name}, try talking about it '
          'first, at a calm moment. Often it isn’t really about the '
          'money.\n\nThis button will still be here if it turns out to be '
          'what you want.',
  'delete.what_happens': 'What happens',
  'delete.point_profile': 'Your name, email and profile are erased.',
  'delete.point_signin':
      'You won’t be able to sign in with this account again.',
  'delete.point_fresh':
      'You can sign up again with the same email, but it starts empty. '
          'Nothing comes back.',
  'delete.point_solo':
      'Every budget, entry and saving pot of yours goes with it.',
  'delete.point_leave': 'You leave the household you share with {name}.',
  'delete.point_partner_keeps':
      '{name} keeps the shared budgets and ledger. Those are their records '
          'too.',
  'delete.point_forever': 'This can’t be undone.',
  'delete.shared_title': 'The shared records',
  'delete.shared_blurb':
      'The budgets and the ledger are not yours alone. You can ask for them '
          'to be erased, but {name} decides.',
  'delete.ask_erase': 'Ask {name} to erase everything we shared',
  'delete.ask_erase_note':
      '{name} will be asked. If they say no, the records stay with them.',
  'delete.confirm_title': 'Confirm',
  'delete.confirm_blurb': 'Type {word} to continue.',
  'delete.confirm_word': 'DELETE',
  'delete.err_word': 'Type {word} exactly to continue.',
  'delete.final_title': 'Delete your account?',
  'delete.final_body':
      'After this your account is gone and can’t be brought back.',
  'delete.confirm_cta': 'Yes, delete it',
  'delete.keep_account': 'Cancel',
  'delete.cta': 'Delete my account',

  'erase.title': '{name} deleted their account',
  'erase.body':
      '{name} asked for everything you shared to be erased too: the budgets, '
          'the categories and the whole ledger. It’s your call.',
  'erase.keep': 'Keep the records',
  'erase.erase': 'Erase everything',
  'erase.kept': 'The shared records have been kept.',
  'erase.confirm_title': 'Erase every shared record?',
  'erase.confirm_body':
      'All your budgets, categories and ledger entries go. This can’t be '
          'undone.',
  'erase.confirm_cta': 'Erase everything',

  'app.cannot_reach': 'Could not load your data',
  'app.setup_title': 'One setup step left',
};
