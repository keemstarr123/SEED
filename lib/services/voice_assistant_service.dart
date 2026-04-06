import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:seed/services/user_service.dart';

enum VoiceAssistantState {
  idle,
  orderListening,
  processing,
  showingResult,
  noSpeechTimeout, // opened mic but user never spoke
  noProductMatch, // Gemini could not match any product
}

class VoiceOrderResult {
  final String transcribedText;
  final Map<String, int> cart;
  final List<Map<String, dynamic>> allProducts;

  const VoiceOrderResult({
    required this.transcribedText,
    required this.cart,
    required this.allProducts,
  });
}

/// Singleton voice assistant service.
///
/// Triggered by the (+) FAB button — no wake word.
/// Listens via speech_to_text, stops after 3s of silence.
/// Order parsing: Gemini (sends full product list for fuzzy matching).
class VoiceAssistantService {
  static final VoiceAssistantService _instance =
      VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  // ── Speech-to-Text ────────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _sttInitialized = false;
  bool _orderCaptured = false;
  bool _hasSpeech = false; // true once any word is heard
  bool _isRestarting = false; // suppresses idle transition during any restart
  Timer? _initialSilenceTimer; // 20s — fires if user never speaks
  Timer? _postSpeechSilenceTimer; // 5s — fires after user stops speaking
  String? _resolvedLocaleId; // cached after first locale resolution

  // ── Streams ───────────────────────────────────────────────────────────────
  final _stateController = StreamController<VoiceAssistantState>.broadcast();
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

  // Modify mode — holds the cart being modified
  bool _isModifying = false;
  Map<String, int> _modifyCart = {};
  List<Map<String, dynamic>> _modifyProducts = [];

  // Session token — incremented on every new session to discard late STT callbacks
  int _sessionToken = 0;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Called when user taps the (+) FAB. Starts listening immediately.
  /// [localeId] — pass null to use device default, or e.g. 'ms-MY', 'zh-CN'
  Future<void> startListening({String? localeId}) async {
    if (kIsWeb) return;
    _selectedLocaleId = localeId;
    _orderCaptured = false;
    _hasSpeech = false;
    _isModifying = false;
    _modifyCart = {};
    _modifyProducts = [];
    _accumulatedText = '';
    _previousText = '';
    _sessionText = '';
    _resolvedLocaleId = null;
    _sessionToken++;
    _cancelTimers();
    _setState(VoiceAssistantState.orderListening);
    await Future.delayed(const Duration(milliseconds: 200));
    await _startOrderListening();
  }

  String? _selectedLocaleId;

  void _cancelTimers() {
    _initialSilenceTimer?.cancel();
    _initialSilenceTimer = null;
    _postSpeechSilenceTimer?.cancel();
    _postSpeechSilenceTimer = null;
  }

  void _scheduleRestart() {
    if (_isRestarting) return; // prevent stacking
    _isRestarting = true;
    Future.delayed(const Duration(milliseconds: 150), () async {
      if (_state == VoiceAssistantState.orderListening && !_orderCaptured) {
        await _startOrderListening();
      }
      _isRestarting = false;
    });
  }

  /// Switches language mid-session without closing the overlay.
  Future<void> switchLocale({required String localeId}) async {
    _isRestarting = true;
    _selectedLocaleId = localeId;
    _resolvedLocaleId = null;
    _orderCaptured = false;
    _hasSpeech = false;
    _accumulatedText = '';
    _previousText = '';
    _sessionText = '';
    _sessionToken++;
    _cancelTimers();
    await _speech.stop();
    await Future.delayed(const Duration(milliseconds: 600));
    _isRestarting = false;
    _setState(VoiceAssistantState.orderListening);
    await _startOrderListening();
  }

  Future<void> stopAll() async {
    _cancelTimers();
    await _speech.stop();
    _setState(VoiceAssistantState.idle);
  }

  Future<void> dismissAndReset() async {
    _cancelTimers();
    _lastResult = null;
    _orderCaptured = false;
    _isModifying = false;
    _modifyCart = {};
    _modifyProducts = [];
    await _speech.stop();
    _setState(VoiceAssistantState.idle);
  }

