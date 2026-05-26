import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/engine/security_engine.dart';

class IOSSecurityAssistant {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final SecurityEngine _engine;

  IOSSecurityAssistant(this._engine);

  /// Allows iOS users to scan screenshots of WhatsApp/Telegram chats.
  /// This is the primary protection method on iOS where background scanning is restricted.
  Future<ThreatResult> scanScreenshot(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (recognizedText.text.isEmpty) {
        return ThreatResult.safe;
      }

      // Pass the extracted text to our existing security engine
      final result = await _engine.analyzeText(recognizedText.text);

      return result;
    } catch (e) {
      return ThreatResult.safe;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
