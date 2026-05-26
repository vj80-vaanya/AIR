import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/background/ios_security_assistant.dart';
import '../../core/engine/security_engine.dart';

class IOSSafetyScannerWidget extends StatefulWidget {
  const IOSSafetyScannerWidget({super.key});

  @override
  State<IOSSafetyScannerWidget> createState() => _IOSSafetyScannerWidgetState();
}

class _IOSSafetyScannerWidgetState extends State<IOSSafetyScannerWidget> {
  final _picker = ImagePicker();
  bool _isScanning = false;
  ThreatResult? _lastResult;

  Future<void> _scanFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isScanning = true);
    
    final assistant = IOSSecurityAssistant(SecurityEngine.instance);
    final result = await assistant.scanScreenshot(image.path);
    
    setState(() {
      _lastResult = result;
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'iOS Protection Assistant',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a screenshot of any suspicious chat and scan it here for instant verification.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_isScanning)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _scanFromGallery,
                icon: const Icon(Icons.add_photo_alternate_on_outlined),
                label: const Text('Scan Screenshot'),
              ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(_lastResult!),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThreatResult result) {
    final isSafe = result.riskScore < 50;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSafe ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSafe ? Colors.green : Colors.red),
      ),
      child: Column(
        children: [
          Text(
            isSafe ? 'Looks Safe' : 'Scam Detected!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSafe ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.reason,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
