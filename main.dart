import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

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
      body: IndexedStack(index: i, children: [StatTab(p), BoqTab(p), const CalcTab(), HandTab(p), FilesTab(p)]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'الموقف'),
          NavigationDestination(icon: Icon(Icons.straighten), label: 'الحصر'),
          NavigationDestination(icon: Icon(Icons.calculate), label: 'حسابات'),
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

class BoqTab extends StatefulWidget {
  final Proj p;
  const BoqTab(this.p, {super.key});
  @override
  State<BoqTab> createState() => _BoqS();
}

class _BoqS extends State<BoqTab> {
  final d = TextEditingController(), u = TextEditingController(), q = TextEditingController(), s = TextEditingController();
  String kind = 'مقاس';
  List<Map<String, dynamic>> rows = [];
  final sp = SpeechToText();
  bool on = false;
  String get key => 'boq_${widget.p.id}';

  @override
  void initState() {
    super.initState();
    final j = prefs.getString(key);
    if (j != null) rows = (jsonDecode(j) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void save() => prefs.setString(key, jsonEncode(rows));

  void add() {
    final n = double.tryParse(dg(q.text));
    if (d.text.trim().isEmpty || n == null) return;
    setState(() {
      rows.add({'d': d.text.trim(), 'u': u.text, 'q': n, 's': s.text, 'k': kind});
      d.clear(); u.clear(); q.clear(); s.clear();
    });
    save();
  }

  void parse(String t) {
    t = dg(t);
    final m = RegExp(r'\d+(\.\d+)?').firstMatch(t);
    var qq = '', uu = '';
    if (m != null) { qq = m[0]!; t = t.replaceFirst(m[0]!, ' '); }
    for (final x in ['متر طولي', 'م.ط', 'متر', 'عدد', 'مجموعة', 'طقم']) {
      if (t.contains(x)) { uu = x; t = t.replaceFirst(x, ' '); break; }
    }
    setState(() { d.text = t.replaceAll(RegExp(r'\s+'), ' ').trim(); u.text = uu; q.text = qq; });
  }

  Future<void> mic() async {
    if (on) { await sp.stop(); setState(() => on = false); return; }
    if (!await sp.initialize()) { if (mounted) snack(context, 'الميكروفون غير متاح'); return; }
    setState(() => on = true);
    sp.listen(localeId: 'ar_EG', onResult: (r) {
      if (r.finalResult) { parse(r.recognizedWords); setState(() => on = false); }
    });
  }

  Future<void> export() async {
    final b = StringBuffer('\uFEFFالبند,الوحدة,الكمية,النوع,المصدر\n');
    for (final r in rows) {
      b.writeln([r['d'], r['u'], fmt(r['q']), r['k'], r['s']].map((x) => '"${x.toString().replaceAll('"', '""')}"').join(','));
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/hasr_${widget.p.id}.csv');
    await f.writeAsString(b.toString());
    await Share.shareXFiles([XFile(f.path)], text: 'حصر ${widget.p.name}');
  }

  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(14), children: [
        Text('قول البند كامل بالميكروفون، مثال: نقطة إنارة 12 عدد', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: d, decoration: dec('وصف البند'))),
          IconButton(onPressed: mic, icon: Icon(on ? Icons.stop_circle : Icons.mic, color: on ? Colors.red : null)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: u, decoration: dec('الوحدة'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: q, keyboardType: TextInputType.number, decoration: dec('الكمية'))),
        ]),
        const SizedBox(height: 8),
        TextField(controller: s, decoration: dec('المصدر: لوحة / دور / منطقة')),
        Row(children: [
          DropdownButton<String>(value: kind, items: ['مقاس', 'تقديري'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => kind = v!)),
          const Spacer(),
          FilledButton(onPressed: add, child: const Text('إضافة')),
        ]),
        const Divider(),
        Text('جدول الحصر (${rows.length} بند)', style: bold),
        for (var i = 0; i < rows.length; i++)
          ListTile(
            dense: true,
            title: Text(rows[i]['d']),
            subtitle: Text('${rows[i]['u']} • ${fmt(rows[i]['q'])} • ${rows[i]['k']} • ${rows[i]['s']}'),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() => rows.removeAt(i)); save(); }),
          ),
        if (rows.isNotEmpty) OutlinedButton.icon(onPressed: export, icon: const Icon(Icons.ios_share), label: const Text('تصدير Excel (CSV)')),
      ]);
}

class CalcTab extends StatefulWidget {
  const CalcTab({super.key});
  @override
  State<CalcTab> createState() => _CalcS();
}

class _CalcS extends State<CalcTab> {
  final c = List.generate(5, (_) => TextEditingController());
  final labels = ['الجهد (فولت)', 'التيار (أمبير)', 'الطول (متر)', 'المقطع (مم²)', 'معامل القدرة (مثال 0.85)'];
  int ph = 1;
  String out = '';

  void calc() {
    final v = c.map((e) => double.tryParse(dg(e.text)) ?? 0).toList();
    if (v[0] == 0 || v[1] == 0 || v[2] == 0 || v[3] == 0) { setState(() => out = 'أدخل كل القيم'); return; }
    final pf = v[4] == 0 ? 1.0 : v[4];
    final dv = (ph == 3 ? sqrt(3) : 2) * 0.0175 * v[2] * v[1] * pf / v[3];
    setState(() => out = '${dv.toStringAsFixed(2)} فولت (${(dv / v[0] * 100).toStringAsFixed(2)}%)');
  }

  @override
  Widget build(BuildContext ctx) => ListView(padding: const EdgeInsets.all(14), children: [
        const Text('هبوط الجهد في الكابل', style: bold),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: 1, label: Text('فاز واحد')), ButtonSegment(value: 3, label: Text('3 فاز'))],
          selected: {ph},
          onSelectionChanged: (s) => setState(() => ph = s.first),
        ),
        for (var i = 0; i < 5; i++)
          Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: c[i], keyboardType: TextInputType.number, decoration: dec(labels[i]))),
        const SizedBox(height: 10),
        FilledButton(onPressed: calc, child: const Text('احسب')),
        Padding(padding: const EdgeInsets.all(12), child: Text(out, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green))),
        const Text('حساب تقريبي بمقاومة النحاس 0.0175 وبإهمال المفاعلة. راجع الكود المصري وجداول الشركة المصنعة قبل الاعتماد.', style: TextStyle(color: Colors.grey)),
      ]);
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
