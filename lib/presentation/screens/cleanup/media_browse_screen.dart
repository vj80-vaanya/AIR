import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';

class MediaBrowseScreen extends StatefulWidget {
  final String category;
  final String label;
  final Color  accentColor;

  const MediaBrowseScreen({
    super.key,
    required this.category,
    required this.label,
    required this.accentColor,
  });

  @override
  State<MediaBrowseScreen> createState() => _MediaBrowseScreenState();
}

class _MediaBrowseScreenState extends State<MediaBrowseScreen> {
  static const _ch       = MethodChannel('ai_security/media_cleanup');
  static const _pageSize = 20;

  final List<_MediaFile>       _files     = [];
  final Set<String>            _selected  = {};
  final Map<String, Uint8List?> _thumbs   = {};  // path → decoded thumb (null = tried, failed)

  bool    _loading  = true;
  bool    _hasMore  = true;
  bool    _deleting = false;
  int     _offset   = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  // ── Phase 1: load metadata (instant) ──────────────────────────────────────

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() { _loading = true; });
    try {
      final raw = await _ch.invokeListMethod<Object>('getFilesMeta', {
        'category': widget.category,
        'offset':   _offset,
        'limit':    _pageSize,
      });
      final batch = (raw ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _MediaFile(
          path:     m['path']     as String,
          name:     m['name']     as String,
          size:     m['size']     as int,
          modified: DateTime.fromMillisecondsSinceEpoch(m['modified'] as int),
          mimeType: m['mimeType'] as String? ?? '',
          isSent:   m['isSent']  as bool?   ?? false,
        );
      }).toList();

      setState(() {
        _files.addAll(batch);
        _offset  += batch.length;
        _hasMore  = batch.length == _pageSize;
        _loading  = false;
      });

      // Phase 2: load thumbnails in background
      _loadThumbs(batch.map((f) => f.path).toList());
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Phase 2: load thumbnails — images first (fast), then videos ──────────

  Future<void> _loadThumbs(List<String> paths) async {
    if (paths.isEmpty || !mounted) return;

    final imagePaths = paths.where(_isImagePath).toList();
    final videoPaths = paths.where(_isVideoPath).toList();

    // Images first — usually fast even uncached
    if (imagePaths.isNotEmpty) {
      try {
        final raw = await _ch.invokeMapMethod<String, dynamic>('getThumbnailBatch', {'paths': imagePaths});
        if (!mounted) return;
        setState(() {
          raw?.forEach((path, b64) {
            _thumbs[path] = b64 != null ? base64Decode(b64 as String) : null;
          });
        });
      } catch (_) {}
    }

    // Videos second — may take longer on first generation
    if (videoPaths.isNotEmpty && mounted) {
      try {
        final raw = await _ch.invokeMapMethod<String, dynamic>('getThumbnailBatch', {'paths': videoPaths});
        if (!mounted) return;
        setState(() {
          raw?.forEach((path, b64) {
            _thumbs[path] = b64 != null ? base64Decode(b64 as String) : null;
          });
        });
      } catch (_) {}
    }
  }

  static bool _isImagePath(String p) {
    final ext = p.toLowerCase().split('.').last;
    return const {'jpg','jpeg','png','gif','bmp','webp'}.contains(ext);
  }

  static bool _isVideoPath(String p) {
    final ext = p.toLowerCase().split('.').last;
    return const {'mp4','3gp','mkv','mov','avi','webm'}.contains(ext);
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void _toggleSelect(String path) => setState(() {
    if (_selected.contains(path)) _selected.remove(path);
    else _selected.add(path);
  });

  void _selectAll()    => setState(() => _selected.addAll(_files.map((f) => f.path)));
  void _clearSelection() => setState(() => _selected.clear());

  // ── Deletion ───────────────────────────────────────────────────────────────

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final count     = _selected.length;
    final totalSize = _files.where((f) => _selected.contains(f.path)).fold<int>(0, (s, f) => s + f.size);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   Text('Delete $count file${count == 1 ? '' : 's'}?'),
        content: Text('This will free ${_fmtSize(totalSize)}. Cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style:    FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    if (!ok || !mounted) return;

    setState(() { _deleting = true; });
    try {
      final res = await _ch.invokeMapMethod<String, dynamic>('deleteFiles', {'paths': _selected.toList()});
      final freed = (res?['freed'] as int?) ?? 0;
      HapticFeedback.mediumImpact();
      setState(() {
        _files.removeWhere((f) => _selected.contains(f.path));
        _selected.toList().forEach((p) => _thumbs.remove(p));
        _selected.clear();
        _deleting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Freed ${_fmtSize(freed)}'),
          backgroundColor: AppColors.secondary,
        ));
      }
    } catch (e) {
      setState(() { _deleting = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sel    = _selected.length;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: sel > 0
            ? Text('$sel selected', style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.w700))
            : Text(widget.label),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (sel > 0) ...[
            TextButton(onPressed: _clearSelection, child: const Text('Cancel')),
            TextButton(
              onPressed: _deleteSelected,
              child: Text('Delete ($sel)', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ] else if (_files.isNotEmpty)
            TextButton(onPressed: _selectAll, child: const Text('Select all')),
        ],
      ),
      body: _buildBody(isDark),
      bottomNavigationBar: sel > 0
          ? _BottomBar(count: sel, onDelete: _deleteSelected, color: widget.accentColor)
          : null,
    );
  }

  Widget _buildBody(bool isDark) {
    if (_deleting) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: AppColors.danger),
        SizedBox(height: 16),
        Text('Deleting files…', style: TextStyle(fontWeight: FontWeight.w600)),
      ]));
    }
    if (_error != null && _files.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, size: 56, color: AppColors.warning),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () { _offset = 0; _hasMore = true; _files.clear(); _loadMore(); }, child: const Text('Retry')),
        ]),
      ));
    }
    if (!_loading && _files.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded, size: 72, color: widget.accentColor.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text('Nothing here', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('All clean!', style: TextStyle(color: AppColors.textSecondary)),
      ]));
    }

    final isVisual = ['images','videos','large_files','old_media','forwarded','duplicates']
        .contains(widget.category);

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${_files.length} files${_hasMore ? '+' : ''} · sorted by size',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ),
      if (isVisual)
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= _files.length) {
                  return _hasMore
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton(onPressed: _loadMore, child: const Text('Load more')),
                        ))
                      : const SizedBox.shrink();
                }
                final f     = _files[i];
                final thumb = _thumbs.containsKey(f.path) ? _thumbs[f.path] : _kLoading;
                return _ThumbCell(
                  file:        f,
                  thumb:       thumb,
                  selected:    _selected.contains(f.path),
                  color:       widget.accentColor,
                  onTap:       () => _selected.isEmpty ? _showPreview(f) : _toggleSelect(f.path),
                  onLongPress: () => _toggleSelect(f.path),
                );
              },
              childCount: _files.length + (_hasMore ? 1 : 0),
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              if (i >= _files.length) {
                return _hasMore
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton(onPressed: _loadMore, child: const Text('Load more')),
                      ))
                    : const SizedBox.shrink();
              }
              final f = _files[i];
              return _ListCell(
                file:        f,
                selected:    _selected.contains(f.path),
                color:       widget.accentColor,
                onTap:       () => _toggleSelect(f.path),
                onLongPress: () => _toggleSelect(f.path),
              );
            },
            childCount: _files.length + (_hasMore ? 1 : 0),
          ),
        ),
      if (_loading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
    ]);
  }

  // Sentinel to distinguish "not yet loaded" from "loaded but null"
  static final _kLoading = Uint8List(0);

  void _showPreview(_MediaFile f) {
    final thumb = _thumbs[f.path];
    if (thumb == null || thumb.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(child: Center(child: Image.memory(thumb))),
          Positioned(top: 40, right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )),
          Positioned(bottom: 24, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Text('${f.name}  ·  ${_fmtSize(f.size)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ))),
        ]),
      ),
    );
  }
}

