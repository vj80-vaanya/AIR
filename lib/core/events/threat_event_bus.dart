import 'dart:async';

/// Single-broadcast bus that fires whenever a new threat is persisted.
/// Background services call [emit]; the dashboard listens and refreshes.
class ThreatEventBus {
  ThreatEventBus._();
  static final ThreatEventBus instance = ThreatEventBus._();

  final _ctrl = StreamController<DateTime>.broadcast();

  Stream<DateTime> get stream => _ctrl.stream;

  void emit() => _ctrl.add(DateTime.now());
}
