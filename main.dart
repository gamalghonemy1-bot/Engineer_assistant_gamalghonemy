import 'dart:convert';
import 'dart:io';
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
  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    return Scaffold(
      appBar: AppBar(title: Text(p.name, overflow: TextOverflow.ellipsis)),
      body: IndexedStack(index: i, children: [StatTab(p), BoqTab(p), FollowTab(p), HandTab(p), FilesTab(p)]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'الموقف'),
          NavigationDestination(icon: Icon(Icons.straighten), label: 'الحصر'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'متابعة'),
          NavigationDestination(icon: Icon(Icons.fact_check), label: 'الاستلام'),
          NavigationDestination(icon: Icon(Icons.folder), label: 'الملفات'),
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
      rows.add({'fl': fl.text.trim(), 'sp': spc.text.trim(), 'd': d.text.trim(), 'u': u.text.trim(), 'q': n, 'k': kind});
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

const hand = {
  'لوحات التوزيع': ['مطابقة اللوحات للمواصفات والرسومات', 'ترميز القواطع وبيان الأحمال على كل لوحة', 'إحكام الربط وتوازن الأحمال على الفازات'],
  'الكابلات والمواسير': ['مطابقة أقطار الكابلات والأسلاك للمقايسة', 'مسارات الكابلات والتراي وتثبيتها', 'عدم تجاوز نسبة ملء المواسير وسلامة الوصلات'],
  'التأريض والاختبارات': ['قياس مقاومة شبكة التأريض', 'اختبار العزل (ميجر) للكابلات', 'اختبار القواطع التفاضلية وتشغيل الدوائر'],
  'الإنارة والقوى': ['مطابقة عدد النقاط والمفاتيح والبرايز للرسومات', 'شدة الإضاءة وتشغيل الطوارئ', 'نقاط التكييف والمراوح'],
  'التيار الخفيف': ['شبكة البيانات والتليفونات واختبارها', 'الكاميرات والإنذار والحريق وتشغيلها', 'وجود الكتالوجات والشهادات والرسومات التنفيذية'],
};

class HandTab extends StatefulWidget {
  final Proj p;
  const HandTab(this.p, {super.key});
  @override
  State<HandTab> createState() => _HandS();
}

class _HandS extends State<HandTab> {
  Set<String> done = {};
  String get key => 'hand_${widget.p.id}';
  @override
  void initState() {
    super.initState();
    done = (prefs.getStringList(key) ?? []).toSet();
  }

  @override
  Widget build(BuildContext c) {
    final total = hand.values.fold<int>(0, (a, b) => a + b.length);
    return ListView(padding: const EdgeInsets.all(14), children: [
      Text('${done.length} / $total', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green)),
      LinearProgressIndicator(value: done.length / total, minHeight: 10, borderRadius: BorderRadius.circular(5)),
      for (final e in hand.entries) ...[
        Padding(padding: const EdgeInsets.only(top: 14), child: Text(e.key, style: bold)),
        for (final x in e.value)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(x),
            value: done.contains(e.key + x),
            onChanged: (v) {
              setState(() { if (v == true) { done.add(e.key + x); } else { done.remove(e.key + x); } });
              prefs.setStringList(key, done.toList());
            },
          ),
      ],
    ]);
  }
}

class FilesTab extends StatefulWidget {
  final Proj p;
  const FilesTab(this.p, {super.key});
  @override
  State<FilesTab> createState() => _FilesS();
}

class _FilesS extends State<FilesTab> {
  List<String> fs = [];
  String get key => 'files_${widget.p.id}';
  @override
  void initState() {
    super.initState();
    fs = prefs.getStringList(key) ?? [];
  }

  Future<void> add() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (r == null) return;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/p_${widget.p.id}')..createSync(recursive: true);
    for (final f in r.files) {
      if (f.path == null) continue;
      final to = '${dir.path}/${f.name}';
      await File(f.path!).copy(to);
      if (!fs.contains(to)) fs.add(to);
    }
    await prefs.setStringList(key, fs);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(14), children: [
        FilledButton.icon(onPressed: add, icon: const Icon(Icons.attach_file), label: const Text('رفع ملفات المشروع (لوحات / PDF / Excel)')),
        const SizedBox(height: 8),
        if (fs.isEmpty) const Text('لا توجد ملفات بعد.', style: TextStyle(color: Colors.grey)),
        for (final f in fs)
          ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(f.split('/').last),
            onTap: () => Share.shareXFiles([XFile(f)]),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                try { await File(f).delete(); } catch (_) {}
                fs.remove(f);
                await prefs.setStringList(key, fs);
                if (mounted) setState(() {});
              },
            ),
          ),
      ]);
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
