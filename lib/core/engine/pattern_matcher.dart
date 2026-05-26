/// Rule-based scam pattern matching — pure Dart, no native code.
/// Covers Indian scam categories: banking fraud, lottery, govt impersonation,
/// delivery scams, and high-urgency phishing.
class PatternMatcher {
  static final _upiRegex   = RegExp(r'[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}');
  static final _urlRegex   = RegExp(r'(https?:\/\/|www\.)[^\s]+');
  static final _phoneRegex = RegExp(r'(\+91[\-\s]?)?[6-9]\d{9}');

  static const _rules = <_Rule>[
    // Banking fraud & Hinglish equivalents
    _Rule('your account has been suspended',  'BANKING_FRAUD',        90),
    _Rule('kyc update',                       'BANKING_FRAUD',        88),
    _Rule('pan card',                         'BANKING_FRAUD',        75),
    _Rule('aadhaar update',                   'BANKING_FRAUD',        85),
    _Rule('your sim will be blocked',         'BANKING_FRAUD',        92),
    _Rule('electricity bill pending',         'BILL_SCAM',            88),
    _Rule('bijli bill',                       'BILL_SCAM',            90), // Hinglish

    // Lottery / prize & Hinglish
    _Rule('congratulations you have won',     'LOTTERY',              95),
    _Rule('mubarak ho',                       'LOTTERY',              90), // Hinglish: Congratulations
    _Rule('inam jeeta hai',                   'LOTTERY',              92), // Hinglish: Won a prize
    _Rule('kbc lottery',                      'LOTTERY',              96),
    _Rule('lucky draw',                       'LOTTERY',              85),

    // Urgency markers
    _Rule('immediately',                      'URGENCY',              30),
    _Rule('turant',                           'URGENCY',              40), // Hinglish: Immediately
    _Rule('aaj hi',                           'URGENCY',              35), // Hinglish: Today itself
    _Rule('last date',                        'URGENCY',              45),
    _Rule('within 24 hours',                  'URGENCY',              50),

    // Digital Arrest & Law Enforcement Impersonation
    _Rule('digital arrest',                   'DIGITAL_ARREST',       98),
    _Rule('cbi',                              'DIGITAL_ARREST',       85),
    _Rule('narcotics',                        'DIGITAL_ARREST',       88),
    _Rule('mumbai police',                    'DIGITAL_ARREST',       85),
    _Rule('illegal parcel',                   'DIGITAL_ARREST',       90),
    _Rule('video call verification',          'DIGITAL_ARREST',       92),
    _Rule('supreme court',                    'DIGITAL_ARREST',       80),
    _Rule('arrest warrant',                   'DIGITAL_ARREST',       95),

    // Stock Market & Investment Traps
    _Rule('insider tips',                     'INVESTMENT_SCAM',      85),
    _Rule('guaranteed returns',               'INVESTMENT_SCAM',      90),
    _Rule('stock market profit',              'INVESTMENT_SCAM',      75),
    _Rule('trading group',                    'INVESTMENT_SCAM',      70),
    _Rule('crypto investment',                'INVESTMENT_SCAM',      82),
    _Rule('earn daily',                       'INVESTMENT_SCAM',      65),

    // WhatsApp Hijacking & Mule Account Scams
    _Rule('rent your whatsapp',               'ACCOUNT_HIJACK',       95),
    _Rule('scan qr to earn',                  'ACCOUNT_HIJACK',       92),
    _Rule('whatsapp account renting',         'ACCOUNT_HIJACK',       98),
    _Rule('automatic earnings',               'ACCOUNT_HIJACK',       80),
  ];

  static PatternResult analyze(String text) {
    final lower = text.toLowerCase();
    int score = 0;
    String category = 'SAFE';
    int urgencyScore = 0;

    // 1. Keyword analysis
    for (final rule in _rules) {
      if (lower.contains(rule.keyword)) {
        if (rule.category == 'URGENCY') {
          urgencyScore += rule.weight;
        } else if (rule.weight > score) {
          score = rule.weight;
          category = rule.category;
        }
      }
    }

    // 2. Entity extraction "Smartness"
    final hasUpi   = _upiRegex.hasMatch(text);
    final hasUrl   = _urlRegex.hasMatch(text);
    final hasPhone = _phoneRegex.hasMatch(text);

    // Boost score if suspicious entities coexist with scam keywords
    if (score > 0) {
      if (hasUpi) score += 15;
      if (hasUrl) score += 10;
      if (urgencyScore > 40) score += 15;
    }

    // Special case: UPI ID in a message about "electricity bill" or "lottery"
    if (hasUpi && (category == 'BILL_SCAM' || category == 'LOTTERY')) {
       score = (score + 25).clamp(0, 100);
    }

    return PatternResult(
      score: score.clamp(0, 100),
      category: category,
      hasSuspiciousEntities: hasUpi || hasUrl,
    );
  }
}

class PatternResult {
  const PatternResult({
    required this.score,
    required this.category,
    this.hasSuspiciousEntities = false,
  });
  final int    score;
  final String category;
  final bool   hasSuspiciousEntities;
}

class _Rule {
  const _Rule(this.keyword, this.category, this.weight);
  final String keyword;
  final String category;
  final int    weight;
}
