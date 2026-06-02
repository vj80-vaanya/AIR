import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/engine/security_engine.dart';
import '../../../core/utils/extensions.dart';

class SpamCallsScreen extends StatefulWidget {
  const SpamCallsScreen({super.key});
  @override
  State<SpamCallsScreen> createState() => _SpamCallsScreenState();
}

class _SpamCallsScreenState extends State<SpamCallsScreen> {
  static const _ch = MethodChannel('ai_security/device_data');

  // In-memory cache — avoids re-analysing 200 calls every time user opens screen
  static List<_CallEntry>? _cachedCalls;
  static DateTime?         _cacheTime;
  static const _cacheTtl   = Duration(minutes: 5);

  List<_CallEntry> _calls   = [];
  bool             _loading   = true;
  String?          _error;
  bool             _analysing = false;
  int              _analyseGen = 0;

  static const _typeIncoming = 1;
  static const _typeMissed   = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    // Return cached results if still fresh
    if (!forceRefresh &&
        _cachedCalls != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      setState(() { _calls = _cachedCalls!; _loading = false; });
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final raw = await _ch.invokeListMethod<Map>(
          'getCallLog', {'limit': 200});
      final entries = <_CallEntry>[];

      for (final c in (raw ?? [])) {
        final number   = c['number']?.toString() ?? '';
        final name     = c['name']?.toString() ?? '';
        final type     = c['type'] as int? ?? 0;
        final date     = c['date'] as int? ?? 0;
        final duration = c['duration'] as int? ?? 0;

        // Only analyse incoming/missed from unknowns
        if (number.isEmpty) continue;
        if (name.isNotEmpty) continue; // saved contact — skip
        if (type != _typeIncoming && type != _typeMissed) continue;

        entries.add(_CallEntry(
          number:     number,
          date:       DateTime.fromMillisecondsSinceEpoch(date),
          duration:   duration,
          isMissed:   type == _typeMissed,
          riskScore:  -1, // not analysed yet
          category:   '',
          reason:     '',
        ));
      }

      _analyseGen++; // cancel any previous analysis loop
      setState(() { _calls = entries; _loading = false; });

      // Analyse in background — captures current generation so stale loops abort.
      _analyseAll(_analyseGen);
    } on PlatformException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _analyseAll(int gen) async {
    if (!mounted) return;
    setState(() => _analysing = true);
    for (int i = 0; i < _calls.length; i++) {
      // Abort if screen was disposed or a new load started.
      if (!mounted || _analyseGen != gen) return;
      final c = _calls[i];
      final r = await SecurityEngine.instance.analyzeCall(
        phoneNumber:    c.number,
        isKnownContact: false,
      );
      if (!mounted || _analyseGen != gen) return;
      setState(() {
        _calls[i] = _CallEntry(
          number:    c.number,
          date:      c.date,
          duration:  c.duration,
          isMissed:  c.isMissed,
          riskScore: r.riskScore,
          category:  r.category,
          reason:    r.reason,
        );
      });
    }
    if (mounted && _analyseGen == gen) {
      setState(() => _analysing = false);
      // Cache completed analysis results
      _cachedCalls = List.unmodifiable(_calls);
      _cacheTime   = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    // Group by risk
    final high   = _calls.where((c) => c.riskScore >= 70).toList();
    final medium = _calls.where((c) => c.riskScore >= 30 && c.riskScore < 70).toList();
    final safe   = _calls.where((c) => c.riskScore >= 0  && c.riskScore < 30).toList();
    final pending= _calls.where((c) => c.riskScore < 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Log Analyser'),
        actions: [
          if (_analysing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width:  18,
                  height: 18,
                  child:  CircularProgressIndicator(
                    color:       AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon:      const Icon(Icons.refresh_rounded),
              onPressed: () => _load(forceRefresh: true),
              tooltip:   'Re-scan call log',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!)
              : _calls.isEmpty
                  ? _EmptyView()
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                          Spacing.md, Spacing.sm, Spacing.md, 100),
                      children: [
                        // Stats bar
                        _StatsBar(
                          high:   high.length,
                          medium: medium.length,
                          safe:   safe.length,
                          isDark: isDark,
                        ),
                        const SizedBox(height: Spacing.md),

                        if (high.isNotEmpty) ...[
                          _GroupHeader(
                              label: 'HIGH RISK',
                              color: AppColors.danger,
                              count: high.length),
                          const SizedBox(height: 8),
                          ...high.map((c) => _CallCard(
                              call: c, isDark: isDark)),
                          const SizedBox(height: Spacing.md),
                        ],

                        if (medium.isNotEmpty) ...[
                          _GroupHeader(
                              label: 'SUSPICIOUS',
                              color: AppColors.warning,
                              count: medium.length),
                          const SizedBox(height: 8),
                          ...medium.map((c) => _CallCard(
                              call: c, isDark: isDark)),
                          const SizedBox(height: Spacing.md),
                        ],

                        if (safe.isNotEmpty) ...[
                          _GroupHeader(
                              label: 'LIKELY SAFE',
                              color: AppColors.secondary,
                              count: safe.length),
                          const SizedBox(height: 8),
                          ...safe.map((c) => _CallCard(
                              call: c, isDark: isDark)),
                          const SizedBox(height: Spacing.md),
                        ],

                        if (pending.isNotEmpty)
                          Center(
                            child: Text(
                              'Analysing ${pending.length} calls…',
                              style: TextStyle(
                                color:    AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

// ── Stats banner ──────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.high,
    required this.medium,
    required this.safe,
    required this.isDark,
  });
  final int  high, medium, safe;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill(label: 'High risk', value: high,   color: AppColors.danger,    isDark: isDark),
        const SizedBox(width: 8),
        _Pill(label: 'Suspicious', value: medium, color: AppColors.warning,   isDark: isDark),
        const SizedBox(width: 8),
        _Pill(label: 'Safe',       value: safe,   color: AppColors.secondary, isDark: isDark),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });
  final String label;
  final int    value;
  final Color  color;
  final bool   isDark;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color:      color,
                  fontSize:   22,
                  fontWeight: FontWeight.w800,
                  height:     1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color:    color.withOpacity(0.80),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.color,
    required this.count,
  });
  final String label;
  final Color  color;
  final int    count;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 3, height: 14, color: color,
              margin: const EdgeInsets.only(right: 8)),
          Text(
            label,
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w700,
              color:      color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      );
}

// ── Call card ─────────────────────────────────────────────────────────────────

class _CallCard extends StatelessWidget {
  const _CallCard({required this.call, required this.isDark});
  final _CallEntry call;
  final bool       isDark;

