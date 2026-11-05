import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() => runApp(const AxbisApp());

//THEME
const kPrimary = Color(0xFF2745C7);
const kDark = Color(0xFF0B1B3F);
const kBg = Color(0xFFF2F5FB);

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: kPrimary);
  TextStyle? f(TextStyle? s) =>
      s?.copyWith(fontSize: max(16.0, s.fontSize ?? 16)); // min 16
  final t = base.textTheme;
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    textTheme: TextTheme(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade500),
      suffixStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: kPrimary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimary, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: const TextStyle(fontSize: 16, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

//MODEL & STORE
class Account {
  final String email, password;
  final bool isAdmin;
  double tokens; // budget capacity in M KRW
  Account(this.email, this.password, {this.isAdmin = false, this.tokens = 0});
}

class PrintJob {
  final String id, email, machineCode, fileName;
  final int durationSec, pcs, unitPriceK; // unitPriceK = thousand KRW / pcs
  final DateTime startedAt;
  final double quality; // dummy AXVision scan result (%)
  PrintJob(this.id, this.email, this.machineCode, this.fileName,
      this.durationSec, this.pcs, this.unitPriceK, this.startedAt, this.quality);

  int get totalPriceK => pcs * unitPriceK;
  double get totalPriceM => totalPriceK / 1000;
  DateTime get endAt => startedAt.add(Duration(seconds: durationSec));
  bool get done => !DateTime.now().isBefore(endAt);
  double get progress {
    final el = DateTime.now().difference(startedAt).inMilliseconds;
    return (el / (durationSec * 1000)).clamp(0.0, 1.0);
  }

  int get remainingSec {
    final r = endAt.difference(DateTime.now()).inMilliseconds;
    return r <= 0 ? 0 : (r / 1000).ceil();
  }
}

class Store extends ChangeNotifier {
  static final Store i = Store._();
  Store._();

  final accounts = <Account>[
    Account('admin@axbis.com', 'admin123', isAdmin: true),
    Account('produksi@dummy-corp.com', 'user123', tokens: 100),
    Account('factory@contoh-industri.com', 'user123', tokens: 50),
  ];
  final jobs = <PrintJob>[]; // history: never deleted
  Account? current;
  final _rnd = Random();

  String? login(String email, String pass, bool asAdmin) {
    final m = accounts.where((a) =>
        a.email.toLowerCase() == email.trim().toLowerCase() &&
        a.password == pass &&
        a.isAdmin == asAdmin);
    if (m.isEmpty) return 'Invalid email or password';
    current = m.first;
    notifyListeners();
    return null;
  }

  void logout() {
    current = null;
    notifyListeners();
  }

  String? addToken(String email, double amount) {
    if (amount <= 0) return 'Amount must be greater than 0';
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) return 'Invalid email address';
    final m = accounts.where((a) => a.email.toLowerCase() == e && !a.isAdmin);
    if (m.isEmpty) {
      accounts.add(Account(e, 'user123', tokens: amount)); // new client
    } else {
      m.first.tokens += amount;
    }
    notifyListeners();
    return null;
  }

  String? startJob(Account u, String machine, String file, int sec, int pcs,
      int unitPriceK) {
    final cost = pcs * unitPriceK / 1000; // M KRW
    if (u.tokens + 1e-9 < cost) {
      return 'Insufficient budget capacity '
          '(remaining ${mkrw(u.tokens)}, required ${mkrw(cost)})';
    }
    u.tokens -= cost;
    jobs.insert(
      0,
      PrintJob('JOB-${1000 + jobs.length + 1}', u.email, machine, file, sec,
          pcs, unitPriceK, DateTime.now(), 60 + _rnd.nextDouble() * 39.9),
    );
    notifyListeners();
    return null;
  }
}

//UTIL & SHARED WIDGETS
String hms(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

String mkrw(double v) => '${v.toStringAsFixed(3)} M KRW';

TextStyle ts(
        {double size = 16, FontWeight w = FontWeight.w400, Color? c}) =>
    TextStyle(fontSize: max(16, size), fontWeight: w, color: c);

BoxDecoration cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
            color: Color(0x1A1B2A5E), blurRadius: 18, offset: Offset(0, 8))
      ],
    );

void snack(BuildContext c, String m, {bool err = false}) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(m, style: ts(c: Colors.white)),
    backgroundColor: err ? Colors.red.shade700 : Colors.green.shade700,
  ));
}

