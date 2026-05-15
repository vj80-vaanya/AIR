import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/threat_model.dart';
import '../../domain/entities/threat.dart';

part 'threat_provider.g.dart';

@riverpod
class SelectedChannel extends _$SelectedChannel {
  @override
  ThreatChannel? build() => null; /* null = all */

  void select(ThreatChannel? channel) => state = channel;
}

@riverpod
Future<List<Threat>> filteredThreats(FilteredThreatsRef ref) async {
  final channel = ref.watch(selectedChannelProvider);
  await Future.delayed(const Duration(milliseconds: 200));
  /* In production: call ThreatRepository with channel filter */
  return [];
}
