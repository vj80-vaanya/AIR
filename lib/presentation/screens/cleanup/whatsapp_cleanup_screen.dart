import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/extensions.dart';

class WhatsAppCleanupScreen extends StatefulWidget {
  const WhatsAppCleanupScreen({super.key});
  @override
  State<WhatsAppCleanupScreen> createState() => _WhatsAppCleanupScreenState();
}

class _WhatsAppCleanupScreenState extends State<WhatsAppCleanupScreen>
    with SingleTickerProviderStateMixin {
  static const _ch = MethodChannel('ai_security/media_cleanup');

  _ScreenState _state   = _ScreenState.idle;
  bool         _permitted = false;
  _ScanResult? _result;
  String?      _error;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _checkPermission();
    // Pre-warm cache immediately in background — by the time user taps Scan it's likely ready
    _ch.invokeMethod('warmCache').catchError((_) {});
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  Future<void> _checkPermission() async {
    if (!Platform.isAndroid) {
      setState(() { _permitted = true; _state = _ScreenState.idle; });
      return;
    }
    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted ||
        await Permission.photos.isGranted) {
      setState(() { _permitted = true; _state = _ScreenState.idle; });
    } else {
      setState(() { _state = _ScreenState.noPermission; });
    }
  }

  Future<void> _requestPermission() async {
    bool granted = false;
    if (Platform.isAndroid) {
      final manage = await Permission.manageExternalStorage.request();
      if (manage.isGranted) {
        granted = true;
      } else {
        final statuses = await [
          Permission.storage, Permission.photos,
          Permission.videos,  Permission.audio,
        ].request();
        granted = (statuses[Permission.storage]?.isGranted ?? false) ||
                  (statuses[Permission.photos]?.isGranted ?? false);
      }
    } else {
      granted = (await Permission.photos.request()).isGranted;
    }
    if (granted) {
      setState(() { _permitted = true; _state = _ScreenState.idle; });
    } else {
      setState(() { _state = _ScreenState.noPermission; });
    }
  }

  // ── Scan ───────────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    setState(() { _state = _ScreenState.scanning; _error = null; });
    try {
      final raw = await _ch
          .invokeMapMethod<String, dynamic>('scanAll')
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () => throw Exception(
                'Scan timed out. Your media library may be very large — try again.'),
          );
      if (!mounted) return;
      setState(() {
        _result = _ScanResult.fromMap(raw ?? {});
        _state  = _ScreenState.results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _state = _ScreenState.error; });
    }
  }

  // ── Deletion ───────────────────────────────────────────────────────────────

  Future<void> _deleteCategory(String cat, String label) async {
    final stat = _result?.categories[cat];
    if (stat == null || stat.count == 0) return;
    final ok = await _confirm(
      title:   'Delete all $label?',
      message: 'Permanently deletes ${stat.count} files (${_fmt(stat.size)}). Cannot be undone.',
    );
    if (!ok || !mounted) return;
    setState(() { _state = _ScreenState.scanning; });
    try {
      final res = await _ch.invokeMapMethod<String, dynamic>('deleteCategory', {'category': cat});
      final freed = (res?['freed'] as int?) ?? 0;
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Freed ${_fmt(freed)}'),
          backgroundColor: AppColors.secondary,
        ));
      }
      await _startScan();
    } catch (e) {
      setState(() { _error = e.toString(); _state = _ScreenState.error; });
    }
  }

  Future<bool> _confirm({required String title, required String message}) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   15,
                    height:     1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This cannot be undone. These files will be permanently removed from your phone.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style:    FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      ) ?? false;

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _browse(String category, String label, Color color) {
    context.push('/cleanup/browse', extra: {
      'category': category, 'label': label, 'color': color,
    });
  }

  void _browseDuplicates() => context.push('/cleanup/duplicates');

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('WhatsApp Cleanup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_state == _ScreenState.results)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _startScan,
              tooltip: 'Rescan',
            ),
        ],
      ),
      body: switch (_state) {
        _ScreenState.noPermission => _NoPermission(onGrant: _requestPermission),
        _ScreenState.idle         => _IdleView(anim: _pulseAnim, onScan: _startScan, isDark: isDark),
        _ScreenState.scanning     => const _ScanningView(),
        _ScreenState.error        => _ErrorView(error: _error!, onRetry: _startScan),
        _ScreenState.results      => _ResultsView(
            result:   _result!,
            isDark:   isDark,
            onBrowse:     _browse,
            onDuplicates: _browseDuplicates,
            onDelete:     _deleteCategory,
          ),
      },
    );
  }
}

// ── Screen states ─────────────────────────────────────────────────────────────

enum _ScreenState { noPermission, idle, scanning, error, results }

