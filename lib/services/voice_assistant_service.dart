import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/services/user_service.dart';

enum VoiceAssistantState {
  idle,
  listeningForWakeWord, // Porcupine is running silently in background
  orderListening,       // Wake word fired; STT is capturing the order
  processing,           // Gemini is parsing the spoken order
  showingResult,        // "My Order" dialog is visible
}

class VoiceOrderResult {
  final String transcribedText;
  final Map<String, int> cart; // productId → quantity
  final List<Map<String, dynamic>> allProducts;

  const VoiceOrderResult({
    required this.transcribedText,
    required this.cart,
    required this.allProducts,
  });
}

/// Singleton service.
///
/// Phase 1 – Wake word: Porcupine listens continuously in the background.
/// Triggered by the keyword configured in .env:
///   • PORCUPINE_KEYWORD_PATH = path to a custom .ppn asset  (preferred)
///   • PORCUPINE_BUILTIN_KEYWORD = COMPUTER | ALEXA | JARVIS …  (fallback)
///   • Requires PICOVOICE_ACCESS_KEY from console.picovoice.ai
///
/// Phase 2 – Order capture: speech_to_text records the spoken order.
///
/// Phase 3 – Parsing: Gemini maps words → product IDs.
class VoiceAssistantService {
  static final VoiceAssistantService _instance =
      VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  // ── Porcupine (wake word) ─────────────────────────────────────────────────
  PorcupineManager? _porcupineManager;

  // ── Speech-to-Text (order capture) ───────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _sttInitialized = false;
  bool _orderCaptured = false; // guards against double-processing

  // ── Streams ───────────────────────────────────────────────────────────────
  final _stateController =
      StreamController<VoiceAssistantState>.broadcast();
  final _audioLevelController = StreamController<double>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();

  Stream<VoiceAssistantState> get stateStream => _stateController.stream;
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;

  // ── State ─────────────────────────────────────────────────────────────────
  VoiceAssistantState _state = VoiceAssistantState.idle;
  VoiceAssistantState get currentState => _state;

  VoiceOrderResult? _lastResult;
  VoiceOrderResult? get lastResult => _lastResult;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Initialise Porcupine and start always-on wake word detection.
  /// No-op on web (Porcupine is mobile-only).
  Future<void> startWakeWordListener() async {
    if (kIsWeb) {
      debugPrint('[Porcupine] Skipped – not supported on web');
      return;
    }
    _setState(VoiceAssistantState.listeningForWakeWord);
    await _initPorcupine();
  }

  /// Pause everything and go idle (called on app dispose).
  Future<void> stopAll() async {
    await _speech.stop();
    await _porcupineManager?.delete();
    _porcupineManager = null;
    _setState(VoiceAssistantState.idle);
  }

  /// Called by the overlay's Modify / close button, or after confirming order.
  /// Clears the last result and resumes Porcupine.
  Future<void> dismissAndReset() async {
    _lastResult = null;
    _orderCaptured = false;
    _speech.stop(); // signal STT to stop (async internally)
    await _resumePorcupine();
  }

  // ── Porcupine initialisation ──────────────────────────────────────────────

  Future<void> _initPorcupine() async {
    // Release any previous instance
    await _porcupineManager?.delete();
    _porcupineManager = null;

    final accessKey = dotenv.env['PICOVOICE_ACCESS_KEY'] ?? '';
    if (accessKey.isEmpty) {
      debugPrint('[Porcupine] ❌ PICOVOICE_ACCESS_KEY not set in .env');
      return;
    }

    try {
      final customPath = dotenv.env['PORCUPINE_KEYWORD_PATH'];

      if (customPath != null && customPath.isNotEmpty) {
        // Custom keyword (.ppn file from Picovoice Console stored in assets/)
        _porcupineManager = await PorcupineManager.fromKeywordPaths(
          accessKey,
          [customPath],
          _onWakeWord,
          errorCallback: _onPorcupineError,
          sensitivities: [0.7],
        );
        debugPrint('[Porcupine] Using custom keyword: $customPath');
      } else {
        // Fall back to a built-in keyword.
        // Change PORCUPINE_BUILTIN_KEYWORD in .env to any of:
        // ALEXA, AMERICANO, BLUEBERRY, BUMBLEBEE, COMPUTER,
        // GRAPEFRUIT, GRASSHOPPER, HEY_GOOGLE, HEY_SIRI, JARVIS,
        // OK_GOOGLE, PICOVOICE, PORCUPINE, TERMINATOR
        final builtInName =
            (dotenv.env['PORCUPINE_BUILTIN_KEYWORD'] ?? 'COMPUTER')
                .toUpperCase();
        final keyword = BuiltInKeyword.values.firstWhere(
          (k) => k.name == builtInName,
          orElse: () => BuiltInKeyword.COMPUTER,
        );

        _porcupineManager = await PorcupineManager.fromBuiltInKeywords(
          accessKey,
          [keyword],
          _onWakeWord,
          errorCallback: _onPorcupineError,
          sensitivities: [0.7],
        );
        debugPrint('[Porcupine] Using built-in keyword: ${keyword.name}');
      }

      await _porcupineManager!.start();
      debugPrint('[Porcupine] ✅ Wake word listener started.');
    } on PorcupineException catch (e) {
      debugPrint('[Porcupine] Init error: ${e.message}');
    } catch (e) {
      debugPrint('[Porcupine] Unexpected error: $e');
    }
  }