// ── Thumbnail cell ────────────────────────────────────────────────────────────

class _ThumbCell extends StatelessWidget {
  const _ThumbCell({
    required this.file, required this.thumb, required this.selected,
    required this.color, required this.onTap, required this.onLongPress,
  });
  final _MediaFile   file;
  final Uint8List?   thumb;   // null=failed, empty=loading, non-empty=ready
  final bool         selected;
  final Color        color;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final isVideo = file.mimeType.startsWith('video/') ||
        file.path.toLowerCase().contains('.mp4') ||
        file.path.toLowerCase().contains('.3gp');
    final isLoading = thumb != null && thumb!.isEmpty;
    final hasThumb  = thumb != null && thumb!.isNotEmpty;

    return GestureDetector(
      onTap:       onTap,
      onLongPress: onLongPress,
      child: Stack(fit: StackFit.expand, children: [
        // Background / thumbnail
        if (hasThumb)
          Image.memory(thumb!, fit: BoxFit.cover)
        else if (isLoading)
          Container(
            color: Colors.grey.shade900,
            child: const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30))),
          )
        else
          Container(
            color: Colors.grey.shade800,
            child: Icon(_iconFor(file.mimeType), color: Colors.white38, size: 36),
          ),

        // Video play overlay
        if (isVideo)
          Center(child: Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          )),

        // Size badge
        Positioned(bottom: 4, right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
            child: Text(_fmtSize(file.size),
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
          )),

        // Selection overlay + checkbox
        if (selected) Container(color: color.withOpacity(0.45)),
        Positioned(top: 6, right: 6,
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color:  selected ? color : Colors.black38,
              shape:  BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: selected ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
          )),
      ]),
    );
  }
}

