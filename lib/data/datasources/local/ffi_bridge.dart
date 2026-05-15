import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../../../generated/ffi_bindings.dart';

/// Singleton wrapper around the C security engine.
/// Gracefully degrades to stub responses when the native library is not
/// available (e.g. development builds without a compiled .so).
class FFIBridge {
  FFIBridge._();
  static final FFIBridge instance = FFIBridge._();

  SecurityEngineBindings? _bindings;
  bool _initialized    = false;
  bool _engineAvailable = false;

  // ── Initialization ─────────────────────────────────────────────────────────

  void init() {
    if (_initialized) return;
    _initialized = true;
    try {
      final lib = _loadLibrary();
      _bindings = SecurityEngineBindings(lib);
      _engineAvailable = true;
    } catch (e) {
      debugPrint('[FFIBridge] Native engine not available: $e');
      _engineAvailable = false;
    }
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) return DynamicLibrary.open('libsecurity_engine.so');
    if (Platform.isIOS)     return DynamicLibrary.process();
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Returns 0 on success, -1 if the native engine is not loaded.
  int initEngine(String dbPath, String modelPath) {
    if (!_engineAvailable) return -1;
    final dp = dbPath.toNativeUtf8();
    final mp = modelPath.toNativeUtf8();
    try {
      return _bindings!.se_init(dp.cast(), mp.cast());
    } finally {
      calloc.free(dp);
      calloc.free(mp);
    }
  }

  void cleanup() {
    if (_engineAvailable) _bindings?.se_cleanup();
  }

  // ── Analysis ───────────────────────────────────────────────────────────────

  Map<String, dynamic> analyzeCall({
    required String phoneNumber,
    required String callerId,
    required bool   isKnownContact,
  }) {
    if (!_engineAvailable) return _stub('Pattern engine offline');
    final ptr = calloc<CallInfo>();
    try {
      _write(phoneNumber, ptr.ref.phone_number, 32);
      _write(callerId,    ptr.ref.caller_id,    128);
      ptr.ref.timestamp        = DateTime.now().millisecondsSinceEpoch;
      ptr.ref.is_known_contact = isKnownContact;
      return _toMap(_bindings!.se_analyze_call(ptr));
    } finally {
      calloc.free(ptr);
    }
  }

  Map<String, dynamic> analyzeSms({
    required String sender,
    required String body,
    required bool   containsUrl,
    String          extractedUrl = '',
  }) {
    if (!_engineAvailable) return _stub('Pattern engine offline');
    final ptr = calloc<SMSInfo>();
    try {
      _write(sender,       ptr.ref.sender,        32);
      _write(body,         ptr.ref.body,           4096);
      _write(extractedUrl, ptr.ref.extracted_url,  2048);
      ptr.ref.contains_url = containsUrl;
      return _toMap(_bindings!.se_analyze_sms(ptr));
    } finally {
      calloc.free(ptr);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _stub(String reason) => {
    'riskScore':   0,
    'category':    'UNAVAILABLE',
    'reason':      reason,
    'shouldBlock': false,
    'confidence':  0.0,
  };

  Map<String, dynamic> _toMap(ThreatAssessment a) => {
    'riskScore':   a.risk_score,
    'category':    _read(a.category),
    'reason':      _read(a.reason),
    'shouldBlock': a.should_block,
    'confidence':  a.confidence,
  };

  /// Read a null-terminated char array into a Dart String (UTF-8).
  String _read(Array<Char> arr) {
    final bytes = <int>[];
    for (int i = 0; i < 512; i++) {
      final b = arr[i];
      if (b == 0) break;
      bytes.add(b & 0xFF);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Write a UTF-8 string into a fixed-length char array (null-terminated).
  void _write(String src, Array<Char> dst, int maxLen) {
    final bytes = utf8.encode(src);
    final limit = bytes.length < maxLen - 1 ? bytes.length : maxLen - 1;
    for (int i = 0; i < limit; i++) {
      dst[i] = bytes[i];
    }
    dst[limit] = 0;
  }
}
