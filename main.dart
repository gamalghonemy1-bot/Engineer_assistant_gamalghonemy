import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat, PdfColors;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;

late SharedPreferences prefs;
List<Proj> projs = [];

class Proj {
  final List r;
  Proj(this.r);
  dynamic g(int i) => i < r.length ? r[i] : null;
  String t(int i) => (g(i) ?? '').toString();
  String get name => t(0);
  String get id => t(1);
  String get type => t(2);
  String get work => t(3);
  String get sec => t(4);
  String get cn => t(5);
  String get sd => t(6);
  String get e => t(7);
  String get eng => t(8);
  String get st => t(10);
  String get n => t(14);
  dynamic get v => g(9);
  dynamic get pd => g(12);
  num? get pc => g(11) as num?;
  num? get pp => g(13) as num?;
}

String dg(String s) {
  const a = '٠١٢٣٤٥٦٧٨٩';
  return s.split('').map((c) { final i = a.indexOf(c); return i < 0 ? c : '$i'; }).join();
}
String fmt(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
String nf(dynamic v) => v == null ? '—' : v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
InputDecoration dec(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder());
void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
const bold = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);

Future<void> loadStatus() async {
  final s = prefs.getString('status');
  projs = s == null ? [] : (jsonDecode(s) as List).map((e) => Proj(e as List)).toList();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  await loadStatus();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'مساعد مهندس كهرباء',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0A4D9C)),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeS();
}

class _HomeS extends State<Home> {
  Future<void> _import(bool excel) async {
    final r = await FilePicker.platform.pickFiles(type: excel ? FileType.custom : FileType.any, allowedExtensions: excel ? ['xlsx'] : null);
    final path = r?.files.single.path;
    if (path == null) return;
    try {
      if (path.toLowerCase().endsWith('.pdf')) {
        if (mounted) await msg(context, 'ملف PDF الممسوح ضوئيًا لازم يتحول لملف بيانات الأول. ابعته للمساعد (Claude) وهو يرجعلك ملف JSON، وبعدين اختاره من هنا.');
        return;
      }
      String s;
      if (excel) {
        final l = toProjs(await readXlsx(path));
        if (l.isEmpty) throw 'empty';
        s = jsonEncode(l);
      } else {
        s = await File(path).readAsString();
        if (jsonDecode(s) is! List) throw 'bad';
      }
      await prefs.setString('status', s);
      await loadStatus();
      if (mounted) { setState(() {}); snack(context, 'تم تحديث الموقف التنفيذي: ${projs.length} مدرسة'); }
    } catch (e) {
      if (mounted) await msg(context, excel ? 'ما قدرتش أقرأ جدول الموقف التنفيذي من ملف Excel. تأكد إن فيه عناوين الأعمدة (المدرسة، الرقم التعريفي...).' : 'الملف غير صالح، لازم يكون ملف بيانات JSON.');
    }
  }

  Widget _pick() => Column(children: [
        FilledButton.icon(onPressed: () => _import(true), icon: const Icon(Icons.table_chart), label: const Text('ملف Excel (.xlsx)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _import(false), icon: const Icon(Icons.picture_as_pdf), label: const Text('ملف PDF (بعد تحويله لبيانات)')),
      ]);

  @override
  Widget build(BuildContext c) {
    if (projs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('⚡ مساعد مهندس كهرباء')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('📄', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text('ملف الموقف التنفيذي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('اختار نوع ملف الموقف التنفيذي علشان التطبيق يوزّع المدارس على الإنشاء والصيانة.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _pick(),
          ]),
        ),
      );
    }
    final types = ['إنشاء', 'صيانة', 'إزالة'].where((t) => t != 'إزالة' || projs.any((p) => p.type == t)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('⚡ مساعد مهندس كهرباء')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final t in types)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Text(t == 'إنشاء' ? '🏗️' : t == 'صيانة' ? '🔧' : '🧱', style: const TextStyle(fontSize: 32)),
              title: Text('مدارس $t', style: bold),
              subtitle: Text('${projs.where((p) => p.type == t).length} مدرسة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ListScr(t))),
            ),
          ),
        const SizedBox(height: 12),
        const Text('تحديث الموقف التنفيذي', style: bold),
        const SizedBox(height: 8),
        _pick(),
      ]),
    );
  }
}

class ListScr extends StatelessWidget {
  final String t;
  const ListScr(this.t, {super.key});
  @override
  Widget build(BuildContext c) {
    final l = projs.where((p) => p.type == t).toList();
    return Scaffold(
      appBar: AppBar(title: Text('مدارس $t')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: l.length,
        itemBuilder: (_, i) {
          final p = l[i];
          return Card(
            child: InkWell(
              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProjScr(p))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: bold),
                  Text('${p.id} • ${p.st}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (p.pc ?? 0) / 100, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                  Text('${p.pc ?? 0}%'),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProjScr extends StatefulWidget {
  final Proj p;
  const ProjScr(this.p, {super.key});
  @override
  State<ProjScr> createState() => _ProjS();
}

class _ProjS extends State<ProjScr> {
  int i = 0;
  final spentKey = GlobalKey<_SpentS>();
  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    return Scaffold(
      appBar: AppBar(title: Text(p.name, overflow: TextOverflow.ellipsis)),
      body: IndexedStack(index: i, children: [StatTab(p), BoqTab(p), FollowTab(p), SpentTab(p, key: spentKey), DocsTab(p)]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) {
          setState(() => i = v);
          if (v == 3) spentKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'الموقف'),
          NavigationDestination(icon: Icon(Icons.straighten), label: 'الحصر'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'متابعة'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'الصرف'),
          NavigationDestination(icon: Icon(Icons.folder_copy), label: 'المستندات'),
        ],
      ),
    );
  }
}

class StatTab extends StatelessWidget {
  final Proj p;
  const StatTab(this.p, {super.key});
  @override
  Widget build(BuildContext c) {
    final d = DateTime.tryParse(p.e.replaceAll('/', '-'));
    final late = d != null && d.isBefore(DateTime.now()) && (p.pc ?? 0) < 100;
    final rows = [
      ['الرقم التعريفي', p.id],
      ['النوع', '${p.type} - ${p.work}'],
      ['الموقف', p.st],
      ['المقاول', p.cn],
      ['المهندس المشرف', p.eng],
      ['تسليم الموقع', p.sd],
      ['النهو بعد المدة', p.e + (late ? ' ⚠️ متأخر' : '')],
      ['قيمة أمر الإسناد', nf(p.v)],
      ['المنصرف', nf(p.pd)],
      ['القطاع / الخطة', p.sec],
      ['ملاحظات', p.n.isEmpty ? '—' : p.n],
    ];
    return ListView(padding: const EdgeInsets.all(14), children: [
      Text('${p.pc ?? 0}%', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Theme.of(c).colorScheme.primary)),
      LinearProgressIndicator(value: (p.pc ?? 0) / 100, minHeight: 12, borderRadius: BorderRadius.circular(6)),
      const SizedBox(height: 6),
      Text('نسبة الصرف: ${p.pp == null ? '—' : '${p.pp}%'}'),
      const Divider(),
      for (final r in rows)
        ListTile(dense: true, title: Text(r[0], style: const TextStyle(color: Colors.grey, fontSize: 13)), subtitle: Text(r[1], style: const TextStyle(fontSize: 15))),
    ]);
  }
}

const exs = ['جاري 1', 'جاري 2', 'شبه ختامي', 'ختامي'];

class BoqTab extends StatefulWidget {
  final Proj p;
  const BoqTab(this.p, {super.key});
  @override
  State<BoqTab> createState() => _BoqS();
}

class _BoqS extends State<BoqTab> {
  final fl = TextEditingController(), spc = TextEditingController(), d = TextEditingController();
  final u = TextEditingController(), q = TextEditingController(), eng = TextEditingController();
  String kind = 'مقاس';
  int ex = 0;
  List<Map<String, dynamic>> rows = [];
  final sp = SpeechToText();
  String? on;
  bool auto = false;
  Uint8List? sig;
  String get key => 'boq_${widget.p.id}_$ex';

  @override
  void initState() {
    super.initState();
    load();
    eng.text = prefs.getString('eng_name') ?? '';
    final s = prefs.getString('eng_sig');
    if (s != null) sig = base64Decode(s);
  }

