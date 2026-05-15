import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sos_provider.g.dart';

enum SOSState { idle, countdown, active, cancelled }

@riverpod
class SOS extends _$SOS {
  static const _countdownSeconds = 5;

  @override
  ({SOSState state, int countdown}) build() => (state: SOSState.idle, countdown: _countdownSeconds);

  void trigger() {
    state = (state: SOSState.countdown, countdown: _countdownSeconds);
    _tick();
  }

  void cancel() {
    state = (state: SOSState.cancelled, countdown: _countdownSeconds);
  }

  void _tick() async {
    for (int i = _countdownSeconds; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (this.state.state == SOSState.cancelled) return;
      state = (state: SOSState.countdown, countdown: i - 1);
    }
    if (this.state.state != SOSState.cancelled) {
      state = (state: SOSState.active, countdown: 0);
      /* In production: call TriggerSOS use-case here */
    }
  }
}
