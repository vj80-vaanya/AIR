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
    return switch (category.toUpperCase()) {
      'BANKING_FRAUD'              => 'Bank Money Theft',
      'LOTTERY'                    => 'Lottery / Prize Fraud',
      'KYC'                        => 'Fake KYC Update',
      'GOVT_IMPERSONATION'         => 'Fake Government Official',
      'DELIVERY_SCAM'              => 'Fake Delivery / Courier',
      'PHISHING_EMAIL'             => 'Password Theft Attempt',
      'WHATSAPP_SPAM'              => 'WhatsApp Spam',
      'SUSPICIOUS_CALL'            => 'Suspicious Caller',
      'URGENCY'                    => 'Pressure / Urgency Scam',
      'DIGITAL_ARREST'             => 'Fake Arrest Threat',
      'INVESTMENT_SCAM'            => 'Fake Investment Trap',
      'OTP_THEFT'                  => 'OTP Theft Attempt',
      'ACCOUNT_HIJACK'             => 'Account Takeover Attempt',
      'FINANCIAL_FRAUD_ATTEMPT'    => 'Financial Fraud Attempt',
      'IMAGE_BASED_BANKING_FRAUD'  => 'Scam Image (Bank Fraud)',
      'IMAGE_BASED_DIGITAL_ARREST' => 'Scam Image (Fake Arrest)',
      'ROBOCALL_BOT'               => 'Robocall / Bot Caller',
      'AI_DETECTED_SPAM'           => 'AI-Detected Scam',
      'UNVERIFIED'                 => 'Unknown Caller',
      'SAFE'                       => 'Safe',
      'LEGITIMATE'                 => 'Legitimate',
      _                            => 'Suspicious Message',
    };
  }

  /// Returns plain-language advice for a given threat category.
  static String categoryAdvice(String category) {
    return switch (category.toUpperCase()) {
      'BANKING_FRAUD' || 'OTP_THEFT' =>
          'Do NOT share any OTP, PIN, or password. Call your bank directly on the number on the back of your card.',
      'DIGITAL_ARREST' =>
          'There is no such thing as a "Digital Arrest" in India. This is a scam. Hang up immediately. Real police do not arrest people over video calls.',
      'INVESTMENT_SCAM' =>
          'No legitimate investment guarantees high returns. Do not send any money. Report to cybercrime.gov.in.',
      'LOTTERY' =>
          'You cannot win a prize you did not enter. This is a scam. Delete the message.',
      'KYC' =>
          'Banks never ask for KYC over SMS or phone calls. Visit your bank branch in person if needed.',
      'GOVT_IMPERSONATION' =>
          'Government agencies contact citizens by post, not WhatsApp. Verify by calling the official helpline.',
      'PHISHING_EMAIL' =>
          'Do NOT click any link in this message. Go directly to the official website by typing the address.',
      'ACCOUNT_HIJACK' =>
          'Never scan QR codes sent by strangers. This is an attempt to take over your account.',
      'DELIVERY_SCAM' =>
          'Do not pay any fee to receive a package you did not order. This is a scam.',
      'SUSPICIOUS_CALL' || 'ROBOCALL_BOT' =>
          'Block this number. Do not call back. Save this record as proof if needed.',
      'SAFE' || 'LEGITIMATE' =>
          'This message is safe. No action needed.',
      _ =>
          'Do not reply, click links, or share personal information. Block this sender and report it.',
    };
  }

  /// Converts raw engine reason strings to plain user-facing language.
  static String reasonPlain(String reason) {
    if (reason.isEmpty) return 'Suspicious patterns detected.';
    var r = reason
        // engine labels
        .replaceAll('AI_DETECTED_SPAM',         'AI detected spam')
        .replaceAll('FINANCIAL_FRAUD_ATTEMPT',   'financial fraud attempt')
        .replaceAll('BANKING_FRAUD',             'bank fraud attempt')
        .replaceAll('DIGITAL_ARREST',            'fake arrest scam')
        .replaceAll('INVESTMENT_SCAM',           'fake investment trap')
        .replaceAll('OTP_THEFT',                 'OTP theft attempt')
        .replaceAll('ACCOUNT_HIJACK',            'account takeover attempt')
        .replaceAll('ROBOCALL_BOT',              'automated spam caller')
        // engine reason fragments
        .replaceAll('+ High message velocity (Bot activity)',
                    '— many messages sent very quickly (automated spam)')
        .replaceAll('High message velocity (Bot activity)',
                    'Many messages sent very quickly (automated spam).')
        .replaceAll('financial social engineering detected',
                    'Message uses pressure tactics to get money or personal details.')
        .replaceAll('intent match',              'matches known scam pattern')
        .replaceAll('malicious URL heuristic match',
                    'link looks like a fake or fraudulent website')
        .replaceAll('+ Platform risk (Unverified Business)',
                    '— sent from an unverified account')
        .replaceAll('+ High-risk Telegram vector',
                    '— sent via Telegram, a common channel for investment scams')
        .replaceAll('Suspicious caller attributes detected',
                    'This caller has patterns associated with scam calls.')
        .replaceAll('No issues found',           'No scam patterns detected.')
        .replaceAll('bot behaviour',             'automated fraud activity');
    // Strip bare category codes that may slip through (e.g. "(BANKING_FRAUD)")
    r = r.replaceAll(RegExp(r'\([A-Z_]{4,}\)'), '');
    return r.trim();
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
