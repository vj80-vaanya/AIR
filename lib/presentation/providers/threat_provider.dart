import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/threat_model.dart';
import '../../domain/entities/threat.dart';
import '../../data/datasources/local/database_manager.dart';

part 'threat_provider.g.dart';

@riverpod
class SelectedChannel extends _$SelectedChannel {
  @override
  ThreatChannel? build() => null; // null = all channels

  void select(ThreatChannel? channel) => state = channel;
}

@riverpod
Future<List<Threat>> filteredThreats(FilteredThreatsRef ref) async {
  final channel = ref.watch(selectedChannelProvider);
  final db = await DatabaseManager.database;

  final rows = channel == null
      ? await db.query('threats', orderBy: 'timestamp DESC', limit: 100)
      : await db.query(
          'threats',
          where: 'channel = ?',
          whereArgs: [channel.name],
          orderBy: 'timestamp DESC',
          limit: 100,
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
