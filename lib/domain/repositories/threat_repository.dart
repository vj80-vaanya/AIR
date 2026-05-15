import '../entities/threat.dart';
import '../../data/models/threat_model.dart';

abstract interface class ThreatRepository {
  Future<Threat>       analyzeCall({required String phone, required String callerId, required bool isKnown});
  Future<Threat>       analyzeSms({required String sender, required String body, required bool hasUrl, String url});
  Future<Threat>       analyzeEmail({required String from, required String displayName, required String subject, required String bodyPreview});
  Future<Threat>       analyzeWhatsApp({required String sender, required bool isBusiness, required int frequency24h, required bool hasUrl, String urlDomain});
  Future<List<Threat>> getThreats({ThreatChannel? channel, int limit, int offset});
  Future<int>          getThreatCount({DateTime? since});
  Future<void>         deleteAll();
}
