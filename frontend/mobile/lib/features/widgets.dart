import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/data_controller.dart';
import '../data/models.dart';
import '../data/providers.dart';

const incomeCategories = ['Salary', 'Business', 'Gift', 'Investment', 'Other'];
const expenseCategories = ['Food', 'Transport', 'Rent', 'Bills', 'Shopping', 'Health', 'Education', 'Entertainment', 'Other'];

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.color, required this.icon});
  final String label, value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(20), boxShadow: softShadow(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 18, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color))),
        ]),
      );
}

DateTime userNow(int tzOffsetMin) => DateTime.now();

/// Add / edit a transaction (works offline; syncs automatically).
Future<void> showTxnSheet(BuildContext context, WidgetRef ref, {required String type, Txn? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _TxnForm(type: existing?.type ?? type, existing: existing),
    ),
  );
}

class _TxnForm extends ConsumerStatefulWidget {
  const _TxnForm({required this.type, this.existing});
  final String type;
  final Txn? existing;
  @override
  ConsumerState<_TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends ConsumerState<_TxnForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount, _note;
  late String _category;
  late DateTime _date;

  bool get _income => widget.type == 'income';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(text: e == null ? '' : (e.amountMinor / 100).toStringAsFixed(2));
    _note = TextEditingController(text: e?.note ?? '');
    _category = e?.category ?? (_income ? incomeCategories : expenseCategories).first;
    _date = e?.date.toLocal() ?? DateTime.now();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (t == null) return;
    setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final c = ref.read(dataProvider.notifier);
    final minor = toMinor(double.parse(_amount.text.trim()));
    final e = widget.existing;
    if (e == null) {
      await c.addTxn(type: widget.type, amountMinor: minor, category: _category, note: _note.text.trim(), date: _date);
    } else {
      await c.updateTxn(e.copyWith(amountMinor: minor, category: _category, note: _note.text.trim(), date: _date));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = _income ? incomeCategories : expenseCategories;
    final color = _income ? kIncome : kExpense;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.existing == null ? (_income ? 'Add Income' : 'Add Expense') : 'Edit ${_income ? 'Income' : 'Expense'}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amount, autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '৳ '),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter an amount greater than 0';
              if (n > 1e9) return 'Amount too large';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: cats.contains(_category) ? _category : cats.first,
            items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _category = v!),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date & time', suffixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(DateFormat('d MMM yyyy, h:mm a').format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _note, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Note / description')),
          const SizedBox(height: 8),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: color), onPressed: _save, child: const Text('Save')),
        ]),
      ),
    );
  }
}

/// Small sync status chip used on Home and Profile.
class SyncChip extends ConsumerWidget {
  const SyncChip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppData d = ref.watch(dataProvider);
    final dirty = d.txns.any((t) => t.dirty) || d.routines.any((r) => r.dirty);
    final (icon, text, color) = d.syncing
        ? (Icons.sync, 'Syncing…', kPrimary)
        : d.syncError != null
            ? (Icons.error_outline, 'Sync error', kExpense)
            : dirty
                ? (Icons.cloud_off_outlined, 'Offline changes', Colors.orange)
                : (Icons.cloud_done_outlined, 'Synced', kIncome);
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(text, style: TextStyle(color: color, fontSize: 12)),
      side: BorderSide.none, visualDensity: VisualDensity.compact,
    );
  }
}