  // ── Wake word callback (runs on platform thread → posted to main) ─────────

  void _onWakeWord(int keywordIndex) async {
    if (_state != VoiceAssistantState.listeningForWakeWord) return;
    debugPrint('[Porcupine] 🔔 Wake word detected (index $keywordIndex)');

    // Pause Porcupine while STT is active (both use the microphone)
    await _porcupineManager?.stop();

    // Give the OS time to fully release the mic before STT claims it
    await Future.delayed(const Duration(milliseconds: 800));

    _orderCaptured = false;
    _setState(VoiceAssistantState.orderListening); // shows the overlay

    await _startOrderListening();
  }

  void _onPorcupineError(PorcupineException error) {
    debugPrint('[Porcupine] ⚠️ Error: ${error.message}');
  }

  // ── STT – order capture ───────────────────────────────────────────────────

  Future<bool> _initStt() async {
    if (_sttInitialized) return true;
    _sttInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('[STT] Error: ${error.errorMsg}');
        if (_state == VoiceAssistantState.orderListening && !_orderCaptured) {
          _resumePorcupine();
        }
      },
      onStatus: (status) {
        debugPrint('[STT] Status: $status');
        // STT stopped on its own (timeout / silence) without capturing order
        if ((status == 'done' || status == 'notListening') &&
            _state == VoiceAssistantState.orderListening &&
            !_orderCaptured) {
          _resumePorcupine();
        }
      },
    );
    return _sttInitialized;
  }

  Future<void> _startOrderListening() async {
    if (!await _initStt()) {
      debugPrint('[STT] ❌ Could not initialise speech recognition.');
      _resumePorcupine();
      return;
    }

    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 5),
      onSoundLevelChange: (level) {
        // Normalise roughly -2 dB … +10 dB → 0.0 … 1.0
        final normalised = ((level + 2) / 12).clamp(0.0, 1.0);
        _audioLevelController.add(normalised.toDouble());
      },
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_state != VoiceAssistantState.orderListening) return;

    _transcriptController.add(result.recognizedWords);

    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      _orderCaptured = true;
      _processOrderText(result.recognizedWords.trim());
    }
  }

  // ── Order processing ──────────────────────────────────────────────────────

  Future<void> _processOrderText(String orderText) async {
    _setState(VoiceAssistantState.processing);
    await _speech.stop();

    debugPrint('[Voice] Processing order: "$orderText"');

    try {
      // Strip common filler words
      final cleaned = orderText
          .replaceAll(
            RegExp(
              r'^(i want|i would like|give me|can i have|please)\s+',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      debugPrint('[Voice] Cleaned text: "$cleaned"');

      final ownerId = UserService().currentOwnerId;
      debugPrint('[Voice] Owner ID: $ownerId');
      if (ownerId == null) throw Exception('No owner ID – user not loaded');

      debugPrint('[Voice] Fetching products from Supabase...');
      final supabase = Supabase.instance.client;
      final productsRes = await supabase
          .from('products')
          .select(
              'id, name, unit_price, keyword, image_url, *, categories!inner(name)')
          .eq('categories.business_id', ownerId);

      final products = List<Map<String, dynamic>>.from(productsRes);
      debugPrint('[Voice] Got ${products.length} products');

      debugPrint('[Voice] Calling Gemini...');
      final cart = await _parseOrderWithGemini(cleaned, products);
      debugPrint('[Voice] Cart result: $cart');

      _lastResult = VoiceOrderResult(
        transcribedText: orderText,
        cart: cart,
        allProducts: products,
      );
      _setState(VoiceAssistantState.showingResult);
      debugPrint('[Voice] ✅ Showing result dialog');
    } catch (e, stack) {
      debugPrint('[Voice] ❌ Processing error: $e');
      debugPrint('[Voice] Stack: $stack');
      _resumePorcupine();
    }
  }

  Future<Map<String, int>> _parseOrderWithGemini(
    String orderText,
    List<Map<String, dynamic>> products,
  ) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not set in .env');
    }

    final productList = products
        .map((p) => {
              'id': p['id'].toString(),
              'name': p['name'] ?? '',
              'keyword': p['keyword'] ?? p['name'] ?? '',
            })
        .toList();

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.0,
      ),
    );

    final prompt = '''
You are an order-parsing assistant for a food business POS system.

Available Products:
${jsonEncode(productList)}

Spoken Order: "$orderText"

Rules:
- Match spoken words to product name or keyword using fuzzy, case-insensitive matching.
- Quantities: "one"→1, "two"→2, "three"→3, "four"→4, "five"→5, "a"/"an"→1.
- If a spoken item closely matches multiple products, prefer the one whose keyword matches best.
- Return ONLY a valid JSON object: { "product-id": quantity, ... }
- If nothing matches, return {}.

Return ONLY valid JSON, no explanation, no markdown.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{}';

    try {
      final cleanJson = text
          .trim()
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (e) {
      debugPrint('[Gemini] Parse error: $e\nRaw: $text');
      return {};
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _resumePorcupine() async {
    _setState(VoiceAssistantState.listeningForWakeWord);
    // Give the mic time to fully release before Porcupine claims it again
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      await _porcupineManager?.start();
      debugPrint('[Porcupine] ✅ Resumed wake word listener');
    } catch (e) {
      debugPrint('[Porcupine] ⚠️ Resume failed ($e), re-initialising...');
      await _initPorcupine();
    }
  }

  void _setState(VoiceAssistantState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
