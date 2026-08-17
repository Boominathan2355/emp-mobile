import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../services/attendance_service.dart';
import 'route_history_screen.dart';

/// History tab: Attendance (punch-clock rows) or Route (map replay) — toggled
/// with a segmented control.
///
/// Attendance data source: `GET /api/attendance`, which is NOT live on the
/// backend yet (there's no punch-clock table). Until it ships, this shows an
/// explanatory empty/error state instead of fabricating rows. Route replay
/// (`GET /api/tracking/route`) IS live and real.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = AttendanceService();
  late Future<List<AttendanceRecord>> _future;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _future = _service.history();
  }

  void _reload() => setState(() => _future = _service.history());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Attendance')),
                ButtonSegment(value: 1, label: Text('Route')),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: AppTheme.accent,
                backgroundColor: AppTheme.cardAlt,
                side: const BorderSide(color: AppTheme.cardAlt),
              ),
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
        ],
      ),
      body: _tab == 1
          ? RouteHistoryScreen(user: widget.user)
          : _attendanceBody(context),
    );
  }

  Widget _attendanceBody(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<AttendanceRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final err = snap.error;
            final notLive = err is ApiException &&
                (err.status == 404 || err.status == 501);
            return _Message(
              icon: Icons.history_toggle_off,
              title: notLive
                  ? 'History not available yet'
                  : 'Could not load history',
              subtitle: notLive
                  ? 'The attendance service is not live on the server yet.'
                  : (err is ApiException ? err.message : '$err'),
              onRetry: _reload,
            );
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const _Message(
              icon: Icons.event_available,
              title: 'No attendance yet',
              subtitle: 'Your check-ins will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _HistoryCard(rows[i]),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(this.r);
  final AttendanceRecord r;

  Color get _statusColor => switch (r.status) {
        'present' => AppTheme.success,
        'late' => const Color(0xFFE0A800),
        'absent' => const Color(0xFFE5484D),
        _ => AppTheme.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('In: ${r.checkIn ?? "—"}',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text('Out: ${r.checkOut ?? "—"}',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Hours: ${r.hours.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.textMuted)),
              const Text('  ·  ', style: TextStyle(color: AppTheme.textMuted)),
              Text('${r.distanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(color: AppTheme.textMuted)),
              const Text('  ·  ', style: TextStyle(color: AppTheme.textMuted)),
              Text(r.status, style: TextStyle(color: _statusColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
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
        const SizedBox(height: 120),
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
