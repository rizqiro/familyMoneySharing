/// Banjar, Javanese and Sundanese.
///
/// =============================================================================
/// PLEASE READ BEFORE TRUSTING THESE
/// =============================================================================
/// These were written by an AI assistant with real but uneven knowledge of the
/// three languages. Treat every line as a first draft that a native speaker
/// should check. Nothing here is authoritative, and some of it is probably
/// stilted or plain wrong.
///
/// Where confidence was low, the line was LEFT OUT rather than guessed. A
/// missing key silently falls back to Indonesian (see `app_text.dart`), which
/// every speaker of these languages also reads - so a gap is invisible to the
/// user, while a bad guess is not.
///
/// Register: the polite second person is used throughout - `pian` in Banjar,
/// `panjenengan` in Javanese, `anjeun` in Sundanese - since the app is for two
/// spouses talking about money. Change it if that reads as too formal at home.
///
/// =============================================================================
/// HOW TO FIX OR ADD A LINE
/// =============================================================================
/// 1. Find the key in `_id` in `app_text.dart` - that map is always complete.
/// 2. Add or correct the same key in the map below.
/// 3. Hot restart. That is all - no code generation, no rebuild step.
///
/// Keep `{placeholders}` spelled exactly as they are; they are replaced with
/// real values at runtime. Move them wherever the grammar wants them.
library;

