import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cart_reset_confirmation.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../data/models/models.dart';

class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});
  @override
  ConsumerState<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends ConsumerState<CityScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите город'), leading: context.canPop() ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()) : null),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(children: [
            TextField(onChanged: (value) => setState(() => _query = value.trim().toLowerCase()), decoration: InputDecoration(hintText: 'Поиск города', prefixIcon: Icon(Icons.search_rounded, color: palette.inkMuted))),
            const SizedBox(height: 16),
            Expanded(
              child: ref.watch(citiesProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Не удалось загрузить города\n$error', textAlign: TextAlign.center)),
                data: (cities) {
                  final visible = cities.where((city) => city.name.toLowerCase().contains(_query)).toList();
                  return ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _CityTile(city: visible[index]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CityTile extends ConsumerWidget {
  const _CityTile({required this.city});
  final City city;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sessionProvider).cityId == city.id;
    final palette = context.kofePalette;
    return KofeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: current ? palette.surfaceMuted : null,
      borderColor: current ? palette.ink : palette.line,
      onTap: () async {
        final session = ref.read(sessionProvider);
        if (session.cityId != city.id && !await confirmCartReset(context, hasItems: ref.read(cartProvider).items.isNotEmpty)) return;
        if (session.cityId != city.id) ref.read(cartProvider.notifier).clear();
        ref.read(sessionProvider.notifier).setCity(city);
        if (context.mounted) context.go('/venue');
      },
      child: Row(children: [
        Expanded(child: Text(city.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        Icon(current ? Icons.check_rounded : Icons.arrow_forward_ios_rounded, color: palette.ink, size: current ? 20 : 14),
      ]),
    );
  }
}
