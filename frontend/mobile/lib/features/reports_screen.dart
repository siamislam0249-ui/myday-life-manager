import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/providers.dart';
import 'widgets.dart';

const _palette = [kPrimary, kExpense, kIncome, Color(0xFFF79009), Color(0xFF7A5AF8), Color(0xFF06AED4), Color(0xFFEE46BC), Color(0xFF667085)];

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<ReportsScreen> {
  bool _yearly = false;
  int _year = DateTime.now().year, _month = DateTime.now().month;
  bool _exporting = false;

  void _shift(int delta) => setState(() {
        if (_yearly) {
          _year += delta;
        } else {
          final d = DateTime(_year, _month + delta);
          _year = d.year;
          _month = d.month;
        }
      });

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final res = await ref.read(dioProvider).get<List<int>>('/reports/export',
          queryParameters: {'period': _yearly ? 'yearly' : 'monthly', 'year': _year, if (!_yearly) 'month': _month, 'format': format},
          options: Options(responseType: ResponseType.bytes));
      final name = 'myday-${_yearly ? 'yearly' : 'monthly'}-$_year${_yearly ? '' : '-${_month.toString().padLeft(2, '0')}'}';
      final mime = switch (format) { 'xlsx' => MimeType.microsoftExcel, 'pdf' => MimeType.pdf, _ => MimeType.csv };
      await FileSaver.instance.saveFile(name: name, bytes: Uint8List.fromList(res.data!), ext: format, mimeType: mime);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved $name.$format')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export needs an internet connection: ${apiError(e)}')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(dataProvider);
    final tz = ref.watch(sessionProvider).user?.tzOffsetMin ?? 360;
    if (!d.ready) return const Center(child: CircularProgressIndicator());

    final months = [for (var m = 1; m <= 12; m++) computeMonth(openingBalanceMinor: d.openingMinor, txns: d.txns, year: _year, month: m, tzOffsetMin: tz)];
    final cur = _yearly ? null : months[_month - 1];
    final opening = _yearly ? months.first.openingMinor : cur!.openingMinor;
    final income = _yearly ? months.fold<int>(0, (a, m) => a + m.incomeMinor) : cur!.incomeMinor;
    final expense = _yearly ? months.fold<int>(0, (a, m) => a + m.expenseMinor) : cur!.expenseMinor;
    final closing = _yearly ? months.last.closingMinor : cur!.closingMinor;
    final cats = <String, int>{};
    for (final m in (_yearly ? months : [cur!])) {
      m.categories.forEach((k, v) => cats[k] = (cats[k] ?? 0) + v);
    }
    final catList = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final txns = [for (final m in (_yearly ? months : [cur!])) ...m.transactions];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Monthly')), ButtonSegment(value: true, label: Text('Yearly'))],
          selected: {_yearly},
          onSelectionChanged: (s) => setState(() => _yearly = s.first),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
          Text(_yearly ? '$_year' : DateFormat('MMMM yyyy').format(DateTime(_year, _month)), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
        ]),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.7,
          children: [
            StatCard(label: 'Opening Balance', value: fmtMoney(opening), color: kPrimary, icon: Icons.flag_outlined),
            StatCard(label: 'Total Income', value: fmtMoney(income), color: kIncome, icon: Icons.south_west_rounded),
            StatCard(label: 'Total Expense', value: fmtMoney(expense), color: kExpense, icon: Icons.north_east_rounded),
            StatCard(label: 'Closing Balance', value: fmtMoney(closing), color: kIncome, icon: Icons.account_balance_wallet_outlined),
          ],
        ),
        const SizedBox(height: 20),
        Text('Expenses by category', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (catList.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No expenses in this period.')))
        else
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              SizedBox(height: 200, child: PieChart(PieChartData(
                sectionsSpace: 2, centerSpaceRadius: 44,
                sections: [for (var i = 0; i < catList.length; i++)
                  PieChartSectionData(value: catList[i].value.toDouble(), color: _palette[i % _palette.length], radius: 40, showTitle: false)],
              ))),
              const SizedBox(height: 12),
              for (var i = 0; i < catList.length; i++)
                ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 6, backgroundColor: _palette[i % _palette.length]),
                  title: Text(catList[i].key),
                  trailing: Text('${fmtMoney(catList[i].value)}  (${(catList[i].value * 100 / expense).toStringAsFixed(1)}%)'),
                ),
            ]),
          )),
        if (_yearly) ...[
          const SizedBox(height: 20),
          Text('Income vs expense by month', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
            child: SizedBox(height: 220, child: BarChart(BarChartData(
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Text(DateFormat('MMM').format(DateTime(2000, v.toInt() + 1)).substring(0, 1), style: const TextStyle(fontSize: 11)),
                )),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: [for (var i = 0; i < 12; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: months[i].incomeMinor / 100, color: kIncome, width: 6),
                  BarChartRodData(toY: months[i].expenseMinor / 100, color: kExpense, width: 6),
                ])],
            ))),
          )),
        ],
        const SizedBox(height: 20),
        Text('Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Category')), DataColumn(label: Text('Note')), DataColumn(label: Text('Amount'), numeric: true)],
            rows: [for (final t in txns)
              DataRow(cells: [
                DataCell(Text(DateFormat('d MMM, h:mm a').format(t.date.toLocal()))),
                DataCell(Text(t.category)),
                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: Text(t.note, overflow: TextOverflow.ellipsis))),
                DataCell(Text(fmtMoney(t.signedMinor, sign: true), style: TextStyle(color: t.type == 'income' ? kIncome : kExpense, fontWeight: FontWeight.w700))),
              ])],
          ),
        )),
        const SizedBox(height: 20),
        Text('Download', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          for (final f in const [('xlsx', Icons.table_chart, 'Excel'), ('pdf', Icons.picture_as_pdf, 'PDF'), ('csv', Icons.description, 'CSV')])
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _exporting ? null : () => _export(f.$1), icon: Icon(f.$2, size: 18), label: Text(f.$3)),
            )),
        ]),
        const SizedBox(height: 6),
        Text('Downloads are generated by the server, so they need an internet connection. Make sure your offline changes are synced first.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