// ── List cell (non-visual types) ──────────────────────────────────────────────

class _ListCell extends StatelessWidget {
  const _ListCell({
    required this.file, required this.selected, required this.color,
    required this.onTap, required this.onLongPress,
  });
  final _MediaFile   file;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap, onLongPress: onLongPress,
      child: Container(
        margin:  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : (isDark ? AppColors.borderDark : AppColors.border)),
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(_iconFor(file.mimeType), color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(file.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${_fmtSize(file.size)}  ·  ${_fmtDate(file.modified)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ])),
          if (selected)
            Icon(Icons.check_circle_rounded, color: color, size: 22)
          else
            const Icon(Icons.radio_button_unchecked, color: AppColors.textDisabled, size: 22),
        ]),
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.count, required this.onDelete, required this.color});
  final int count; final VoidCallback onDelete; final Color color;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: FilledButton.icon(
        onPressed: onDelete,
        icon:  const Icon(Icons.delete_rounded),
        label: Text('Delete $count file${count == 1 ? '' : 's'}'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
  );
}

// ── Data model ────────────────────────────────────────────────────────────────

class _MediaFile {
  const _MediaFile({
    required this.path, required this.name, required this.size,
    required this.modified, required this.mimeType, required this.isSent,
  });
  final String   path, name, mimeType;
  final int      size;
  final DateTime modified;
  final bool     isSent;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

IconData _iconFor(String mime) {
  if (mime.startsWith('image/')) return Icons.image_rounded;
  if (mime.startsWith('video/')) return Icons.videocam_rounded;
  if (mime.startsWith('audio/')) return Icons.headset_rounded;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_rounded;
  return Icons.insert_drive_file_rounded;
}

String _fmtSize(int bytes) {
  if (bytes < 1024)       return '$bytes B';
  if (bytes < 1048576)    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}

String _fmtDate(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays == 0)   return 'Today';
  if (diff.inDays == 1)   return 'Yesterday';
  if (diff.inDays < 30)   return '${diff.inDays}d ago';
  if (diff.inDays < 365)  return '${(diff.inDays / 30).round()}mo ago';
  return '${(diff.inDays / 365).round()}yr ago';
}