/// Rebuilds every 0.5s for real time clock & progress
class Ticker extends StatefulWidget {
  final Widget Function(BuildContext, DateTime) builder;
  const Ticker({super.key, required this.builder});
  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => widget.builder(c, DateTime.now());
}

class Shell extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Widget> children;
  const Shell(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [kDark, Color(0xFF1D3F91)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 22),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: ts(
                                    size: 22,
                                    w: FontWeight.w800,
                                    c: Colors.white)),
                            Text(subtitle,
                                overflow: TextOverflow.ellipsis,
                                style: ts(c: Colors.white70)),
                          ]),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: Store.i.logout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                  padding: const EdgeInsets.all(16), children: children),
            ),
          ),
        ),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const SectionTitle(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          Icon(icon, color: kPrimary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: ts(size: 19, w: FontWeight.w800))),
        ]),
      );
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text, style: ts(w: FontWeight.w600)),
      );
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const StatTile(this.icon, this.label, this.value,
      {super.key, this.color = kPrimary});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label, style: ts(c: Colors.black54)),
          Text(value, style: ts(size: 19, w: FontWeight.w800)),
        ]),
      );
}

//APP
class AxbisApp extends StatelessWidget {
  const AxbisApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AXBIS Machine Rental',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: Store.i,
        builder: (_, __) {
          final u = Store.i.current;
          if (u == null) return const LoginPage();
          return u.isAdmin ? const AdminPage() : UserPage(user: u);
        },
      ),
    );
  }
}

//LOGIN
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _admin = false;

  void _fill() {
    _email.text = _admin ? 'admin@axbis.com' : 'produksi@dummy-corp.com';
    _pass.text = _admin ? 'admin123' : 'user123';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [kDark, Color(0xFF2745C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 30,
                          offset: Offset(0, 14))
                    ]),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [kPrimary, Color(0xFF6C8CFF)])),
                    child: const Icon(Icons.precision_manufacturing,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text('AXBIS',
                      style: ts(size: 32, w: FontWeight.w900, c: kDark)
                          .copyWith(letterSpacing: 5)),
                  Text('Machine Rental System',
                      style: ts(c: Colors.black54)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: false,
                            label: Text('User'),
                            icon: Icon(Icons.business)),
                        ButtonSegment(
                            value: true,
                            label: Text('Admin'),
                            icon: Icon(Icons.admin_panel_settings)),
                      ],
                      selected: {_admin},
                      onSelectionChanged: (s) => setState(() {
                        _admin = s.first;
                        _fill();
                      }),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: FieldLabel('Email')),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        hintText: 'name@company.com',
                        prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: FieldLabel('Password')),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(
                        hintText: 'Enter password',
                        prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Login'),
                      onPressed: () {
                        final err =
                            Store.i.login(_email.text, _pass.text, _admin);
                        if (err != null) snack(context, err, err: true);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: () => setState(_fill),
                      child:
                          Text('Fill demo account', style: ts(w: FontWeight.w600))),
                  Text(
                    'Admin: admin@axbis.com / admin123\nUser: produksi@dummy-corp.com / user123',
                    textAlign: TextAlign.center,
                    style: ts(c: Colors.black45),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//JOB CARD (USER & ADMIN)
class JobCard extends StatelessWidget {
  final PrintJob job;
  final bool showEmail;
  const JobCard({super.key, required this.job, this.showEmail = false});

  Widget _line(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 20, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: ts())),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final done = job.done;
    final color = done ? Colors.green : Colors.orange;
    final good = job.quality >= 85;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardDeco(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 7, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(job.id,
                                style: ts(size: 19, w: FontWeight.w800))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: color.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.shade300)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(done ? Icons.check_circle : Icons.autorenew,
                                size: 18, color: color.shade800),
                            const SizedBox(width: 6),
                            Text(done ? 'COMPLETED' : 'IN PROGRESS',
                                style: ts(
                                    w: FontWeight.w800, c: color.shade800)),
                          ]),
                        ),
                      ]),
                      if (showEmail)
                        _line(Icons.business, job.email),
                      _line(Icons.precision_manufacturing,
                          'Machine: ${job.machineCode}'),
                      _line(Icons.view_in_ar, 'File: ${job.fileName}'),
                      _line(Icons.inventory_2,
                          '${job.pcs} pcs × ${job.unitPriceK}.000 KRW'),
                      _line(Icons.payments,
                          'Total: ${mkrw(job.totalPriceM)}'),
                      _line(Icons.schedule,
                          'Started ${hms(job.startedAt)}'
                          '${done ? '  •  Finished ${hms(job.endAt)}' : ''}  •  ${job.durationSec}s'),
                      const SizedBox(height: 14),
                      if (!done) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                              value: job.progress, minHeight: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            '${(job.progress * 100).toStringAsFixed(0)}%  •  ${job.remainingSec}s remaining',
                            style: ts(w: FontWeight.w600, c: kPrimary)),
                      ] else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: (good ? Colors.green : Colors.orange)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            Icon(
                                good ? Icons.verified : Icons.warning_amber,
                                size: 30,
                                color: good ? Colors.green : Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('AXVision Scan (dummy)',
                                        style: ts(c: Colors.black54)),
                                    Text(
                                        '${job.quality.toStringAsFixed(1)}%  •  ${good ? 'GOOD' : 'NEEDS REVIEW'}',
                                        style: ts(
                                            size: 19, w: FontWeight.w800)),
                                  ]),
                            ),
                          ]),
                        ),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

