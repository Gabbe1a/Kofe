import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/order_status_sync.dart';
import 'data/api/kofe_api.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  final store = await LocalStore.open();
  bindLocalStore(store);

  // Refresh profile from API if already logged in (bonuses/orders stay DB-backed).
  if (store.session.isAuthed) {
    try {
      final user = await KofeApi(baseUrl: AppConfig.apiBaseUrl).fetchMe();
      store.session = store.session.copyWith(isAuthed: true, user: user);
      await store.saveSession(store.session);
    } catch (_) {
      // Keep cached user if offline.
    }
  }

  runApp(const ProviderScope(child: KofeMamaApp()));
}

class KofeMamaApp extends ConsumerWidget {
  const KofeMamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final preference = ref.watch(sessionProvider.select((s) => s.themePreference));
    return OrderStatusSync(
      child: MaterialApp.router(
        title: 'Кофе',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: switch (preference) {
          ThemePreference.light => ThemeMode.light,
          ThemePreference.dark => ThemeMode.dark,
          ThemePreference.system => ThemeMode.system,
        },
        routerConfig: router,
      ),
    );
  }
}
