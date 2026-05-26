class UrlSafetyEngine {
  /// Heuristic analysis of a URL to detect phishing without a cloud database.
  static int analyzeUrl(String url) {
    int risk = 0;
    final lower = url.toLowerCase();

    // 1. Punycode/Homograph attack check
    if (url.contains('xn--')) risk += 50;

    // 2. IP-based URLs (often malicious)
    final ipRegex = RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}');
    if (ipRegex.hasMatch(url)) risk += 40;

    // 3. Domain Spoofing (e.g., sbi-verification.com instead of sbi.co.in)
    final suspiciousKeywords = ['verify', 'update', 'secure', 'login', 'account', 'kyc', 'support'];
    final knownBrands = ['sbi', 'hdfc', 'icici', 'axis', 'paytm', 'amazon', 'flipkart'];
    
    for (final brand in knownBrands) {
      if (lower.contains(brand)) {
        // If it contains a brand name but isn't the official TLD
        if (!lower.contains('.co.in') && !lower.contains('.com') && !lower.contains('.in')) {
          risk += 30;
        }
        // Brand + suspicious keyword (e.g., sbi-kyc-update.net)
        for (final kw in suspiciousKeywords) {
          if (lower.contains(kw)) risk += 20;
        }
      }
    }

    // 4. URL Shorteners (risk factor)
    final shorteners = ['bit.ly', 't.co', 'tinyurl.com', 'is.gd', 'goo.gl'];
    for (final s in shorteners) {
      if (lower.contains(s)) risk += 15;
    }

    return risk.clamp(0, 100);
  }
}