//USER PAGE
class UserPage extends StatefulWidget {
  final Account user;
  const UserPage({super.key, required this.user});
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  bool _showIsland = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final myJobs = Store.i.jobs.where((j) => j.email == u.email).toList();
    return Shell(
      title: 'AXBIS Client',
      subtitle: u.email,
      icon: Icons.business,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
                colors: [kPrimary, Color(0xFF6C8CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x552745C7),
                  blurRadius: 20,
                  offset: Offset(0, 10))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white),
              const SizedBox(width: 8),
              Text('Budget Capacity', style: ts(c: Colors.white70)),
            ]),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(u.tokens.toStringAsFixed(3),
                  style: ts(size: 44, w: FontWeight.w900, c: Colors.white)),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 8),
                child: Text('M KRW',
                    style: ts(size: 20, w: FontWeight.w700, c: Colors.white)),
              ),
            ]),
            Text('Remaining in Millions KRW', style: ts(c: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => setState(() => _showIsland = !_showIsland),
            icon: Icon(_showIsland ? Icons.close : Icons.play_circle),
            label: Text(_showIsland ? 'Close' : 'Use Machine'),
          ),
        ),
        if (_showIsland) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200)),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.orange.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Production time, quantity and unit price are dummy & random data.',
                    style: ts(c: Colors.orange.shade900)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          MachineIsland(
              user: u, onStarted: () => setState(() => _showIsland = false)),
        ],
        const SectionTitle(Icons.history, 'Production History'),
        Ticker(
          builder: (_, __) => Column(
            children: myJobs.isEmpty
                ? [
                    Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                            child: Text('No production yet.',
                                style: ts(c: Colors.black45))))
                  ]
                : myJobs.map((j) => JobCard(job: j)).toList(),
          ),
        ),
      ],
    );
  }
}

class MachineIsland extends StatefulWidget {
  final Account user;
  final VoidCallback onStarted;
  const MachineIsland({super.key, required this.user, required this.onStarted});
  @override
  State<MachineIsland> createState() => _MachineIslandState();
}

class _MachineIslandState extends State<MachineIsland> {
  final _r = Random();
  final _machine = TextEditingController();
  String? _file;
  late int sec, pcs, unitK;

  @override
  void initState() {
    super.initState();
    _randomize();
  }