// ── Idle (pre-scan) view ──────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.anim, required this.onScan, required this.isDark});
  final Animation<double> anim;
  final VoidCallback      onScan;
  final bool              isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: anim,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withOpacity(0.35),
                      blurRadius: 32, spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.cleaning_services_rounded,
                    size: 56, color: Colors.white),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Scan WhatsApp Media',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Find duplicates, large files, old media and useless content — then clean what you don\'t need.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                fontSize: 14, height: 1.55,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onScan,
                icon:  const Icon(Icons.radar_rounded),
                label: const Text('Start Scan', style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scanning view ─────────────────────────────────────────────────────────────

class _ScanningView extends StatefulWidget {
  const _ScanningView();

  @override
  State<_ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<_ScanningView> {
  static const _tips = [
    'Looking through WhatsApp Images folder…',
    'Checking for duplicate photos…',
    'Finding large videos…',
    'Scanning old forwarded media…',
    'Calculating space used by stickers…',
    'Almost done — sorting by size…',
  ];
  int _tip = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _next);
  }

  void _next() {
    if (!mounted) return;
    setState(() => _tip = (_tip + 1) % _tips.length);
    Future.delayed(const Duration(seconds: 3), _next);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: Color(0xFF059669), strokeWidth: 3),
            const SizedBox(height: 24),
            const Text('Scanning WhatsApp storage…',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _tips[_tip],
                key:       ValueKey(_tip),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height:   1.5),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'This may take up to 30 seconds\non phones with lots of media.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:    AppColors.textDisabled,
                  fontSize: 12,
                  height:   1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results view ──────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.result,
    required this.isDark,
    required this.onBrowse,
    required this.onDuplicates,
    required this.onDelete,
  });
  final _ScanResult                                      result;
  final bool                                             isDark;
  final void Function(String cat, String label, Color)   onBrowse;
  final VoidCallback                                     onDuplicates;
  final void Function(String cat, String label)          onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        // Total banner
        _TotalBanner(total: result.total, isDark: isDark),
        const SizedBox(height: 20),

        // Smart insights
        _SectionHeader('SMART INSIGHTS'),
        const SizedBox(height: 10),

        _SmartCard(
          icon:  Icons.copy_all_rounded,
          label: 'Duplicates',
          desc:  'Exact copies wasting space',
          color: AppColors.danger,
          stat:  result.smart['duplicates'],
          onTap: onDuplicates,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _SmartCard(
          icon:  Icons.video_library_rounded,
          label: 'Large Files',
          desc:  'Videos & files over 50 MB',
          color: const Color(0xFF8B5CF6),
          stat:  result.smart['large_files'],
          onTap: () => onBrowse('large_files', 'Large Files', const Color(0xFF8B5CF6)),
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _SmartCard(
          icon:  Icons.history_rounded,
          label: 'Old Media',
          desc:  'Not opened in 6+ months outside of WhatsApp — review before deleting',
          color: AppColors.warning,
          stat:  result.smart['old_media'],
          onTap: () => onBrowse('old_media', 'Old Media', AppColors.warning),
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _SmartCard(
          icon:  Icons.forward_rounded,
          label: 'Sent / Forwarded',
          desc:  'Files you sent to others',
          color: AppColors.info,
          stat:  result.smart['forwarded'],
          onTap: () => onBrowse('forwarded', 'Sent / Forwarded', AppColors.info),
          isDark: isDark,
        ),

        const SizedBox(height: 24),
        _SectionHeader('BY CATEGORY'),
        const SizedBox(height: 10),

        for (final c in _stdCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CategoryCard(
              cat:     c,
              stat:    result.categories[c.key] ?? _CatStats.zero,
              isDark:  isDark,
              onBrowse: () => onBrowse(c.key, c.label, c.color),
              onDelete: () => onDelete(c.key, c.label),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: AppColors.textSecondary, letterSpacing: 1.0,
    ),
  );
}

// ── Total banner ──────────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.total, required this.isDark});
  final _TotalStats total;
  final bool        isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fmt(total.size), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1)),
            Text('${total.count} files · tap a category to review', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        )),
      ]),
    );
  }
}

// ── Smart insight card ────────────────────────────────────────────────────────

class _SmartCard extends StatelessWidget {
  const _SmartCard({
    required this.icon, required this.label, required this.desc,
    required this.color, required this.stat, required this.onTap, required this.isDark,
  });
  final IconData   icon;
  final String     label, desc;
  final Color      color;
  final _SmartStats? stat;
  final VoidCallback onTap;
  final bool         isDark;

