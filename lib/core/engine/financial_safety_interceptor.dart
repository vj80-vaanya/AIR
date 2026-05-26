class FinancialSafetyInterceptor {
  static final _financialTriggers = [
    'upi', 'gpay', 'phonepe', 'paytm', 'scanner', 'qr code', 'pin', 'otp',
    'bank', 'kosh', 'paisa', 'transfer', 'received', 'pending'
  ];

  /// Specifically analyzes messages for "Payment Request" scams common in India.
  /// This detects the "Receive Money" scam where users are tricked into entering a PIN.
  static int analyzeSocialEngineering(String text) {
    final lower = text.toLowerCase();
    int riskPoints = 0;

    // 1. Check for the "Receive vs Send" confusion
    if (lower.contains('receive') && (lower.contains('pin') || lower.contains('upi'))) {
      riskPoints += 40; // Legitimate apps never ask for a PIN to RECEIVE money.
    }

    // 2. QR Code triggers
    if (lower.contains('scan') && lower.contains('qr')) {
      riskPoints += 30;
    }

    // 3. Urgent Financial Action
    if (lower.contains('limit') || lower.contains('expire') || lower.contains('block')) {
       if (lower.contains('bank') || lower.contains('card')) {
         riskPoints += 25;
       }
    }

    return riskPoints.clamp(0, 100);
  }
}
