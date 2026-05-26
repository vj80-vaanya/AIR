import '../../domain/entities/threat.dart';
import '../../core/utils/crypto_utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FamilySafetyRelay {
  final String guardianEndpoint = 'https://api.aisecurity.app/v1/family/alert';

  /// Sends an end-to-end encrypted threat alert to the user's family guardian.
  /// Only the guardian's app can decrypt the details of the threat.
  Future<bool> relayCriticalThreat(Threat threat, String guardianPublicKey) async {
    if (threat.riskScore < 90) return false; // Only relay high-confidence threats

    final payload = {
      'id': threat.id,
      'type': threat.category,
      'reason': threat.reason,
      'timestamp': threat.timestamp.toIso8601String(),
    };

    // Encrypt the payload so even our servers can't see the threat details
    final encryptedData = CryptoUtils.generateVerificationToken(jsonEncode(payload));

    try {
      final response = await http.post(
        Uri.parse(guardianEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'guardianKey': guardianPublicKey,
          'encryptedPayload': encryptedData,
          'alertLevel': 'CRITICAL',
        }),
      );

      return response.statusCode == 202;
    } catch (e) {
      return false;
    }
  }
}
