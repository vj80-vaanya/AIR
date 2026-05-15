import 'package:flutter/foundation.dart';

import 'onnx_classifier.dart';
import 'pattern_matcher.dart';
import 'wordpiece_tokenizer.dart';

/// Result of a threat assessment.
class ThreatResult {
  const ThreatResult({
    required this.riskScore,
    required this.category,
    required this.reason,
    required this.shouldBlock,
    required this.confidence,
  });

  final int    riskScore;   // 0–100
  final String category;    // e.g. 'BANKING_FRAUD', 'SPAM', 'SAFE'
  final String reason;
  final bool   shouldBlock;
  final double confidence;  // 0.0–1.0

  Map<String, dynamic> toMap() => {
    'riskScore':   riskScore,
    'category':    category,
    'reason':      reason,
    'shouldBlock': shouldBlock,
    'confidence':  confidence,
  };

  static const safe = ThreatResult(
    riskScore:   0,
    category:    'SAFE',
    reason:      'No threats detected',
    shouldBlock: false,
    confidence:  0.95,
  );
}

/// Pure-Dart security engine. No FFI, no native code.
/// Pattern matching always runs; ML inference used when model is loaded.
class SecurityEngine {
  SecurityEngine._();
  static final SecurityEngine instance = SecurityEngine._();

  WordPieceTokenizer? _tokenizer;
  OnnxClassifier?     _classifier;
  bool                _mlReady = false;

  Future<void> init() async {
    try {
      _tokenizer  = await WordPieceTokenizer.load();
      _classifier = await OnnxClassifier.load();
      _mlReady    = _classifier != null;
      debugPrint('[SecurityEngine] ML ready: $_mlReady');
    } catch (e) {
      debugPrint('[SecurityEngine] Init error (pattern-only mode): $e');
      _mlReady = false;
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<ThreatResult> analyzeCall({
    required String phoneNumber,
    String callerId       = '',
    bool   isKnownContact = false,
  }) async {
    if (isKnownContact) return ThreatResult.safe;

    int    score    = 0;
    String category = 'SAFE';

    // High-risk international prefixes common in Indian scam calls
    const riskPrefixes = ['+92', '+880', '+60', '+66', '+856', '+855', '0092'];
    for (final p in riskPrefixes) {
      if (phoneNumber.startsWith(p)) {
        score    = 70;
        category = 'SUSPICIOUS_CALL';
        break;
      }
    }

    // Unknown / private number
    if (callerId.isEmpty ||
        callerId.toLowerCase() == 'unknown' ||
        callerId.toLowerCase() == 'private') {
      score    = (score + 20).clamp(0, 100);
      category = score > 0 ? category : 'UNVERIFIED';
    }

    // Abnormal length (not a valid Indian/international number)
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 14) {
      score    = (score + 25).clamp(0, 100);
      category = 'SUSPICIOUS_CALL';
    }

    return ThreatResult(
      riskScore:   score,
      category:    category,
      reason:      score > 0 ? 'Suspicious caller attributes detected' : 'No issues found',
      shouldBlock: score >= 85,
      confidence:  0.75,
    );
  }

  Future<ThreatResult> analyzeSms({
    required String sender,
    required String body,
    bool   containsUrl   = false,
    String extractedUrl  = '',
  }) async {
    return _analyzeText(body, containsUrl: containsUrl);
  }

  Future<ThreatResult> analyzeText(String text) => _analyzeText(text);

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<ThreatResult> _analyzeText(String text, {bool containsUrl = false}) async {
    final pattern = PatternMatcher.analyze(text);

    double mlScore  = 0.0;
    bool   mlUsed   = false;

    if (_mlReady && text.trim().isNotEmpty) {
      final tokens = _tokenizer!.tokenize(text);
      mlScore = await _classifier!.classify(tokens);
      mlUsed  = true;
    }

    // URL in message adds to score
    final urlBonus = containsUrl ? 15 : 0;

    // Combine: pattern 55 % + ML 35 % + URL 10 %
    final int combined = mlUsed
        ? (pattern.score * 0.55 + mlScore * 100 * 0.35 + urlBonus * 0.10).round()
        : (pattern.score * 0.90 + urlBonus * 0.10).round();

    final clamped  = combined.clamp(0, 100);
    final category = _resolveCategory(pattern, mlScore, mlUsed);

    return ThreatResult(
      riskScore:   clamped,
      category:    category,
      reason:      _buildReason(pattern.score, mlScore, mlUsed),
      shouldBlock: clamped >= 75,
      confidence:  mlUsed ? 0.85 : 0.70,
    );
  }

  String _resolveCategory(PatternResult p, double mlScore, bool mlUsed) {
    if (p.category != 'SAFE') return p.category;
    if (mlUsed && mlScore >= 0.65) return 'SPAM';
    return 'SAFE';
  }

  String _buildReason(int patternScore, double mlScore, bool mlUsed) {
    final parts = <String>[];
    if (patternScore > 0) parts.add('pattern match ($patternScore/100)');
    if (mlUsed) parts.add('ML score ${(mlScore * 100).round()}%');
    return parts.isEmpty ? 'No threats detected' : parts.join(', ');
  }
}
