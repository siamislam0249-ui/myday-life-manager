import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'features/auth_screens.dart';
import 'features/home_screen.dart';
import 'features/profile_screen.dart';
import 'features/reports_screen.dart';
import 'features/routine_screen.dart';
import 'features/shell.dart';
import 'features/wallet_screen.dart';

class MyDayApp extends ConsumerStatefulWidget {
  const MyDayApp({super.key});
  @override
  ConsumerState<MyDayApp> createState() => _MyDayAppState();
}

class _MyDayAppState extends ConsumerState<MyDayApp> {
  late final GoRouter _router;
  final _refresh = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    ref.listenManual(sessionProvider, (_, __) => _refresh.value++);
    _router = GoRouter(
      initialLocation: '/home',
      refreshListenable: _refresh,
      redirect: (context, state) {
        final s = ref.read(sessionProvider);
        if (s.loading) return null;
        final authPage = state.matchedLocation == '/login' || state.matchedLocation == '/register';
        if (s.user == null) return authPage ? null : '/login';
        return authPage ? '/home' : null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/routine', builder: (_, __) => const RoutineScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())]),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return MaterialApp.router(
      title: 'MyDay',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
      builder: (context, child) => session.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : child!,
    );
  }
}
