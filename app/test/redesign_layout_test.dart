import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kofe_mama/core/data_providers.dart';
import 'package:kofe_mama/core/theme/app_theme.dart';
import 'package:kofe_mama/features/cart/cart_screen.dart';
import 'package:kofe_mama/features/cart/payment_screen.dart';
import 'package:kofe_mama/features/menu/category_screen.dart';
import 'package:kofe_mama/features/orders/orders_screen.dart';
import 'package:kofe_mama/features/product/product_screen.dart';
import 'package:kofe_mama/features/profile/profile_edit_screen.dart';
import 'package:kofe_mama/features/profile/profile_screen.dart';
import 'package:kofe_mama/features/splash/splash_screen.dart';

import 'fake_kofe_api.dart';

List<Override> get _apiOverrides => [
      apiProvider.overrideWithValue(FakeKofeApi()),
    ];

Widget _app(Widget child) => ProviderScope(
      overrides: _apiOverrides,
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );

Widget _routed(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(path: '/menu', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/product/:id', builder: (_, _) => const SizedBox()),
    ],
  );
  return ProviderScope(
    overrides: _apiOverrides,
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('PDP keeps its primary controls in a 375 by 812 viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _routed(const ProductScreen(productId: 'p_caramel')),
    );
    await tester.pumpAndSettle();

    expect(find.text('S'), findsOneWidget);
    expect(find.textContaining('мл'), findsWidgets);
    expect(find.text('Выберите кофе'), findsOneWidget);
    expect(find.text('Выберите молоко'), findsOneWidget);
    expect(find.textContaining('В заказ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guest profile and empty cart render their branded entry points',
    (tester) async {
      await tester.pumpWidget(_app(const ProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Гость'), findsOneWidget);
      expect(find.text('Войти'), findsOneWidget);

      await tester.pumpWidget(_app(const CartScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Пока пусто'), findsOneWidget);
      expect(find.text('В меню'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('splash shows brand wordmark on cream', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
        GoRoute(
          path: '/city',
          builder: (_, _) => const Scaffold(body: Text('city-ok')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _apiOverrides,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    expect(find.text('КОФЕ МАМА'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('category, orders, payment and profile edit mount', (tester) async {
    await tester.pumpWidget(
      _routed(const CategoryScreen(categoryId: 'lemonades')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Лимонады'), findsWidgets);

    await tester.pumpWidget(_app(const OrdersScreen()));
    await tester.pumpAndSettle();
    expect(find.text('История заказов'), findsOneWidget);

    await tester.pumpWidget(_app(const OrderDetailScreen(orderId: '55743')));
    await tester.pumpAndSettle();
    expect(find.textContaining('55743'), findsWidgets);

    await tester.pumpWidget(_app(const PaymentScreen()));
    expect(find.text('Способ оплаты'), findsOneWidget);
    expect(find.text('Карта 2056'), findsOneWidget);
    expect(find.text('СБП'), findsOneWidget);

    await tester.pumpWidget(_app(const ProfileEditScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Мои данные'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