  /// Called when user taps Modify on the result screen.
  /// Restarts listening with the current cart as context for Gemini.
  Future<void> modifyOrder({
    required Map<String, int> currentCart,
    required List<Map<String, dynamic>> allProducts,
  }) async {
    _isModifying = true;
    _modifyCart = Map.from(currentCart);
    _modifyProducts = List.from(allProducts);
    _orderCaptured = false;
    _hasSpeech = false;
    _accumulatedText = '';
    _previousText = '';
    _sessionText = '';
    _sessionToken++;
    _cancelTimers();
    _setState(VoiceAssistantState.orderListening);
    await Future.delayed(const Duration(milliseconds: 200));
    await _startOrderListening();
  }

  // ── STT init ──────────────────────────────────────────────────────────────

  Future<bool> _initStt() async {
    if (_sttInitialized) return true;
    _sttInitialized = await _speech.initialize(
      debugLogging: true,
      onError: (e) {
        debugPrint('[STT] Error: ${e.errorMsg}');
        if (_isRestarting) return;
        if (_state != VoiceAssistantState.orderListening || _orderCaptured)
          return;
        const restartableErrors = [
          'error_speech_timeout',
          'error_no_match',
          'error_client',
        ];
        if (restartableErrors.contains(e.errorMsg)) {
          // Save accumulated text before restart so next session can append to it
          if (_accumulatedText.isNotEmpty) {
            _previousText = _accumulatedText;
          }
          debugPrint(
            '[STT] Restarting after ${e.errorMsg} — saved: "$_previousText"',
          );
          _scheduleRestart();
        } else {
          _cancelTimers();
          _setState(VoiceAssistantState.idle);
        }
      },
      onStatus: (s) {
        debugPrint('[STT] Status: $s');
        // Timers handle all closing logic — onStatus never drives state changes
      },
    );
    return _sttInitialized;
  }

  // ── STT order capture ─────────────────────────────────────────────────────

