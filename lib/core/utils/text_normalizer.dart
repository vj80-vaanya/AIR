class TextNormalizer {
  /// Normalizes text to prevent bypasses like "S.B.I" or "K.Y.C".
  /// Handles common character substitutions used by scammers.
  static String normalize(String text) {
    var normalized = text.toLowerCase();

    // 1. Remove common separators scammers use to break words
    normalized = normalized.replaceAll(RegExp(r'[.\-_\s*#@]'), '');

    // 2. Homoglyph/Character substitution mapping
    final substitutions = {
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '8': 'b',
      '@': 'a',
      '!': 'i',
      '$': 's',
      'v': 'u', // common in some scripts
    };

    substitutions.forEach((old, replacement) {
      normalized = normalized.replaceAll(old, replacement);
    });

    // 3. Normalize whitespace (though step 1 removed most)
    normalized = normalized.trim();

    return normalized;
  }
}
