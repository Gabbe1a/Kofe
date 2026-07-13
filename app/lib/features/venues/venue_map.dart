import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit_lite/yandex_mapkit_lite.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

/// Venue map with Yandex MapKit on Android/iOS and canvas fallback elsewhere.
class VenueMap extends StatelessWidget {
  const VenueMap({
    super.key,
    required this.venues,
    this.selectedId,
    this.onSelect,
    this.height = 240,
    this.expand = false,
    this.showExpandHint = false,
    this.borderRadius = 18,
    this.interactive = true,
    this.onControllerReady,
  });

  final List<Venue> venues;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  /// Used when [expand] is false.
  final double height;
  /// Fill parent instead of fixed [height] (fullscreen map).
  final bool expand;
  final bool showExpandHint;
  final double borderRadius;
  final bool interactive;
  final ValueChanged<YandexMapController>? onControllerReady;

  static bool get _supportsYandex {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) {
      final empty = const Center(child: Text('Нет точек на карте'));
      return expand
          ? SizedBox.expand(child: empty)
          : SizedBox(height: height, child: empty);
    }

    final map = _supportsYandex
        ? _YandexVenueMap(
            venues: venues,
            selectedId: selectedId,
            onSelect: onSelect,
            interactive: interactive,
            onControllerReady: onControllerReady,
          )
        : _FallbackVenueMap(
            venues: venues,
            selectedId: selectedId,
            onSelect: onSelect,
          );

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          map,
          if (showExpandHint)
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Нажмите на точку, чтобы выбрать',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Explicit size — StackFit.expand alone is not enough for platform views
    // when parent only gives loose constraints (e.g. nested Navigator).
    if (expand) {
      return SizedBox.expand(child: framed);
    }
    return SizedBox(height: height, width: double.infinity, child: framed);
  }
}

class _YandexVenueMap extends StatefulWidget {
  const _YandexVenueMap({
    required this.venues,
    this.selectedId,
    this.onSelect,
    this.interactive = true,
    this.onControllerReady,
  });

  final List<Venue> venues;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final bool interactive;
  final ValueChanged<YandexMapController>? onControllerReady;

  @override
  State<_YandexVenueMap> createState() => _YandexVenueMapState();
}

class _YandexVenueMapState extends State<_YandexVenueMap> {
  YandexMapController? _controller;
  bool _didFit = false;

  @override
  void didUpdateWidget(covariant _YandexVenueMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final venuesChanged = !listEquals(
      oldWidget.venues.map((v) => v.id).toList(),
      widget.venues.map((v) => v.id).toList(),
    );
    if (venuesChanged) {
      _fitCamera();
    } else if (oldWidget.selectedId != widget.selectedId &&
        widget.selectedId != null) {
      _focusSelected();
    }
  }

