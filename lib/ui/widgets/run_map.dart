import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';

/// A map that belongs to the palette.
///
/// Standard OSM tiles are desaturated to luminance and then re-tinted with the
/// screen's chroma, so the map reads as part of the red/blue field instead of a
/// bright rectangle pasted onto it. Attribution is kept — it's a licence
/// requirement, and it's styled down rather than removed.
class RunMap extends StatefulWidget {
  const RunMap({
    required this.route,
    required this.accent,
    this.follow = true,
    this.onFollowChanged,
    this.interactive = false,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<GeoPoint> route;
  final Color accent;
  final bool follow;
  final ValueChanged<bool>? onFollowChanged;

  /// Live map: gestures off, camera locked to the runner.
  final bool interactive;
  final EdgeInsets padding;

  @override
  State<RunMap> createState() => _RunMapState();
}

class _RunMapState extends State<RunMap> {
  final MapController _c = MapController();
  bool _centered = false;

  @override
  void didUpdateWidget(RunMap old) {
    super.didUpdateWidget(old);
    if (!widget.follow) _centered = false;
  }

  void _syncCamera() {
    if (!widget.follow || widget.route.isEmpty || !_c.mapEventStream.isBroadcast) {
      // fall through; the guard below handles un-attached controllers
    }
    final pts = widget.route;
    if (!widget.follow || pts.isEmpty) return;
    try {
      if (!_centered && pts.length >= 3) {
        _c.fitCamera(
          CameraFit.coordinates(
            coordinates: pts.map((p) => LatLng(p.lat, p.lon)).toList(),
            padding: widget.padding,
            maxZoom: 16.5,
          ),
        );
        _centered = true;
      } else {
        final last = pts.last;
        _c.move(LatLng(last.lat, last.lon), _c.camera.zoom);
      }
    } catch (_) {
      // Controller not attached yet — the next frame will catch up.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.route.map((p) => LatLng(p.lat, p.lon)).toList();
    final hasTrack = pts.length >= 2;

    Widget map = FlutterMap(
      mapController: _c,
      options: MapOptions(
        initialCenter: pts.isNotEmpty ? pts.last : const LatLng(51.5074, -0.1278),
        initialZoom: 15,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onMapReady: () => setState(_syncCamera),
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && widget.onFollowChanged != null) widget.onFollowChanged!(false);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zeroTo5k.mfm',
          maxZoom: 19,
        ),
        if (hasTrack)
          PolylineLayer(
            polylines: [
              // Casing beneath the stroke so the route stays legible over any
              // tile colour, plus a soft bloom for the "just travelled" look.
              Polyline(
                points: pts,
                strokeWidth: 11,
                color: Colors.black.withValues(alpha: 0.22),
              ),
              Polyline(
                points: pts,
                strokeWidth: 6.5,
                color: widget.accent,
              ),
              Polyline(
                points: pts,
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        if (pts.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: pts.last,
                width: 26,
                height: 26,
                child: const _PositionDot(),
              ),
            ],
          ),
      ],
    );

    // Desaturate → re-tint.
    map = ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: map,
    );
    map = Stack(
      fit: StackFit.expand,
      children: [
        map,
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.55),
              backgroundBlendMode: BlendMode.color,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppPalette.ink.withValues(alpha: 0.22),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.34),
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
        ),
        // Legibility floor: the attribution chip.
        Positioned(
          right: 8,
          bottom: 6,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '© OpenStreetMap',
                style: TextStyle(
                  fontFamily: 'Barlow',
                  fontSize: 8.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (pts.length < 2) {
      map = Stack(
        fit: StackFit.expand,
        children: [
          map,
          IgnorePointer(
            child: Center(
              child: _WaitingForGps(accent: widget.accent),
            ),
          ),
        ],
      );
    }

    // Keep the camera locked to the runner as fixes arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCamera());

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.interactive ? 28 : 0),
      child: map,
    );
  }
}

class _PositionDot extends StatelessWidget {
  const _PositionDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 3),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.5),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _WaitingForGps extends StatefulWidget {
  const _WaitingForGps({required this.accent});

  final Color accent;

  @override
  State<_WaitingForGps> createState() => _WaitingForGpsState();
}

class _WaitingForGpsState extends State<_WaitingForGps> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: M3EShape.full,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(widget.accent),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Finding your position…',
              style: TextStyle(
                fontFamily: 'Barlow',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
