import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/engine/security_engine.dart';

class ImageScamAnalyzer {
  final SecurityEngine _engine;

  ImageScamAnalyzer(this._engine);

  /// Analyzes an image file at [imagePath] for scam content using on-device OCR.
  /// Scammers often send fake "Arrest Warrants" or "Bank Notices" as images.
  Future<ThreatResult> analyzeImage(String imagePath) async {
    final extractedText = await _performOcr(imagePath);

    if (extractedText.isEmpty) return ThreatResult.safe;

    final result = await _engine.analyzeText(extractedText);

    // Boost score for image-based scams — visual spoofing increases severity
    if (result.riskScore > 50) {
      return ThreatResult(
        riskScore:    (result.riskScore + 15).clamp(0, 100),
        category:     'IMAGE_BASED_${result.category}',
        reason:       'Scam content detected in image: ${result.reason}',
        shouldBlock:  true,
        confidence:   result.confidence,
      );
    }

    return result;
  }

  Future<String> _performOcr(String imagePath) async {
    final inputImage  = InputImage.fromFilePath(imagePath);
    final recognizer  = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }
}
