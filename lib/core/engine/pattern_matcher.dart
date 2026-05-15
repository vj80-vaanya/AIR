/// Rule-based scam pattern matching — pure Dart, no native code.
/// Covers Indian scam categories: banking fraud, lottery, govt impersonation,
/// delivery scams, and high-urgency phishing.
class PatternMatcher {
  static const _rules = <_Rule>[
    // Banking fraud
    _Rule('your account has been suspended',  'BANKING_FRAUD',        90),
    _Rule('account will be blocked',          'BANKING_FRAUD',        85),
    _Rule('account has been blocked',         'BANKING_FRAUD',        88),
    _Rule('kyc verification is incomplete',   'BANKING_FRAUD',        88),
    _Rule('kyc update',                       'BANKING_FRAUD',        78),
    _Rule('kyc is incomplete',                'BANKING_FRAUD',        85),
    _Rule('upi pin has expired',              'BANKING_FRAUD',        88),
    _Rule('share your otp',                   'BANKING_FRAUD',        96),
    _Rule('send otp',                         'BANKING_FRAUD',        95),
    _Rule('do not share otp',                 'SAFE',                 -10),
    _Rule('account has been compromised',     'BANKING_FRAUD',        88),
    _Rule('verify your details',              'BANKING_FRAUD',        80),
    _Rule('bank details to claim',            'BANKING_FRAUD',        90),
    _Rule('enter new pin',                    'BANKING_FRAUD',        85),
    _Rule('sbi account suspended',            'BANKING_FRAUD',        90),
    _Rule('hdfc account',                     'BANKING_FRAUD',        68),
    _Rule('unblock your account',             'BANKING_FRAUD',        85),
    _Rule('click here to unblock',            'BANKING_FRAUD',        88),

    // Lottery / prize
    _Rule('congratulations you have won',     'LOTTERY',              95),
    _Rule('you have been selected',           'LOTTERY',              80),
    _Rule('lucky draw',                       'LOTTERY',              85),
    _Rule('claim your prize',                 'LOTTERY',              90),
    _Rule('lottery winner',                   'LOTTERY',              95),
    _Rule('processing fee to claim',          'LOTTERY',              92),
    _Rule('rs 1 lakh',                        'LOTTERY',              72),
    _Rule('gift voucher',                     'LOTTERY',              70),
    _Rule('free gift',                        'LOTTERY',              68),
    _Rule('win now',                          'LOTTERY',              75),

    // Government impersonation
    _Rule('aadhaar blocked',                  'GOVT_IMPERSONATION',   90),
    _Rule('aadhaar card is blocked',          'GOVT_IMPERSONATION',   92),
    _Rule('income tax department',            'GOVT_IMPERSONATION',   85),
    _Rule('income tax refund',                'GOVT_IMPERSONATION',   88),
    _Rule('police complaint filed',           'GOVT_IMPERSONATION',   90),
    _Rule('avoid arrest',                     'GOVT_IMPERSONATION',   96),
    _Rule('settle payment to avoid',          'GOVT_IMPERSONATION',   94),
    _Rule('trai',                             'GOVT_IMPERSONATION',   80),
    _Rule('your mobile number will be blocked', 'GOVT_IMPERSONATION', 88),

    // Delivery scam
    _Rule('your parcel is held',              'DELIVERY_SCAM',        80),
    _Rule('customs duty',                     'DELIVERY_SCAM',        82),
    _Rule('package on hold',                  'DELIVERY_SCAM',        78),
    _Rule('delivery failed',                  'DELIVERY_SCAM',        65),

    // Urgency / phishing
    _Rule('click here to claim',              'URGENCY',              85),
    _Rule('call immediately',                 'URGENCY',              75),
    _Rule('urgent',                           'URGENCY',              60),
    _Rule('limited time',                     'URGENCY',              65),
    _Rule('expires today',                    'URGENCY',              70),
    _Rule('act now',                          'URGENCY',              72),
    _Rule('bit.ly',                           'URGENCY',              80),
    _Rule('tinyurl',                          'URGENCY',              78),
  ];

  static PatternResult analyze(String text) {
    final lower = text.toLowerCase();
    int score = 0;
    String category = 'SAFE';

    for (final rule in _rules) {
      if (lower.contains(rule.keyword)) {
        if (rule.weight < 0) {
          // Negative rules reduce score (e.g. "do not share otp" is legitimate)
          score = (score + rule.weight).clamp(0, 100);
        } else if (rule.weight > score) {
          score = rule.weight;
          category = rule.category;
        }
      }
    }

    return PatternResult(score: score, category: category);
  }
}

class PatternResult {
  const PatternResult({required this.score, required this.category});
  final int    score;    // 0–100
  final String category; // e.g. 'BANKING_FRAUD', 'SAFE'
}

class _Rule {
  const _Rule(this.keyword, this.category, this.weight);
  final String keyword;
  final String category;
  final int    weight;
}