// =============================================================================
// BAHASA BANJAR (bjn) - South Kalimantan
// =============================================================================
const Map<String, String> banjarText = {
  // ------------------------------------------------------------- common
  'common.save': 'Simpan',
  'common.save_changes': 'Simpan ubahan',
  'common.cancel': 'Batal',
  'common.delete': 'Hapus',
  'common.remove': 'Hapus',
  'common.edit': 'Ubah',
  'common.add': 'Tambah',
  'common.confirm': 'Satuju',
  'common.decline': 'Tulak',
  'common.retry': 'Cuba pulang',
  'common.you': 'Pian',
  'common.partner': 'Pasangan',
  'common.left': 'sisa',
  'common.over': 'labih',

  // --------------------------------------------------------------- auth
  'auth.welcome_back': 'Salamat datang pulang.',
  'auth.name_hint': 'Ngaran pian',
  'auth.email_hint': 'Email',
  'auth.password_hint': 'Kata sandi',
  'auth.sign_in': 'Masuk',
  'auth.create_account': 'Gawi akun',
  'auth.have_account': 'Ulun sudah ada akun',
  'auth.no_account': 'Gawi akun hanyar',
  'auth.sign_out': 'Kaluar',

  // --------------------------------------------------------- onboarding
  'onboarding.hi': 'Hai {name}',
  'onboarding.start': 'Mulai rumah tangga kami',
  'onboarding.join': 'Gabung lawan pasangan',
  'onboarding.household_name_hint': 'Ngaran rumah tangga',
  'onboarding.currency': 'MATA UANG',
  'onboarding.create': 'Gawi rumah tangga',

  // -------------------------------------------------------------- shell
  'shell.tab_overview': 'Ringkasan',
  'shell.tab_budgets': 'Anggaran',
  'shell.tab_ledger': 'Catatan',
  'shell.tab_inbox': 'Kotak masuk',

  // ---------------------------------------------------------- dashboard
  'dashboard.subtitle': 'Ringkasan basama',
  'dashboard.your_budgets': 'Anggaran pian',
  'dashboard.accumulated': 'Total anggaran',
  'dashboard.their_budgets': 'Anggaran {name}',
  'dashboard.who_spent': 'Sapa balanja apa',
  'dashboard.where_went': 'Ka mana parginya',
  'dashboard.latest': 'Paling hanyar',
  'dashboard.left_to_spend': 'SISA GASAN DIBALANJAAKAN',
  'dashboard.over_budget_by': 'LABIH MATAN ANGGARAN',
  'dashboard.you_control': 'Pian nang mamigang ini',
  'dashboard.yours': 'Punya pian',
  'dashboard.theirs': 'Punya {name}',
  'dashboard.put_aside': 'Ditabung bulan ini',
  'dashboard.see_not_spend': 'Kawa dilihat, kada kawa dibalanjaakan.',
  'dashboard.request_money': 'Minta duit',
  'dashboard.request_from': 'Minta duit lawan {name}',
  'dashboard.create_my_budget': 'Gawi anggaran ulun surang',
  'dashboard.no_budget_title': 'Pian balum mamigang anggaran',

  // ------------------------------------------------------------ budgets
  'budgets.title': 'Anggaran',
  'budgets.this_month': 'Bulan ini',
  'budgets.saving_pots': 'Tabungan',
  'budgets.new_budget': 'Anggaran hanyar',
  'budgets.create': 'Gawi anggaran',
  'budgets.you_control': 'Pian nang mamigang ini',
  'budgets.partner_controls': '{name} nang mamigang ini',

  // ----------------------------------------------------- budget editor
  'budget_editor.new': 'Anggaran hanyar',
  'budget_editor.edit': 'Ubah anggaran',
  'budget_editor.type': 'JINIS',
  'budget_editor.monthly': 'Bulanan',
  'budget_editor.saving': 'Tabungan',
  'budget_editor.amount': 'JUMLAH',
  'budget_editor.target': 'TARGET',
  'budget_editor.who_controls': 'SAPA NANG MAMIGANG',

  // --------------------------------------------------- category editor
  'category_editor.new': 'Kategori hanyar',
  'category_editor.edit': 'Ubah kategori',
  'category_editor.name_hint': 'Ngaran kategori',
  'category_editor.allocation': 'PAMBAGIAN',
  'category_editor.add': 'Tambah kategori',

  // ---------------------------------------------------- expense editor
  'expense.new': 'Pangaluaran hanyar',
  'expense.edit': 'Ubah pangaluaran',
  'expense.budget': 'ANGGARAN',
  'expense.category': 'KATEGORI',
  'expense.note_hint': 'Gasan apa? (kada wajib)',
  'expense.add': 'Tambah pangaluaran',

  // ------------------------------------------------------------- ledger
  'ledger.title': 'Catatan',
  'ledger.everyone': 'Samuanya',
  'ledger.empty': 'Balum ada nang dicatat',
  'ledger.today': 'HARI INI',
  'ledger.yesterday': 'KAMARIAN',

  // -------------------------------------------------------------- inbox
  'inbox.title': 'Kotak masuk',
  'inbox.empty': 'Kadada nang paralu disatujui',
  'inbox.waiting_on_you': 'Manunggu pian',
  'inbox.waiting_on_partner': 'Manunggu pasangan',
  'inbox.money_request': 'Pamintaan duit',
  'inbox.send_money': 'Kirim duit',
  'inbox.declined': 'Ditulak',
  'inbox.confirmed': 'Disatujui',
  'inbox.withdraw': 'Tarik',

  // ------------------------------------------------------ request money
  'request.title': 'Minta duit',
  'request.from': 'MATAN',
  'request.amount': 'JUMLAH',
  'request.what_for': 'GASAN APA',
  'request.lands_in': 'MASUK KA',
  'request.send': 'Kirim pamintaan',

  // ----------------------------------------------------------- settings
  'settings.title': 'Pangaturan',
  'settings.partner': 'Pasangan',
  'settings.connected': 'Tasambung',
  'settings.household': 'Rumah tangga',
  'settings.name': 'Ngaran',
  'settings.currency': 'Mata uang',
  'settings.language': 'Bahasa',
  'settings.preferences': 'Pilihan',
  'settings.account': 'Akun',
  'settings.leave': 'Kaluar matan rumah tangga',
  'settings.leave_cta': 'Kaluar',
  'settings.your_name': 'Ngaran pian',
  'settings.household_name': 'Ngaran rumah tangga',
};

