import 'package:flutter/services.dart';

class ClipboardGuardian {
  static const _otpRegex = r'\b\d{4,6}\b';

  /// Monitors the clipboard for sensitive data like OTPs.
  /// If an OTP is copied while a threat is active, it flags it.
  static Future<bool> isSensitiveDataPresent() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return false;

    final hasOtp = RegExp(_otpRegex).hasMatch(data!.text!);
    return hasOtp;
  }

  /// Clears the clipboard to prevent scammers from pasting stolen OTPs.
  static Future<void> clearClipboard() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  }
}
