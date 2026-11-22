import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.account_balance_wallet_rounded, 'Wallet'),
    (Icons.alarm_rounded, 'Routine'),
    (Icons.bar_chart_rounded, 'Reports'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 840; // responsive: rail on tablets / web
    void go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
    final body = Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: shell),
    );
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            destinations: [for (final i in _items) NavigationRailDestination(icon: Icon(i.$1), label: Text(i.$2))],
          ),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: go,
        destinations: [for (final i in _items) NavigationDestination(icon: Icon(i.$1), label: i.$2)],
      ),
    );
  }
}