  void load() {
    final j = prefs.getString(key);
    rows = j == null ? [] : (jsonDecode(j) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void save() => prefs.setString(key, jsonEncode(rows));

  void add() {
    final n = num.tryParse(dg(q.text));
    if (d.text.trim().isEmpty || n == null) { snack(context, 'اكتب البند والكمية'); return; }
    setState(() {
      rows.add({'fl': fl.text.trim(), 'sp': spc.text.trim(), 'd': d.text.trim(), 'u': u.text.trim(), 'q': n, 'k': kind, 'dt': today()});
      d.clear(); u.clear(); q.clear();
    });
    save();
  }

  void onItem(String t) {
    final r = parseItem(t);
    setState(() {
      d.text = r['d'];
      if (r['q'] != null) { u.text = r['u']; q.text = fmt(r['q']); }
    });
    if (r['q'] == null) {
      snack(context, 'قول كلمة "بالعدد" وبعدها الكمية');
    } else if (auto) {
      add();
    }
  }

  Future<void> mic(String tag, void Function(String) cb) async {
    if (on != null) {
      final was = on;
      await sp.stop();
      setState(() => on = null);
      if (was == tag) return;
    }
    if (!await sp.initialize()) { if (mounted) snack(context, 'الميكروفون غير متاح'); return; }
    setState(() => on = tag);
    sp.listen(localeId: 'ar_EG', onResult: (r) {
      if (r.finalResult) { cb(r.recognizedWords); setState(() => on = null); }
    });
  }

  Widget micBtn(String tag, void Function(String) cb) => IconButton(
      onPressed: () => mic(tag, cb), icon: Icon(on == tag ? Icons.stop_circle : Icons.mic, color: on == tag ? Colors.red : null));

  Future<Uint8List> _pdf() => buildPdf(widget.p, exs[ex], rows, sig, eng.text.trim());

  bool _empty() {
    if (rows.isEmpty) { snack(context, 'لا توجد بنود في هذا المستخلص'); return true; }
    return false;
  }

  Future<void> printIt() async {
    if (_empty()) return;
    await Printing.layoutPdf(onLayout: (_) => _pdf(), name: 'hasr_${widget.p.id}_${ex + 1}');
  }

  Future<void> sharePdf() async {
    if (_empty()) return;
    await Printing.sharePdf(bytes: await _pdf(), filename: 'hasr_${widget.p.id}_${ex + 1}.pdf');
  }

  Future<void> xlsx() async {
    if (_empty()) return;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/hasr_${widget.p.id}_${ex + 1}.xlsx');
    await f.writeAsBytes(buildXlsx(widget.p, exs[ex], rows, eng.text.trim()));
    await Share.shareXFiles([XFile(f.path)], text: 'حصر ${widget.p.name} - ${exs[ex]}');
  }

  Future<void> sign() async {
    final b = await Navigator.push<Uint8List>(context, MaterialPageRoute(builder: (_) => const SigScreen()));
    if (b != null) {
      prefs.setString('eng_sig', base64Encode(b));
      setState(() => sig = b);
    }
  }

  @override
  Widget build(BuildContext c) {
    final run = <String, num>{};
    final cum = <num>[];
    for (final r in rows) {
      final k = '${r['d']}|${r['u']}';
      run[k] = (run[k] ?? 0) + (r['q'] as num);
      cum.add(run[k]!);
    }
    final tot = totals(rows);
    return ListView(padding: const EdgeInsets.all(14), children: [
      DropdownButtonFormField<int>(
        value: ex,
        decoration: dec('نوع المستخلص'),
        items: [for (var i = 0; i < exs.length; i++) DropdownMenuItem(value: i, child: Text(exs[i]))],
        onChanged: (v) => setState(() { ex = v!; load(); }),
      ),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: TextField(controller: fl, decoration: dec('الدور'))), micBtn('fl', (t) => setState(() => fl.text = t.trim()))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: TextField(controller: spc, decoration: dec('الفراغ'))), micBtn('sp', (t) => setState(() => spc.text = t.trim()))]),
      const SizedBox(height: 8),
      const Text('قول اسم البند ثم "بالعدد" ثم الكمية. مثال: نقطة إنارة بالعدد 12', style: TextStyle(color: Colors.grey)),
      Row(children: [Expanded(child: TextField(controller: d, decoration: dec('البند'))), micBtn('d', onItem)]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: u, decoration: dec('الوحدة'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: q, keyboardType: TextInputType.number, decoration: dec('الكمية'))),
      ]),
      Row(children: [
        DropdownButton<String>(value: kind, items: ['مقاس', 'تقديري'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => kind = v!)),
        const Spacer(),
        FilledButton(onPressed: add, child: const Text('إضافة')),
      ]),
      SwitchListTile(dense: true, title: const Text('إضافة تلقائية بعد الصوت'), value: auto, onChanged: (v) => setState(() => auto = v)),
      const Divider(),
      Text('بنود المستخلص (${rows.length})', style: bold),
      for (var i = 0; i < rows.length; i++)
        ListTile(
          dense: true,
          title: Text('${rows[i]['d']}'),
          subtitle: Text('${rows[i]['fl']} • ${rows[i]['sp']}\n${fmt(rows[i]['q'])} ${rows[i]['u']} • إجمالي البند حتى الآن: ${fmt(cum[i])} • ${rows[i]['k']}'),
          isThreeLine: true,
          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() => rows.removeAt(i)); save(); }),
        ),
      if (tot.isNotEmpty) ...[
        const Divider(),
        const Text('الإجمالي', style: bold),
        for (final t in tot)
          ListTile(dense: true, title: Text('${t[0]}'), trailing: Text('${fmt(t[2] as num)} ${t[1]}', style: bold)),
      ],
      const Divider(),
      TextField(controller: eng, onChanged: (v) => prefs.setString('eng_name', v), decoration: dec('اسم مهندس الكهرباء (للتوقيع)')),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton.icon(onPressed: sign, icon: const Icon(Icons.draw), label: Text(sig == null ? 'توقيع إلكتروني' : 'تغيير التوقيع')),
        const SizedBox(width: 12),
        if (sig != null) Image.memory(sig!, height: 48),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: printIt, icon: const Icon(Icons.print), label: const Text('طباعة')),
        OutlinedButton.icon(onPressed: sharePdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF')),
        OutlinedButton.icon(onPressed: xlsx, icon: const Icon(Icons.table_chart), label: const Text('Excel')),
      ]),
    ]);
  }
}

List<List<dynamic>> totals(List<Map<String, dynamic>> rows) {
  final m = <String, List<dynamic>>{};
  for (final r in rows) {
    final k = '${r['d']}|${r['u']}';
    final e = m.putIfAbsent(k, () => [r['d'], r['u'], 0.0]);
    e[2] = (e[2] as num) + (r['q'] as num);
  }
  return m.values.toList();
}

final Map<String, num> _words = {
  for (final e in {
    'صفر': 0, 'واحد': 1, 'واحدة': 1, 'اتنين': 2, 'اثنين': 2, 'اثنان': 2, 'تلاتة': 3, 'ثلاثة': 3, 'تلات': 3, 'اربعة': 4, 'أربعة': 4, 'اربع': 4,
    'خمسة': 5, 'خمس': 5, 'ستة': 6, 'ست': 6, 'سبعة': 7, 'سبع': 7, 'تمانية': 8, 'ثمانية': 8, 'تمان': 8, 'تسعة': 9, 'تسع': 9, 'عشرة': 10, 'عشر': 10,
    'احداشر': 11, 'حداشر': 11, 'اتناشر': 12, 'اثناعشر': 12, 'تلتاشر': 13, 'اربعتاشر': 14, 'خمستاشر': 15, 'ستاشر': 16, 'سبعتاشر': 17, 'تمنتاشر': 18, 'تسعتاشر': 19,
    'عشرين': 20, 'عشرون': 20, 'تلاتين': 30, 'ثلاثين': 30, 'اربعين': 40, 'أربعين': 40, 'خمسين': 50, 'ستين': 60, 'سبعين': 70, 'تمانين': 80, 'ثمانين': 80, 'تسعين': 90,
    'ميه': 100, 'مية': 100, 'مائة': 100, 'ميت': 100, 'ميتين': 200, 'مئتين': 200, 'مائتين': 200, 'تلتمية': 300, 'ثلاثمائة': 300, 'ربعمية': 400, 'اربعمائة': 400,
    'خمسمية': 500, 'خمسمائة': 500, 'ستمية': 600, 'ستمائة': 600, 'سبعمية': 700, 'سبعمائة': 700, 'تمنمية': 800, 'ثمانمائة': 800, 'تسعمية': 900, 'تسعمائة': 900,
    'الف': 1000, 'ألف': 1000, 'الفين': 2000, 'ألفين': 2000,
  }.entries)
    nz(e.key): e.value,
};

num? spokenNum(String s) {
  num sum = 0;
  var got = false;
  for (final w in s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty)) {
    final n = num.tryParse(w);
    if (n != null) { sum += n; got = true; continue; }
    var x = nz(w);
    if (!_words.containsKey(x) && x.startsWith('و') && _words.containsKey(x.substring(1))) x = x.substring(1);
    final v = _words[x];
    if (v == null) { if (got) break; continue; }
    sum += v;
    got = true;
  }
  return got ? sum : null;
}

Map<String, dynamic> parseItem(String raw) {
  final t = dg(raw);
  const keys = {'بالعدد': 'عدد', 'بالمتر الطولي': 'م.ط', 'بالمتر': 'متر', 'بالمجموعة': 'مجموعة', 'بالطقم': 'طقم'};
  var at = -1;
  var kw = '';
  for (final e in keys.entries) {
    final i = t.indexOf(e.key);
    if (i >= 0 && (at < 0 || i < at || (i == at && e.key.length > kw.length))) { at = i; kw = e.key; }
  }
  if (at < 0) return {'d': t.trim(), 'u': '', 'q': null};
  return {'d': t.substring(0, at).trim(), 'u': keys[kw]!, 'q': spokenNum(t.substring(at + kw.length).trim())};
}

String today() {
  final d = DateTime.now();
  return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

class SigScreen extends StatefulWidget {
  const SigScreen({super.key});
  @override
  State<SigScreen> createState() => _SigS();
}

class _SigS extends State<SigScreen> {
  final pts = <List<Offset>>[];
  final gk = GlobalKey();

  Future<void> save() async {
    if (pts.isEmpty) return;
    final b = gk.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    if (mounted) Navigator.pop(context, bd!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('توقيع مهندس الكهرباء'), actions: [TextButton(onPressed: () => setState(pts.clear), child: const Text('مسح'))]),
        body: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RepaintBoundary(
                key: gk,
                child: Container(
                  color: Colors.white,
                  child: GestureDetector(
                    onPanStart: (d) => setState(() => pts.add([d.localPosition])),
                    onPanUpdate: (d) => setState(() => pts.last.add(d.localPosition)),
                    child: CustomPaint(painter: _SigP(pts), size: Size.infinite),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: FilledButton(onPressed: save, child: const Text('حفظ التوقيع'))),
        ]),
      );
}

class _SigP extends CustomPainter {
  final List<List<Offset>> pts;
  _SigP(this.pts);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.black..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (final l in pts) {
      if (l.length == 1) { c.drawPoints(ui.PointMode.points, l, p); continue; }
      final path = Path()..moveTo(l.first.dx, l.first.dy);
      for (final o in l.skip(1)) { path.lineTo(o.dx, o.dy); }
      c.drawPath(path, p);
    }
  }
  @override
  bool shouldRepaint(_SigP o) => true;
}