  @override
  Widget build(BuildContext context) {
    final color = call.riskScore < 0
        ? AppColors.textDisabled
        : call.riskScore.riskColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: call.riskScore >= 70
              ? color.withOpacity(0.35)
              : (isDark ? AppColors.borderDark : AppColors.border),
          width: call.riskScore >= 70 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Risk badge
            Container(
              width:  44,
              height: 44,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: call.riskScore < 0
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      '${call.riskScore}',
                      style: TextStyle(
                        color:      color,
                        fontWeight: FontWeight.w800,
                        fontSize:   15,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.number,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    call.isMissed ? 'Missed · ${call.date.relativeTime}' : call.date.relativeTime,
                    style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    call.riskScore >= 0 && call.reason.isNotEmpty
                        ? call.reason
                        : call.riskScore >= 0
                            ? 'No suspicious patterns found.'
                            : '',
                    style: TextStyle(
                      color:    call.riskScore >= 30 ? color : AppColors.textSecondary,
                      fontSize: 11,
                      height:   1.4,
                    ),
                    maxLines:  2,
                    overflow:  TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (call.isMissed)
              const Icon(Icons.call_missed_rounded,
                  color: AppColors.danger, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Empty / error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.call_rounded, size: 64, color: AppColors.textDisabled),
              SizedBox(height: 16),
              Text('No unknown calls found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(
                  'Only calls from people NOT saved in your contacts are shown here. Saved contacts are trusted and not analysed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_disabled_rounded,
                  size: 60, color: AppColors.warning),
              const SizedBox(height: 16),
              const Text('Call log unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _CallEntry {
  const _CallEntry({
    required this.number,
    required this.date,
    required this.duration,
    required this.isMissed,
    required this.riskScore,
    required this.category,
    required this.reason,
  });
  final String   number, category, reason;
  final DateTime date;
  final int      duration, riskScore;
  final bool     isMissed;
}
