import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  /// Hashes a phone number using SHA-256 with an optional salt.
  /// This implements the Zero-Knowledge Architecture requirement by
  /// ensuring raw phone numbers are never sent to the server.
  static String hashPhoneNumber(String phoneNumber, {String? salt}) {
    // Normalize phone number (remove non-digits)
    final normalized = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    final bytes = utf8.encode(normalized + (salt ?? ''));
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Generates a cryptographic token for verification.
  static String generateVerificationToken(String data) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(data + timestamp);
    return sha256.convert(bytes).toString();
  }
}
