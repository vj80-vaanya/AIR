// AUTO-GENERATED — run `dart run ffigen` to regenerate from security_engine.h
// ignore_for_file: camel_case_types, non_constant_identifier_names

import 'dart:ffi';

final class ThreatAssessment extends Struct {
  @Int32()  external int    risk_score;
  @Array(64) external Array<Char> category;
  @Array(256) external Array<Char> reason;
  @Bool()   external bool   should_block;
  @Float()  external double confidence;
}

final class CallInfo extends Struct {
  @Array(32)  external Array<Char> phone_number;
  @Array(128) external Array<Char> caller_id;
  @Int64()    external int         timestamp;
  @Bool()     external bool        is_known_contact;
}

final class SMSInfo extends Struct {
  @Array(32)   external Array<Char> sender;
  @Array(4096) external Array<Char> body;
  @Bool()      external bool        contains_url;
  @Array(2048) external Array<Char> extracted_url;
}

final class EmailInfo extends Struct {
  @Array(256)  external Array<Char> from_address;
  @Array(128)  external Array<Char> display_name;
  @Array(512)  external Array<Char> subject;
  @Array(2048) external Array<Char> body_preview;
  @Bool()      external bool        has_attachment;
  @Array(1024) external Array<Char> attachment_names;
}

final class WhatsAppInfo extends Struct {
  @Array(32)  external Array<Char> sender_phone;
  @Bool()     external bool        is_business_account;
  @Int32()    external int         message_frequency_24h;
  @Bool()     external bool        contains_url;
  @Array(256) external Array<Char> url_domain;
}

final class SensorData extends Struct {
  @Float() external double accel_x;
  @Float() external double accel_y;
  @Float() external double accel_z;
  @Float() external double gyro_x;
  @Float() external double gyro_y;
  @Float() external double gyro_z;
  @Int64() external int    timestamp;
}

final class FallResult extends Struct {
  @Bool()  external bool   fall_detected;
  @Float() external double confidence;
  @Int32() external int    severity;
}

class SecurityEngineBindings {
  final DynamicLibrary _lib;
  SecurityEngineBindings(this._lib);

  late final _se_init = _lib.lookupFunction<
    Int32 Function(Pointer<Char>, Pointer<Char>),
    int   Function(Pointer<Char>, Pointer<Char>)>('se_init');

  late final _se_cleanup = _lib.lookupFunction<
    Void Function(), void Function()>('se_cleanup');

  late final _se_analyze_call = _lib.lookupFunction<
    ThreatAssessment Function(Pointer<CallInfo>),
    ThreatAssessment Function(Pointer<CallInfo>)>('se_analyze_call');

  late final _se_analyze_sms = _lib.lookupFunction<
    ThreatAssessment Function(Pointer<SMSInfo>),
    ThreatAssessment Function(Pointer<SMSInfo>)>('se_analyze_sms');

  late final _se_detect_fall = _lib.lookupFunction<
    FallResult Function(Pointer<SensorData>),
    FallResult Function(Pointer<SensorData>)>('se_detect_fall');

  late final _se_trigger_sos = _lib.lookupFunction<
    Int32 Function(Pointer<Pointer<Char>>, Int32),
    int   Function(Pointer<Pointer<Char>>, int)>('se_trigger_sos');

  late final _se_cancel_sos = _lib.lookupFunction<
    Int32 Function(), int Function()>('se_cancel_sos');

  late final _se_get_last_error = _lib.lookupFunction<
    Pointer<Char> Function(),
    Pointer<Char> Function()>('se_get_last_error');

  int              se_init(Pointer<Char> dbPath, Pointer<Char> modelPath)
      => _se_init(dbPath, modelPath);
  void             se_cleanup() => _se_cleanup();
  ThreatAssessment se_analyze_call(Pointer<CallInfo> info)  => _se_analyze_call(info);
  ThreatAssessment se_analyze_sms(Pointer<SMSInfo> info)    => _se_analyze_sms(info);
  FallResult       se_detect_fall(Pointer<SensorData> data) => _se_detect_fall(data);
  int              se_trigger_sos(Pointer<Pointer<Char>> c, int n) => _se_trigger_sos(c, n);
  int              se_cancel_sos() => _se_cancel_sos();
  Pointer<Char>    se_get_last_error() => _se_get_last_error();
}
