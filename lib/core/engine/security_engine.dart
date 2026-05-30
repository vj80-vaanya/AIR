import 'package:flutter/foundation.dart';

import '../utils/crypto_utils.dart';
import '../utils/text_normalizer.dart';
import 'behavioral_analyzer.dart';
import 'financial_safety_interceptor.dart';
import 'onnx_classifier.dart';
import 'pattern_matcher.dart';
import 'reputation_manager.dart';
import 'url_safety_engine.dart';
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
  
  final _reputationManager = SenderReputationManager();
  
  // Recent threat memory (Last 15 minutes)
  final List<ThreatResult> _recentCriticalThreats = [];

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

    final senderHash = CryptoUtils.hashPhoneNumber(phoneNumber);
    final botRisk = await _reputationManager.updateCallReputation(senderHash);

    int    score    = (botRisk * 100).round();
    String category = botRisk > 0 ? 'ROBOCALL_BOT' : 'SAFE';
    // High-risk international prefixes common in Indian scam calls
    const riskPrefixes = ['+92', '+880', '+60', '+66', '+856', '+855', '0092'];
    for (final p in riskPrefixes) {
      if (phoneNumber.startsWith(p)) {
        score    = (score + 50).clamp(0, 100);
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

  Future<ThreatResult> analyzeNotification({
    required String package,
    required String sender,
    required String body,
  }) async {
    // 1. Zero-Knowledge Sender Identification
    final senderHash = CryptoUtils.hashPhoneNumber(sender);
    final velocityRisk = await _reputationManager.updateReputation(senderHash);

    // 2. Base text analysis
    final result = await _analyzeText(body);
    
    double smartScore = result.riskScore.toDouble();
    String smartReason = result.reason;

    // 3. Platform & Velocity Intelligence
    if (velocityRisk > 0) {
      smartScore += (velocityRisk * 100);
      smartReason += ' + High message velocity (Bot activity)';
    }

    if (package == 'com.whatsapp') {
      if (sender.toLowerCase().contains('business') || sender.toLowerCase().contains('official')) {
        if (result.riskScore > 40) {
           smartScore += 15;
           smartReason += ' + Platform risk (Unverified Business)';
        }
      }
    } else if (package == 'org.telegram.messenger') {
      if (body.toLowerCase().contains('crypto') || body.toLowerCase().contains('invest')) {
        smartScore += 20;
        smartReason += ' + High-risk Telegram vector';
      }
    }

    return ThreatResult(
      riskScore:   smartScore.round().clamp(0, 100),
      category:    result.category,
      reason:      smartReason,
      shouldBlock: smartScore >= 80,
      confidence:  result.confidence,
    );
  }

  Future<ThreatResult> analyzeText(String text) => _analyzeText(text);

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<ThreatResult> _analyzeText(String text, {bool containsUrl = false}) async {
    // Tier 1: Adversarial Normalization & Pattern Matching (Fast)
    final normalized = TextNormalizer.normalize(text);
    final pattern = PatternMatcher.analyze(normalized);
    final tone    = BehavioralAnalyzer.analyzeTone(text);
    final socialEng = FinancialSafetyInterceptor.analyzeSocialEngineering(text);
    
    int urlRisk = 0;
    if (containsUrl || text.contains('http')) {
       // Extract URL simple heuristic
       final urlMatch = RegExp(r'(https?:\/\/|www\.)[^\s]+').firstMatch(text);
       if (urlMatch != null) {
         urlRisk = UrlSafetyEngine.analyzeUrl(urlMatch.group(0)!);
       }
    }

    // Tier 2: AI Inference (Heuristic-triggered)
    double mlScore  = 0.0;
    bool   mlUsed   = false;

    // Only run ML if Tier 1 is ambiguous (score between 20 and 85)
    final tier1Score = pattern.score + socialEng;
    if (_mlReady && tier1Score > 20 && tier1Score < 85) {
      final tokens = _tokenizer!.tokenize(text);
      mlScore = await _classifier!.classify(tokens);
      mlUsed  = true;
    }

    // Dynamic Scoring Intelligence:
    double combinedScore = 0.0;

    if (mlUsed) {
      combinedScore = (pattern.score * 0.3 + mlScore * 100 * 0.4 + socialEng * 0.2 + tone * 0.1).roundToDouble();
    } else {
      combinedScore = (pattern.score * 0.5 + socialEng * 0.3 + tone * 0.2).toDouble();
    }

    // High-impact URL or Entity boost
    if (urlRisk > 50) combinedScore += 25;
    if (pattern.hasSuspiciousEntities) combinedScore += 10;

    final clamped  = combinedScore.round().clamp(0, 100);
    final category = _resolveCategory(pattern, mlScore, mlUsed, socialEng);

    return ThreatResult(
      riskScore:   clamped,
      category:    category,
      reason:      _buildReason(pattern, mlScore, mlUsed, socialEng, urlRisk),
      shouldBlock: clamped >= 75,
      confidence:  mlUsed ? 0.92 : 0.80,
    );
  }

  void recordThreat(ThreatResult result) {
    if (result.riskScore >= 80) {
      _recentCriticalThreats.add(result);
      // Auto-cleanup after 15 minutes
      Future.delayed(const Duration(minutes: 15), () {
        _recentCriticalThreats.remove(result);
      });
    }
  }

  bool hasRecentCriticalThreat() {
    return _recentCriticalThreats.isNotEmpty;
  }

  ThreatResult? getMostRecentThreat() {
    return _recentCriticalThreats.isNotEmpty ? _recentCriticalThreats.last : null;
  }

  String _resolveCategory(PatternResult p, double mlScore, bool mlUsed, int socialEng) {
    if (socialEng > 50) return 'FINANCIAL_FRAUD_ATTEMPT';
    if (p.category != 'SAFE') return p.category;
    if (mlUsed && mlScore >= 0.75) return 'AI_DETECTED_SPAM';
    return 'SAFE';
  }

  String _buildReason(PatternResult p, double mlScore, bool mlUsed, int socialEng, int urlRisk) {
    if (p.category == 'DIGITAL_ARREST') {
       return 'CRITICAL: Potential "Digital Arrest" scam. Note: Digital Arrest does not legally exist in India. Do not join video calls from unknown officials.';
    }
    if (p.category == 'INVESTMENT_SCAM') {
       return 'WARNING: Potential Stock/Investment Trap. Beware of "guaranteed returns" or "insider tips" from unverified groups.';
    }
    if (p.category == 'ACCOUNT_HIJACK') {
       return 'CRITICAL: WhatsApp Hijacking Attempt. Never "rent" your account or scan QR codes from strangers to earn money.';
    }
    final parts = <String>[];
    if (socialEng > 0) parts.add('financial social engineering detected');
    if (urlRisk > 40) parts.add('malicious URL heuristic match');
    if (p.score > 0) parts.add('intent match (${p.category})');
    if (mlUsed) parts.add('AI confidence ${(mlScore * 100).round()}%');
    return parts.isEmpty ? 'No threats detected' : parts.join(' + ');
  }
}
