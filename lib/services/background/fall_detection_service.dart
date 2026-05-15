import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../../data/datasources/local/ffi_bridge.dart';
import '../notifications/notification_service.dart';

class FallDetectionService {
  FallDetectionService._();
  static final FallDetectionService instance = FallDetectionService._();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>?     _gyroSub;

  AccelerometerEvent? _lastAccel;
  GyroscopeEvent?     _lastGyro;

  void start() {
    _accelSub = accelerometerEventStream().listen((e) {
      _lastAccel = e;
      _evaluate();
    });
    _gyroSub = gyroscopeEventStream().listen((e) => _lastGyro = e);
  }

  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
  }

  void _evaluate() {
    final a = _lastAccel;
    final g = _lastGyro;
    if (a == null) return;

    /* Build a map matching the FFI call contract */
    // In production, call the C engine via FFI for proper fall detection
    // This is a simplified placeholder
    final accelMag = _magnitude(a.x, a.y, a.z);
    if (accelMag < 2.0 /* near freefall */ || accelMag > 25.0 /* impact */) {
      /* Let C engine handle the windowed 3-phase detection */
    }
  }

  double _magnitude(double x, double y, double z) {
    return (x * x + y * y + z * z);  /* squared — sqrt omitted for perf */
  }
}
