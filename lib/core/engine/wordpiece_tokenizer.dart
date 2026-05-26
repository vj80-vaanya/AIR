import 'dart:convert';
import 'package:flutter/services.dart';

/// WordPiece tokenizer matching the HuggingFace bert-tiny vocab.
/// Reads assets/data/vocab.txt (30 522 lines) once and caches in memory.
class WordPieceTokenizer {
  static const int _seqLen = 64;
  static const int _clsId  = 101;
  static const int _sepId  = 102;
  static const int _padId  = 0;
  static const int _unkId  = 100;

  final Map<String, int> _vocab;

  WordPieceTokenizer._(this._vocab);

  static Future<WordPieceTokenizer> load() async {
    final raw   = await rootBundle.loadString('assets/data/vocab.txt');
    final lines = const LineSplitter().convert(raw);
    final vocab = <String, int>{};
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].isNotEmpty) vocab[lines[i]] = i;
    }
    return WordPieceTokenizer._(vocab);
  }

  /// Returns a fixed-length int list of token IDs, padded to [_seqLen].
  List<int> tokenize(String text) {
    final ids = <int>[_clsId];

    for (final word in _splitWords(text.toLowerCase())) {
      if (word.isEmpty) continue;
      ids.addAll(_wordpiece(word));
      if (ids.length >= _seqLen - 1) break;
    }

    ids.add(_sepId);
    while (ids.length < _seqLen) ids.add(_padId);
    return ids.take(_seqLen).toList();
  }

  List<String> _splitWords(String text) =>
      text.split(RegExp(r'[\s.,!?;:()\[\]{}<>/\\@#$%^&*+=|~`]+'));

  List<int> _wordpiece(String word) {
    if (_vocab.containsKey(word)) return [_vocab[word]!];

    final out   = <int>[];
    int   start = 0;

    while (start < word.length) {
      int    end   = word.length;
      int?   found;

      while (start < end) {
        final sub = start == 0
            ? word.substring(start, end)
            : '##${word.substring(start, end)}';
        if (_vocab.containsKey(sub)) {
          found = _vocab[sub];
          break;
        }
        end--;
      }

      if (found == null) return [_unkId];
      out.add(found);
      start = end;
    }

    return out;
  }
}
