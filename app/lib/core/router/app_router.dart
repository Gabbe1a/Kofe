import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/cart/payment_screen.dart';
import '../../features/menu/category_screen.dart';
import '../../features/menu/menu_screen.dart';
import '../../features/onboarding/city_screen.dart';
import '../../features/onboarding/venue_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/product/product_screen.dart';
import '../../features/profile/profile_edit_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/promo/promo_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/venues/venues_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      if (location == '/splash' || location == '/city') return null;
      if (session.cityId == null) return '/city';
      if (session.venueId == null) return location == '/venue' ? null : '/venue';
      if (!session.promoSeen) {
        if (location == '/promo') return null;
        if (location == '/venue') return '/promo';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/city', builder: (_, _) => const CityScreen()),
      GoRoute(path: '/venue', builder: (_, _) => const VenueScreen()),
      GoRoute(path: '/promo', builder: (_, _) => const PromoScreen()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthPhoneScreen()),
      GoRoute(path: '/auth/code', builder: (_, _) => const AuthCodeScreen()),
      GoRoute(path: '/product/:id', builder: (_, state) => ProductScreen(productId: state.pathParameters['id']!)),
      GoRoute(
        path: '/cart/item/:index',
        builder: (_, state) => ProductScreen.editCartItem(
          editingCartIndex: int.tryParse(state.pathParameters['index'] ?? '') ?? -1,
        ),
      ),
      GoRoute(path: '/menu/category/:id', builder: (_, state) => CategoryScreen(categoryId: state.pathParameters['id']!)),
      GoRoute(path: '/profile/edit', builder: (_, _) => const ProfileEditScreen()),
      GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: '/active-order/:id',
        builder: (_, state) => OrderDetailScreen(
          orderId: state.pathParameters['id']!,
          activeMode: true,
        ),
      ),
      GoRoute(path: '/orders/:id', builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/payment', builder: (_, _) => const PaymentScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/menu', builder: (_, _) => const MenuScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/cart', builder: (_, _) => const CartScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/venues', builder: (_, _) => const VenuesScreen())]),
        ],
      ),
    ],
  );
});