Future<Uint8List> buildPdf(Proj p, String ex, List<Map<String, dynamic>> rows, Uint8List? sig, String eng) async {
  final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
  final bld = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: reg, bold: bld));
  pw.Widget cell(String t, {bool b = false, bool fill = false}) => pw.Container(
        color: fill ? PdfColors.grey300 : null,
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(t, textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );
  pw.Widget table(List<String> head, List<List<String>> data, List<double> w) => pw.Table(
        border: pw.TableBorder.all(width: .5),
        columnWidths: {for (var i = 0; i < w.length; i++) i: pw.FlexColumnWidth(w[w.length - 1 - i])},
        children: [
          pw.TableRow(children: head.reversed.map((h) => cell(h, b: true, fill: true)).toList()),
          for (final r in data) pw.TableRow(children: r.reversed.map((x) => cell(x)).toList()),
        ],
      );
  pw.Widget sigBox(String title, {Uint8List? img, String name = ''}) => pw.Column(children: [
        pw.Text(title, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.SizedBox(height: 50, width: 120, child: img == null ? null : pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.contain)),
        pw.Container(width: 130, height: .6, color: PdfColors.black),
        pw.SizedBox(height: 3),
        pw.Text(name, textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 10)),
      ]);
  final tot = totals(rows);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.all(28),
    build: (c) => [
      pw.Center(child: pw.Text('حصر الأعمال الكهربائية - مستخلص $ex', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 6),
      pw.Text('المدرسة: ${p.name}   |   الرقم التعريفي: ${p.id}   |   النوع: ${p.type}', textDirection: pw.TextDirection.rtl),
      pw.Text('المقاول: ${p.cn}   |   التاريخ: ${today()}', textDirection: pw.TextDirection.rtl),
      pw.SizedBox(height: 10),
      table(
        ['م', 'الدور', 'الفراغ', 'البند', 'الوحدة', 'الكمية', 'النوع'],
        [for (var i = 0; i < rows.length; i++) ['${i + 1}', '${rows[i]['fl']}', '${rows[i]['sp']}', '${rows[i]['d']}', '${rows[i]['u']}', fmt(rows[i]['q']), '${rows[i]['k']}']],
        [.6, 1.4, 1.6, 4, 1, 1, 1],
      ),
      pw.SizedBox(height: 14),
      pw.Text('إجمالي البنود', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      table(
        ['م', 'البند', 'الوحدة', 'الإجمالي'],
        [for (var i = 0; i < tot.length; i++) ['${i + 1}', '${tot[i][0]}', '${tot[i][1]}', fmt(tot[i][2] as num)]],
        [.6, 5, 1, 1.4],
      ),
      pw.SizedBox(height: 34),
      pw.Row(
        textDirection: pw.TextDirection.rtl,
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [sigBox('المشرف'), sigBox('مهندس الكهرباء', img: sig, name: eng), sigBox('رئيس القسم')],
      ),
    ],
  ));
  return doc.save();
}

List<int> buildXlsx(Proj p, String ex, List<Map<String, dynamic>> rows, String eng) {
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  final sb = StringBuffer();
  var n = 0;
  void row(List<dynamic> cells) {
    n++;
    sb.write('<row r="$n">');
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      final ref = '${String.fromCharCode(65 + i)}$n';
      if (c is num) {
        sb.write('<c r="$ref"><v>$c</v></c>');
      } else {
        sb.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${esc(c.toString())}</t></is></c>');
      }
    }
    sb.write('</row>');
  }
  row(['حصر الأعمال الكهربائية - ${p.name}']);
  row(['الرقم التعريفي', p.id, 'نوع المستخلص', ex, 'التاريخ', today()]);
  row([]);
  row(['م', 'الدور', 'الفراغ', 'البند', 'الوحدة', 'الكمية', 'النوع']);
  for (var i = 0; i < rows.length; i++) {
    final x = rows[i];
    row([i + 1, x['fl'], x['sp'], x['d'], x['u'], x['q'], x['k']]);
  }
  row([]);
  row(['إجمالي البنود']);
  row(['م', 'البند', 'الوحدة', 'الإجمالي']);
  final tot = totals(rows);
  for (var i = 0; i < tot.length; i++) {
    row([i + 1, tot[i][0], tot[i][1], tot[i][2]]);
  }
  row([]);
  row(['المشرف', '', 'مهندس الكهرباء: $eng', '', 'رئيس القسم']);
  row(['............', '', '............', '', '............']);
  const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  final a = Archive();
  void put(String name, String body) {
    final b = utf8.encode(body);
    a.addFile(ArchiveFile(name, b.length, b));
  }
  const head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  put('[Content_Types].xml', '$head<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>');
  put('_rels/.rels', '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
  put('xl/workbook.xml', '$head<workbook xmlns="$ns" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="الحصر" sheetId="1" r:id="rId1"/></sheets></workbook>');
  put('xl/_rels/workbook.xml.rels', '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>');
  put('xl/worksheets/sheet1.xml', '$head<worksheet xmlns="$ns"><sheetViews><sheetView rightToLeft="1" workbookViewId="0"/></sheetViews><cols><col min="1" max="1" width="14" customWidth="1"/><col min="2" max="3" width="22" customWidth="1"/><col min="4" max="4" width="46" customWidth="1"/><col min="5" max="7" width="14" customWidth="1"/></cols><sheetData>${sb.toString()}</sheetData></worksheet>');
  return ZipEncoder().encode(a)!;
}

String fd(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Future<String?> askText(BuildContext c, String title, {String init = '', int lines = 1}) {
  final tc = TextEditingController(text: init);
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(controller: tc, maxLines: lines, autofocus: true, decoration: dec('')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, tc.text), child: const Text('تمام')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext c, String m) async =>
    (await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(content: Text(m), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('نعم')),
      ]),
    )) ==
    true;

Future<String?> pickPhoto(BuildContext c, String id) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: c,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera), title: const Text('الكاميرا'), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('المعرض'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
      ]),
    ),
  );
  if (src == null) return null;
  final x = await ImagePicker().pickImage(source: src, imageQuality: 80, maxWidth: 1800);
  if (x == null) return null;
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/p_$id')..createSync(recursive: true);
  final to = '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(x.path).copy(to);
  return to;
}

Widget thumb(BuildContext c, String? path, String label) {
  if (path == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Column(children: [
      InkWell(
        onTap: () => showDialog(context: c, builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(File(path))))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(path), width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 90, height: 90, child: Icon(Icons.broken_image))),
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]),
  );
}

Widget _sb(String t, bool on, Color col, VoidCallback f) => InkWell(
      onTap: f,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: on ? col.withOpacity(.22) : null,
        child: Text(t, style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 18, color: on ? col : Colors.grey)),
      ),
    );

Widget statusBox(bool? s, void Function(bool?) set) => Container(
      decoration: BoxDecoration(
        border: Border.all(width: 2, color: s == null ? Colors.grey : (s ? Colors.green : Colors.red)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _sb('✓ تم', s == true, Colors.green, () => set(s == true ? null : true)),
        _sb('✗ لم يتم', s == false, Colors.red, () => set(s == false ? null : false)),
      ]),
    );

List<String> splitPoints(String t) =>
    t.split(RegExp(r'\s*(?:نقطة جديدة|نقطه جديده|التالي|التالى)\s*')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

List<String> cleanLines(String t) => t
    .split('\n')
    .map((e) => e.replaceFirst(RegExp(r'^\s*(?:[-•*]|\(?[0-9٠-٩]+\s*[.\-)])\s*'), '').trim())
    .where((e) => e.isNotEmpty)
    .toList();

class Dictator {
  final sp = SpeechToText();
  bool loop = false, ready = false;
  void Function(String)? onText;
  void Function()? onChange;

  Future<bool> start(void Function(String) cb, {bool continuous = false, void Function()? changed}) async {
    onText = cb;
    onChange = changed;
    if (!ready) {
      ready = await sp.initialize(onStatus: (s) {
        if (s.startsWith('done') && loop) {
          Future.delayed(const Duration(milliseconds: 400), () { if (loop) _go(); });
        } else if (s.startsWith('done')) {
          onChange?.call();
        }
      });
      if (!ready) return false;
    }
    loop = continuous;
    _go();
    onChange?.call();
    return true;
  }

  void _go() => sp.listen(localeId: 'ar_EG', onResult: (r) {
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) onText?.call(r.recognizedWords.trim());
      });

  Future<void> stop() async {
    loop = false;
    await sp.stop();
    onChange?.call();
  }

  bool get active => loop || sp.isListening;
}

class FollowTab extends StatefulWidget {
  final Proj p;
  const FollowTab(this.p, {super.key});
  @override
  State<FollowTab> createState() => _FollowS();
}

class _FollowS extends State<FollowTab> {
  int sec = 0;
  @override
  Widget build(BuildContext c) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('توزيع الشغل'), icon: Icon(Icons.groups)),
              ButtonSegment(value: 1, label: Text('مرور'), icon: Icon(Icons.fact_check)),
            ],
            selected: {sec},
            onSelectionChanged: (s) => setState(() => sec = s.first),
          ),
        ),
        Expanded(child: IndexedStack(index: sec, children: [WorkView(widget.p), VisitsView(widget.p)])),
      ]);
}

class WorkView extends StatefulWidget {
  final Proj p;
  const WorkView(this.p, {super.key});
  @override
  State<WorkView> createState() => _WorkS();
}

class _WorkS extends State<WorkView> {
  List<String> pts = [], imgs = [];
  final add = TextEditingController();
  final dic = Dictator();
  String get kp => 'work_${widget.p.id}';
  String get ki => 'workimg_${widget.p.id}';

  @override
  void initState() {
    super.initState();
    pts = prefs.getStringList(kp) ?? [];
    imgs = prefs.getStringList(ki) ?? [];
  }

  @override
  void dispose() {
    dic.stop();
    super.dispose();
  }

