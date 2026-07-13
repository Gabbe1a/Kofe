import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mapkit_lite/yandex_mapkit_lite.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/cart_reset_confirmation.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../data/models/models.dart';
import 'venue_map.dart';

class VenuesScreen extends ConsumerStatefulWidget {
  const VenuesScreen({super.key});

  @override
  ConsumerState<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends ConsumerState<VenuesScreen> {
  YandexMapController? _mapController;

  static const _mockDistances = [
    '1.2 км от вас',
    '3.4 км от вас',
    '5.1 км от вас',
  ];

  Future<void> _selectVenue(BuildContext context, List<Venue> venues, String id) async {
    final venue = venues.firstWhere((v) => v.id == id);
    final currentVenue = ref.read(sessionProvider).venueId;
    if (currentVenue == venue.id) return;
    if (!await confirmCartReset(
      context,
      hasItems: ref.read(cartProvider).items.isNotEmpty,
    )) {
      return;
    }
    ref.read(cartProvider.notifier).clear();
    ref.read(sessionProvider.notifier).setVenue(venue);
  }

  Future<void> _fitAll(List<Venue> venues) async {
    final controller = _mapController;
    if (controller == null || venues.isEmpty) return;
    if (venues.length == 1) {
      final v = venues.first;
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: v.lat, longitude: v.lng),
            zoom: 14,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.45,
        ),
      );
      return;
    }
    var minLat = venues.first.lat;
    var maxLat = venues.first.lat;
    var minLng = venues.first.lng;
    var maxLng = venues.first.lng;
    for (final v in venues) {
      if (v.lat < minLat) minLat = v.lat;
      if (v.lat > maxLat) maxLat = v.lat;
      if (v.lng < minLng) minLng = v.lng;
      if (v.lng > maxLng) maxLng = v.lng;
    }
    final latPad = ((maxLat - minLat) * 0.22).clamp(0.012, 0.08);
    final lngPad = ((maxLng - minLng) * 0.22).clamp(0.012, 0.08);
    await controller.moveCamera(
      CameraUpdate.newGeometry(
        Geometry.fromBoundingBox(
          BoundingBox(
            northEast: Point(
              latitude: maxLat + latPad,
              longitude: maxLng + lngPad,
            ),
            southWest: Point(
              latitude: minLat - latPad,
              longitude: minLng - lngPad,
            ),
          ),
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.45,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final session = ref.watch(sessionProvider);
    final cityId = session.cityId ?? 'rnd';
    final venuesAsync = ref.watch(venuesProvider(cityId));
    final citiesAsync = ref.watch(citiesProvider);

    final cityName = session.city?.name ??
        citiesAsync.maybeWhen(
          data: (cities) {
            for (final c in cities) {
              if (c.id == cityId) return c.name;
            }
            return 'Заведения';
          },
          orElse: () => 'Заведения',
        ) ??
        'Заведения';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/city'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: palette.ink,
                ),
                const SizedBox(width: 4),
                Text(
                  cityName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 22, color: palette.ink),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        minimum: KofeLayout.pageSafeArea,
        child: venuesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Ошибка загрузки точек\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkMuted),
            ),
          ),
          data: (venues) => _buildBody(context, session, venues),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SessionState session,
    List<Venue> venues,
  ) {
    final palette = context.kofePalette;
    Venue? selected;
    for (final v in venues) {
      if (v.id == session.venueId) {
        selected = v;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 4),
        const _FulfillmentSwitcher(),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: VenueMap(
                      venues: venues,
                      selectedId: session.venueId,
                      height: 260,
                      borderRadius: 0,
                      showExpandHint: false,
                      interactive: false,
                      onControllerReady: (c) => _mapController = c,
                      onSelect: (id) => _selectVenue(context, venues, id),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _MapRoundButton(
                        tooltip: 'На весь экран',
                        icon: Icons.fullscreen_rounded,
                        onPressed: () => _openFullscreenMap(
                          context,
                          venues,
                          session.venueId,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MapRoundButton(
                        tooltip: 'Показать все точки',
                        icon: Icons.zoom_out_map_rounded,
                        onPressed: () => _fitAll(venues),
                      ),
                    ],
                  ),
                ),
                if (selected case final Venue selectedVenue)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: _SelectedVenueChip(
                      venue: selectedVenue,
                      onOpen: () => _openFullscreenMap(
                        context,
                        venues,
                        selectedVenue.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Ближайшие кофейни',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: venues.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
            ),
            itemBuilder: (context, i) {
              final v = venues[i];
              final isSelected = session.venueId == v.id;
              final distance = _mockDistances[i % _mockDistances.length];
              final hours = v.hours.isEmpty
                  ? 'Часы уточняйте'
                  : '${v.hours.first.open} – ${v.hours.first.close}';
              return KofeSurface(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                onTap: () => _selectVenue(context, venues, v.id),
                child: Stack(
                  children: [
                    if (isSelected)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: palette.action,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? palette.action
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? palette.action
                                  : palette.inkMuted.withValues(alpha: 0.45),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: palette.onAction,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.fullAddress,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: palette.inkMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hours,
                                    style: TextStyle(
                                      color: palette.inkMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.route_rounded,
                                    size: 14,
                                    color: palette.inkMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    distance,
                                    style: TextStyle(
                                      color: palette.inkMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: palette.surfaceMuted,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Позвонить',
                            icon: Icon(
                              Icons.phone_outlined,
                              color: palette.ink,
                            ),
                            onPressed: () {
                              final tel = v.phone.replaceAll(
                                RegExp(r'[^\d+]'),
                                '',
                              );
                              launchUrl(Uri.parse('tel:$tel'));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
        ),
      ],
    );
  }

  Future<void> _openFullscreenMap(
    BuildContext context,
    List<Venue> venues,
    String? selectedId,
  ) async {
    // rootNavigator: cover bottom nav shell; otherwise map gets tiny constraints.
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVenueMapPage(
          venues: venues,
          initialSelectedId: selectedId,
          onSelect: (id) {
            _selectVenue(context, venues, id);
          },
        ),
      ),
    );
  }
}

class _FulfillmentSwitcher extends StatelessWidget {
  const _FulfillmentSwitcher();

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 18,
                    color: palette.ink,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'С собой',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Opacity(
              opacity: 0.55,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Доставка скоро появится'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delivery_dining_outlined,
                        size: 18,
                        color: palette.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Доставка',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Material(
      color: palette.surface,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: palette.ink, size: 22),
      ),
    );
  }
}

