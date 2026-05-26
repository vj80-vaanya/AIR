import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/protection_status.dart';
import '../../domain/entities/threat.dart';
import '../../data/models/threat_model.dart';
import '../../data/datasources/local/database_manager.dart';

part 'dashboard_provider.g.dart';

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
  final weekRows = await db.rawQuery(
    'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ?',
    [startOfWeek],
  );

  final todayCount = (todayRows.first['cnt'] as int?) ?? 0;
  final weekCount = (weekRows.first['cnt'] as int?) ?? 0;

  final score = (100 - (todayCount * 5)).clamp(0, 100);

  return ProtectionStatus(
    score: score,
    threatsBlockedToday: todayCount,
    threatsBlockedWeek: weekCount,
    callProtectionActive: true,
    smsProtectionActive: true,
    whatsappProtectionActive: true,
    emailProtectionActive: true,
    fallDetectionActive: true,
    lastUpdated: now,
  );
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
    orElse: () => ThreatChannel.whatsapp,
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
        'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ? AND was_blocked = 0',
        [startOfWeek],
      );

      state = AsyncData({
        'blocked': (blocked.first['cnt'] as int?) ?? 0,
        'flagged': (flagged.first['cnt'] as int?) ?? 0,
        'safe': 0,
      });
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}