// =============================================================================
// BASA JAWA (jv)
// =============================================================================
const Map<String, String> javaneseText = {
  // ------------------------------------------------------------- common
  'common.save': 'Simpen',
  'common.save_changes': 'Simpen owahan',
  'common.cancel': 'Batal',
  'common.delete': 'Busak',
  'common.remove': 'Busak',
  'common.edit': 'Owahi',
  'common.add': 'Tambah',
  'common.confirm': 'Setuju',
  'common.decline': 'Nolak',
  'common.retry': 'Coba maneh',
  'common.you': 'Panjenengan',
  'common.partner': 'Pasangan',
  'common.left': 'turah',
  'common.over': 'luwih',

  // --------------------------------------------------------------- auth
  'auth.welcome_back': 'Sugeng rawuh maneh.',
  'auth.name_hint': 'Jeneng panjenengan',
  'auth.email_hint': 'Email',
  'auth.password_hint': 'Tembung sandi',
  'auth.sign_in': 'Mlebu',
  'auth.create_account': 'Gawe akun',
  'auth.have_account': 'Aku wis duwe akun',
  'auth.no_account': 'Gawe akun anyar',
  'auth.sign_out': 'Metu',

  // --------------------------------------------------------- onboarding
  'onboarding.hi': 'Halo {name}',
  'onboarding.start': 'Miwiti omah kita',
  'onboarding.join': 'Gabung karo pasangan',
  'onboarding.household_name_hint': 'Jeneng omah',
  'onboarding.currency': 'DHUWIT',
  'onboarding.create': 'Gawe omah',

  // -------------------------------------------------------------- shell
  'shell.tab_overview': 'Ringkesan',
  'shell.tab_budgets': 'Anggaran',
  'shell.tab_ledger': 'Cathetan',
  'shell.tab_inbox': 'Kothak mlebu',

  // ---------------------------------------------------------- dashboard
  'dashboard.subtitle': 'Ringkesan bebarengan',
  'dashboard.your_budgets': 'Anggaran panjenengan',
  'dashboard.accumulated': 'Total anggaran',
  'dashboard.their_budgets': 'Anggarane {name}',
  'dashboard.who_spent': 'Sapa mblanja apa',
  'dashboard.where_went': 'Menyang endi dhuwite',
  'dashboard.latest': 'Paling anyar',
  'dashboard.left_to_spend': 'TURAHAN KANGGO BLANJA',
  'dashboard.over_budget_by': 'LUWIH SAKA ANGGARAN',
  'dashboard.you_control': 'Panjenengan sing nyekel iki',
  'dashboard.yours': 'Duwekmu',
  'dashboard.theirs': 'Duweke {name}',
  'dashboard.put_aside': 'Ditabung sasi iki',
  'dashboard.see_not_spend': 'Bisa dideleng, ora bisa diblanjakake.',
  'dashboard.request_money': 'Njaluk dhuwit',
  'dashboard.request_from': 'Njaluk dhuwit marang {name}',
  'dashboard.create_my_budget': 'Gawe anggaranku dhewe',
  'dashboard.no_budget_title': 'Panjenengan durung nyekel anggaran',

  // ------------------------------------------------------------ budgets
  'budgets.title': 'Anggaran',
  'budgets.this_month': 'Sasi iki',
  'budgets.saving_pots': 'Tabungan',
  'budgets.new_budget': 'Anggaran anyar',
  'budgets.create': 'Gawe anggaran',
  'budgets.you_control': 'Panjenengan sing nyekel iki',
  'budgets.partner_controls': '{name} sing nyekel iki',

  // ----------------------------------------------------- budget editor
  'budget_editor.new': 'Anggaran anyar',
  'budget_editor.edit': 'Owahi anggaran',
  'budget_editor.type': 'JINIS',
  'budget_editor.monthly': 'Saben sasi',
  'budget_editor.saving': 'Tabungan',
  'budget_editor.amount': 'CACAHE',
  'budget_editor.target': 'TARGET',
  'budget_editor.who_controls': 'SAPA SING NYEKEL',

  // --------------------------------------------------- category editor
  'category_editor.new': 'Kategori anyar',
  'category_editor.edit': 'Owahi kategori',
  'category_editor.name_hint': 'Jeneng kategori',
  'category_editor.allocation': 'PANDUMAN',
  'category_editor.add': 'Tambah kategori',

  // ---------------------------------------------------- expense editor
  'expense.new': 'Pengeluaran anyar',
  'expense.edit': 'Owahi pengeluaran',
  'expense.budget': 'ANGGARAN',
  'expense.category': 'KATEGORI',
  'expense.note_hint': 'Kanggo apa? (ora wajib)',
  'expense.add': 'Tambah pengeluaran',

  // ------------------------------------------------------------- ledger
  'ledger.title': 'Cathetan',
  'ledger.everyone': 'Kabeh',
  'ledger.empty': 'Durung ana sing dicathet',
  'ledger.today': 'DINA IKI',
  'ledger.yesterday': 'WINGI',

  // -------------------------------------------------------------- inbox
  'inbox.title': 'Kothak mlebu',
  'inbox.empty': 'Ora ana sing kudu disetujoni',
  'inbox.waiting_on_you': 'Ngenteni panjenengan',
  'inbox.waiting_on_partner': 'Ngenteni pasangan',
  'inbox.money_request': 'Panjaluk dhuwit',
  'inbox.send_money': 'Kirim dhuwit',
  'inbox.declined': 'Ditolak',
  'inbox.confirmed': 'Disetujoni',
  'inbox.withdraw': 'Ditarik',

  // ------------------------------------------------------ request money
  'request.title': 'Njaluk dhuwit',
  'request.from': 'SAKA',
  'request.amount': 'CACAHE',
  'request.what_for': 'KANGGO APA',
  'request.lands_in': 'MLEBU MENYANG',
  'request.send': 'Kirim panjaluk',

  // ----------------------------------------------------------- settings
  'settings.title': 'Setelan',
  'settings.partner': 'Pasangan',
  'settings.connected': 'Wis nyambung',
  'settings.household': 'Omah',
  'settings.name': 'Jeneng',
  'settings.currency': 'Dhuwit',
  'settings.language': 'Basa',
  'settings.preferences': 'Pilihan',
  'settings.account': 'Akun',
  'settings.leave': 'Metu saka omah iki',
  'settings.leave_cta': 'Metu',
  'settings.your_name': 'Jeneng panjenengan',
  'settings.household_name': 'Jeneng omah',
};