class _SelectedVenueChip extends StatelessWidget {
  const _SelectedVenueChip({required this.venue, required this.onOpen});

  final Venue venue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Material(
      color: palette.surface,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_cafe_rounded,
                  color: palette.ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Выбрано · самовывоз',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.inkMuted,
                      ),
                    ),
                    Text(
                      venue.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.fullscreen_rounded,
                color: palette.inkMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenVenueMapPage extends ConsumerStatefulWidget {
  const _FullscreenVenueMapPage({
    required this.venues,
    required this.initialSelectedId,
    required this.onSelect,
  });

  final List<Venue> venues;
  final String? initialSelectedId;
  final ValueChanged<String> onSelect;

  @override
  ConsumerState<_FullscreenVenueMapPage> createState() =>
      _FullscreenVenueMapPageState();
}

class _FullscreenVenueMapPageState
    extends ConsumerState<_FullscreenVenueMapPage> {
  late String? _selectedId = widget.initialSelectedId;

  Venue? get _selected {
    for (final v in widget.venues) {
      if (v.id == _selectedId) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final selected = _selected;
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VenueMap(
              venues: widget.venues,
              selectedId: _selectedId,
              height: size.height,
              borderRadius: 0,
              showExpandHint: selected == null,
              onSelect: (id) {
                setState(() => _selectedId = id);
                widget.onSelect(id);
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _MapRoundButton(
                      tooltip: 'Закрыть',
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.line),
                      ),
                      child: Text(
                        '${widget.venues.length} точки',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + bottomInset,
                child: Material(
                  color: palette.surface,
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: palette.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.local_cafe_rounded,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selected.shortName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selected.fullAddress,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.inkMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Забрать здесь'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