  List<MapObject> get _mapObjects {
    return [
      for (final venue in widget.venues)
        PlacemarkMapObject(
          mapId: MapObjectId('venue_${venue.id}'),
          point: Point(latitude: venue.lat, longitude: venue.lng),
          opacity: 1,
          consumeTapEvents: true,
          zIndex: venue.id == widget.selectedId ? 3 : 1,
          onTap: (_, _) => widget.onSelect?.call(venue.id),
          // No PlacemarkText — street labels were huge and cluttered the map.
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                venue.id == widget.selectedId
                    ? 'assets/images/map/pin_selected.png'
                    : 'assets/images/map/pin.png',
              ),
              // Tip of the pin sits on the coordinate.
              anchor: const Offset(0.5, 0.92),
              scale: venue.id == widget.selectedId ? 1.05 : 0.92,
            ),
          ),
        ),
    ];
  }

  Future<void> _focusSelected() async {
    final controller = _controller;
    final id = widget.selectedId;
    if (controller == null || id == null) return;
    Venue? venue;
    for (final v in widget.venues) {
      if (v.id == id) {
        venue = v;
        break;
      }
    }
    if (venue == null) return;
    await controller.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: venue.lat, longitude: venue.lng),
          zoom: 14.5,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.45,
      ),
    );
  }

  Future<void> _fitCamera() async {
    final controller = _controller;
    if (controller == null || widget.venues.isEmpty) return;

    if (widget.venues.length == 1) {
      final v = widget.venues.first;
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: v.lat, longitude: v.lng),
            zoom: 14,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.6,
        ),
      );
      return;
    }

    var minLat = widget.venues.first.lat;
    var maxLat = widget.venues.first.lat;
    var minLng = widget.venues.first.lng;
    var maxLng = widget.venues.first.lng;
    for (final v in widget.venues) {
      minLat = math.min(minLat, v.lat);
      maxLat = math.max(maxLat, v.lat);
      minLng = math.min(minLng, v.lng);
      maxLng = math.max(maxLng, v.lng);
    }

    final latPad = math.max((maxLat - minLat) * 0.22, 0.012);
    final lngPad = math.max((maxLng - minLng) * 0.22, 0.012);

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
        duration: 0.6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YandexMap(
      mapObjects: _mapObjects,
      mapType: MapType.map,
      mode2DEnabled: true,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      fastTapEnabled: true,
      nightModeEnabled: Theme.of(context).brightness == Brightness.dark,
      logoAlignment: const MapAlignment(
        horizontal: HorizontalAlignment.left,
        vertical: VerticalAlignment.top,
      ),
      onMapCreated: (controller) async {
        _controller = controller;
        widget.onControllerReady?.call(controller);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (!_didFit) {
          _didFit = true;
          await _fitCamera();
        }
      },
    );
  }
}

class _FallbackVenueMap extends StatefulWidget {
  const _FallbackVenueMap({
    required this.venues,
    this.selectedId,
    this.onSelect,
  });

  final List<Venue> venues;
  final String? selectedId;
  final ValueChanged<String>? onSelect;

  @override
  State<_FallbackVenueMap> createState() => _FallbackVenueMapState();
}

class _FallbackVenueMapState extends State<_FallbackVenueMap> {
  double _scale = 1;
  double _baseScale = 1;
  Offset _pan = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (_) => _baseScale = _scale,
      onScaleUpdate: (d) {
        setState(() {
          _scale = (_baseScale * d.scale).clamp(0.85, 2.4);
          _pan += d.focalPointDelta;
        });
      },
      onDoubleTap: () => setState(() {
        _scale = 1;
        _baseScale = 1;
        _pan = Offset.zero;
      }),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5EC),
              Color(0xFFD5E4D8),
              Color(0xFFC8D9CC),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _MapGridPainter(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final positions = _project(
                widget.venues,
                constraints.biggest,
              );
              return Transform.translate(
                offset: _pan,
                child: Transform.scale(
                  scale: _scale,
                  child: Stack(
                    children: [
                      for (final entry in positions.entries)
                        _Pin(
                          center: entry.value,
                          venue: entry.key,
                          selected: entry.key.id == widget.selectedId,
                          onTap: () => widget.onSelect?.call(entry.key.id),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Map<Venue, Offset> _project(List<Venue> venues, Size size) {
    final lats = venues.map((v) => v.lat);
    final lngs = venues.map((v) => v.lng);
    var minLat = lats.reduce(math.min);
    var maxLat = lats.reduce(math.max);
    var minLng = lngs.reduce(math.min);
    var maxLng = lngs.reduce(math.max);

    if ((maxLat - minLat).abs() < 0.01) {
      minLat -= 0.02;
      maxLat += 0.02;
    }
    if ((maxLng - minLng).abs() < 0.01) {
      minLng -= 0.02;
      maxLng += 0.02;
    }

    const pad = 48.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    return {
      for (final v in venues)
        v: Offset(
          pad + ((v.lng - minLng) / (maxLng - minLng)) * w,
          pad + (1 - (v.lat - minLat) / (maxLat - minLat)) * h,
        ),
    };
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.center,
    required this.venue,
    required this.selected,
    required this.onTap,
  });

  final Offset center;
  final Venue venue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 44.0 : 34.0;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.ink : AppColors.primary,
            border: Border.all(color: AppColors.surface, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.local_cafe_rounded,
            size: selected ? 20 : 16,
            color: AppColors.surface,
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
