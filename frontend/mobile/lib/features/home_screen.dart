import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/providers.dart';
import 'widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(dataProvider);
    final user = ref.watch(sessionProvider).user;
    final now = DateTime.now();
    final m = computeMonth(
        openingBalanceMinor: d.openingMinor, txns: d.txns, year: now.year, month: now.month, tzOffsetMin: user?.tzOffsetMin ?? 360);
    final balance = availableBalanceMinor(d.openingMinor, d.txns);
    final today = d.routines.where((r) => r.appliesOn(now)).toList();

    if (!d.ready) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () => ref.read(dataProvider.notifier).sync(),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${user?.name.split(' ').first ?? ''} 👋', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(DateFormat('EEEE, d MMMM').format(now), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          const SyncChip(),
        ]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kPrimary, Color(0xFF2E90FA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24), boxShadow: softShadow(context)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Available Balance', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, child: Text(fmtMoney(balance), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800))),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: StatCard(label: 'Total Income', value: fmtMoney(m.incomeMinor), color: kIncome, icon: Icons.south_west_rounded)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(label: 'Total Expense', value: fmtMoney(m.expenseMinor), color: kExpense, icon: Icons.north_east_rounded)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kIncome),
            onPressed: () => showTxnSheet(context, ref, type: 'income'), icon: const Icon(Icons.add), label: const FittedBox(child: Text('Add Income', maxLines: 1)))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kExpense),
            onPressed: () => showTxnSheet(context, ref, type: 'expense'), icon: const Icon(Icons.remove), label: const FittedBox(child: Text('Add Expense', maxLines: 1)))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => context.go('/routine'), icon: const Icon(Icons.alarm), label: const FittedBox(child: Text('My Routine', maxLines: 1)))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => context.go('/reports'), icon: const Icon(Icons.bar_chart), label: const FittedBox(child: Text('Monthly Reports', maxLines: 1)))),
        ]),
        const SizedBox(height: 24),
        Text("Today's Tasks", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (today.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No tasks for today.'))),
        for (final r in today)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: CheckboxListTile(
                value: r.doneOn(now),
                onChanged: (v) => ref.read(dataProvider.notifier).setDone(r, now, v ?? false),
                title: Text(r.title, style: TextStyle(decoration: r.doneOn(now) ? TextDecoration.lineThrough : null)),
                subtitle: Text(r.time),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ),
      ]),
    );
  }
}
