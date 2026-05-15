import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/protection_status.dart';
import '../../domain/entities/threat.dart';
import '../../data/models/threat_model.dart';

part 'dashboard_provider.g.dart';

@riverpod
Future<ProtectionStatus> protectionStatus(ProtectionStatusRef ref) async {
  /* In production this would call GetProtectionScore use-case */
  await Future.delayed(const Duration(milliseconds: 200));
  return ProtectionStatus.initial();
}

@riverpod
Future<List<Threat>> recentThreats(RecentThreatsRef ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return [];
}

@riverpod
class WeeklyStats extends _$WeeklyStats {
  @override
  AsyncValue<Map<String, int>> build() {
    return const AsyncData({'blocked': 0, 'flagged': 0, 'safe': 0});
  }
}