  void save() {
    prefs.setStringList(kp, pts);
    prefs.setStringList(ki, imgs);
  }

  void addPts(Iterable<String> l) {
    setState(() => pts.addAll(l.where((e) => e.trim().isNotEmpty)));
    save();
  }

  Future<void> dictate() async {
    if (dic.active) { await dic.stop(); return; }
    final ok = await dic.start((t) { if (mounted) addPts(splitPoints(t)); }, continuous: true, changed: () { if (mounted) setState(() {}); });
    if (!ok && mounted) snack(context, 'الميكروفون غير متاح');
  }

  Future<void> micOne() async {
    if (dic.active) { await dic.stop(); return; }
    final ok = await dic.start((t) { if (mounted) setState(() => add.text = add.text.isEmpty ? t : '${add.text} $t'); }, changed: () { if (mounted) setState(() {}); });
    if (!ok && mounted) snack(context, 'الميكروفون غير متاح');
  }

  Future<void> addImg() async {
    final path = await pickPhoto(context, widget.p.id);
    if (path != null) { setState(() => imgs.add(path)); save(); }
  }

  Future<void> pasteText() async {
    final t = await askText(context, 'الصق النص (كل سطر نقطة)', lines: 8);
    if (t != null) addPts(cleanLines(t));
  }

  Future<void> importTxt() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null) return;
    try {
      addPts(cleanLines(await File(path).readAsString()));
    } catch (_) {
      if (mounted) snack(context, 'الملف غير نصي');
    }
  }

  Future<void> edit(int i) async {
    final t = await askText(context, 'تعديل النقطة', init: pts[i], lines: 3);
    if (t != null && t.trim().isNotEmpty) { setState(() => pts[i] = t.trim()); save(); }
  }

  @override
  Widget build(BuildContext c) {
    final on = dic.active;
    return ListView(padding: const EdgeInsets.all(14), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: addImg, icon: const Icon(Icons.image), label: const Text('استيراد صورة')),
        FilledButton.icon(
          onPressed: dictate,
          style: on ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
          icon: Icon(on ? Icons.stop : Icons.mic),
          label: Text(on ? 'إيقاف التسجيل' : 'تسجيل صوتي'),
        ),
        OutlinedButton.icon(onPressed: pasteText, icon: const Icon(Icons.paste), label: const Text('لصق نص')),
        OutlinedButton.icon(onPressed: importTxt, icon: const Icon(Icons.description), label: const Text('ملف نصي')),
      ]),
      if (on) const Padding(padding: EdgeInsets.only(top: 8), child: Text('بسمعك... كل جملة بتبقى نقطة، أو قول "نقطة جديدة" بين النقاط', style: TextStyle(color: Colors.red))),
      if (imgs.isNotEmpty) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < imgs.length; i++)
              Stack(children: [
                thumb(c, imgs[i], 'صورة ${i + 1}'),
                Positioned(top: 0, left: 0, child: InkWell(onTap: () { setState(() => imgs.removeAt(i)); save(); }, child: const Icon(Icons.cancel, color: Colors.red, size: 22))),
              ]),
          ]),
        ),
        const Text('الصورة للرجوع إليها. اكتب نقطها بالصوت أو الصق نصها.', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
      const Divider(),
      Text('توزيع الشغل (${pts.length})', style: bold),
      for (var i = 0; i < pts.length; i++)
        ListTile(
          dense: true,
          leading: CircleAvatar(radius: 13, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
          title: Text(pts[i]),
          onTap: () => edit(i),
          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() => pts.removeAt(i)); save(); }),
        ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: add, decoration: dec('نقطة جديدة'))),
        IconButton(onPressed: micOne, icon: const Icon(Icons.mic)),
        FilledButton(onPressed: () { if (add.text.trim().isNotEmpty) { addPts([add.text.trim()]); add.clear(); } }, child: const Text('إضافة')),
      ]),
    ]);
  }
}

class VisitsView extends StatefulWidget {
  final Proj p;
  const VisitsView(this.p, {super.key});
  @override
  State<VisitsView> createState() => _VisitsS();
}

class _VisitsS extends State<VisitsView> {
  List<Map<String, dynamic>> vs = [];
  String get k => 'visits_${widget.p.id}';

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    final j = prefs.getString(k);
    vs = j == null ? [] : (jsonDecode(j) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> open(int i) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => VisitScreen(widget.p, i)));
    if (mounted) setState(load);
  }

  Future<void> newVisit() async {
    final work = prefs.getStringList('work_${widget.p.id}') ?? [];
    final prev = vs.isEmpty ? <dynamic>[] : (vs.first['notes'] as List);
    final v = <String, dynamic>{
      'date': today(),
      'dist': [for (final t in work) {'t': t, 's': null}],
      'notes': [
        for (final n in prev)
          if (n['s'] != true) {'t': n['t'], 's': null, 'b': n['b'], 'a': null, 'c': true},
      ],
    };
    vs.insert(0, v);
    prefs.setString(k, jsonEncode(vs));
    await open(0);
  }

  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(14), children: [
        FilledButton.icon(onPressed: newVisit, icon: const Icon(Icons.add), label: const Text('مرور جديد')),
        const SizedBox(height: 8),
        if (vs.isEmpty) const Text('لا توجد مرورات بعد.', style: TextStyle(color: Colors.grey)),
        for (var i = 0; i < vs.length; i++)
          Builder(builder: (_) {
            final all = [...(vs[i]['dist'] as List), ...(vs[i]['notes'] as List)];
            final ok = all.where((e) => e['s'] == true).length;
            final no = all.where((e) => e['s'] == false).length;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.event_note),
                title: Text('مرور ${vs[i]['date']}', style: bold),
                subtitle: Text('✓ $ok   ✗ $no   لم يُراجع ${all.length - ok - no}'),
                onTap: () => open(i),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'حذف هذا المرور؟')) {
                      setState(() => vs.removeAt(i));
                      prefs.setString(k, jsonEncode(vs));
                    }
                  },
                ),
              ),
            );
          }),
      ]);
}

class VisitScreen extends StatefulWidget {
  final Proj p;
  final int i;
  const VisitScreen(this.p, this.i, {super.key});
  @override
  State<VisitScreen> createState() => _VisitS();
}

class _VisitS extends State<VisitScreen> {
  List<Map<String, dynamic>> vs = [];
  late Map<String, dynamic> v;
  final nt = TextEditingController();
  final dic = Dictator();
  String get k => 'visits_${widget.p.id}';
  List get dist => v['dist'] as List;
  List get notes => v['notes'] as List;

  @override
  void initState() {
    super.initState();
    vs = (jsonDecode(prefs.getString(k) ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)).toList();
    v = vs[widget.i];
  }

  @override
  void dispose() {
    dic.stop();
    super.dispose();
  }

  void save() => prefs.setString(k, jsonEncode(vs));

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) { setState(() => v['date'] = fd(d)); save(); }
  }

  Future<void> photo(Map n, String key) async {
    final path = await pickPhoto(context, widget.p.id);
    if (path != null) { setState(() => n[key] = path); save(); }
  }

  Future<void> mic() async {
    if (dic.active) { await dic.stop(); return; }
    final ok = await dic.start((t) { if (mounted) setState(() => nt.text = nt.text.isEmpty ? t : '${nt.text} $t'); }, changed: () { if (mounted) setState(() {}); });
    if (!ok && mounted) snack(context, 'الميكروفون غير متاح');
  }

  void addNote() {
    if (nt.text.trim().isEmpty) return;
    setState(() {
      notes.add({'t': nt.text.trim(), 's': null, 'b': null, 'a': null, 'c': false});
      nt.clear();
    });
    save();
  }

  Widget title(String t) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text(t, style: bold));

  Widget distItem(Map d) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['t']}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            statusBox(d['s'] as bool?, (s) { setState(() => d['s'] = s); save(); }),
          ]),
        ),
      );

  Widget noteCard(Map n, bool review) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${n['t']}', style: const TextStyle(fontSize: 15)),
            if (n['b'] != null || n['a'] != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [thumb(context, n['b'] as String?, 'قبل'), thumb(context, n['a'] as String?, 'بعد')])),
            Wrap(spacing: 4, children: [
              TextButton.icon(onPressed: () => photo(n, 'b'), icon: const Icon(Icons.photo_camera, size: 18), label: Text(n['b'] == null ? 'صورة قبل' : 'تغيير قبل')),
              if (review) TextButton.icon(onPressed: () => photo(n, 'a'), icon: const Icon(Icons.photo_camera_back, size: 18), label: Text(n['a'] == null ? 'صورة بعد' : 'تغيير بعد')),
            ]),
            Row(children: [
              if (review) statusBox(n['s'] as bool?, (s) { setState(() => n['s'] = s); save(); }),
              const Spacer(),
              if (!review) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { setState(() => notes.remove(n)); save(); }),
            ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext c) {
    final carried = notes.where((n) => n['c'] == true).toList();
    final fresh = notes.where((n) => n['c'] != true).toList();
    return Scaffold(
      appBar: AppBar(title: Text('مرور ${v['date']}')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        ListTile(leading: const Icon(Icons.event), title: Text('التاريخ: ${v['date']}'), trailing: const Icon(Icons.edit), onTap: pickDate),
        title('مراجعة توزيع الشغل'),
        if (dist.isEmpty) const Text('أضف نقاط توزيع الشغل من تبويب "توزيع الشغل" قبل بدء المرور.', style: TextStyle(color: Colors.grey)),
        for (final d in dist) distItem(d),
        title('ملاحظات الزيارة السابقة'),
        if (carried.isEmpty) const Text('لا توجد ملاحظات مرحّلة.', style: TextStyle(color: Colors.grey)),
        for (final n in carried) noteCard(n, true),
        title('ملاحظات جديدة'),
        for (final n in fresh) noteCard(n, false),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: nt, decoration: dec('ملحوظة جديدة'))),
          IconButton(onPressed: mic, icon: Icon(dic.active ? Icons.stop_circle : Icons.mic, color: dic.active ? Colors.red : null)),
          FilledButton(onPressed: addNote, child: const Text('إضافة')),
        ]),
        const SizedBox(height: 30),
      ]),
    );
  }
}

