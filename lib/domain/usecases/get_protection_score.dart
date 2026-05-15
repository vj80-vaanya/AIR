import '../entities/protection_status.dart';
import '../repositories/threat_repository.dart';

class GetProtectionScore {
  const GetProtectionScore(this._repo);
  final ThreatRepository _repo;

  Future<ProtectionStatus> call() async {
    final now  = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayCount = await _repo.getThreatCount(since: today);
    final weekCount  = await _repo.getThreatCount(since: weekAgo);

    /* Score starts at 100 and degrades by unblocked threat exposure.
       Simplified linear model; production uses weighted categories. */
    final score = (100 - (todayCount * 2)).clamp(0, 100);

    return ProtectionStatus(
      score:                    score,
      threatsBlockedToday:      todayCount,
      threatsBlockedWeek:       weekCount,
      callProtectionActive:     true,
      smsProtectionActive:      true,
      whatsappProtectionActive: true,
      emailProtectionActive:    true,
      fallDetectionActive:      true,
      lastUpdated:              now,
    );
  }
}
