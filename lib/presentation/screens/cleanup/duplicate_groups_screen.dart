import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';

class DuplicateGroupsScreen extends StatefulWidget {
  const DuplicateGroupsScreen({super.key});

  @override
  State<DuplicateGroupsScreen> createState() => _DuplicateGroupsScreenState();
}

class _DuplicateGroupsScreenState extends State<DuplicateGroupsScreen> {
  static const _ch = MethodChannel('ai_security/media_cleanup');

  List<_DupGroup> _groups   = [];
  bool            _loading  = true;
  bool            _deleting = false;
  String?         _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await _ch.invokeListMethod<Object>('getDuplicateGroups');
      final groups = (raw ?? []).map((e) {
        final m     = Map<String, dynamic>.from(e as Map);
        final files = (m['files'] as List).map((fe) {
          final fm = Map<String, dynamic>.from(fe as Map);
          final tb = fm['thumb'] as String?;
          return _DupFile(
            path:     fm['path']     as String,
            name:     fm['name']     as String,
            size:     fm['size']     as int,
            modified: DateTime.fromMillisecondsSinceEpoch(fm['modified'] as int),
            isSent:   fm['isSent']  as bool? ?? false,
            keep:     fm['keep']    as bool? ?? false,
            thumb:    tb != null ? base64Decode(tb) : null,
          );
        }).toList();
        return _DupGroup(
          md5:   m['md5']   as String,
          count: m['count'] as int,
          size:  m['size']  as int,
          files: files,
        );
      }).toList();
      setState(() { _groups = groups; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int get _totalWastedBytes => _groups.fold(0, (s, g) => s + g.size * (g.count - 1));
  int get _totalWastedFiles => _groups.fold(0, (s, g) => s + g.count - 1);

  Future<void> _deleteAllDuplicates() async {
    if (_groups.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Delete all duplicates?'),
        content: Text(
          'Keeps 1 copy of each. Deletes $_totalWastedFiles files and frees ${_fmtSize(_totalWastedBytes)}. Cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style:    FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete duplicates'),
          ),
        ],
      ),
    ) ?? false;
    if (!ok || !mounted) return;

    // Collect all non-keep paths
    final toDelete = _groups
        .expand((g) => g.files.where((f) => !f.keep))
        .map((f) => f.path)
        .toList();

    setState(() { _deleting = true; });
    try {
      final res = await _ch.invokeMapMethod<String, dynamic>('deleteFiles', {'paths': toDelete});
      final freed = (res?['freed'] as int?) ?? 0;
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Freed ${_fmtSize(freed)}'),
          backgroundColor: AppColors.secondary,
        ));
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() { _deleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Duplicate Files'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_groups.isNotEmpty && !_loading && !_deleting)
            TextButton(
              onPressed: _deleteAllDuplicates,
              child: const Text('Delete all', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading || _deleting) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: _deleting ? AppColors.danger : AppColors.primary),
        const SizedBox(height: 16),
        Text(_deleting ? 'Deleting duplicates…' : 'Finding duplicates…',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ]));
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, size: 56, color: AppColors.warning),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ]),
      ));
    }
    if (_groups.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded, size: 72, color: AppColors.secondary),
        SizedBox(height: 16),
        Text('No duplicates found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text('Your WhatsApp media is unique!', style: TextStyle(color: AppColors.textSecondary)),
      ]));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Summary banner
        _SummaryBanner(
          groupCount: _groups.length,
          fileCount:  _totalWastedFiles,
          wasted:     _totalWastedBytes,
          isDark:     isDark,
        ),
        const SizedBox(height: 16),
        const Text('DUPLICATE GROUPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1)),
        const SizedBox(height: 10),
        ..._groups.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GroupCard(
            group: g,
            isDark: isDark,
            onDeleted: (freed) {
              // Show snackbar from parent context (still mounted), then reload
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Freed ${_fmtSize(freed)}'),
                backgroundColor: AppColors.secondary,
                duration: const Duration(seconds: 2),
              ));
              _load();
            },
          ),
        )),
      ],
    );
  }
}

// ── Summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.groupCount, required this.fileCount,
    required this.wasted, required this.isDark,
  });
  final int  groupCount, fileCount, wasted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.danger, Color(0xFFFF6B6B)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.copy_all_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fmtSize(wasted), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
          Text('$groupCount groups · $fileCount duplicate files', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
      ]),
    );
  }
}

// ── Group card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  const _GroupCard({required this.group, required this.isDark, required this.onDeleted});
  final _DupGroup              group;
  final bool                   isDark;
  final void Function(int freed) onDeleted;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  static const _ch = MethodChannel('ai_security/media_cleanup');
  bool _expanded = false;
  bool _deleting = false;

  Future<void> _deleteGroup() async {
    final toDelete  = widget.group.files.where((f) => !f.keep).toList();
    final keepFile  = widget.group.files.firstWhere((f) => f.keep,
        orElse: () => widget.group.files.first);
    if (toDelete.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${toDelete.length} duplicate${toDelete.length > 1 ? 's' : ''}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Will keep (newest copy):',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(keepFile.name,
                style: const TextStyle(color: AppColors.secondary, fontSize: 13)),
            const SizedBox(height: 12),
            Text('Will permanently delete: ${toDelete.length} older cop${toDelete.length > 1 ? 'ies' : 'y'}. Cannot be undone.',
                style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style:    FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete copies'),
          ),
        ],
      ),
    ) ?? false;
    if (!ok || !mounted) return;

    setState(() { _deleting = true; });
    try {
      final res = await _ch.invokeMapMethod<String, dynamic>(
          'deleteFiles', {'paths': toDelete.map((f) => f.path).toList()});
      final freed = (res?['freed'] as int?) ?? 0;
      HapticFeedback.lightImpact();
      widget.onDeleted(freed);
    } catch (e) {
      if (mounted) setState(() { _deleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g      = widget.group;
    final isDark = widget.isDark;
    final waste  = g.size * (g.count - 1);

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: Column(children: [
        // Header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // First file thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: g.files.first.thumb != null
                    ? Image.memory(g.files.first.thumb!, width: 52, height: 52, fit: BoxFit.cover)
                    : Container(width: 52, height: 52, color: Colors.grey.shade800,
                        child: const Icon(Icons.image_rounded, color: Colors.white38)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${g.count} copies · ${_fmtSize(g.size)} each',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  '${_fmtSize(waste)} wasted',
                  style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(g.files.first.name,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              if (_deleting)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger))
              else
                GestureDetector(
                  onTap: _deleteGroup,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                    ),
                    child: Text('Keep 1', style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
            ]),
          ),
        ),

        // Expanded files list
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ALL COPIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: g.files.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _FileChip(file: g.files[i], isDark: isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.file, required this.isDark});
  final _DupFile file;
  final bool     isDark;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: file.thumb != null
              ? Image.memory(file.thumb!, width: 72, height: 72, fit: BoxFit.cover)
              : Container(width: 72, height: 72, color: Colors.grey.shade800,
                  child: const Icon(Icons.image_rounded, color: Colors.white38)),
        ),
        if (file.keep)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: const Center(child: Text('KEEP', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      SizedBox(
        width: 72,
        child: Text(
          file.isSent ? '📤 Sent' : '📥 Recv',
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    ]);
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _DupGroup {
  const _DupGroup({required this.md5, required this.count, required this.size, required this.files});
  final String        md5;
  final int           count, size;
  final List<_DupFile> files;
}

class _DupFile {
  const _DupFile({
    required this.path, required this.name, required this.size,
    required this.modified, required this.isSent, required this.keep, required this.thumb,
  });
  final String     path, name;
  final int        size;
  final DateTime   modified;
  final bool       isSent, keep;
  final Uint8List? thumb;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtSize(int bytes) {
  if (bytes < 1024)       return '$bytes B';
  if (bytes < 1048576)    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}
