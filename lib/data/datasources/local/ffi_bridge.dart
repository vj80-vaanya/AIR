/// FFIBridge is now a thin shim over SecurityEngine (pure Dart).
/// The C/FFI layer has been replaced — this file is kept so that any
/// remaining call sites compile without changes.
library ffi_bridge;

export '../../../core/engine/security_engine.dart' show SecurityEngine, ThreatResult;