Future<void> msg(BuildContext c, String m) => showDialog(
    context: c,
    builder: (_) => AlertDialog(content: Text(m), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('تمام'))]));

String nz(String s) => dg(s).replaceAll(RegExp(r'[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي').replaceAll(RegExp(r'\s+'), ' ').trim();

int colIndex(String ref) {
  var n = 0;
  for (final ch in ref.codeUnits) {
    if (ch >= 65 && ch <= 90) { n = n * 26 + (ch - 64); } else { break; }
  }
  return n - 1;
}

Future<List<List<String>>> readXlsx(String path) async {
  final z = ZipDecoder().decodeBytes(await File(path).readAsBytes());
  String? txt(ArchiveFile? f) => f == null ? null : utf8.decode(f.content as List<int>);
  final ss = <String>[];
  final sst = txt(z.findFile('xl/sharedStrings.xml'));
  if (sst != null) {
    for (final si in XmlDocument.parse(sst).findAllElements('si')) {
      ss.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }
  final rows = <List<String>>[];
  final sheets = z.files.where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')).toList();
  sheets.sort((a, b) => a.name.compareTo(b.name));
  for (final f in sheets) {
    for (final row in XmlDocument.parse(txt(f)!).findAllElements('row')) {
      final cells = <String>[];
      for (final c in row.findElements('c')) {
        final col = colIndex(c.getAttribute('r') ?? '');
        while (cells.length < col) { cells.add(''); }
        final t = c.getAttribute('t');
        final v = c.getElement('v')?.innerText ?? '';
        var val = v;
        if (t == 's') {
          val = ss[int.parse(v)];
        } else if (t == 'inlineStr') {
          val = c.findAllElements('t').map((x) => x.innerText).join();
        }
        cells.add(val);
      }
      rows.add(cells);
    }
  }
  return rows;
}

List<List<dynamic>> toProjs(List<List<String>> rows) {
  final m = <String, int>{};
  var type = 'إنشاء';
  final out = <List<dynamic>>[];
  String at(List<String> r, String k) {
    final i = m[k];
    return (i == null || i >= r.length) ? '' : r[i].trim();
  }
  num? pn(String s) => num.tryParse(dg(s).replaceAll(',', '').replaceAll('%', '').trim());
  num? pct(String s) {
    final v = pn(s);
    if (v == null) return null;
    return (v > 0 && v <= 1 && s.contains('.')) ? (v * 100).round() : v;
  }
  String dt(String s) {
    final v = pn(s);
    if (v != null && v > 20000 && v < 70000) {
      final d = DateTime(1899, 12, 30).add(Duration(days: v.toInt()));
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }
    return s;
  }
  for (final r in rows) {
    final j = r.map(nz).toList();
    final line = j.join(' ');
    if (line.contains('المدرسه') && line.contains('تعريفي')) {
      m.clear();
      for (var i = 0; i < j.length; i++) {
        final h = j[i];
        void s(String k, bool ok) { if (ok && !m.containsKey(k)) m[k] = i; }
        s('name', h.contains('المدرسه'));
        s('id', h.contains('تعريفي'));
        s('work', h.contains('نوع الاعمال'));
        s('cn', h.contains('المقاول'));
        s('sd', h.contains('تسليم'));
        s('e', h.contains('النهو'));
        s('eng', h.contains('المهندس'));
        s('v', h.contains('قيمه'));
        s('st', h.contains('الموقف'));
        s('pc', h.contains('نسبه الانجاز') && !h.contains('يوم'));
        s('pd', h.contains('المنصرف'));
        s('pp', h.contains('نسبه الصرف'));
      }
      continue;
    }
    if (m.isEmpty) continue;
    if (line.contains('مشروعات')) {
      if (line.contains('الانشاء')) { type = 'إنشاء'; }
      else if (line.contains('الصيانه')) { type = 'صيانة'; }
      else if (line.contains('الازاله')) { type = 'إزالة'; }
      continue;
    }
    final id = dg(at(r, 'id'));
    if (!RegExp(r'^\d{5,}$').hasMatch(id)) continue;
    out.add([at(r, 'name'), id, type, at(r, 'work'), 'من ملف Excel', at(r, 'cn'), dt(at(r, 'sd')), dt(at(r, 'e')), at(r, 'eng'), pn(at(r, 'v')), at(r, 'st'), pct(at(r, 'pc')), pn(at(r, 'pd')), pct(at(r, 'pp')), '']);
  }
  return out;
}

// ======================= المقايسة + المستخلصات + المستندات =======================
const _hs = TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.4);
const _small = TextStyle(fontSize: 12, color: Colors.grey);

Color tagColor(String k) => k == 'استحداث' ? Colors.green : k == 'تجاوز' ? Colors.orange : k == 'إلغاء' ? Colors.red : Colors.blueGrey;

String normD(String s) => nz(s).replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

double sim(String a, String b) {
  final x = normD(a).split(' ').where((e) => e.length > 1).toSet();
  final y = normD(b).split(' ').where((e) => e.length > 1).toSet();
  if (x.isEmpty || y.isEmpty) return 0;
  return x.intersection(y).length / x.union(y).length;
}

List<Map<String, dynamic>> loadList(Proj p, String k) {
  final j = prefs.getString('${k}_${p.id}');
  return j == null ? [] : (jsonDecode(j) as List).map((e) => Map<String, dynamic>.from(e)).toList();
}

void saveList(Proj p, String k, List<Map<String, dynamic>> l) => prefs.setString('${k}_${p.id}', jsonEncode(l));

String memoKind(String raw, String def) {
  final n = nz(raw);
  if (n.contains('استحداث')) return 'استحداث';
  if (n.contains('تجاوز')) return 'تجاوز';
  if (n.contains('الغاء')) return 'إلغاء';
  return def.isEmpty ? 'استحداث' : def;
}

List<Map<String, dynamic>> tableToItems(List<List<String>> rows) {
  final m = <String, int>{};
  final out = <Map<String, dynamic>>[];
  num? pn(String s) => num.tryParse(dg(s).replaceAll(',', '').replaceAll('%', '').trim());
  String at(List<String> r, String k) {
    final i = m[k];
    return (i == null || i >= r.length) ? '' : r[i].trim();
  }
  for (final r in rows) {
    final j = r.map(nz).toList();
    final hasD = j.any((h) => h.contains('البند') || h.contains('الوصف') || h.contains('البيان'));
    final hasQ = j.any((h) => h.contains('الكميه'));
    if (hasD && hasQ) {
      m.clear();
      for (var i = 0; i < j.length; i++) {
        final h = j[i];
        void s(String k, bool ok) { if (ok && !m.containsKey(k)) m[k] = i; }
        final isNo = h == 'م' || h.contains('رقم') || h.contains('كود');
        s('no', isNo);
        s('d', !isNo && (h.contains('البند') || h.contains('الوصف') || h.contains('البيان')));
        s('u', h.contains('الوحده'));
        s('q', h.contains('الكميه'));
        s('pr', h.contains('السعر') || h.contains('الفئه'));
        s('k', h.contains('الصفه') || h.contains('نوع التعديل') || h.contains('الحاله'));
      }
      continue;
    }
    if (!m.containsKey('d') || !m.containsKey('q')) continue;
    final d = at(r, 'd');
    final q = pn(at(r, 'q'));
    if (d.isEmpty || q == null) continue;
    out.add({'no': at(r, 'no'), 'd': d, 'u': at(r, 'u'), 'q': q, 'pr': pn(at(r, 'pr')), 'k': at(r, 'k')});
  }
  return out;
}

int findRow(List<Map<String, dynamic>> rows, String no, String d, String u, {Map<String, String>? mp}) {
  if (mp != null) {
    final id = mp['${normD(d)}|${normD(u)}'];
    if (id != null) {
      final i = rows.indexWhere((r) => r['id'] == id);
      if (i >= 0) return i;
    }
  }
  if (no.trim().isNotEmpty) {
    final i = rows.indexWhere((r) => '${r['no']}'.trim() == no.trim());
    if (i >= 0) return i;
  }
  final nd = normD(d);
  var best = -1;
  var bs = 0.0;
  for (var i = 0; i < rows.length; i++) {
    final nr = normD('${rows[i]['d']}');
    var s = nr == nd ? 1.0 : sim(nr, nd);
    final ru = normD('${rows[i]['u']}');
    if (u.trim().isNotEmpty && ru.isNotEmpty && ru != normD(u)) s -= 0.15;
    if (s > bs) { bs = s; best = i; }
  }
  return bs >= 0.6 ? best : -1;
}

List<Map<String, dynamic>> mergeBoq(Proj p) {
  final rows = <Map<String, dynamic>>[];
  final seen = <String, int>{};
  Map<String, dynamic> mk(Map m, String k, num q, bool isNew) {
    final b = '${normD('${m['d']}')}|${normD('${m['u'] ?? ''}')}';
    final c = seen[b] ?? 0;
    seen[b] = c + 1;
    return {'id': c == 0 ? b : '$b#$c', 'no': '${m['no'] ?? ''}', 'd': '${m['d']}', 'u': '${m['u'] ?? ''}', 'q': q, 'orig': isNew ? 0 : q, 'pr': m['pr'], 'k': k, 'tag': k, 'new': isNew, 'un': false, 'adj': 0};
  }
  for (final b in loadList(p, 'bq')) {
    rows.add(mk(b, 'أصلي', (b['q'] as num?) ?? 0, false));
  }
  for (final m in loadList(p, 'memo')) {
    final k = '${m['k']}';
    final q = (m['q'] as num?) ?? 0;
    if (k == 'استحداث') { rows.add(mk(m, 'استحداث', q, true)); continue; }
    final i = findRow(rows, '${m['no'] ?? ''}', '${m['d']}', '${m['u'] ?? ''}');
    if (i >= 0) {
      rows[i]['adj'] = (rows[i]['adj'] as num) + (k == 'تجاوز' ? q : -q);
    } else {
      final r = mk(m, k, k == 'إلغاء' ? -q : q, true);
      r['un'] = true;
      r['tag'] = '$k (غير مرتبط بالمقايسة)';
      rows.add(r);
    }
  }
  for (final r in rows) {
    final a = r['adj'] as num;
    if (a == 0 || r['un'] == true) continue;
    num q = (r['q'] as num) + a;
    if (q < 0) q = 0;
    r['q'] = q;
    if (r['k'] == 'استحداث') { r['tag'] = a > 0 ? 'استحداث + تجاوز ${fmt(a)}' : 'استحداث - ${fmt(-a)}'; continue; }
    r['k'] = a > 0 ? 'تجاوز' : 'إلغاء';
    r['tag'] = a > 0 ? 'تجاوز +${fmt(a)}' : (q == 0 ? 'ملغي بالكامل' : 'إلغاء ${fmt(-a)}');
  }
  return rows;
}

List<Map<String, dynamic>> allExtracts(Proj p) {
  final out = <Map<String, dynamic>>[];
  for (final e in loadList(p, 'ext')) {
    out.add({'no': e['no'], 'date': e['date'], 'src': 'مستورد', 'items': e['items']});
  }
  for (var ex = 0; ex < exs.length; ex++) {
    final j = prefs.getString('boq_${p.id}_$ex');
    if (j == null) continue;
    final rows = (jsonDecode(j) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    if (rows.isEmpty) continue;
    final dates = rows.map((r) => '${r['dt'] ?? ''}').where((s) => s.isNotEmpty).toList()..sort();
    out.add({
      'no': exs[ex],
      'date': dates.isEmpty ? '' : dates.last,
      'src': 'من الحصر',
      'items': totals(rows).map((t) => {'d': t[0], 'u': t[1], 'q': t[2]}).toList(),
    });
  }
  return out;
}

Map<String, dynamic> computeSpend(Proj p) {
  final rows = mergeBoq(p);
  final mp = Map<String, String>.from(jsonDecode(prefs.getString('map_${p.id}') ?? '{}'));
  final by = <String, List<Map<String, dynamic>>>{};
  final un = <Map<String, dynamic>>[];
  for (final e in allExtracts(p)) {
    for (final it in (e['items'] as List)) {
      final q = (it['q'] as num?) ?? 0;
      final i = findRow(rows, '${it['no'] ?? ''}', '${it['d']}', '${it['u'] ?? ''}', mp: mp);
      final rec = <String, dynamic>{'ex': '${e['no']}', 'date': '${e['date'] ?? ''}', 'q': q};
      if (i < 0) {
        un.add({...rec, 'd': '${it['d']}', 'u': '${it['u'] ?? ''}'});
      } else {
        (by[rows[i]['id'] as String] ??= []).add(rec);
      }
    }
  }
  return {'rows': rows, 'by': by, 'un': un};
}

Widget _statBox(String t, String v, Color col) => Column(children: [
      Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: col)),
      Text(t, style: _small),
    ]);