  @override
  Widget build(BuildContext context) {
    final empty = (stat?.count ?? 0) == 0;
    return GestureDetector(
      onTap: empty ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: empty ? (isDark ? AppColors.borderDark : AppColors.border)
                                          : color.withOpacity(0.35), width: empty ? 1 : 1.5),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(
              empty ? desc : '${stat!.count} files · ${_fmt(stat!.size)}',
              style: TextStyle(color: empty ? AppColors.textDisabled : AppColors.textSecondary, fontSize: 12),
            ),
          ])),
          if (!empty)
            Icon(Icons.chevron_right_rounded, color: color, size: 22)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('Clean', style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}

// ── Standard category card ────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.cat, required this.stat, required this.isDark,
    required this.onBrowse, required this.onDelete,
  });
  final _StdCat      cat;
  final _CatStats    stat;
  final bool         isDark;
  final VoidCallback onBrowse, onDelete;

  @override
  Widget build(BuildContext context) {
    final empty = stat.count == 0;
    return GestureDetector(
      onTap: empty ? null : onBrowse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: cat.color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(cat.icon, color: cat.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(
              empty ? 'Nothing to clean' : '${stat.count} files · ${_fmt(stat.size)}',
              style: TextStyle(color: empty ? AppColors.textDisabled : AppColors.textSecondary, fontSize: 12),
            ),
          ])),
          if (!empty) ...[
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: const Text('Delete all', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: cat.color, size: 20),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('Clean', style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}

// ── Permission / Error views ──────────────────────────────────────────────────

class _NoPermission extends StatelessWidget {
  const _NoPermission({required this.onGrant});
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.folder_off_rounded, size: 72, color: AppColors.textDisabled),
        const SizedBox(height: Spacing.md),
        const Text('Storage Access Needed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Grant storage permission so the app can find WhatsApp media files.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: Spacing.lg),
        ElevatedButton.icon(onPressed: onGrant,
            icon: const Icon(Icons.folder_open_rounded), label: const Text('Grant Storage Access')),
      ]),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String       error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.warning_amber_rounded, size: 60, color: AppColors.warning),
        const SizedBox(height: Spacing.md),
        const Text('Could not scan storage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: Spacing.lg),
        ElevatedButton.icon(onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ]),
    ),
  );
}

// ── Data models ───────────────────────────────────────────────────────────────

class _ScanResult {
  final Map<String, _CatStats>   categories;
  final Map<String, _SmartStats> smart;
  final _TotalStats              total;

  const _ScanResult({required this.categories, required this.smart, required this.total});

  factory _ScanResult.fromMap(Map<String, dynamic> m) {
    final cats   = (m['categories'] as Map?)?.cast<String, dynamic>() ?? {};
    final smarts = (m['smart']      as Map?)?.cast<String, dynamic>() ?? {};
    final tot    = (m['total']      as Map?)?.cast<String, dynamic>() ?? {};

    return _ScanResult(
      categories: cats.map((k, v) {
        final mv = Map<String, dynamic>.from(v as Map);
        return MapEntry(k, _CatStats(count: (mv['count'] as int?) ?? 0, size: (mv['size'] as int?) ?? 0));
      }),
      smart: smarts.map((k, v) {
        final mv = Map<String, dynamic>.from(v as Map);
        return MapEntry(k, _SmartStats(count: (mv['count'] as int?) ?? 0, size: (mv['size'] as int?) ?? 0));
      }),
      total: _TotalStats(count: (tot['count'] as int?) ?? 0, size: (tot['size'] as int?) ?? 0),
    );
  }
}

class _CatStats {
  const _CatStats({required this.count, required this.size});
  static const zero = _CatStats(count: 0, size: 0);
  final int count, size;
}

class _SmartStats {
  const _SmartStats({required this.count, required this.size});
  final int count, size;
}

class _TotalStats {
  const _TotalStats({required this.count, required this.size});
  final int count, size;
}

class _StdCat {
  const _StdCat({required this.key, required this.label, required this.icon, required this.color});
  final String key, label;
  final IconData icon;
  final Color    color;
}

const _stdCategories = [
  _StdCat(key: 'images',   label: 'Images & GIFs',        icon: Icons.image_rounded,       color: AppColors.info),
  _StdCat(key: 'videos',   label: 'Videos',               icon: Icons.videocam_rounded,    color: Color(0xFF8B5CF6)),
  _StdCat(key: 'audio',    label: 'Voice Notes & Audio',  icon: Icons.headset_rounded,     color: AppColors.secondary),
  _StdCat(key: 'docs',     label: 'Documents',            icon: Icons.description_rounded, color: AppColors.warning),
  _StdCat(key: 'stickers', label: 'Stickers',             icon: Icons.emoji_emotions_rounded, color: AppColors.danger),
];

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(int bytes) {
  if (bytes < 1024)       return '$bytes B';
  if (bytes < 1048576)    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}
