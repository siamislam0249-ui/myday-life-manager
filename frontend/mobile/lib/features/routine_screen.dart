import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/providers.dart';
import 'widgets.dart';

const _cats = {
  'wake': ('Wake up', Icons.wb_twilight), 'teeth': ('Brushing teeth', Icons.clean_hands), 'shower': ('Shower', Icons.shower),
  'breakfast': ('Breakfast', Icons.free_breakfast), 'office': ('Office', Icons.work), 'lunch': ('Lunch', Icons.lunch_dining),
  'exercise': ('Exercise', Icons.fitness_center), 'dinner': ('Dinner', Icons.dinner_dining), 'sleep': ('Sleep', Icons.bedtime),
  'custom': ('Custom', Icons.star),
};
const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(dataProvider);
    final c = ref.read(dataProvider.notifier);
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('My Routine'), actions: const [SyncChip(), SizedBox(width: 12)]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        onPressed: () => showRoutineSheet(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New', style: TextStyle(color: Colors.white)),
      ),
      body: !d.ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), children: [
              Text(DateFormat('EEEE, d MMMM').format(now), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final r in d.routines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: r.doneOn(now),
                        onChanged: r.appliesOn(now) ? (v) => c.setDone(r, now, v ?? false) : null,
                      ),
                      title: Text(r.title, style: TextStyle(fontWeight: FontWeight.w600, decoration: r.doneOn(now) ? TextDecoration.lineThrough : null)),
                      subtitle: Text('${r.time} · ${_repeatText(r)}${r.reminderEnabled ? '' : ' · no reminder'}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            showRoutineSheet(context, ref, existing: r);
                          } else if (v == 'snooze') {
                            await c.snooze(r);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Snoozed for ${r.snoozeMinutes} min')));
                            }
                          } else if (v == 'delete') {
                            c.deleteRoutine(r);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'snooze', child: Text('Snooze')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
                ),
              if (d.routines.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No routines yet.'))),
            ]),
    );
  }

  static String _repeatText(Routine r) => switch (r.repeat) {
        'daily' => 'Every day',
        'weekly' => r.daysOfWeek.map((i) => _dayNames[i]).join(', '),
        _ => r.date ?? 'Once',
      };
}

Future<void> showRoutineSheet(BuildContext context, WidgetRef ref, {Routine? existing}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _RoutineForm(existing: existing),
      ),
    );

class _RoutineForm extends ConsumerStatefulWidget {
  const _RoutineForm({this.existing});
  final Routine? existing;
  @override
  ConsumerState<_RoutineForm> createState() => _RoutineFormState();
}

class _RoutineFormState extends ConsumerState<_RoutineForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late String _time, _repeat, _category;
  late Set<int> _days;
  late bool _reminder;
  late int _snooze;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _time = e?.time ?? '07:00';
    _repeat = e?.repeat ?? 'daily';
    _category = e?.category ?? 'custom';
    _days = {...?e?.daysOfWeek};
    _reminder = e?.reminderEnabled ?? true;
    _snooze = e?.snoozeMinutes ?? 10;
    _date = e?.date != null ? DateTime.tryParse(e!.date!) : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    String? err;
    if (_repeat == 'weekly' && _days.isEmpty) err = 'Choose at least one day';
    if (_repeat == 'once' && _date == null) err = 'Choose a date';
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final c = ref.read(dataProvider.notifier);
    final days = _days.toList()..sort();
    final dateStr = _repeat == 'once' ? dateKey(_date!) : null;
    final e = widget.existing;
    if (e == null) {
      await c.saveRoutine(c.newRoutine(title: _title.text.trim(), time: _time, category: _category, repeat: _repeat,
          days: _repeat == 'weekly' ? days : const [], date: dateStr, reminder: _reminder, snooze: _snooze));
    } else {
      await c.saveRoutine(e.copyWith(title: _title.text.trim(), time: _time, category: _category, repeat: _repeat,
          daysOfWeek: _repeat == 'weekly' ? days : const [], date: dateStr, reminderEnabled: _reminder, snoozeMinutes: _snooze));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.existing == null ? 'New routine' : 'Edit routine', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextFormField(controller: _title, maxLength: 100, decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            DropdownButtonFormField<String>(
              value: _category,
              items: [for (final e in _cats.entries) DropdownMenuItem(value: e.key, child: Row(children: [Icon(e.value.$2, size: 18), const SizedBox(width: 8), Text(e.value.$1)]))],
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final p = _time.split(':');
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
                if (t != null) setState(() => _time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
              },
              child: InputDecorator(decoration: const InputDecoration(labelText: 'Time', suffixIcon: Icon(Icons.schedule)), child: Text(_time)),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'once', label: Text('Once')),
              ],
              selected: {_repeat},
              onSelectionChanged: (s) => setState(() => _repeat = s.first),
            ),
            if (_repeat == 'weekly')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(label: Text(_dayNames[i]), selected: _days.contains(i), onSelected: (s) => setState(() => s ? _days.add(i) : _days.remove(i))),
                ]),
              ),
            if (_repeat == 'once')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(_date == null ? 'Choose date' : DateFormat('d MMM yyyy').format(_date!)),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Reminder notification'), value: _reminder, onChanged: (v) => setState(() => _reminder = v)),
            DropdownButtonFormField<int>(
              value: _snooze,
              items: [for (final m in [5, 10, 15, 30, 60]) DropdownMenuItem(value: m, child: Text('$m minutes'))],
              onChanged: (v) => setState(() => _snooze = v!),
              decoration: const InputDecoration(labelText: 'Snooze for'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ]),
        ),
      );
}
