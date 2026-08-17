import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../services/route_service.dart';

/// Route replay for the signed-in employee on a chosen day.
/// Loads `GET /api/tracking/route?employee=<code>&date=YYYY-MM-DD` and shows
/// the GPS trail on a map with check-in/out punches and detected stops.
class RouteHistoryScreen extends StatefulWidget {
  const RouteHistoryScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> {
  final _service = RouteService();
  late DateTime _date;
  late Future<RouteHistory> _future;

  static const _tileUrl = 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const _routeColor = Color(0xFF4C8DFF);
  static const _startColor = Color(0xFF3BB273);
  static const _endColor = Color(0xFFE5484D);
  static const _stopColor = Color(0xFFE0A800);

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _future = _load();
  }

  Future<RouteHistory> _load() {
    final d = _date;
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${d.year}-${two(d.month)}-${two(d.day)}';
    final id = widget.user.code.isNotEmpty
        ? widget.user.code
        : widget.user.id.toString();
    return _service.history(employeeId: id, date: date);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Pick a date',
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _reload();
    }
  }

  static String _fmt(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _dateLabel(_date),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Change date'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<RouteHistory>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                final err = snap.error;
                return _StateMessage(
                  icon: Icons.route,
                  title: 'Could not load the route',
                  subtitle: err is ApiException ? err.message : '$err',
                  onRetry: _reload,
                );
              }
              final route = snap.data!;
              if (route.points.isEmpty) {
                return const _StateMessage(
                  icon: Icons.alt_route,
                  title: 'No route for this day',
                  subtitle:
                      'There were no recorded positions for you on the selected date.',
                );
              }
              return _RouteView(route: route);
            },
          ),
        ),
      ],
    );
  }

  static String _dateLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _RouteView extends StatelessWidget {
  const _RouteView({required this.route});
  final RouteHistory route;

  @override
  Widget build(BuildContext context) {
    final points = route.points;
    LatLng center() {
      final sum = points
          .fold<({double lat, double lng})>(
              (lat: 0, lng: 0),
              (acc, p) =>
                  (lat: acc.lat + p.lat, lng: acc.lng + p.lng));
      return LatLng(sum.lat / points.length, sum.lng / points.length);
    }

    final trail = points.map((p) => LatLng(p.lat, p.lng)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Container(
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF3A3B40)),
          ),
          child: FlutterMap(
            options: MapOptions(initialCenter: center(), initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: _RouteHistoryScreenState._tileUrl,
                userAgentPackageName: 'tech.devopslabs.emp_mobile',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: trail,
                    color: _RouteHistoryScreenState._routeColor,
                    strokeWidth: 4,
                  ),
                ],
              ),
              MarkerLayer(markers: _markers(trail)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.cardAlt,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _Stat(value: '${route.distanceKm.toStringAsFixed(1)} km', label: 'Distance'),
              _Stat(value: route.duration ?? '—', label: 'Duration'),
              _Stat(value: '${route.points.length}', label: 'Points'),
              _Stat(value: '${route.stops.length}', label: 'Stops'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _Punch(
                tag: 'IN',
                time: route.checkIn != null
                    ? _RouteHistoryScreenState._fmt(route.checkIn!.time)
                    : '—',
                place: route.checkIn?.place ?? 'Check-in',
                color: _RouteHistoryScreenState._startColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Punch(
                tag: 'OUT',
                time: route.checkOut != null
                    ? _RouteHistoryScreenState._fmt(route.checkOut!.time)
                    : '—',
                place: route.checkOut?.place ?? 'Check-out',
                color: _RouteHistoryScreenState._endColor,
              ),
            ),
          ],
        ),

        if (route.stops.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Stops',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...route.stops.asMap().entries.map((e) => _StopRow(
                index: e.key + 1,
                stop: e.value,
              )),
        ],
      ],
    );
  }

  List<Marker> _markers(List<LatLng> trail) {
    final out = <Marker>[];
    void pin(LatLng p, String label, Color color) {
      out.add(Marker(
        point: p,
        width: 34,
        height: 34,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.bg, width: 2),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ));
    }

    final checkIn = route.checkIn;
    if (checkIn != null) {
      pin(LatLng(checkIn.lat, checkIn.lng), 'IN',
          _RouteHistoryScreenState._startColor);
    } else if (trail.isNotEmpty) {
      pin(trail.first, 'IN', _RouteHistoryScreenState._startColor);
    }
    final checkOut = route.checkOut;
    if (checkOut != null) {
      pin(LatLng(checkOut.lat, checkOut.lng), 'OUT',
          _RouteHistoryScreenState._endColor);
    } else if (trail.length > 1) {
      pin(trail.last, 'OUT', _RouteHistoryScreenState._endColor);
    }
    route.stops.asMap().forEach((i, s) {
      pin(LatLng(s.lat, s.lng), '${i + 1}',
          _RouteHistoryScreenState._stopColor);
    });
    return out;
  }
}

class _Punch extends StatelessWidget {
  const _Punch({
    required this.tag,
    required this.time,
    required this.place,
    required this.color,
  });
  final String tag;
  final String time;
  final String place;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(tag,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(time,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text(place,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.index, required this.stop});
  final int index;
  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final inT = _RouteHistoryScreenState._fmt(stop.arrival);
    final outT = stop.departure != null
        ? _RouteHistoryScreenState._fmt(stop.departure!)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE0A800),
              shape: BoxShape.circle,
            ),
            child: Text('$index',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop.label ?? 'Stop $index',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  outT != null ? '$inT – $outT' : inT,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (stop.duration != null)
            Text(stop.duration!,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 90),
        Icon(icon, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted)),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        ],
      ],
    );
  }
}
