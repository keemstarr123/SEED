import 'package:flutter/foundation.dart';
import 'package:flutter_wake_word/use_model.dart';
import 'package:flutter_wake_word/instance_config.dart';
import 'package:permission_handler/permission_handler.dart';

class WakeWordService {
  static const String _licenseKey =
      'MTc3NzU4MjgwMDAwMA==-DjFidRwm0IRAGfH/z5nbjGYCrKtm0Q+sc2LNoexBnm8=';

  final UseModel _useModel = UseModel();
  bool _initialized = false;

  final List<InstanceConfig> _configs = [
    InstanceConfig(
      id: 'need_help_now',
      modelName: 'need_help_now.onnx',
      threshold: 0.98,
      bufferCnt: 3,
      sticky: false,
    ),
  ];

  Future<void> init({required VoidCallback onWakeWordDetected}) async {
    if (kIsWeb || _initialized) return;

    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      debugPrint('[WakeWordService] Mic permission not granted — skipping');
      return;
    }

    try {
      await _useModel.setKeywordDetectionLicense(_licenseKey);

      await _useModel.loadModel(_configs, (Map<String, dynamic> event) {
        final phrase = event['phrase'] as String?;
        debugPrint('[WakeWordService] Wake word detected: $phrase');
        onWakeWordDetected();
      });

      _initialized = true;
      debugPrint('[WakeWordService] Initialized and listening for "need help now"');
    } catch (e) {
      debugPrint('[WakeWordService] Failed to load model: $e');
    }
  }

  Future<void> stopListening() async {
    if (!_initialized) return;
    await _useModel.stopListening();
    debugPrint('[WakeWordService] Stopped');
  }

  Future<void> startListening() async {
    if (!_initialized) return;
    await _useModel.startListening();
    debugPrint('[WakeWordService] Listening for "need help now"...');
  }

  Future<void> dispose() async {
    await stopListening();
  }
}
