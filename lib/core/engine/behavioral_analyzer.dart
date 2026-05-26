class BehavioralAnalyzer {
  static const _urgencyMarkers = [
    'immediately', 'urgent', 'now', 'today', '24 hours', 'blocked', 'suspended',
    'turant', 'aaj hi', 'jaldi', 'band ho jayega', 'khatam'
  ];

  static const _authorityMarkers = [
    'police', 'court', 'bank', 'official', 'trai', 'rbi', 'income tax',
    'department', 'government', 'officer', 'cbi', 'narcotics', 'ed', 'investigation',
    'supreme court', 'warrant', 'arrest'
  ];

  /// Returns a score from 0-100 based on the "scam tone" of the message.
  static int analyzeTone(String text) {
    final lower = text.toLowerCase();
    int score = 0;

    // Check for urgency
    int urgencyCount = 0;
    for (final marker in _urgencyMarkers) {
      if (lower.contains(marker)) urgencyCount++;
    }
    score += (urgencyCount * 15);

    // Check for false authority
    int authorityCount = 0;
    for (final marker in _authorityMarkers) {
      if (lower.contains(marker)) authorityCount++;
    }
    score += (authorityCount * 10);

    // Scammers often use ALL CAPS for urgency
    if (text == text.toUpperCase() && text.length > 10) {
      score += 20;
    }

    return score.clamp(0, 100);
  }
}
