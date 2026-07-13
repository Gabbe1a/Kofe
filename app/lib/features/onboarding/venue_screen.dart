import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cart_reset_confirmation.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../data/models/models.dart';
import '../venues/venue_map.dart';

class VenueScreen extends ConsumerStatefulWidget {
  const VenueScreen({super.key});
  @override
  ConsumerState<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends ConsumerState<VenueScreen> {
  String? _selected;
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.go('/city')), title: Text('Точка · ${session.city?.name ?? ''}')),
      body: ref.watch(venuesProvider(session.cityId ?? 'rnd')).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Не удалось загрузить точки\n$error', textAlign: TextAlign.center)),
        data: (venues) {
          _selected ??= venues.isNotEmpty ? venues.first.id : null;
          return SafeArea(
            child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 12), child: ClipRRect(borderRadius: BorderRadius.circular(18), child: VenueMap(venues: venues, selectedId: _selected, height: 190, onSelect: (id) => setState(() => _selected = id)))),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: venues.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _VenueTile(venue: venues[index], selected: _selected == venues[index].id, onTap: () => setState(() => _selected = venues[index].id)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selected == null ? null : () async {
                      final venue = venues.firstWhere((item) => item.id == _selected);
                      final current = ref.read(sessionProvider).venueId;
                      if (current != venue.id && !await confirmCartReset(context, hasItems: ref.read(cartProvider).items.isNotEmpty)) return;
                      if (current != venue.id) ref.read(cartProvider.notifier).clear();
                      ref.read(sessionProvider.notifier).setVenue(venue);
                      if (context.mounted) context.go('/promo');
                    },
                    child: const Text('Выбрать точку'),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.venue, required this.selected, required this.onTap});
  final Venue venue;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return KofeSurface(
      color: selected ? palette.surfaceMuted : null,
      borderColor: selected ? palette.ink : palette.line,
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KofeRoundIcon(icon: selected ? Icons.check_rounded : Icons.storefront_outlined),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(venue.shortName, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(venue.fullAddress, style: TextStyle(color: palette.inkMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(venue.hours.map((item) => '${item.daysLabel}: ${item.open}–${item.close}').join('\n'), style: TextStyle(color: palette.inkMuted, fontSize: 12)),
        ])),
      ]),
    );
  }
}
