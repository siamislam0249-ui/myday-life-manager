import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/providers.dart';
import 'widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _editOpening(BuildContext context, WidgetRef ref, int current) async {
    final ctrl = TextEditingController(text: (current / 100).toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Opening balance'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('The balance you had before your first transaction. It is counted once and carried forward automatically each month.'),
          const SizedBox(height: 12),
          TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(prefixText: '৳ ')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    final n = double.tryParse(ctrl.text.trim());
    if (ok == true && n != null && n.abs() <= 1e9) await ref.read(dataProvider.notifier).setOpening(toMinor(n));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final d = ref.watch(dataProvider);
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Card(child: ListTile(
          leading: const CircleAvatar(backgroundColor: kPrimary, child: Icon(Icons.person, color: Colors.white)),
          title: Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(user?.email ?? ''),
        )),
        const SizedBox(height: 12),
        Card(child: ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Opening balance'),
          subtitle: Text(fmtMoney(d.openingMinor)),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editOpening(context, ref, d.openingMinor),
        )),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).state = s.first,
            ),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sync now'),
          subtitle: Text(d.syncError ?? (d.lastSync == null ? 'Not synced yet' : 'Last synced ${DateFormat('d MMM, h:mm a').format(d.lastSync!)}')),
          trailing: const SyncChip(),
          onTap: () => ref.read(dataProvider.notifier).sync(),
        )),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: kExpense, minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          onPressed: () async {
            final dirty = d.txns.any((t) => t.dirty) || d.routines.any((r) => r.dirty);
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Logout?'),
                content: Text(dirty ? 'You have changes not synced yet. They stay on this device and sync the next time you log in with internet.' : 'You will need to log in again.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Logout')),
                ],
              ),
            );
            if (ok == true) await ref.read(sessionProvider.notifier).logout();
          },
        ),
      ]),
    );
  }
}