// =============================================================================
// BASA SUNDA (su)
// =============================================================================
const Map<String, String> sundaneseText = {
  // ------------------------------------------------------------- common
  'common.save': 'Simpen',
  'common.save_changes': 'Simpen parobahan',
  'common.cancel': 'Bolay',
  'common.delete': 'Pupus',
  'common.remove': 'Pupus',
  'common.edit': 'Robah',
  'common.add': 'Tambah',
  'common.confirm': 'Satuju',
  'common.decline': 'Tolak',
  'common.retry': 'Cobian deui',
  'common.you': 'Anjeun',
  'common.partner': 'Pasangan',
  'common.left': 'sésa',
  'common.over': 'leuwih',

  // --------------------------------------------------------------- auth
  'auth.welcome_back': 'Wilujeng sumping deui.',
  'auth.name_hint': 'Ngaran anjeun',
  'auth.email_hint': 'Email',
  'auth.password_hint': 'Kecap sandi',
  'auth.sign_in': 'Asup',
  'auth.create_account': 'Jieun akun',
  'auth.have_account': 'Abdi parantos gaduh akun',
  'auth.no_account': 'Jieun akun anyar',
  'auth.sign_out': 'Kaluar',

  // --------------------------------------------------------- onboarding
  'onboarding.hi': 'Halo {name}',
  'onboarding.start': 'Ngamimitian imah urang',
  'onboarding.join': 'Gabung jeung pasangan',
  'onboarding.household_name_hint': 'Ngaran imah',
  'onboarding.currency': 'MATA UANG',
  'onboarding.create': 'Jieun imah',

  // -------------------------------------------------------------- shell
  'shell.tab_overview': 'Ringkesan',
  'shell.tab_budgets': 'Anggaran',
  'shell.tab_ledger': 'Catetan',
  'shell.tab_inbox': 'Kotak asup',

  // ---------------------------------------------------------- dashboard
  'dashboard.subtitle': 'Ringkesan babarengan',
  'dashboard.your_budgets': 'Anggaran anjeun',
  'dashboard.accumulated': 'Total anggaran',
  'dashboard.their_budgets': 'Anggaran {name}',
  'dashboard.who_spent': 'Saha balanja naon',
  'dashboard.where_went': 'Ka mana duitna',
  'dashboard.latest': 'Panganyarna',
  'dashboard.left_to_spend': 'SÉSA KEUR DIBALANJAKEUN',
  'dashboard.over_budget_by': 'LEUWIH TI ANGGARAN',
  'dashboard.you_control': 'Anjeun anu nyekel ieu',
  'dashboard.yours': 'Milik anjeun',
  'dashboard.theirs': 'Milik {name}',
  'dashboard.put_aside': 'Ditabung bulan ieu',
  'dashboard.see_not_spend': 'Bisa ditingali, teu bisa dibalanjakeun.',
  'dashboard.request_money': 'Ménta duit',
  'dashboard.request_from': 'Ménta duit ka {name}',
  'dashboard.create_my_budget': 'Jieun anggaran sorangan',
  'dashboard.no_budget_title': 'Anjeun can nyekel anggaran',

  // ------------------------------------------------------------ budgets
  'budgets.title': 'Anggaran',
  'budgets.this_month': 'Bulan ieu',
  'budgets.saving_pots': 'Tabungan',
  'budgets.new_budget': 'Anggaran anyar',
  'budgets.create': 'Jieun anggaran',
  'budgets.you_control': 'Anjeun anu nyekel ieu',
  'budgets.partner_controls': '{name} anu nyekel ieu',

  // ----------------------------------------------------- budget editor
  'budget_editor.new': 'Anggaran anyar',
  'budget_editor.edit': 'Robah anggaran',
  'budget_editor.type': 'JINIS',
  'budget_editor.monthly': 'Bulanan',
  'budget_editor.saving': 'Tabungan',
  'budget_editor.amount': 'JUMLAH',
  'budget_editor.target': 'TARGET',
  'budget_editor.who_controls': 'SAHA ANU NYEKEL',

  // --------------------------------------------------- category editor
  'category_editor.new': 'Kategori anyar',
  'category_editor.edit': 'Robah kategori',
  'category_editor.name_hint': 'Ngaran kategori',
  'category_editor.allocation': 'PAMBAGIAN',
  'category_editor.add': 'Tambah kategori',

  // ---------------------------------------------------- expense editor
  'expense.new': 'Pengeluaran anyar',
  'expense.edit': 'Robah pengeluaran',
  'expense.budget': 'ANGGARAN',
  'expense.category': 'KATEGORI',
  'expense.note_hint': 'Keur naon? (teu wajib)',
  'expense.add': 'Tambah pengeluaran',

  // ------------------------------------------------------------- ledger
  'ledger.title': 'Catetan',
  'ledger.everyone': 'Sadayana',
  'ledger.empty': 'Can aya nu dicatet',
  'ledger.today': 'POÉ IEU',
  'ledger.yesterday': 'KAMARI',

  // -------------------------------------------------------------- inbox
  'inbox.title': 'Kotak asup',
  'inbox.empty': 'Teu aya nu kudu disatujuan',
  'inbox.waiting_on_you': 'Ngantosan anjeun',
  'inbox.waiting_on_partner': 'Ngantosan pasangan',
  'inbox.money_request': 'Panyuhunan duit',
  'inbox.send_money': 'Kirim duit',
  'inbox.declined': 'Ditolak',
  'inbox.confirmed': 'Disatujuan',
  'inbox.withdraw': 'Ditarik',

  // ------------------------------------------------------ request money
  'request.title': 'Ménta duit',
  'request.from': 'TI',
  'request.amount': 'JUMLAH',
  'request.what_for': 'KEUR NAON',
  'request.lands_in': 'ASUP KA',
  'request.send': 'Kirim panyuhunan',

  // ----------------------------------------------------------- settings
  'settings.title': 'Setélan',
  'settings.partner': 'Pasangan',
  'settings.connected': 'Nyambung',
  'settings.household': 'Imah',
  'settings.name': 'Ngaran',
  'settings.currency': 'Mata uang',
  'settings.language': 'Basa',
  'settings.preferences': 'Pilihan',
  'settings.account': 'Akun',
  'settings.leave': 'Kaluar ti imah ieu',
  'settings.leave_cta': 'Kaluar',
  'settings.your_name': 'Ngaran anjeun',
  'settings.household_name': 'Ngaran imah',
};