class SpentTab extends StatefulWidget {
  final Proj p;
  const SpentTab(this.p, {super.key});
  @override
  State<SpentTab> createState() => _SpentS();
}

class _SpentS extends State<SpentTab> {
  Map<String, dynamic> d = {};
  String f = 'الكل';

  @override
  void initState() {
    super.initState();
    d = computeSpend(widget.p);
  }

  void refresh() {
    if (mounted) setState(() => d = computeSpend(widget.p));
  }

  Future<void> importExtract() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    final low = path.toLowerCase();
    if (low.endsWith('.pdf') || low.endsWith('.jpg') || low.endsWith('.jpeg') || low.endsWith('.png')) {
      await msg(context, 'المستخلص الممسوح (PDF أو صورة) لازم يتحول لجدول بنود الأول. ابعته للمساعد (Claude) وهو يرجعلك ملف Excel أو JSON، وبعدين استورده من هنا.');
      return;
    }
    try {
      List<Map<String, dynamic>> items;
      String no = '';
      String date = '';
      if (low.endsWith('.xlsx')) {
        items = tableToItems(await readXlsx(path));
      } else {
        final j = jsonDecode(await File(path).readAsString());
        if (j is List) {
          items = j.map((e) => Map<String, dynamic>.from(e)).toList();
        } else {
          final m = Map<String, dynamic>.from(j);
          items = (m['items'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          no = '${m['no'] ?? ''}';
          date = '${m['date'] ?? ''}';
        }
      }
      items = items.where((e) => '${e['d'] ?? ''}'.isNotEmpty && e['q'] is num).toList();
      if (items.isEmpty) throw 'empty';
      if (no.isEmpty) {
        if (!mounted) return;
        final a = await askText(context, 'رقم المستخلص (مثال: جاري 3)');
        if (a == null || a.trim().isEmpty) return;
        no = a.trim();
        if (!mounted) return;
        date = ((await askText(context, 'تاريخ المستخلص', init: today())) ?? '').trim();
      }
      final l = loadList(widget.p, 'ext')..removeWhere((e) => '${e['no']}' == no);
      l.add({'no': no, 'date': date, 'items': items});
      saveList(widget.p, 'ext', l);
      refresh();
      if (mounted) snack(context, 'تم استيراد مستخلص $no (${items.length} بند)');
    } catch (_) {
      if (mounted) await msg(context, 'تعذّر قراءة المستخلص. لازم يكون Excel فيه أعمدة (البند، الوحدة، الكمية) أو ملف JSON.');
    }
  }

  Future<void> link(Map<String, dynamic> it, List<Map<String, dynamic>> rows) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .75,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Text('اربط "${it['d']}" ببند من المقايسة', style: bold)),
          Expanded(
            child: ListView(children: [
              for (final r in rows) ListTile(dense: true, title: Text('${r['no']} ${r['d']}'), subtitle: Text('${r['u']}'), onTap: () => Navigator.pop(ctx, '${r['id']}')),
            ]),
          ),
        ]),
      ),
    );
    if (id == null) return;
    final mp = Map<String, String>.from(jsonDecode(prefs.getString('map_${widget.p.id}') ?? '{}'));
    mp['${normD('${it['d']}')}|${normD('${it['u']}')}'] = id;
    await prefs.setString('map_${widget.p.id}', jsonEncode(mp));
    refresh();
  }

  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    final rows = (d['rows'] as List).cast<Map<String, dynamic>>();
    final by = d['by'] as Map<String, List<Map<String, dynamic>>>;
    final un = (d['un'] as List).cast<Map<String, dynamic>>();
    final exts = allExtracts(p);
    num spentQ(Map<String, dynamic> r) => (by[r['id']] ?? <Map<String, dynamic>>[]).fold<num>(0, (a, e) => a + (e['q'] as num));
    num tv = 0, sv = 0;
    var hasPr = false;
    var full = 0, part = 0, none = 0;
    for (final r in rows) {
      final q = r['q'] as num;
      final s = spentQ(r);
      final pr = r['pr'] as num?;
      if (pr != null) { hasPr = true; tv += pr * q; sv += pr * s; }
      if (q > 0 && s >= q) { full++; } else if (s > 0) { part++; } else { none++; }
    }
    bool pass(Map<String, dynamic> r) {
      final s = spentQ(r);
      final q = r['q'] as num;
      switch (f) {
        case 'تم صرفه': return s > 0;
        case 'المتبقي': return q - s > 0;
        case 'استحداث': return r['k'] == 'استحداث';
        case 'تجاوز': return r['k'] == 'تجاوز';
        case 'إلغاء': return r['k'] == 'إلغاء';
        default: return true;
      }
    }
    final ratio = hasPr ? (tv == 0 ? 0.0 : (sv / tv).clamp(0, 1).toDouble()) : (rows.isEmpty ? 0.0 : (full + part * .5) / rows.length);
    final shown = rows.where(pass).toList();
    return ListView(padding: const EdgeInsets.all(14), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ما تم صرفه / المتبقي', style: bold),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text('ارفع المقايسة من تبويب "المستندات" الأول، وبعدها استورد المستخلصات هنا.', style: TextStyle(color: Colors.grey))
            else ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: hasPr
                  ? [_statBox('المقايسة (جنيه)', nf(tv.round()), Colors.blueGrey), _statBox('تم صرفه', nf(sv.round()), Colors.green), _statBox('المتبقي', nf((tv - sv).round()), Colors.orange)]
                  : [_statBox('صُرف كليًا', '$full', Colors.green), _statBox('جزئيًا', '$part', Colors.orange), _statBox('لم يُصرف', '$none', Colors.red)]),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: ratio, minHeight: 10, borderRadius: BorderRadius.circular(5)),
              Text('${(ratio * 100).round()}% ${hasPr ? 'من قيمة المقايسة' : 'تقدير حسب الكميات'}', style: _small),
            ],
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المستخلصات (${exts.length})', style: bold),
            const Text('مستخلصات الحصر بتتضاف هنا تلقائيًا.', style: _small),
            for (final e in exts)
              ListTile(
                dense: true,
                title: Text('${e['no']}'),
                subtitle: Text('${(e['date'] ?? '').toString().isEmpty ? 'بدون تاريخ' : e['date']} • ${(e['items'] as List).length} بند • ${e['src']}'),
                trailing: e['src'] == 'مستورد'
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirm(c, 'حذف المستخلص ${e['no']}؟')) {
                            saveList(p, 'ext', loadList(p, 'ext')..removeWhere((x) => '${x['no']}' == '${e['no']}'));
                            refresh();
                          }
                        },
                      )
                    : null,
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(onPressed: importExtract, icon: const Icon(Icons.upload_file), label: const Text('استيراد مستخلص (Excel / JSON)')),
          ]),
        ),
      ),
      if (rows.isNotEmpty) ...[
        Wrap(spacing: 6, children: [
          for (final t in ['الكل', 'تم صرفه', 'المتبقي', 'استحداث', 'تجاوز', 'إلغاء']) ChoiceChip(label: Text(t), selected: f == t, onSelected: (_) => setState(() => f = t)),
        ]),
        const SizedBox(height: 6),
        for (final r in shown) _rowCard(r, by[r['id']] ?? <Map<String, dynamic>>[], spentQ(r)),
        if (shown.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد بنود في هذا التصنيف.', style: TextStyle(color: Colors.grey))),
      ],
      if (un.isNotEmpty) ...[
        const Divider(),
        Text('بنود مستخلصات غير مطابقة للمقايسة (${un.length})', style: bold),
        for (final u in un)
          Card(
            child: ListTile(
              dense: true,
              title: Text('${u['d']}'),
              subtitle: Text('${u['ex']} بتاريخ ${u['date']} • ${fmt(u['q'] as num)} ${u['u']}'),
              trailing: TextButton(onPressed: () => link(u, rows), child: const Text('ربط')),
            ),
          ),
      ],
    ]);
  }

  Widget _rowCard(Map<String, dynamic> r, List<Map<String, dynamic>> list, num s) {
    final q = r['q'] as num;
    final rem = q - s;
    final pr = r['pr'] as num?;
    final title = ('${r['no']}'.isEmpty ? '' : '${r['no']} - ') + '${r['d']}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: _hs)),
            const SizedBox(width: 6),
            Chip(label: Text('${r['tag']}', style: const TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: tagColor('${r['k']}'), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 14, children: [
            Text('المقايسة: ${fmt(q)} ${r['u']}'),
            Text('تم صرفه: ${fmt(s)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            Text('المتبقي: ${fmt(rem)}', style: TextStyle(color: rem < 0 ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)),
          ]),
          if (pr != null) Text('بالجنيه  •  المقايسة ${nf((pr * q).round())}  •  تم ${nf((pr * s).round())}  •  متبقي ${nf((pr * rem).round())}', style: _small),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: q <= 0 ? 0.0 : (s / q).clamp(0, 1).toDouble(), minHeight: 6, borderRadius: BorderRadius.circular(3)),
          if (rem < 0) const Text('⚠ المنصرف أكبر من كمية المقايسة', style: TextStyle(color: Colors.red, fontSize: 12)),
          for (final e in list) Text('• ${e['ex']} بتاريخ ${(e['date'] ?? '').toString().isEmpty ? '—' : e['date']}  —  ${fmt(e['q'] as num)} ${r['u']}', style: _small),
          if (list.isEmpty) const Text('لم يُصرف في أي مستخلص بعد', style: _small),
        ]),
      ),
    );
  }
}

