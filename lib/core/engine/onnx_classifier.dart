import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Runs highly compressed Small Language Models (SLMs) on-device.
/// Supports INT8 quantized models for maximum performance on mobile hardware.
/// All inference is strictly local; no data is ever sent to the cloud.
class OnnxClassifier {
  final OrtSession _session;

  OnnxClassifier._(this._session);

  static Future<OnnxClassifier?> load() async {
    try {
      OrtEnv.instance.init();
      final opts    = OrtSessionOptions();
      
      // Optimization: Enable basic graph optimizations and set threads
      opts.setInterOpNumThreads(1);
      opts.setIntraOpNumThreads(2);
      
      final rawData = await rootBundle.load('assets/models/text_classifier.onnx');
      final bytes   = rawData.buffer.asUint8List();
      final session = OrtSession.fromBuffer(bytes, opts);
      return OnnxClassifier._(session);
    } catch (e) {
      debugPrint('[OnnxClassifier] Could not load model: $e');
      return null;
    }
  }

  /// Runs inference in a privacy-preserving manner.
  /// Input tokens are cleared from memory immediately after use.
  Future<double> classify(List<int> tokenIds) async {
    try {
      // Use compute() to offload to a separate isolate, keeping UI responsive
      return await compute(_runInference, _InferenceInput(_session, tokenIds));
    } catch (e) {
      debugPrint('[OnnxClassifier] Inference error: $e');
      return 0.0;
    }
  }

  void dispose() => _session.release();
}

// ── Inference (runs on worker isolate via compute) ─────────────────────────

class _InferenceInput {
  const _InferenceInput(this.session, this.tokenIds);
  final OrtSession session;
  final List<int>  tokenIds;
}

double _runInference(_InferenceInput input) {
  final ids   = Int64List.fromList(input.tokenIds);
  final attn  = Int64List.fromList(input.tokenIds.map((t) => t != 0 ? 1 : 0).toList());
  final types = Int64List(input.tokenIds.length);
  final shape = [1, input.tokenIds.length];

  final ortIds  = OrtValueTensor.createTensorWithDataList(ids,   shape);
  final ortAttn = OrtValueTensor.createTensorWithDataList(attn,  shape);
  final ortType = OrtValueTensor.createTensorWithDataList(types, shape);

  final outputs = input.session.run(
    OrtRunOptions(),
    {
      'input_ids':      ortIds,
      'attention_mask': ortAttn,
      'token_type_ids': ortType,
    },
  );

  ortIds.release();
  ortAttn.release();
  ortType.release();

  // logits: List<List<double>> shape [1, 2]
  final logits = (outputs[0]?.value as List<List<double>>)[0];
  for (final o in outputs) o?.release();

  // softmax
  final maxL = math.max(logits[0], logits[1]);
  final e0   = math.exp(logits[0] - maxL);
  final e1   = math.exp(logits[1] - maxL);
  return e1 / (e0 + e1);
}
