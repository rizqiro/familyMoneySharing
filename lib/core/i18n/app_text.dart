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
  'common.confirm': 'Setujui',
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
  'auth.tagline': 'Satu gambaran bersama ke mana uang kalian pergi.',
  'auth.welcome_back': 'Selamat datang kembali.',
  'auth.name_hint': 'Nama kamu',
  'auth.email_hint': 'Email',
  'auth.password_hint': 'Kata sandi',
  'auth.forgot_password': 'Lupa kata sandi',
  'auth.sign_in': 'Masuk',
  'auth.create_account': 'Buat akun',
  'auth.have_account': 'Saya sudah punya akun',
  'auth.no_account': 'Buat akun baru',
  'auth.err_name': 'Isi nama panggilan kamu',
  'auth.err_email_empty': 'Isi email kamu',
  'auth.err_email_invalid': 'Sepertinya itu bukan alamat email',
  'auth.err_password_empty': 'Isi kata sandi kamu',
  'auth.err_password_short': 'Pakai minimal 6 karakter',
  'auth.reset_need_email': 'Isi email dulu, baru tekan atur ulang.',
  'auth.reset_sent': 'Tautan atur ulang dikirim ke {email}',
  'auth.sign_out': 'Keluar',

  // --------------------------------------------------------- onboarding
  'onboarding.hi': 'Hai {name}',
  'onboarding.blurb':
      'Uang itu dibagi, jadi aplikasinya juga. Mulai rumah tangga dan undang '
          'pasangan kamu, atau gabung ke yang sudah dia buat.',
  'onboarding.start': 'Mulai rumah tangga kami',
  'onboarding.start_blurb':
      'Buat ruang bersama, lalu tunjukkan kode QR ke pasangan kamu.',
  'onboarding.join': 'Gabung dengan pasangan',
  'onboarding.join_blurb':
      'Pindai kode QR dia, atau ketik kode undangan yang dia kirim.',
  'onboarding.name_household': 'Beri nama rumah tangga',
  'onboarding.household_name_hint': 'Nama rumah tangga',
  'onboarding.currency': 'MATA UANG',
  'onboarding.create': 'Buat rumah tangga',
  'onboarding.default_name': 'Rumah tangga {name}',

  // ------------------------------------------------------------- invite
  'invite.title': 'Undang pasangan',
  'invite.blurb':
      'Minta dia buka Family Money, pilih "Gabung dengan pasangan", lalu '
          'arahkan kameranya ke sini.',
  'invite.or_type': 'ATAU KETIK KODE INI',
  'invite.copy': 'Salin kode',
  'invite.copied': 'Kode disalin',
  'invite.new_code': 'Kode baru',
  'invite.expiry':
      'Sekali pakai, dan hangus dalam 24 jam. Siapa pun yang punya kodenya '
          'bisa gabung, jadi kirim langsung ke dia.',
  'invite.connected': 'Kalian sudah terhubung.',

  // --------------------------------------------------------------- join
  'join.title': 'Gabung dengan pasangan',
  'join.tap_to_scan': 'Ketuk untuk pindai kodenya',
  'join.stop_camera': 'Matikan kamera',
  'join.or': 'ATAU',
  'join.enter_code': 'Masukkan kode undangan',
  'join.enter_code_blurb': 'Delapan karakter, dari layar ponsel pasangan kamu.',
  'join.camera_unavailable': 'Kamera tidak bisa dipakai.',
  'join.still_type': '{message}\n\nKamu tetap bisa mengetik kodenya di bawah.',
  'join.cta': 'Gabung rumah tangga',
  'join.confirm_title': 'Gabung ke rumah tangga ini?',
  'join.confirm_body':
      '{name} mengundang kamu ke "{household}". Kalian berdua akan melihat '
          'semua anggaran dan semua pengeluaran di dalamnya.',
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
  'dashboard.connect_blurb':
      'Tunjukkan kode QR supaya kalian melihat angka yang sama.',
  'dashboard.your_budgets': 'Anggaran kamu',
  'dashboard.accumulated': 'Total anggaran',
  'dashboard.their_budgets': 'Anggaran {name}',
  'dashboard.who_spent': 'Siapa belanja apa',
  'dashboard.where_went': 'Ke mana perginya',
  'dashboard.latest': 'Terbaru',
  'dashboard.other': 'Lainnya ({count})',
  'dashboard.left_to_spend': 'SISA UNTUK DIBELANJAKAN',
  'dashboard.over_budget_by': 'LEBIH DARI ANGGARAN',
  'dashboard.you_control': 'Kamu yang pegang ini',
  'dashboard.ahead_of_pace': 'Lebih cepat dari seharusnya',
  'dashboard.per_day_left': '{amount}/hari tersisa',
  'dashboard.spent_of': '{spent} dari {planned}',
  'dashboard.spent_of_both': '{spent} terpakai dari {planned} berdua',
  'dashboard.spent_of_solo': '{spent} terpakai dari {planned}',
  'dashboard.yours': 'Punya kamu',
  'dashboard.theirs': 'Punya {name}',
  'dashboard.put_aside': 'Ditabung bulan ini',
  'dashboard.entries_one': '{count} catatan bulan ini',
  'dashboard.entries_many': '{count} catatan bulan ini',
  'dashboard.to_confirm': '{count} perlu disetujui',
  'dashboard.moved_in': '{amount} masuk · diatur di {base}',
  'dashboard.moved_out': '{amount} keluar · diatur di {base}',
  'dashboard.no_budget_title': 'Kamu belum pegang anggaran',
  'dashboard.no_budget_blurb':
      'Pengeluaran diambil dari anggaran yang kamu pegang. Anggaran {name} '
          'bisa kamu lihat, tapi bukan untuk kamu belanjakan.',
  'dashboard.no_budget_blurb_solo':
      'Pengeluaran diambil dari anggaran yang kamu pegang. Buat satu dulu '
          'untuk mulai mencatat.',
  'dashboard.request_from': 'Minta uang ke {name}',
  'dashboard.create_my_budget': 'Buat anggaran saya sendiri',
  'dashboard.see_not_spend': 'Bisa dilihat, tidak bisa dibelanjakan.',
  'dashboard.request_money': 'Minta uang',
  'dashboard.target_of': 'Target {amount}',
  'dashboard.left_of': '{amount} sisa dari {planned}',
  'dashboard.over_of': '{amount} lebih dari {planned}',
  'dashboard.saving_of': '{spent} dari target {planned}',

  // ------------------------------------------------------------ budgets
  'budgets.title': 'Anggaran',
  'budgets.this_month': 'Bulan ini',
  'budgets.saving_pots': 'Tabungan',
  'budgets.new_budget': 'Anggaran baru',
  'budgets.none_title': 'Belum ada anggaran untuk {month}',
  'budgets.none_blurb':
      'Tentukan rencana belanja kalian, bagi jadi beberapa kategori, lalu '
          'kalian berdua bisa mulai mencatat.',
  'budgets.create': 'Buat anggaran',
  'budgets.copy_from': 'Salin dari {month}',
  'budgets.nothing_to_copy': 'Tidak ada milik kamu untuk disalin dari {month}.',
  'budgets.copied_one': '{count} anggaran disalin.',
  'budgets.copied_many': '{count} anggaran disalin.',
  'budgets.categories_one': '{count} kategori',
  'budgets.categories_many': '{count} kategori',
  'budgets.awaiting': '{count} menunggu persetujuan',
  'budgets.over_allocated': 'Pembagian melebihi rencana',
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
  'budget_editor.saving_blurb':
      'Terbawa dari bulan ke bulan sampai targetnya tercapai.',
  'budget_editor.amount': 'JUMLAH',
  'budget_editor.target': 'TARGET',
  'budget_editor.add_target_date': 'Tambah tanggal target (opsional)',
  'budget_editor.by_date': 'Sebelum {date}',
  'budget_editor.who_controls': 'SIAPA YANG PEGANG',
  'budget_editor.who_controls_blurb':
      'Yang pegang menentukan kategorinya. Kalian berdua tetap melihat '
          'semuanya, tapi hanya dia yang bisa belanja dari anggaran ini.',
  'budget_editor.err_name': 'Beri nama anggarannya.',
  'budget_editor.err_amount': 'Isi jumlah lebih dari nol.',

  // --------------------------------------------------- category editor
  'category_editor.new': 'Kategori baru',
  'category_editor.edit': 'Ubah kategori',
  'category_editor.in_budget': 'Di dalam {budget}',
  'category_editor.name_hint': 'Nama kategori',
  'category_editor.allocation': 'PEMBAGIAN',
  'category_editor.will_ask':
      '{name} akan diminta menyetujui pembagian ini.',
  'category_editor.add': 'Tambah kategori',
  'category_editor.send': 'Kirim untuk disetujui',
  'category_editor.save_and_ask': 'Simpan dan minta lagi',
  'category_editor.sent_to': 'Dikirim ke {name} untuk disetujui.',
  'category_editor.err_name': 'Beri nama kategorinya.',
  'category_editor.err_amount': 'Bagi jumlah lebih dari nol.',

  // ----------------------------------------------------- budget detail
  'status.pending': 'Menunggu persetujuan',
  'status.approved': 'Disetujui',
  'status.rejected': 'Ditolak',
  'detail.of_planned': 'dari {amount}',
  'detail.of_target': 'dari target {amount}',
  'detail.where_it_stands': 'UANGNYA BERDIRI DI SINI',
  'detail.already_spent': 'Sudah dibelanjakan',
  'detail.in_categories': 'Masih dijatah kategori',
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
      'Kategori berjumlah {allocated}, lebih dari rencana {planned}.',
  'detail.no_categories': 'Belum ada kategori',
  'detail.no_categories_yours':
      'Bagi anggaran ini supaya kalian tahu uangnya untuk apa.',
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
          'berdua. Ini tidak bisa dibatalkan.',
  'detail.remove_category_title': 'Hapus {name}?',
  'detail.remove_category_spent':
      'Pengeluarannya tetap ada di catatan, hanya tidak berkategori lagi.',
  'detail.remove_category_empty': 'Belum ada yang dibelanjakan dari kategori ini.',
  'detail.not_found': 'Anggaran tidak ditemukan',
  'detail.not_found_blurb':
      'Mungkin sudah dihapus, atau milik bulan yang lain.',

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
          'minta pasangan kamu memindahkan sebagian.',
  'expense.delete_title': 'Hapus pengeluaran ini?',
  'expense.delete_body':
      'Catatan ini hilang untuk kalian berdua dan totalnya kembali turun.',
  'expense.err_amount': 'Isi jumlah lebih dari nol.',
  'expense.err_budget': 'Pilih anggaran mana yang dipakai.',

  // ------------------------------------------------------------- ledger
  'ledger.title': 'Catatan',
  'ledger.everyone': 'Semua',
  'ledger.entries_one': '{count} catatan',
  'ledger.entries_many': '{count} catatan',
  'ledger.empty': 'Belum ada yang dicatat',
  'ledger.empty_blurb':
      'Ketuk tombol + untuk mencatat pengeluaran. Pasangan kamu langsung '
          'melihatnya.',
  'ledger.today': 'HARI INI',
  'ledger.yesterday': 'KEMARIN',

  // -------------------------------------------------------------- inbox
  'inbox.title': 'Kotak masuk',
  'inbox.empty': 'Tidak ada yang perlu disetujui',
  'inbox.empty_unpaired':
      'Begitu pasangan kamu gabung, pembagian anggaran dan permintaan uang '
          'akan muncul di sini.',
  'inbox.empty_blurb':
      'Pembagian yang perlu disepakati dan permintaan memindahkan uang sama-'
          'sama muncul di sini.',
  'inbox.waiting_on_you': 'Menunggu kamu',
  'inbox.waiting_on_partner': 'Menunggu pasangan',
  'inbox.money_request': 'Permintaan uang',
  'inbox.asking_for':
      '{name} minta uang dari {from}, untuk masuk ke {to}.',
  'inbox.leaves': 'Sisa {amount}',
  'inbox.more_than_you_have': 'Lebih dari yang ada',
  'inbox.would_go_over': 'Menyetujuinya akan membuat {budget} melebihi anggaran.',
  'inbox.send_money': 'Kirim uang',
  'inbox.money_moved': 'Uang dipindahkan',
  'inbox.declined': 'Ditolak',
  'inbox.confirmed': 'Disetujui',
  'inbox.decline_title': 'Tolak',
  'inbox.decline_hint': 'Beri alasan (opsional)',
  'inbox.withdraw': 'Tarik',
  'inbox.editing_replaces': 'Mengubah kategori menggantikan permintaan ini.',
  'inbox.waiting_from': '{amount} dari {budget} · menunggu {name}',
  'inbox.waiting_amount': '{amount} · menunggu {name}',
  'inbox.vs_before': '{amount} dari sebelumnya',
  'inbox.note':
      'Pembagian yang belum disetujui tetap dihitung dalam rencana, jadi '
          'angkanya mencerminkan niat kalian sambil dibicarakan. Uang baru '
          'pindah setelah permintaan disetujui.',

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
      'Kamu belum pegang apa-apa, jadi ini membuatkan anggaran untuk menerimanya.',
  'request.partner_confirms':
      '{name} menyetujuinya di kotak masuk. Kalau dia setuju, uangnya pindah '
          'ke anggaran kamu — kamu tetap tidak belanja dari punya dia.',
  'request.send': 'Kirim permintaan',
  'request.left_in': '{amount} tersisa di {budget}',
  'request.err_source': 'Pilih dari anggaran yang mana.',
  'request.err_amount': 'Isi jumlah lebih dari nol.',
  'request.err_too_much': 'Hanya ada {amount} tersisa di {budget}.',
  'request.err_name': 'Beri nama anggaran tujuannya.',
  'request.err_destination': 'Pilih uangnya mau masuk ke mana.',
  'request.sent_to': 'Dikirim ke {name}.',
  'request.none_title': 'Belum ada yang bisa diminta',
  'request.none_unpaired':
      'Hubungkan pasangan kamu dulu, baru bisa minta uang ke dia.',
  'request.none_blurb': '{name} belum punya anggaran bulanan untuk dipindahkan.',

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
      'Kalau kalian mengatur anggaran dari tanggal gajian, bukan tanggal 1, '
          'pilih harinya di sini. Pengeluaran otomatis masuk ke bulan yang tepat.',
  'settings.language': 'Bahasa',
  'settings.preferences': 'Preferensi',
  'settings.account': 'Akun',
  'settings.leave': 'Keluar dari rumah tangga',
  'settings.leave_title': 'Keluar dari rumah tangga ini?',
  'settings.leave_body':
      'Kamu berhenti melihat anggaran dan catatan bersama. Semuanya tetap ada '
          'pada pasangan kamu, dan kamu bisa diundang lagi.',
  'settings.leave_cta': 'Keluar',
  'settings.your_name': 'Nama kamu',
  'settings.household_name': 'Nama rumah tangga',

  // -------------------------------------------------------------- chart
  'chart.range_day': 'Harian',
  'chart.range_month': 'Bulanan',
  'chart.range_year': 'Tahunan',
  'chart.left_in': 'Sisa di {name} \u2014 anggaran kamu',
  'chart.over_in': 'Lebih di {name} \u2014 anggaran kamu',
  'chart.left_household': 'Sisa di seluruh anggaran rumah tangga',
  'chart.over_household': 'Lebih dari seluruh anggaran rumah tangga',
  'chart.budget_of': 'Anggaran {amount}',
  'chart.projection_ok':
      'Dengan laju ini kamu selesai di {amount} \u2014 sisa {left}.',
  'chart.projection_over':
      'Dengan laju ini kamu selesai di {amount} \u2014 lebih {over}.',
  'chart.projection_none': 'Belum ada yang dicatat bulan ini.',
  'chart.fix_daily': 'Turunkan ke {amount}/hari supaya pas.',
  'chart.fix_stop': 'Anggarannya sudah habis.',
  'chart.daily_note_none': 'Jatah harian {amount}. Belum ada hari yang lewat.',
  'chart.daily_note_one': 'Jatah harian {amount}. {count} hari lewat jatah.',
  'chart.daily_note_many': 'Jatah harian {amount}. {count} hari lewat jatah.',
  'chart.year_note': '{amount} terpakai sepanjang {year}.',
  'chart.legend_spent': 'Terpakai',
  'chart.legend_pace': 'Laju ideal',
  'chart.legend_projection': 'Perkiraan',
  'chart.a11y':
      'Grafik {range}. {spent} terpakai dari anggaran {budget}.',

  // -------------------------------------------------------------- errors
  'error.permission_denied':
      'Firebase menolak permintaan ini. Biasanya karena aturan keamanan '
          'belum dipasang di Firebase Console \u2014 buka tab Rules, tempel '
          'isi firebase/firestore.rules, lalu Publish. Kalau sudah dipasang, '
          'berarti ini memang bukan milik kamu.',
  'error.offline': 'Tidak bisa menghubungi Firebase. Cek koneksi kamu; '
      'catatan yang sudah dibuat akan terkirim sendiri nanti.',
  'error.signed_out': 'Sesi kamu habis. Masuk lagi, ya.',
  'error.not_found': 'Datanya sudah tidak ada. Mungkin baru dihapus.',
  'error.already_exists': 'Datanya sudah ada.',
  'error.needs_index':
      'Firestore butuh index untuk query ini. Buka log error-nya \u2014 ada '
          'tautan untuk membuatnya sekali klik.',
  'error.quota': 'Kuota Firebase habis untuk hari ini. Coba lagi besok.',
  'error.email_taken': 'Email itu sudah dipakai.',
  'error.email_invalid': 'Emailnya tidak valid.',
  'error.password_weak': 'Kata sandinya terlalu pendek. Minimal 6 huruf.',
  'error.credentials': 'Email atau kata sandinya salah.',
  'error.too_many': 'Terlalu banyak percobaan. Tunggu sebentar.',
  'error.unknown': 'Ada yang tidak beres. Coba lagi.',

  // ------------------------------------------------- income & transfers
  'expense.new_income': 'Catat pemasukan',
  'expense.edit_income': 'Ubah pemasukan',
  'expense.kind_spending': 'Keluar',
  'expense.kind_income': 'Masuk',

  'category_editor.headroom': 'Sisa {amount} dari {total} belum dibagi.',
  'category_editor.none_left':
      'Semua anggaran sudah dibagi. Kurangi kategori lain dulu.',
  'category_editor.err_over':
      'Kelebihan {over}. Di {budget} cuma sisa {headroom} yang belum dibagi \u2014 '
          'kurangi kategori lain dulu, atau naikkan jumlah anggarannya.',

  'detail.taken_out': 'Diambil lagi',
  'detail.income_added': '{amount} masuk ke anggaran ini.',
  'detail.record_income': 'Catat pemasukan',
  'detail.record_spending': 'Catat pengeluaran',
  'detail.record_deposit': 'Setor',
  'detail.record_withdrawal': 'Ambil',

  'inbox.all_allocated':
      '{budget} sudah dibagi habis ke kategori. Nanti kamu pilih kategori '
          'mana yang dikurangi.',
  'inbox.take_from_title': 'Ambil dari kategori mana?',
  'inbox.take_from_blurb':
      '{amount} akan dikurangi dari salah satu kategori di {budget}.',
  'inbox.only_has': 'Cuma ada {amount}',
  'inbox.no_categories_to_take_from':
      'Tidak ada kategori yang bisa dikurangi di anggaran ini.',

  'history.title': 'Riwayat dana',
  'history.on_this_budget': 'Perpindahan dana',
  'history.received_from': 'Terima dari {name}',
  'history.gave_to': 'Kasih ke {name}',
  'history.refused_by': '{name} menolak',
  'history.you_refused': 'Kamu tolak permintaan {name}',
  'history.out_of': 'dari {category}',

  'saving_seed.education': 'Pendidikan',
  'saving_seed.emergency': 'Dana darurat',
  'saving_seed.other': 'Lainnya',

  // ---------------------------------------------------------- app-level
  'splash.preparing': 'Menyiapkan rumah tangga kamu\u2026',

  'app.cannot_reach': 'Tidak bisa mengambil data kamu',
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
  'auth.tagline': 'One shared picture of where your money goes.',
  'auth.welcome_back': 'Welcome back.',
  'auth.name_hint': 'Your name',
  'auth.email_hint': 'Email',
  'auth.password_hint': 'Password',
  'auth.forgot_password': 'Forgot password',
  'auth.sign_in': 'Sign in',
  'auth.create_account': 'Create account',
  'auth.have_account': 'I already have an account',
  'auth.no_account': 'Create an account',
  'auth.err_name': 'Tell us what to call you',
  'auth.err_email_empty': 'Enter your email',
  'auth.err_email_invalid': 'That does not look like an email',
  'auth.err_password_empty': 'Enter your password',
  'auth.err_password_short': 'Use at least 6 characters',
  'auth.reset_need_email': 'Enter your email first, then tap reset.',
  'auth.reset_sent': 'Reset link sent to {email}',
  'auth.sign_out': 'Sign out',

  'onboarding.hi': 'Hi {name}',
  'onboarding.blurb':
      'Money is shared, so the app is too. Start a household and invite your '
          'partner, or join the one they already made.',
  'onboarding.start': 'Start our household',
  'onboarding.start_blurb':
      'Create the shared space, then show your partner a QR code to join it.',
  'onboarding.join': 'Join my partner',
  'onboarding.join_blurb':
      'Scan their QR code, or type the invite code they send you.',
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
      'Single use, and it expires in 24 hours. Anyone with the code can join, '
          'so share it directly.',
  'invite.connected': 'You are connected.',

  'join.title': 'Join your partner',
  'join.tap_to_scan': 'Tap to scan their code',
  'join.stop_camera': 'Stop camera',
  'join.or': 'OR',
  'join.enter_code': 'Enter the invite code',
  'join.enter_code_blurb':
      'Eight characters, from the screen on your partner’s phone.',
  'join.camera_unavailable': 'The camera is unavailable.',
  'join.still_type': '{message}\n\nYou can still type the code below.',
  'join.cta': 'Join household',
  'join.confirm_title': 'Join this household?',
  'join.confirm_body':
      '{name} invited you to "{household}". You will both see every budget and '
          'every expense in it.',
  'join.cta_short': 'Join',

  'shell.tab_overview': 'Overview',
  'shell.tab_budgets': 'Budgets',
  'shell.tab_ledger': 'Ledger',
  'shell.tab_inbox': 'Inbox',
  'shell.add_expense': 'Add an expense',
  'shell.need_budget': 'Create a budget of your own first, or ask for money.',

  'dashboard.subtitle': 'Shared overview',
  'dashboard.connect': 'Connect your partner',
  'dashboard.connect_blurb':
      'Show them a QR code so you both see the same numbers.',
  'dashboard.your_budgets': 'Your budgets',
  'dashboard.accumulated': 'Accumulated budget',
  'dashboard.their_budgets': '{name}’s budgets',
  'dashboard.who_spent': 'Who spent what',
  'dashboard.where_went': 'Where it went',
  'dashboard.latest': 'Latest',
  'dashboard.other': 'Other ({count})',
  'dashboard.left_to_spend': 'LEFT TO SPEND',
  'dashboard.over_budget_by': 'OVER BUDGET BY',
  'dashboard.you_control': 'You control this',
  'dashboard.ahead_of_pace': 'Ahead of pace',
  'dashboard.per_day_left': '{amount}/day left',
  'dashboard.spent_of': '{spent} of {planned}',
  'dashboard.spent_of_both': '{spent} spent of {planned} across both of you',
  'dashboard.spent_of_solo': '{spent} spent of {planned}',
  'dashboard.yours': 'Yours',
  'dashboard.theirs': '{name}’s',
  'dashboard.put_aside': 'Put aside this month',
  'dashboard.entries_one': '{count} entry this month',
  'dashboard.entries_many': '{count} entries this month',
  'dashboard.to_confirm': '{count} to confirm',
  'dashboard.moved_in': '{amount} moved in · set at {base}',
  'dashboard.moved_out': '{amount} moved out · set at {base}',
  'dashboard.no_budget_title': 'You don’t control a budget yet',
  'dashboard.no_budget_blurb':
      'Spending comes out of a budget you control. {name}’s budgets are '
          'visible to you, but not yours to spend.',
  'dashboard.no_budget_blurb_solo':
      'Spending comes out of a budget you control. Create one to start logging.',
  'dashboard.request_from': 'Request money from {name}',
  'dashboard.create_my_budget': 'Create my own budget',
  'dashboard.see_not_spend': 'You can see it, not spend from it.',
  'dashboard.request_money': 'Request money',
  'dashboard.target_of': 'Target {amount}',
  'dashboard.left_of': '{amount} left of {planned}',
  'dashboard.over_of': '{amount} over of {planned}',
  'dashboard.saving_of': '{spent} of {planned} target',

  'budgets.title': 'Budgets',
  'budgets.this_month': 'This month',
  'budgets.saving_pots': 'Saving pots',
  'budgets.new_budget': 'New budget',
  'budgets.none_title': 'No budgets for {month}',
  'budgets.none_blurb':
      'Decide what you plan to spend, split it into categories, and both of you '
          'can start logging against it.',
  'budgets.create': 'Create a budget',
  'budgets.copy_from': 'Copy from {month}',
  'budgets.nothing_to_copy': 'Nothing of yours to copy from {month}.',
  'budgets.copied_one': 'Copied {count} budget.',
  'budgets.copied_many': 'Copied {count} budgets.',
  'budgets.categories_one': '{count} category',
  'budgets.categories_many': '{count} categories',
  'budgets.awaiting': '{count} awaiting confirmation',
  'budgets.over_allocated': 'Allocated over plan',
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
  'budget_editor.saving_blurb':
      'Carries over month to month until it reaches the target.',
  'budget_editor.amount': 'AMOUNT',
  'budget_editor.target': 'TARGET',
  'budget_editor.add_target_date': 'Add a target date (optional)',
  'budget_editor.by_date': 'By {date}',
  'budget_editor.who_controls': 'WHO CONTROLS IT',
  'budget_editor.who_controls_blurb':
      'The controller sets the categories. You both see everything, but only '
          'they can spend from this budget.',
  'budget_editor.err_name': 'Give the budget a name.',
  'budget_editor.err_amount': 'Enter an amount greater than zero.',

  'category_editor.new': 'New category',
  'category_editor.edit': 'Edit category',
  'category_editor.in_budget': 'In {budget}',
  'category_editor.name_hint': 'Category name',
  'category_editor.allocation': 'ALLOCATION',
  'category_editor.will_ask': '{name} gets asked to confirm this allocation.',
  'category_editor.add': 'Add category',
  'category_editor.send': 'Send for confirmation',
  'category_editor.save_and_ask': 'Save and ask again',
  'category_editor.sent_to': 'Sent to {name} to confirm.',
  'category_editor.err_name': 'Name the category.',
  'category_editor.err_amount': 'Allocate an amount greater than zero.',

  'status.pending': 'Awaiting confirmation',
  'status.approved': 'Confirmed',
  'status.rejected': 'Declined',
  'detail.of_planned': 'of {amount}',
  'detail.of_target': 'of a {amount} target',
  'detail.where_it_stands': 'WHERE THE MONEY STANDS',
  'detail.already_spent': 'Already spent',
  'detail.in_categories': 'Still held by categories',
  'detail.not_carved_up': 'Not carved up yet',
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
      'Categories add up to {allocated}, which is more than the {planned} plan.',
  'detail.no_categories': 'No categories yet',
  'detail.no_categories_yours':
      'Split this budget so you both know what the money is meant for.',
  'detail.no_categories_theirs': '{name} has not split this budget yet.',
  'detail.add_category': 'Add a category',
  'detail.uncategorised': 'Uncategorised spending',
  'detail.activity': 'Activity ({count})',
  'detail.nothing_spent': 'Nothing spent from this budget yet',
  'detail.nothing_spent_yours': 'Entries you file against it show up here.',
  'detail.nothing_spent_theirs': 'Entries {name} files against it show up here.',
  'detail.edit_budget': 'Edit budget',
  'detail.delete_budget': 'Delete budget',
  'detail.delete_title': 'Delete {name}?',
  'detail.delete_body':
      'Its categories and every expense filed under it are deleted too, for '
          'both of you. This cannot be undone.',
  'detail.remove_category_title': 'Remove {name}?',
  'detail.remove_category_spent':
      'The expenses stay in the ledger but stop being categorised.',
  'detail.remove_category_empty': 'Nothing has been spent from it yet.',
  'detail.not_found': 'Budget not found',
  'detail.not_found_blurb':
      'It may have been deleted, or it belongs to another month.',

  'expense.new': 'New expense',
  'expense.edit': 'Edit expense',
  'expense.budget': 'BUDGET',
  'expense.category': 'CATEGORY',
  'expense.note_hint': 'What was it for? (optional)',
  'expense.add': 'Add expense',
  'expense.nothing_yours': 'Nothing of yours to spend from',
  'expense.nothing_yours_blurb':
      'An expense comes out of a budget you control. Create one, or ask your '
          'partner to move some money across.',
  'expense.delete_title': 'Delete this expense?',
  'expense.delete_body':
      'It disappears for both of you and the totals go back down.',
  'expense.err_amount': 'Enter an amount greater than zero.',
  'expense.err_budget': 'Pick which budget this comes out of.',

  'ledger.title': 'Ledger',
  'ledger.everyone': 'Everyone',
  'ledger.entries_one': '{count} entry',
  'ledger.entries_many': '{count} entries',
  'ledger.empty': 'Nothing recorded yet',
  'ledger.empty_blurb':
      'Tap the + button to log what you spent. Your partner sees it straight '
          'away.',
  'ledger.today': 'TODAY',
  'ledger.yesterday': 'YESTERDAY',

  'inbox.title': 'Inbox',
  'inbox.empty': 'Nothing to confirm',
  'inbox.empty_unpaired':
      'Once your partner joins, budget allocations and money requests will come '
          'here.',
  'inbox.empty_blurb':
      'Allocations to agree to, and requests to move money, both land here.',
  'inbox.waiting_on_you': 'Waiting on you',
  'inbox.waiting_on_partner': 'Waiting on your partner',
  'inbox.money_request': 'Money request',
  'inbox.asking_for': '{name} is asking for money out of {from}, into {to}.',
  'inbox.leaves': 'Leaves {amount}',
  'inbox.more_than_you_have': 'More than you have',
  'inbox.would_go_over': 'Approving would put {budget} over budget.',
  'inbox.send_money': 'Send money',
  'inbox.money_moved': 'Money moved',
  'inbox.declined': 'Declined',
  'inbox.confirmed': 'Confirmed',
  'inbox.decline_title': 'Decline',
  'inbox.decline_hint': 'Say why (optional)',
  'inbox.withdraw': 'Withdraw',
  'inbox.editing_replaces': 'Editing the category replaces this request.',
  'inbox.waiting_from': '{amount} from {budget} · waiting on {name}',
  'inbox.waiting_amount': '{amount} · waiting on {name}',
  'inbox.vs_before': '{amount} vs before',
  'inbox.note':
      'Pending allocations still count toward the plan, so the numbers reflect '
          'what you intend while you sort it out. Money only moves once a '
          'request is approved.',

  'request.title': 'Request money',
  'request.subtitle': 'From a budget {name} controls',
  'request.from': 'FROM',
  'request.amount': 'AMOUNT',
  'request.what_for': 'WHAT FOR',
  'request.what_for_hint': 'School shoes, petrol…',
  'request.lands_in': 'LANDS IN',
  'request.name_budget_hint': 'Name a budget of your own',
  'request.creates_budget':
      'You control nothing yet, so this creates a budget for you to receive it '
          'into.',
  'request.partner_confirms':
      '{name} confirms this in their Inbox. If they agree, the money moves into '
          'your budget — you still never spend from theirs.',
  'request.send': 'Send request',
  'request.left_in': '{amount} left in {budget}',
  'request.err_source': 'Choose which budget to ask from.',
  'request.err_amount': 'Enter an amount greater than zero.',
  'request.err_too_much': 'Only {amount} is left in {budget}.',
  'request.err_name': 'Name the budget this should land in.',
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
      'If you budget from payday rather than the 1st, set that day here. '
          'Expenses land in the right month automatically.',
  'settings.language': 'Language',
  'settings.preferences': 'Preferences',
  'settings.account': 'Account',
  'settings.leave': 'Leave household',
  'settings.leave_title': 'Leave this household?',
  'settings.leave_body':
      'You stop seeing the shared budgets and ledger. Everything stays with '
          'your partner, and you can be invited back.',
  'settings.leave_cta': 'Leave',
  'settings.your_name': 'Your name',
  'settings.household_name': 'Household name',

  'chart.range_day': 'Daily',
  'chart.range_month': 'Monthly',
  'chart.range_year': 'Yearly',
  'chart.left_in': 'Left in {name} \u2014 your budget',
  'chart.over_in': 'Over in {name} \u2014 your budget',
  'chart.left_household': 'Left across the household budgets',
  'chart.over_household': 'Over the household budgets',
  'chart.budget_of': 'Budget {amount}',
  'chart.projection_ok':
      'At this rate you finish at {amount} \u2014 {left} to spare.',
  'chart.projection_over':
      'At this rate you finish at {amount} \u2014 {over} over.',
  'chart.projection_none': 'Nothing recorded this month yet.',
  'chart.fix_daily': 'Drop to {amount} a day and you land on it.',
  'chart.fix_stop': 'The budget is already spent.',
  'chart.daily_note_none': '{amount} a day to play with. No day went over yet.',
  'chart.daily_note_one': '{amount} a day to play with. {count} day went over.',
  'chart.daily_note_many':
      '{amount} a day to play with. {count} days went over.',
  'chart.year_note': '{amount} spent across {year}.',
  'chart.legend_spent': 'Spent',
  'chart.legend_pace': 'Even pace',
  'chart.legend_projection': 'Projection',
  'chart.a11y': '{range} chart. {spent} spent of a {budget} budget.',

  'splash.preparing': 'Getting your household ready\u2026',

  'error.permission_denied':
      'Firebase refused this. Usually that means the security rules have not '
          'been deployed \u2014 open the Rules tab in the Firebase Console, '
          'paste in firebase/firestore.rules and Publish. If they are '
          'deployed, then this really is not yours to change.',
  'error.offline': 'Could not reach Firebase. Check your connection; anything '
      'you saved will go out on its own once you are back.',
  'error.signed_out': 'Your session expired. Sign in again.',
  'error.not_found': 'That is not there any more. It may have just been '
      'deleted.',
  'error.already_exists': 'That already exists.',
  'error.needs_index':
      'Firestore needs an index for this query. The full error has a link '
          'that creates it in one click.',
  'error.quota': "Firebase's quota is used up for today. Try again tomorrow.",
  'error.email_taken': 'That email is already in use.',
  'error.email_invalid': 'That email does not look right.',
  'error.password_weak': 'That password is too short. Six characters minimum.',
  'error.credentials': 'That email or password is wrong.',
  'error.too_many': 'Too many attempts. Wait a moment.',
  'error.unknown': 'Something went wrong. Try again.',

  'expense.new_income': 'Add income',
  'expense.edit_income': 'Edit income',
  'expense.kind_spending': 'Out',
  'expense.kind_income': 'In',

  'category_editor.headroom': '{amount} of {total} still unallocated.',
  'category_editor.none_left':
      'All of it is allocated. Free some up from another category first.',
  'category_editor.err_over':
      'That is {over} too much. {budget} has only {headroom} unallocated \u2014 '
          'lower another category first, or raise the budget itself.',

  'detail.taken_out': 'Taken back out',
  'detail.income_added': '{amount} paid into this budget.',
  'detail.record_income': 'Add income',
  'detail.record_spending': 'Add spending',
  'detail.record_deposit': 'Pay in',
  'detail.record_withdrawal': 'Take out',

  'inbox.all_allocated':
      '{budget} is fully carved into categories. You will pick which one this '
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

  'app.cannot_reach': 'Could not reach your data',
  'app.setup_title': 'One setup step left',
};