class BoqViewScreen extends StatelessWidget {
  final Proj p;
  const BoqViewScreen(this.p, {super.key});
  @override
  Widget build(BuildContext c) {
    final rows = mergeBoq(p);
    return Scaffold(
      appBar: AppBar(title: const Text('المقايسة المدمجة')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        for (final r in rows)
          Card(
            child: ListTile(
              title: Text(('${r['no']}'.isEmpty ? '' : '${r['no']} - ') + '${r['d']}', style: _hs),
              subtitle: Text('${fmt(r['q'] as num)} ${r['u']}${r['k'] == 'أصلي' || r['new'] == true ? '' : '  (الأصلي ${fmt(r['orig'] as num)})'}${r['pr'] == null ? '' : '  •  السعر ${nf(r['pr'])}'}'),
              trailing: Chip(label: Text('${r['tag']}', style: const TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: tagColor('${r['k']}'), visualDensity: VisualDensity.compact),
            ),
          ),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد بنود مقايسة بعد.')),
      ]),
    );
  }
}

class DocsTab extends StatefulWidget {
  final Proj p;
  const DocsTab(this.p, {super.key});
  @override
  State<DocsTab> createState() => _DocsS();
}

class _DocsS extends State<DocsTab> {
  List<Map<String, dynamic>> docs = [];
  String f = 'الكل';

  @override
  void initState() {
    super.initState();
    docs = loadList(widget.p, 'docs');
  }

  void save() => saveList(widget.p, 'docs', docs);

  Future<void> add() async {
    final opts = [['رسومات', ''], ['مقايسة', ''], ['مذكرة استحداث', 'استحداث'], ['مذكرة استحداث', 'تجاوز'], ['مذكرة استحداث', 'إلغاء']];
    final kind = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('نوع المستند', style: bold)),
          for (final o in opts) ListTile(title: Text(o[1].isEmpty ? o[0] : '${o[0]} — ${o[1]}'), onTap: () => Navigator.pop(ctx, o)),
        ]),
      ),
    );
    if (kind == null) return;
    final r = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (r == null) return;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/p_${widget.p.id}/docs')..createSync(recursive: true);
    for (final x in r.files) {
      if (x.path == null) continue;
      final to = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${x.name}';
      await File(x.path!).copy(to);
      docs.add({'cat': kind[0], 'sub': kind[1], 'name': x.name, 'path': to, 'date': today()});
    }
    save();
    if (mounted) setState(() {});
  }

  String ext(Map<String, dynamic> d) => '${d['path']}'.split('.').last.toLowerCase();

  bool canImport(Map<String, dynamic> d) => (ext(d) == 'xlsx' || ext(d) == 'json') && (d['cat'] == 'مقايسة' || d['cat'] == 'مذكرة استحداث');

  Future<void> open(Map<String, dynamic> d) async {
    final path = '${d['path']}';
    if (!File(path).existsSync()) { snack(context, 'الملف غير موجود'); return; }
    final e = ext(d);
    final name = '${d['name']}';
    if (e == 'pdf') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewScreen(path, name)));
    } else if (e == 'dxf') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => DxfViewScreen(path, name)));
    } else if (['jpg', 'jpeg', 'png', 'webp'].contains(e)) {
      await showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(File(path)))));
    } else if (e == 'dwg') {
      await msg(context, 'ملف DWG صيغة مغلقة من AutoCAD ومش بيتعرض جوه التطبيق. احفظه من AutoCAD بصيغة PDF أو DXF وارفعه، وهيتعرض مضبوط.');
    } else {
      await Share.shareXFiles([XFile(path)]);
    }
  }

  Future<void> importDoc(Map<String, dynamic> d) async {
    final path = '${d['path']}';
    try {
      List<Map<String, dynamic>> items;
      if (ext(d) == 'xlsx') {
        items = tableToItems(await readXlsx(path));
      } else {
        items = (jsonDecode(await File(path).readAsString()) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      items = items.where((e) => '${e['d'] ?? ''}'.isNotEmpty && e['q'] is num).toList();
      if (items.isEmpty) throw 'empty';
      final isMemo = d['cat'] == 'مذكرة استحداث';
      final key = isMemo ? 'memo' : 'bq';
      final l = loadList(widget.p, key)..removeWhere((e) => e['doc'] == path);
      for (final it in items) {
        final m = Map<String, dynamic>.from(it);
        m['doc'] = path;
        if (isMemo) m['k'] = memoKind('${it['k'] ?? ''}', '${d['sub']}');
        l.add(m);
      }
      saveList(widget.p, key, l);
      if (mounted) { setState(() {}); snack(context, 'تم استيراد ${items.length} بند في ${isMemo ? 'مذكرة ${d['sub']}' : 'المقايسة'}'); }
    } catch (_) {
      if (mounted) await msg(context, 'تعذّر قراءة البنود. لازم الملف Excel فيه أعمدة (البند، الوحدة، الكمية، السعر) أو JSON. لو المقايسة PDF ابعتها للمساعد (Claude) وهو يحوّلها.');
    }
  }

  IconData icon(Map<String, dynamic> d) {
    switch (ext(d)) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'dxf':
      case 'dwg': return Icons.architecture;
      case 'xlsx': return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext c) {
    final m = mergeBoq(widget.p);
    final cnt = <String, int>{};
    for (final r in m) { cnt['${r['k']}'] = (cnt['${r['k']}'] ?? 0) + 1; }
    final cats = ['الكل', 'رسومات', 'مقايسة', 'مذكرة استحداث'];
    final shown = docs.where((d) => f == 'الكل' || d['cat'] == f).toList();
    return ListView(padding: const EdgeInsets.all(14), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المقايسة المدمجة (${m.length} بند)', style: bold),
            Wrap(spacing: 6, children: [
              for (final k in ['أصلي', 'استحداث', 'تجاوز', 'إلغاء'])
                Chip(label: Text('$k ${cnt[k] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: tagColor(k), visualDensity: VisualDensity.compact),
            ]),
            const Text('استورد ملف المقايسة ومذكرات الاستحداث/التجاوز/الإلغاء (Excel أو JSON) من القايمة تحت، وهتتدمج وتتصنف تلقائيًا.', style: _small),
            Row(children: [
              OutlinedButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => BoqViewScreen(widget.p))), icon: const Icon(Icons.table_rows), label: const Text('عرض')),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  if (await confirm(c, 'مسح بنود المقايسة والمذكرات المستوردة؟ (المستندات نفسها هتفضل)')) {
                    saveList(widget.p, 'bq', []);
                    saveList(widget.p, 'memo', []);
                    setState(() {});
                  }
                },
                child: const Text('مسح البنود'),
              ),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: add, icon: const Icon(Icons.attach_file), label: const Text('رفع مستند (رسومات / مقايسة / مذكرة)')),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: [for (final t in cats) ChoiceChip(label: Text(t), selected: f == t, onSelected: (_) => setState(() => f = t))]),
      if (shown.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد مستندات.', style: TextStyle(color: Colors.grey))),
      for (final d in shown)
        Card(
          child: ListTile(
            leading: Icon(icon(d)),
            title: Text('${d['name']}', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${d['sub'].toString().isEmpty ? d['cat'] : '${d['cat']} — ${d['sub']}'} • ${d['date']}'),
            onTap: () => open(d),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'open') { await open(d); }
                if (v == 'share') { await Share.shareXFiles([XFile('${d['path']}')]); }
                if (v == 'import') { await importDoc(d); }
                if (v == 'del') {
                  if (await confirm(c, 'حذف المستند؟')) {
                    try { await File('${d['path']}').delete(); } catch (_) {}
                    docs.remove(d);
                    save();
                    if (mounted) setState(() {});
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'open', child: Text('فتح')),
                const PopupMenuItem(value: 'share', child: Text('مشاركة')),
                if (canImport(d)) const PopupMenuItem(value: 'import', child: Text('استيراد البنود للمقايسة')),
                const PopupMenuItem(value: 'del', child: Text('حذف')),
              ],
            ),
          ),
        ),
    ]);
  }
}

