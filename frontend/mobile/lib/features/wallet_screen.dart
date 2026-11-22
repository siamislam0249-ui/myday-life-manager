import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/providers.dart';
import 'widgets.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(dataProvider);
    final balance = availableBalanceMinor(d.openingMinor, d.txns);
    final fmtDay = DateFormat('EEE, d MMM yyyy');
    String? lastDay;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Wallet'), actions: const [SyncChip(), SizedBox(width: 12)]),
      floatingActionButton: PopupMenuButton<String>(
        onSelected: (t) => showTxnSheet(context, ref, type: t),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'income', child: Text('Add Income')),
          PopupMenuItem(value: 'expense', child: Text('Add Expense')),
        ],
        child: const FloatingActionButton.extended(onPressed: null, backgroundColor: kPrimary, icon: Icon(Icons.add, color: Colors.white), label: Text('Add', style: TextStyle(color: Colors.white))),
      ),
      body: !d.ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), children: [
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Available balance'),
                  Text(fmtMoney(balance), style: const TextStyle(color: kIncome, fontSize: 20, fontWeight: FontWeight.w800)),
                ]),
              )),
              const SizedBox(height: 12),
              if (d.txns.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No transactions yet. Tap Add to create one.'))),
              for (final t in d.txns) ...[
                if (lastDay != fmtDay.format(t.date.toLocal()))
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(lastDay = fmtDay.format(t.date.toLocal()), style: Theme.of(context).textTheme.labelLarge),
                  ),
                Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: kExpense, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.delete, color: Colors.white)),
                  confirmDismiss: (_) async => await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete transaction?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                      ],
                    )),
                  onDismissed: (_) => ref.read(dataProvider.notifier).deleteTxn(t),
                  child: Card(
                    child: ListTile(
                      onTap: () => showTxnSheet(context, ref, type: t.type, existing: t),
                      leading: CircleAvatar(
                        backgroundColor: (t.type == 'income' ? kIncome : kExpense).withOpacity(0.12),
                        child: Icon(t.type == 'income' ? Icons.south_west_rounded : Icons.north_east_rounded, color: t.type == 'income' ? kIncome : kExpense)),
                      title: Text(t.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([DateFormat('h:mm a').format(t.date.toLocal()), if (t.note.isNotEmpty) t.note].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(fmtMoney(t.signedMinor, sign: true), style: TextStyle(fontWeight: FontWeight.w800, color: t.type == 'income' ? kIncome : kExpense)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ]),
    );
  }
}