  Future<void> _startOrderListening() async {
    if (!await _initStt()) {
      _setState(VoiceAssistantState.idle);
      return;
    }

    // Resolve locale once per session, reuse on restarts
    if (_resolvedLocaleId == null) {
      final locales = await _speech.locales();
      debugPrint(
        '[STT] Available locales (${locales.length}): ${locales.map((l) => '${l.localeId}(${l.name})').join(', ')}',
      );

      final localeIds = locales.map((l) => l.localeId).toSet();

      // Build candidate list — selected locale first, then fallbacks
      final candidates = <String>[
        if (_selectedLocaleId != null) ...[
          _selectedLocaleId!,
          _selectedLocaleId!.replaceAll('-', '_'),
          _selectedLocaleId!.replaceAll('_', '-'),
        ],
        'en-MY', 'en_MY', 'en-SG', 'en_SG', 'en-US', 'en_US',
      ];

      String? resolved;
      for (final c in candidates) {
        if (localeIds.contains(c)) {
          resolved = c.replaceAll('_', '-');
          break;
        }
      }
      // Last resort: any English locale
      resolved ??= locales
          .where((l) => l.localeId.toLowerCase().startsWith('en'))
          .firstOrNull
          ?.localeId
          .replaceAll('_', '-');
      // Absolute fallback: first available locale
      resolved ??= locales.firstOrNull?.localeId.replaceAll('_', '-');

      _resolvedLocaleId = resolved;
      debugPrint('[STT] Chosen locale: $_resolvedLocaleId');
    }

    final isMalay = _resolvedLocaleId?.startsWith('ms') ?? false;

    _listenSessionToken = _sessionToken; // bind result callbacks to this session
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 60),
      pauseFor: isMalay
          ? const Duration(seconds: 3)
          : const Duration(seconds: 30),
      localeId: _resolvedLocaleId,
      onSoundLevelChange: (level) {
        _audioLevelController.add(((level + 2) / 12).clamp(0.0, 1.0));
      },
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );

    // 20s timer — only start once, not on every restart
    if (!_hasSpeech && _initialSilenceTimer == null) {
      _initialSilenceTimer = Timer(const Duration(seconds: 20), () {
        if (!_hasSpeech && _state == VoiceAssistantState.orderListening) {
          debugPrint('[STT] No speech detected in 20s — closing');
          _setState(VoiceAssistantState.noSpeechTimeout);
          Future.delayed(const Duration(seconds: 2), () {
            if (_state == VoiceAssistantState.noSpeechTimeout) {
              _setState(VoiceAssistantState.idle);
            }
          });
          _speech.stop();
        }
      });
    }
  }

  String _accumulatedText = ''; // full transcript across all sessions
  String _sessionText = ''; // transcript of current session only
  String _previousText = ''; // confirmed text from previous sessions
  int _listenSessionToken = 0; // token captured at listen start

  void _onSpeechResult(SpeechRecognitionResult result) {
    // Discard late callbacks from a previous session
    if (_listenSessionToken != _sessionToken) return;
    if (_state != VoiceAssistantState.orderListening) return;

    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) {
      _sessionText = words;
      // Append current session to previous sessions' text
      _accumulatedText = (_previousText.isEmpty)
          ? words
          : '$_previousText $words';
      _transcriptController.add(_accumulatedText);
    }

    if (words.isNotEmpty && !_hasSpeech) {
      _hasSpeech = true;
      _initialSilenceTimer?.cancel();
      _initialSilenceTimer = null;
      debugPrint('[STT] Speech detected, switching to 5s post-speech timer');
    }

    if (words.isNotEmpty) {
      // Reset 5s timer on every new word — this is the real end-of-speech trigger
      _postSpeechSilenceTimer?.cancel();
      _postSpeechSilenceTimer = Timer(const Duration(seconds: 5), () {
        if (_state == VoiceAssistantState.orderListening && !_orderCaptured) {
          debugPrint('[STT] 5s silence — processing: $_accumulatedText');
          _orderCaptured = true;
          _processOrderText(_accumulatedText);
        }
      });
    }

    if (result.finalResult && words.isNotEmpty) {
      _previousText = _accumulatedText;
      _sessionText = '';
      debugPrint(
        '[STT] Android finalResult — saved "$_previousText", restarting',
      );
      _scheduleRestart();
    } else if (result.finalResult && words.isEmpty) {
      // Final with nothing — let timers handle it
    }
  }

  // ── Order processing ──────────────────────────────────────────────────────

  Future<void> _processOrderText(String orderText) async {
    _setState(VoiceAssistantState.processing);
    await _speech.stop();

    try {
      final ownerId = UserService().currentOwnerId;
      if (ownerId == null) throw Exception('No owner ID');

      List<Map<String, dynamic>> products;
      Map<String, int> cart;

      if (_isModifying && _modifyProducts.isNotEmpty) {
        products = _modifyProducts;
        cart = await _parseModifyWithGemini(orderText, _modifyCart, products);
      } else {
        final productsRes = await Supabase.instance.client
            .from('products')
            .select(
              'id, name, unit_price, keyword, image_url, *, categories!inner(name)',
            )
            .eq('categories.business_id', ownerId);
        products = List<Map<String, dynamic>>.from(productsRes);
        cart = await _parseOrderWithGemini(orderText, products);
      }

      if (cart.containsKey('__no_match__') || cart.isEmpty) {
        _setState(VoiceAssistantState.noProductMatch);
        // Auto-reset to listening after 3s so user can retry
        await Future.delayed(const Duration(seconds: 3));
        if (_state == VoiceAssistantState.noProductMatch) {
          _orderCaptured = false;
          _hasSpeech = false;
          _setState(VoiceAssistantState.orderListening);
          await _startOrderListening();
        }
        return;
      }

      _lastResult = VoiceOrderResult(
        transcribedText: orderText,
        cart: cart,
        allProducts: products,
      );
      _setState(VoiceAssistantState.showingResult);
    } catch (e, stack) {
      debugPrint('[Voice] ❌ Error: $e\n$stack');
      _setState(VoiceAssistantState.idle);
    }
  }

  Future<Map<String, int>> _parseOrderWithGemini(
    String orderText,
    List<Map<String, dynamic>> products,
  ) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty)
      throw Exception('GEMINI_API_KEY not set');

    final productList = products
        .map(
          (p) => {
            'id': p['id'].toString(),
            'name': p['name'] ?? '',
            'keyword': p['keyword'] ?? '',
          },
        )
        .toList();

    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.0,
      ),
    );

    final response = await model
        .generateContent([
          Content.text('''
You are an order-parsing assistant for a food business POS system.
The spoken order may have been transcribed inaccurately by speech recognition — be very lenient with spelling, phonetics, and word boundaries.

Available Products:
${jsonEncode(productList)}

Spoken Order: "$orderText"

Rules:
- Match spoken words to product name OR keyword using fuzzy, phonetic, case-insensitive matching.
- The transcript may be in English, Malay, Chinese, or mixed — handle all.
- Common Malay quantity words: "satu"→1, "dua"→2, "tiga"→3, "empat"→4, "lima"→5, "sebuah"/"sebiji"/"satu"→1.
- Common Chinese quantity words: "一"→1, "两"/"兩"→2, "三"→3, "四"→4, "五"→5, "一个"/"一份"→1.
- English quantities: "one"→1, "two"→2, "three"→3, "four"→4, "five"→5, "a"/"an"→1.
- If a word sounds like or is a phonetic approximation of a product name, match it.
- Return ONLY a valid JSON object: { "product-id": quantity, ... }
- If nothing matches any product, return { "__no_match__": true }.

Return ONLY valid JSON, no explanation, no markdown.
'''),
        ])
        .timeout(const Duration(seconds: 8));

    try {
      final cleanJson = (response.text ?? '{}')
          .trim()
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (e) {
      debugPrint('[Gemini] Parse error: $e');
      return {};
    }
  }

  Future<Map<String, int>> _parseModifyWithGemini(
    String instruction,
    Map<String, int> currentCart,
    List<Map<String, dynamic>> products,
  ) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty)
      throw Exception('GEMINI_API_KEY not set');

    final productList = products
        .map(
          (p) => {
            'id': p['id'].toString(),
            'name': p['name'] ?? '',
            'keyword': p['keyword'] ?? '',
          },
        )
        .toList();

    // Build current order with names for Gemini context
    final currentOrderNamed = currentCart.entries.map((e) {
      final product = products.firstWhere(
        (p) => p['id'].toString() == e.key,
        orElse: () => {'name': e.key},
      );
      return {'id': e.key, 'name': product['name'], 'quantity': e.value};
    }).toList();

    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.0,
      ),
    );

    final response = await model
        .generateContent([
          Content.text('''
You are modifying an existing food order based on a spoken instruction.

Current Order:
${jsonEncode(currentOrderNamed)}

Available Products:
${jsonEncode(productList)}

Spoken Instruction: "$instruction"

Rules:
- Start with the current order and apply the spoken instruction.
- "add X" → add X to the order (match by name/keyword, fuzzy/phonetic).
- "remove X" / "cancel X" / "no X" → remove X from the order.
- "change X to Y" → replace item X with item Y.
- "make it two" / "change to 3" → update quantity of the most recently mentioned item.
- The instruction may be in English, Malay, Chinese, or mixed — handle all.
- Common Malay quantity words: "satu"→1, "dua"→2, "tiga"→3, "empat"→4, "lima"→5.
- Common Chinese quantity words: "一"→1, "两"/"兩"→2, "三"→3, "四"→4, "五"→5.
- If nothing can be understood, return the current order unchanged.
- Return ONLY a valid JSON object: { "product-id": quantity, ... }
- Omit items with quantity 0 or removed items.

Return ONLY valid JSON, no explanation, no markdown.
'''),
        ])
        .timeout(const Duration(seconds: 8));

    try {
      final cleanJson = (response.text ?? '{}')
          .trim()
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (e) {
      debugPrint('[Gemini Modify] Parse error: $e');
      return currentCart; // fallback: return unchanged order
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setState(VoiceAssistantState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
