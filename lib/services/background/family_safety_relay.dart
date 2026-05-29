import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/entities/threat.dart';
import '../../core/utils/helpers.dart';

/// Relays a critical threat alert to family members via SMS.
/// No backend required — SMS is delivered even without internet.
class FamilySafetyRelay {
  static const _sosChannel = MethodChannel('ai_security/sos');

  Future<void> relayCriticalThreat(Threat threat) async {
    if (threat.riskScore < 90) return;

    final members = SettingsRepository.familyMembers;
    if (members.isEmpty) return;

    final catLabel = Helpers.categoryLabel(threat.category);
    // Omit threat.reason to avoid forwarding raw scam content to third parties.
    final message =
        '⚠️ AI Security ALERT: A $catLabel scam attempt was detected on your family member\'s device. '
        'Risk score: ${threat.riskScore}/100. '
        'Please check on them.';

    for (final member in members) {
      final phone = member['phone'] as String?;
      if (phone == null || phone.isEmpty) continue;
      // Each member is attempted independently — one failure must not block others.
      try {
        await _sosChannel.invokeMethod('sendSosAlerts', {
          'contacts': [{'name': member['name'] ?? '', 'phone': phone}],
          'message':  message,
        });
      } catch (e) {
        debugPrint('[FamilyRelay] SMS to $phone failed: $e');
      }
    }
  }
}
