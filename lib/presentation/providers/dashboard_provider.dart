import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/events/threat_event_bus.dart';
import '../../domain/entities/protection_status.dart';
import '../../domain/entities/threat.dart';
import '../../data/models/threat_model.dart';
import '../../data/datasources/local/database_manager.dart';
import '../../data/repositories/settings_repository.dart';

part 'dashboard_provider.g.dart';

/// Fires whenever a new threat is stored — dashboard listens and invalidates.
/// keepAlive=true so events are not dropped when the dashboard tab is off-screen.
final newThreatStreamProvider = StreamProvider<DateTime>((ref) {
  ref.keepAlive(); // prevent disposal when dashboard is not the active tab
  return ThreatEventBus.instance.stream;
});

@riverpod
Future<ProtectionStatus> protectionStatus(ProtectionStatusRef ref) async {
  final db = await DatabaseManager.database;

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
  final startOfWeek =
      now.subtract(Duration(days: now.weekday - 1)).toIso8601String();

  final todayRows = await db.rawQuery(
    'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ?',
    [startOfDay],
  );
  final todayBlockedRows = await db.rawQuery(
    'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ? AND was_blocked = 1',
    [startOfDay],
  );
  final weekBlockedRows = await db.rawQuery(
    'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ? AND was_blocked = 1',
    [startOfWeek],
  );

  final todayCount   = (todayRows.first['cnt'] as int?) ?? 0;
  final todayBlocked = (todayBlockedRows.first['cnt'] as int?) ?? 0;
  final weekBlocked  = (weekBlockedRows.first['cnt'] as int?) ?? 0;

  // Score: 25 points per feature that is BOTH toggled on AND has its permission granted
  final smsGranted   = await Permission.sms.isGranted;
  final phoneGranted = await Permission.phone.isGranted;

  int protPoints = 0;
  if (SettingsRepository.callProtect  && phoneGranted) protPoints += 25;
  if (SettingsRepository.smsProtect   && smsGranted)   protPoints += 25;
  if (SettingsRepository.waProtect)                    protPoints += 25; // permission checked by NotificationListener
  if (SettingsRepository.emailProtect)                 protPoints += 25;
  final unblocked     = todayCount - todayBlocked;
  final threatPenalty = (unblocked * 4).clamp(0, 40);
  final score         = (protPoints - threatPenalty).clamp(0, 100);

  final status = ProtectionStatus(
    score: score,
    threatsBlockedToday: todayBlocked,
    threatsBlockedWeek: weekBlocked,
    callProtectionActive:     SettingsRepository.callProtect,
    smsProtectionActive:      SettingsRepository.smsProtect,
    whatsappProtectionActive: SettingsRepository.waProtect,
    emailProtectionActive:    SettingsRepository.emailProtect,
    fallDetectionActive:      SettingsRepository.fallDetection,
    lastUpdated: now,
  );

  // Push fresh stats to Android home-screen widget
  try {
    await const MethodChannel('ai_security/device_data').invokeMethod(
      'updateWidgetStats',
      {'score': score, 'today': todayCount},
    );
  } catch (_) {}

  return status;
}

@riverpod
Future<List<Threat>> recentThreats(RecentThreatsRef ref) async {
  final db = await DatabaseManager.database;
  final rows = await db.query(
    'threats',
    orderBy: 'timestamp DESC',
    limit: 50,
  );
  return rows.map(_rowToThreat).toList();
}

Threat _rowToThreat(Map<String, dynamic> row) {
  final channelStr = row['channel'] as String? ?? 'whatsapp';
  final channel = ThreatChannel.values.firstWhere(
    (c) => c.name == channelStr,
    orElse: () => ThreatChannel.other,
  );
  return Threat(
    id: row['id'] as String,
    channel: channel,
    sender: row['sender'] as String? ?? '',
    riskScore: row['risk_score'] as int? ?? 0,
    category: row['category'] as String? ?? 'UNKNOWN',
    reason: row['reason'] as String? ?? '',
    timestamp: DateTime.tryParse(row['timestamp'] as String? ?? '') ??
        DateTime.now(),
    wasBlocked: (row['was_blocked'] as int? ?? 0) == 1,
    confidence: 0.0,
    detail: row['detail'] as String?,
  );
}

@riverpod
class WeeklyStats extends _$WeeklyStats {
  @override
  AsyncValue<Map<String, int>> build() {
    return const AsyncData({'blocked': 0, 'flagged': 0, 'safe': 0});
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final db = await DatabaseManager.database;
      final startOfWeek = DateTime.now()
          .subtract(Duration(days: DateTime.now().weekday - 1))
          .toIso8601String();

      final blocked = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ? AND was_blocked = 1',
        [startOfWeek],
      );
      final flagged = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ? AND was_blocked = 0 AND risk_score >= 60',
        [startOfWeek],
      );

      state = AsyncData({
        'blocked': (blocked.first['cnt'] as int?) ?? 0,
        'flagged': (flagged.first['cnt'] as int?) ?? 0,
        'safe':    0,
      });
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}
