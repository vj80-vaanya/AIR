import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/extensions.dart';

class WhatsAppCleanupScreen extends StatefulWidget {
  const WhatsAppCleanupScreen({super.key});
  @override
  State<WhatsAppCleanupScreen> createState() => _WhatsAppCleanupScreenState();
}

class _WhatsAppCleanupScreenState extends State<WhatsAppCleanupScreen> {
  static const _ch = MethodChannel('ai_security/media_cleanup');

  bool                       _loading   = true;
  bool                       _permitted = false;
  Map<String, _CatStats>     _stats     = {};
  String?                    _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Check/request storage permission
    final perm = Platform.isAndroid
        ? (await Permission.storage.isGranted ||
            await Permission.photos.isGranted)
        : await Permission.photos.isGranted;

    if (!perm) {
      final req = Platform.isAndroid
          ? await Permission.storage.request()
          : await Permission.photos.request();
      if (!req.isGranted) {
        setState(() { _loading = false; _permitted = false; });
        return;
      }
    }

    _permitted = true;
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await _ch.invokeMapMethod<String, dynamic>('getStats');
      final stats = <String, _CatStats>{};
      raw?.forEach((key, value) {
        final m = Map<String, dynamic>.from(value as Map);
        stats[key] = _CatStats(
          count: (m['count'] as int?) ?? 0,
          size:  (m['size']  as int?) ?? 0,
        );
      });
      setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _deleteCategory(String cat) async {
    final confirmed = await _confirmDialog(
      context,
      title:   'Delete all ${_label(cat)}?',
      message: 'This will permanently delete ${_stats[cat]?.count ?? 0} files (${_fmtSize(_stats[cat]?.size ?? 0)}). This cannot be undone.',
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final result = await _ch.invokeMapMethod<String, dynamic>(
        'deleteCategory',
        {'category': cat},
      );
      final freed = (result?['freed'] as int?) ?? 0;
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Freed ${_fmtSize(freed)}'),
          backgroundColor: AppColors.secondary,
        ));
      }
      await _refresh();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title:   Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style:    FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Cleanup'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : !_permitted
              ? _NoPermission(onGrant: _init)
              : _error != null
                  ? _ErrorView(error: _error!, onRetry: _refresh)
                  : _Body(
                      stats:    _stats,
                      isDark:   isDark,
                      onDelete: _deleteCategory,
                    ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.stats,
    required this.isDark,
    required this.onDelete,
  });
  final Map<String, _CatStats> stats;
  final bool                   isDark;
  final ValueChanged<String>   onDelete;

  @override
  Widget build(BuildContext context) {
    final total = stats.values.fold<int>(0, (s, c) => s + c.size);
    final cats  = _categories;

    return ListView(
      padding: EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 100),
      children: [
        // ── Total saved banner ────────────────────────────────────────────
        _TotalBanner(total: total, isDark: isDark),
        const SizedBox(height: Spacing.md),

        // ── How it works note ─────────────────────────────────────────────
        _InfoNote(isDark: isDark),
        const SizedBox(height: Spacing.md),

        Text(
          'BY CATEGORY',
          style: TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w700,
            color:      AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),

        // ── Category cards ────────────────────────────────────────────────
        ...cats.map((c) {
          final stat = stats[c.key] ?? _CatStats(count: 0, size: 0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CategoryCard(
              cat:      c,
              stat:     stat,
              isDark:   isDark,
              onDelete: () => onDelete(c.key),
            ),
          );
        }),
      ],
    );
  }
}

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.total, required this.isDark});
  final int  total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:  AppColors.secondary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.cleaning_services_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtSize(total),
                  style: const TextStyle(
                    color:         Colors.white,
                    fontSize:      28,
                    fontWeight:    FontWeight.w900,
                    letterSpacing: -0.5,
                    height:        1,
                  ),
                ),
                const Text(
                  'WhatsApp media found',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.cat,
    required this.stat,
    required this.isDark,
    required this.onDelete,
  });
  final _Cat         cat;
  final _CatStats    stat;
  final bool         isDark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final empty = stat.count == 0;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width:  46,
              height: 46,
              decoration: BoxDecoration(
                color:        cat.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(cat.icon, color: cat.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    empty
                        ? 'Nothing to clean'
                        : '${stat.count} files · ${_fmtSize(stat.size)}',
                    style: TextStyle(
                      color:    empty
                          ? AppColors.textDisabled
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!empty)
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cat.color, cat.color.withOpacity(0.75)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:  cat.color.withOpacity(0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Delete all',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:        AppColors.secondary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Clean',
                  style: TextStyle(
                    color:      AppColors.secondary,
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        isDark
            ? AppColors.borderDark.withOpacity(0.4)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Only deletes forwarded images, videos, and voice notes WhatsApp has already saved to your storage. Your chats are unaffected.',
              style: TextStyle(
                fontSize: 12,
                color:    isDark ? Colors.white70 : AppColors.textSecondary,
                height:   1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── No permission / Error states ─────────────────────────────────────────────

class _NoPermission extends StatelessWidget {
  const _NoPermission({required this.onGrant});
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_rounded,
                size: 72, color: AppColors.textDisabled),
            const SizedBox(height: Spacing.md),
            const Text(
              'Storage Access Needed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Grant storage permission so the app can find WhatsApp media files.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: Spacing.lg),
            ElevatedButton.icon(
              onPressed: onGrant,
              icon:      const Icon(Icons.folder_open_rounded),
              label:     const Text('Grant Storage Access'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String       error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 60, color: AppColors.warning),
            const SizedBox(height: Spacing.md),
            const Text('Could not scan storage',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: Spacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _CatStats {
  const _CatStats({required this.count, required this.size});
  final int count, size;
}

class _Cat {
  const _Cat({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String   key, label;
  final IconData icon;
  final Color    color;
}

const _categories = [
  _Cat(
    key:   'images',
    label: 'Images & GIFs',
    icon:  Icons.image_rounded,
    color: AppColors.info,
  ),
  _Cat(
    key:   'videos',
    label: 'Videos',
    icon:  Icons.videocam_rounded,
    color: Color(0xFF8B5CF6), // violet
  ),
  _Cat(
    key:   'audio',
    label: 'Voice Notes & Audio',
    icon:  Icons.headset_rounded,
    color: AppColors.secondary,
  ),
  _Cat(
    key:   'docs',
    label: 'Documents',
    icon:  Icons.description_rounded,
    color: AppColors.warning,
  ),
  _Cat(
    key:   'stickers',
    label: 'Stickers',
    icon:  Icons.emoji_emotions_rounded,
    color: AppColors.danger,
  ),
];

// ── Helpers ──────────────────────────────────────────────────────────────────

String _fmtSize(int bytes) {
  if (bytes < 1024)       return '$bytes B';
  if (bytes < 1048576)    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}

String _label(String key) => _categories
    .firstWhere((c) => c.key == key,
        orElse: () => _Cat(
            key: '', label: key, icon: Icons.folder, color: AppColors.primary))
    .label;