class PdfViewScreen extends StatefulWidget {
  final String path, name;
  const PdfViewScreen(this.path, this.name, {super.key});
  @override
  State<PdfViewScreen> createState() => _PdfVS();
}

class _PdfVS extends State<PdfViewScreen> {
  final pages = <Uint8List>[];
  bool done = false;
  String? err;
  int cur = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      await for (final pg in Printing.raster(bytes, dpi: 100)) {
        final png = await pg.toPng();
        if (!mounted) return;
        setState(() => pages.add(png));
        if (pages.length >= 40) break;
      }
    } catch (e) {
      err = '$e';
    }
    if (mounted) setState(() => done = true);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Text('${widget.name}${pages.isEmpty ? '' : '  (${cur + 1}/${pages.length}${done ? '' : '+'})'}', overflow: TextOverflow.ellipsis),
          actions: [IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(widget.path)]))],
        ),
        body: err != null && pages.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('تعذّر عرض الملف\n$err', textAlign: TextAlign.center)))
            : pages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => cur = i),
                    itemBuilder: (_, i) => InteractiveViewer(maxScale: 8, child: Center(child: Image.memory(pages[i], fit: BoxFit.contain))),
                  ),
      );
}

class _G {
  final int c;
  final String v;
  _G(this.c, this.v);
}

class _E {
  final String t;
  final List<_G> g = [];
  _E(this.t);
  double n(int c, [double d = 0]) {
    for (final x in g) { if (x.c == c) return double.tryParse(x.v) ?? d; }
    return d;
  }
  String s(int c) {
    for (final x in g) { if (x.c == c) return x.v; }
    return '';
  }
  List<double> all(int c) => [for (final x in g) if (x.c == c) double.tryParse(x.v) ?? 0];
}

class _Dxf {
  final List<_E> ents = [];
  final Map<String, List<_E>> blocks = {};
  final Map<String, List<double>> base = {};
}

_Dxf parseDxf(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  final out = _Dxf();
  var sec = '';
  _E? e;
  _E? hdr;
  String? blk;
  for (var i = 0; i + 1 < lines.length; i += 2) {
    final c = int.tryParse(lines[i].trim());
    if (c == null) { i--; continue; }
    final v = lines[i + 1].trim();
    if (c == 0) {
      if (hdr != null && blk == null) {
        blk = hdr.s(2);
        out.blocks[blk] = [];
        out.base[blk] = [hdr.n(10), hdr.n(20)];
        hdr = null;
      }
      if (v == 'SECTION') { sec = ''; e = null; continue; }
      if (v == 'ENDSEC') { sec = ''; e = null; blk = null; continue; }
      if (v == 'EOF') break;
      if (v == 'ENDBLK') { blk = null; e = null; continue; }
      if (v == 'BLOCK') { hdr = _E('BLOCK'); e = hdr; blk = null; continue; }
      e = _E(v);
      if (sec == 'BLOCKS' && blk != null) {
        out.blocks[blk]!.add(e);
      } else if (sec == 'ENTITIES') {
        out.ents.add(e);
      }
    } else if (c == 2 && sec.isEmpty && e == null) {
      sec = v;
    } else {
      e?.g.add(_G(c, v));
    }
  }
  return out;
}

List<double> _mul(List<double> p, List<double> q) => [
      p[0] * q[0] + p[2] * q[1],
      p[1] * q[0] + p[3] * q[1],
      p[0] * q[2] + p[2] * q[3],
      p[1] * q[2] + p[3] * q[3],
      p[0] * q[4] + p[2] * q[5] + p[4],
      p[1] * q[4] + p[3] * q[5] + p[5],
    ];

List<double> _arc(double cx, double cy, double r, double a1, double a2) {
  if (a2 <= a1) a2 += 360;
  final n = math.max(8, ((a2 - a1) / 10).ceil());
  final o = <double>[];
  for (var i = 0; i <= n; i++) {
    final a = (a1 + (a2 - a1) * i / n) * math.pi / 180;
    o..add(cx + r * math.cos(a))..add(cy + r * math.sin(a));
  }
  return o;
}

void _flat(List<_E> ents, _Dxf d, List<double> m, int depth, List<List<double>> out) {
  void add(List<double> pts) {
    final o = <double>[];
    for (var i = 0; i + 1 < pts.length; i += 2) {
      o..add(m[0] * pts[i] + m[2] * pts[i + 1] + m[4])..add(m[1] * pts[i] + m[3] * pts[i + 1] + m[5]);
    }
    if (o.length >= 4) out.add(o);
  }
  for (var i = 0; i < ents.length; i++) {
    final e = ents[i];
    switch (e.t) {
      case 'LINE':
        add([e.n(10), e.n(20), e.n(11), e.n(21)]);
        break;
      case 'LWPOLYLINE':
        {
          final xs = e.all(10), ys = e.all(20);
          final lp = <double>[];
          for (var k = 0; k < xs.length && k < ys.length; k++) { lp..add(xs[k])..add(ys[k]); }
          if ((e.n(70).toInt() & 1) == 1 && lp.length >= 4) { lp..add(lp[0])..add(lp[1]); }
          add(lp);
        }
        break;
      case 'POLYLINE':
        {
          final pp = <double>[];
          var j = i + 1;
          while (j < ents.length && ents[j].t == 'VERTEX') { pp..add(ents[j].n(10))..add(ents[j].n(20)); j++; }
          if ((e.n(70).toInt() & 1) == 1 && pp.length >= 4) { pp..add(pp[0])..add(pp[1]); }
          add(pp);
          i = j - 1;
        }
        break;
      case 'CIRCLE':
        add(_arc(e.n(10), e.n(20), e.n(40), 0, 360));
        break;
      case 'ARC':
        add(_arc(e.n(10), e.n(20), e.n(40), e.n(50), e.n(51)));
        break;
      case 'INSERT':
        {
          final name = e.s(2);
          final b = d.blocks[name];
          if (b != null && depth <= 4) {
            final sx = e.n(41, 1), sy = e.n(42, 1);
            final rot = e.n(50) * math.pi / 180;
            final bp = d.base[name] ?? [0.0, 0.0];
            final cs = math.cos(rot), sn = math.sin(rot);
            final a = cs * sx, bb = sn * sx, cc = -sn * sy, dd = cs * sy;
            final local = <double>[a, bb, cc, dd, e.n(10) - (a * bp[0] + cc * bp[1]), e.n(20) - (bb * bp[0] + dd * bp[1])];
            _flat(b, d, _mul(m, local), depth + 1, out);
          }
        }
        break;
      default:
        break;
    }
  }
}

class _DxfP extends CustomPainter {
  final Path path = Path();
  late final Rect box;
  _DxfP(List<List<double>> polys) {
    var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
    for (final p in polys) {
      path.moveTo(p[0], p[1]);
      for (var i = 0; i + 1 < p.length; i += 2) {
        final x = p[i], y = p[i + 1];
        if (i > 0) path.lineTo(x, y);
        x0 = math.min(x0, x); y0 = math.min(y0, y); x1 = math.max(x1, x); y1 = math.max(y1, y);
      }
    }
    box = Rect.fromLTRB(x0, y0, x1, y1);
  }
  @override
  void paint(Canvas c, Size s) {
    final w = box.width, h = box.height;
    if (w <= 0 || h <= 0) return;
    final k = math.min(s.width / w, s.height / h) * 0.95;
    c.save();
    c.translate((s.width - w * k) / 2, (s.height + h * k) / 2);
    c.scale(k, -k);
    c.translate(-box.left, -box.top);
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1 / k..color = Colors.black);
    c.restore();
  }
  @override
  bool shouldRepaint(_DxfP o) => false;
}

class DxfViewScreen extends StatefulWidget {
  final String path, name;
  const DxfViewScreen(this.path, this.name, {super.key});
  @override
  State<DxfViewScreen> createState() => _DxfVS();
}

class _DxfVS extends State<DxfViewScreen> {
  _DxfP? painter;
  String? err;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      if (bytes.length > 22 && String.fromCharCodes(bytes.sublist(0, 18)) == 'AutoCAD Binary DXF') throw 'ملف DXF ثنائي (Binary). احفظه ASCII DXF أو PDF.';
      final d = parseDxf(utf8.decode(bytes, allowMalformed: true));
      final out = <List<double>>[];
      _flat(d.ents, d, [1, 0, 0, 1, 0, 0], 0, out);
      if (out.isEmpty) throw 'ما لقيتش عناصر رسم قابلة للعرض.';
      if (mounted) setState(() => painter = _DxfP(out));
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(widget.name, overflow: TextOverflow.ellipsis), actions: [IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(widget.path)]))]),
        body: err != null
            ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('تعذّر عرض الرسم\n$err', textAlign: TextAlign.center)))
            : painter == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (ctx, cons) => InteractiveViewer(
                      maxScale: 60,
                      child: Container(color: Colors.white, width: cons.maxWidth, height: cons.maxHeight, child: CustomPaint(painter: painter)),
                    ),
                  ),
      );
}
