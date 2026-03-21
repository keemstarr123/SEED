import 'dart:async';
import 'package:flutter/material.dart';
import 'package:siri_wave/siri_wave.dart';
import 'package:seed/services/voice_assistant_service.dart';
import 'package:seed/screens/checkout_screen.dart';
import 'package:seed/main.dart';

class VoiceAssistantOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const VoiceAssistantOverlay({super.key, required this.onDismiss});

  @override
  State<VoiceAssistantOverlay> createState() =>
      _VoiceAssistantOverlayState();
}

class _VoiceAssistantOverlayState extends State<VoiceAssistantOverlay>
    with SingleTickerProviderStateMixin {
  final _service = VoiceAssistantService();

  late final IOS9SiriWaveformController _waveController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  StreamSubscription<VoiceAssistantState>? _stateSub;
  StreamSubscription<double>? _audioLevelSub;
  StreamSubscription<String>? _transcriptSub;

  VoiceAssistantState _state = VoiceAssistantState.orderListening;
  String _transcript = '';
  Map<String, int> _cart = {};

  @override
  void initState() {
    super.initState();

    _waveController = IOS9SiriWaveformController(speed: 0.2, amplitude: 0.0);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _state = _service.currentState;
    if (_service.lastResult != null) {
      _cart = Map.from(_service.lastResult!.cart);
    }

    _stateSub = _service.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      if (state == VoiceAssistantState.showingResult) {
        final result = _service.lastResult;
        if (result != null) setState(() => _cart = Map.from(result.cart));
      }
    });

    _audioLevelSub = _service.audioLevelStream.listen((level) {
      _waveController.amplitude = level;
    });

    _transcriptSub = _service.transcriptStream.listen((text) {
      if (mounted) setState(() => _transcript = text);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _audioLevelSub?.cancel();
    _transcriptSub?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _dismiss() {
    _service.dismissAndReset();
    widget.onDismiss();
  }

  void _confirmOrder() {
    final result = _service.lastResult;
    if (result == null) return;

    // Snapshot cart before dismissing
    final cartSnapshot = Map<String, int>.from(_cart);
    final productsSnapshot = List<Map<String, dynamic>>.from(result.allProducts);

    widget.onDismiss();
    _service.dismissAndReset();

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          initialCart: cartSnapshot,
          products: productsSnapshot,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // ── Dark background (tap outside to dismiss during listening) ──
            GestureDetector(
              onTap: _state == VoiceAssistantState.showingResult ? null : _dismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.87)),
            ),

            // ── Listening / Processing view ────────────────────────────────
            if (_state != VoiceAssistantState.showingResult)
              _buildListeningView(),

            // ── My Order dialog ────────────────────────────────────────────
            if (_state == VoiceAssistantState.showingResult &&
                _service.lastResult != null)
              _buildMyOrderDialog(),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningView() {
    return SafeArea(
      child: Column(
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.close, color: Colors.white54, size: 28),
              ),
            ),
          ),

          const Spacer(),

          // Waveform – SiriWaveform.ios9 is the correct constructor in siri_wave 2.3.0
          SiriWaveform.ios9(
            controller: _waveController,
            options: const IOS9SiriWaveformOptions(
              width: 400,
              height: 120,
              showSupportBar: false,
            ),
          ),

          const SizedBox(height: 28),

          // Transcript
          if (_transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '"$_transcript"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 20),

          // Status label
          Text(
            _statusLabel,
            style: const TextStyle(
              color: Color(0xFF40BBFF),
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 56),
          const Spacer(),
        ],
      ),
    );
  }

  String get _statusLabel {
    switch (_state) {
      case VoiceAssistantState.orderListening:
        return 'listening...';
      case VoiceAssistantState.processing:
        return 'processing...';
      default:
        return 'listening...';
    }
  }

  Widget _buildMyOrderDialog() {
    final result = _service.lastResult!;

    final cartProducts = result.allProducts
        .where((p) => _cart.containsKey(p['id'].toString()))
        .toList();

    double total = 0.0;
    for (final entry in _cart.entries) {
      final product = result.allProducts.firstWhere(
        (p) => p['id'].toString() == entry.key,
        orElse: () => {},
      );
      if (product.isNotEmpty) {
        total +=
            ((product['unit_price'] as num?)?.toDouble() ?? 0.0) * entry.value;
      }
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'My Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // Item list (scrollable if many items)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: cartProducts.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),
                itemBuilder: (_, index) =>
                    _buildOrderItem(cartProducts[index]),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // Total
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  Text(
                    'RM${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dismiss,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Modify',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cartProducts.isEmpty ? null : _confirmOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF40BBFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> product) {
    final productId = product['id'].toString();
    final name = product['name'] ?? 'Unknown';
    final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
    final qty = _cart[productId] ?? 0;
    final imageUrl = product['image_url'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB284),
              shape: BoxShape.circle,
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl == null
                ? const Icon(Icons.fastfood, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 12),

          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'RM ${price.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // Qty controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _circleButton(Icons.remove, () {
                setState(() {
                  final current = _cart[productId] ?? 0;
                  if (current <= 1) {
                    _cart.remove(productId);
                  } else {
                    _cart[productId] = current - 1;
                  }
                });
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$qty',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              _circleButton(Icons.add, () {
                setState(() {
                  _cart[productId] = (_cart[productId] ?? 0) + 1;
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }
}