  // dummy & random: time 1-10s, qty 1-10 pcs, unit price 0-9 (x1.000 KRW)
  void _randomize() {
    sec = _r.nextInt(10) + 1;
    pcs = _r.nextInt(10) + 1;
    unitK = _r.nextInt(10);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['step', 'stp', 'STEP', 'STP'],
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _file = res.files.single.name);
    }
  }

  @override
  void dispose() {
    _machine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDeco(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [kDark, Color(0xFF1D3F91)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            const Icon(Icons.precision_manufacturing, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Machine Control',
                    style: ts(size: 19, w: FontWeight.w800, c: Colors.white))),
            IconButton(
                tooltip: 'Randomize time, quantity & price',
                onPressed: () => setState(_randomize),
                icon: const Icon(Icons.casino, color: Colors.white)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('Machine Code'),
            TextField(
              controller: _machine,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  hintText: 'e.g. AXB-M01-1234',
                  prefixIcon: Icon(Icons.qr_code_2)),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Design File'),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                icon: Icon(_file == null ? Icons.upload_file : Icons.task_alt,
                    color: _file == null ? kPrimary : Colors.green),
                label: Text(_file ?? 'Upload .STEP file',
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: StatTile(Icons.timer, 'Production Time', '$sec s')),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      StatTile(Icons.inventory_2, 'Quantity', '$pcs pcs')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: StatTile(Icons.sell, 'Unit Price', '$unitK.000 KRW',
                      color: Colors.teal)),
              const SizedBox(width: 12),
              Expanded(
                  child: StatTile(
                      Icons.payments, 'Total Price', '${pcs * unitK}.000 KRW',
                      color: Colors.deepOrange)),
            ]),
            const SizedBox(height: 12),
            Ticker(
              builder: (_, now) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: kBg, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.access_time, color: kPrimary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Production Clock', style: ts())),
                  Text(hms(now),
                      style: ts(size: 22, w: FontWeight.w800, c: kDark)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Start Print'),
                onPressed: () {
                  final code = _machine.text.trim();
                  if (code.isEmpty) {
                    snack(context, 'Machine code is required', err: true);
                    return;
                  }
                  if (_file == null) {
                    snack(context, 'Please upload a .STEP file first',
                        err: true);
                    return;
                  }
                  final err = Store.i
                      .startJob(widget.user, code, _file!, sec, pcs, unitK);
                  if (err != null) {
                    snack(context, err, err: true);
                  } else {
                    snack(context,
                        'Production started. Budget −${mkrw(pcs * unitK / 1000)}');
                    widget.onStarted();
                  }
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

//ADMIN PAGE
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _email = TextEditingController();
  final _amount = TextEditingController(text: '100');

  @override
  Widget build(BuildContext context) {
    final users = Store.i.accounts.where((a) => !a.isAdmin).toList();
    return Shell(
      title: 'AXBIS Admin Panel',
      subtitle: 'Monitoring & budget management',
      icon: Icons.admin_panel_settings,
      children: [
        Ticker(
          builder: (_, now) {
            final active = Store.i.jobs.where((j) => !j.done).length;
            final completed = Store.i.jobs.length - active;
            return Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Row(children: [
                  const Icon(Icons.access_time, color: kPrimary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Production Clock', style: ts())),
                  Text(hms(now),
                      style: ts(size: 26, w: FontWeight.w900, c: kDark)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: StatTile(
                        Icons.business, 'Clients', '${users.length}')),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile(Icons.autorenew, 'In Progress', '$active',
                        color: Colors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile(
                        Icons.check_circle, 'Completed', '$completed',
                        color: Colors.green)),
              ]),
            ]);
          },
        ),
        const SectionTitle(Icons.add_card, 'Add Budget Capacity'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: cardDeco(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('Client Email'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  hintText: 'client@company.com',
                  prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 12),
            const FieldLabel('Budget Capacity'),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  hintText: 'e.g. 100',
                  prefixIcon: Icon(Icons.savings_outlined),
                  suffixText: 'M KRW'),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final v in ['10', '50', '100', '500'])
                ActionChip(
                  label: Text('$v M', style: ts(w: FontWeight.w600)),
                  onPressed: () => setState(() => _amount.text = v),
                ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_circle),
                label: const Text('Add Budget'),
                onPressed: () {
                  final amt = double.tryParse(_amount.text) ?? 0;
                  final mail = _email.text;
                  final err = Store.i.addToken(mail, amt);
                  if (err != null) {
                    snack(context, err, err: true);
                  } else {
                    snack(context,
                        '${mkrw(amt)} added to ${mail.trim()}');
                    _email.clear();
                  }
                },
              ),
            ),
          ]),
        ),
        const SectionTitle(Icons.groups, 'Clients & Budget Capacity'),
        ListenableBuilder(
          listenable: Store.i,
          builder: (_, __) => Column(
            children: users
                .map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: cardDeco(),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: const CircleAvatar(
                            backgroundColor: kBg,
                            child: Icon(Icons.business, color: kPrimary)),
                        title: Text(a.email,
                            style: ts(w: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text('Tap to select', style: ts(c: Colors.black45)),
                        trailing: Text(mkrw(a.tokens),
                            style: ts(w: FontWeight.w800, c: kPrimary)),
                        onTap: () => setState(() => _email.text = a.email),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SectionTitle(Icons.monitor_heart, 'Live Production Monitoring'),
        Ticker(
          builder: (_, __) => Column(
            children: Store.i.jobs.isEmpty
                ? [
                    Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                            child: Text('No production activity yet.',
                                style: ts(c: Colors.black45))))
                  ]
                : Store.i.jobs
                    .map((j) => JobCard(job: j, showEmail: true))
                    .toList(),
          ),
        ),
      ],
    );
  }
}