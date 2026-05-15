import 'dart:math';

abstract final class Helpers {
  static String formatPhoneForDisplay(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return phone;
  }

  static String categoryLabel(String category) {
    return switch (category) {
      'BANKING_FRAUD'      => 'Banking Fraud',
      'LOTTERY'            => 'Lottery Scam',
      'KYC'                => 'KYC Fraud',
      'GOVT_IMPERSONATION' => 'Govt Impersonation',
      'DELIVERY_SCAM'      => 'Delivery Scam',
      'PHISHING_EMAIL'     => 'Phishing Email',
      'WHATSAPP_SPAM'      => 'WhatsApp Spam',
      'SUSPICIOUS_CALL'    => 'Suspicious Call',
      'URGENCY'            => 'Urgency Manipulation',
      'SAFE'               => 'Safe',
      'LEGITIMATE'         => 'Legitimate',
      _                    => 'Unknown',
    };
  }

  static int clamp(int val, int min, int max) {
    return val < min ? min : (val > max ? max : val);
  }

  static String generateDeviceId() {
    final rand = Random.secure();
    final bytes = List.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
