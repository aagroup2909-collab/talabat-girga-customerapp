import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/account/account_screen.dart';
import 'features/account/change_password_screen.dart';
import 'features/addresses/address_form_screen.dart';
import 'features/addresses/addresses_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/stores_screen.dart';
import 'features/orders/order_tracking_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/store/store_screen.dart';
import 'models/models.dart';
import 'state/auth.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // الراوتر يعيد تقييم redirect عند تغيّر حالة الدخول.
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(authProvider).user;
      final path = state.matchedLocation;
      // أي 401 يمسح التوكن → user = null → نرجع لشاشة الدخول.
      if (user == null) return path == '/login' || path == '/register' ? null : '/login';
      if (user.name.trim().isEmpty) return path == '/complete-profile' ? null : '/complete-profile';
      if (path == '/login' || path == '/register' || path == '/complete-profile') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, s) => RegisterScreen(args: s.extra is RegisterArgs ? s.extra as RegisterArgs : const RegisterArgs()),
      ),
      GoRoute(path: '/complete-profile', builder: (_, _) => const CompleteProfileScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/orders',
              builder: (_, _) => const OrdersScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) => OrderTrackingScreen(orderId: int.parse(s.pathParameters['id']!)),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (_, _) => const AccountScreen())]),
        ],
      ),
      GoRoute(path: '/search', builder: (_, _) => const StoresScreen(searchMode: true)),
      GoRoute(
        path: '/stores',
        builder: (_, s) => StoresScreen(
          storeTypeId: int.tryParse(s.uri.queryParameters['type'] ?? ''),
          title: s.uri.queryParameters['title'],
        ),
      ),
      GoRoute(path: '/store/:id', builder: (_, s) => StoreScreen(storeId: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/change-password', builder: (_, _) => const ChangePasswordScreen()),
      GoRoute(path: '/addresses', builder: (_, _) => const AddressesScreen()),
      GoRoute(path: '/addresses/new', builder: (_, _) => const AddressFormScreen()),
      GoRoute(path: '/addresses/edit', builder: (_, s) => AddressFormScreen(address: s.extra as Address?)),
    ],
  );
});

class _MainShell extends StatelessWidget {
  const _MainShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'طلباتي'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'طلبات جرجا',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      // عربي أولًا: كل الواجهة من اليمين لليسار.
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
