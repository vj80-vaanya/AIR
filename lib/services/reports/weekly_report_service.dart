import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/local/database_manager.dart';
import '../../core/utils/helpers.dart';
import '../notifications/notification_service.dart';

/// Checks once per session whether a weekly safety summary should be shown.
/// Fires on Sundays (or if 7+ days have passed since the last report).
class WeeklyReportService {
  WeeklyReportService._();
  static final WeeklyReportService instance = WeeklyReportService._();

  static const _keyLastReport = 'weekly_report_last';

  Future<void> maybeShow() async {
    final prefs   = await SharedPreferences.getInstance();
    final now     = DateTime.now();
    final lastRaw = prefs.getString(_keyLastReport);
    final last    = lastRaw != null ? DateTime.tryParse(lastRaw) : null;

    // Show on Sundays or whenever 7 days have elapsed without a report
    final isDue = last == null ||
        now.difference(last).inDays >= 7 ||
        now.weekday == DateTime.sunday;

    if (!isDue) return;

    await _generate();
    await prefs.setString(_keyLastReport, now.toIso8601String());
  }

  Future<void> _generate() async {
    final db        = await DatabaseManager.database;
    final weekStart = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();

    final totalRows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ?',
      [weekStart],
    );
    final blockedRows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM threats WHERE timestamp >= ? AND was_blocked = 1',
      [weekStart],
    );
    final topCatRows = await db.rawQuery(
      'SELECT category, COUNT(*) as cnt FROM threats '
      'WHERE timestamp >= ? GROUP BY category ORDER BY cnt DESC LIMIT 1',
      [weekStart],
    );

    final total   = (totalRows.first['cnt'] as int?) ?? 0;
    final blocked = (blockedRows.first['cnt'] as int?) ?? 0;
    final topCat  = topCatRows.isNotEmpty
        ? Helpers.categoryLabel(topCatRows.first['category'] as String? ?? '')
        : null;

    await NotificationService.instance.showWeeklyReport(
      blocked:     blocked,
      total:       total,
      topCategory: topCat,
    );
  }
}
