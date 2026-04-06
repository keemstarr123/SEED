import 'dart:async';
import 'package:flutter/material.dart';
import 'package:siri_wave/siri_wave.dart';
import 'package:seed/services/voice_assistant_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/screens/pending_orders_screen.dart';
import 'package:seed/main.dart';

class VoiceAssistantOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const VoiceAssistantOverlay({super.key, required this.onDismiss});

  @override
  State<VoiceAssistantOverlay> createState() => _VoiceAssistantOverlayState();
}

class _VoiceAssistantOverlayState extends State<VoiceAssistantOverlay>
    with SingleTickerProviderStateMixin {
  final _service = VoiceAssistantService();

  // Correct class names from siri_wave 2.3.0
  late final IOS9SiriWaveformController _waveController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  StreamSubscription<VoiceAssistantState>? _stateSub;
  StreamSubscription<double>? _audioLevelSub;
  StreamSubscription<String>? _transcriptSub;

  VoiceAssistantState _state = VoiceAssistantState.orderListening;
  String _transcript = '';
  Map<String, int> _cart = {};
  String _selectedLocale = 'en-MY';

  bool _isCreatingOrder = false;
  bool _orderCreationSuccess = false;

  static const _locales = [
    ('EN-MY', 'en-MY'),
    ('EN-US', 'en-US'),
    ('中文', 'zh-CN'),
    ('BM', 'ms-MY'),
  ];

  @override
  void initState() {
    super.initState();

    _waveController = IOS9SiriWaveformController(speed: 0.15, amplitude: 0.3);

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
      } else if (state == VoiceAssistantState.idle) {
        widget.onDismiss();
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

  void _modifyOrder() {
    final result = _service.lastResult;
    if (result == null) return;
    setState(() => _transcript = '');
    _service.modifyOrder(
      currentCart: Map.from(_cart),
      allProducts: result.allProducts,
    );
  }

  Future<void> _confirmOrder() async {
    final result = _service.lastResult;
    if (result == null) return;

    setState(() {
      _isCreatingOrder = true;
    });

    final cartSnapshot = Map<String, int>.from(_cart);
    final productsSnapshot = List<Map<String, dynamic>>.from(
      result.allProducts,
    );

    double itemsTotal = 0.0;
    for (var entry in cartSnapshot.entries) {
      final product = productsSnapshot.firstWhere(
        (p) => p['id'].toString() == entry.key,
        orElse: () => {},
      );
      if (product.isNotEmpty) {
        final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
        itemsTotal += price * entry.value;
      }
    }

    final sst = itemsTotal * 0.06;
    final discount = 0.0;
    final totalPayment = itemsTotal + sst - discount;

    bool success = false;
    String? errorMsg;

    try {
      final ownerId = UserService().currentOwnerId;
      if (ownerId == null) throw Exception('No business ID found.');

      final supabase = Supabase.instance.client;

      final orderRes = await supabase
          .from('orders')
          .insert({
            'subtotal': itemsTotal,
            'tax_amount': sst,
            'discount_amount': discount,
            'total_amount': totalPayment,
            'order_source': 'Voice POS', // Identifying source
            'location': 'Main Counter',
            'transaction_status': 'Pending',
            'business_id': ownerId,
          })
          .select()
          .single();

      final orderId = orderRes['id'];

      List<Map<String, dynamic>> itemsToInsert = [];
      for (var entry in cartSnapshot.entries) {
        final product = productsSnapshot.firstWhere(
          (p) => p['id'].toString() == entry.key,
          orElse: () => {},
        );
        if (product.isNotEmpty) {
          final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
          itemsToInsert.add({
            'transaction_id': orderId,
            'product_id': entry.key,
            'quantity': entry.value,
            'amount': price * entry.value,
          });
        }
      }

      if (itemsToInsert.isNotEmpty) {
        await supabase.from('order_details').insert(itemsToInsert);
      }

      success = true;
    } catch (e) {
      success = false;
      errorMsg = e.toString();
    }

    if (!mounted) return;

    setState(() {
      _isCreatingOrder = false;
    });

    if (success) {
      setState(() {
        _orderCreationSuccess = true;
      });
      // Removed auto-dismiss timer so user can interact with the success modal buttons
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create order: $errorMsg')),
      );
    }
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
            // Dark background
            GestureDetector(
              onTap:
                  (_state == VoiceAssistantState.showingResult &&
                      !_orderCreationSuccess)
                  ? null
                  : _dismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.87)),
            ),

            // Listening view
            if (_state == VoiceAssistantState.orderListening ||
                _state == VoiceAssistantState.noSpeechTimeout)
              _buildListeningView(),

            // Processing loading screen
            if (_state == VoiceAssistantState.processing ||
                _state == VoiceAssistantState.noProductMatch)
              _buildProcessingView(),

            // My Order dialog
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

          // Waveform – uses SiriWaveform.ios9 with correct options type
          SiriWaveform.ios9(
            controller: _waveController,
            options: const IOS9SiriWaveformOptions(
              height: 120,
              width: 360,
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

          const SizedBox(height: 24),
          // Language picker
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _locales.map((entry) {
              final (label, localeId) = entry;
              final isSelected = _selectedLocale == localeId;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedLocale = localeId;
                    _transcript = '';
                  });
                  _service.switchLocale(localeId: localeId);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF40BBFF)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
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
      case VoiceAssistantState.noSpeechTimeout:
        return "I haven't heard from you, closing...";
      default:
        return 'listening...';
    }
  }

  Widget _buildProcessingView() {
    final isNoMatch = _state == VoiceAssistantState.noProductMatch;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isNoMatch
              ? const Icon(
                  Icons.search_off_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 56,
                )
              : const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    color: Color(0xFF40BBFF),
                    strokeWidth: 3,
                  ),
                ),
          const SizedBox(height: 24),
          Text(
            isNoMatch ? 'No products detected' : 'Processing your order...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isNoMatch
                ? 'Please try again and speak clearly.'
                : '"${_service.lastResult?.transcribedText ?? _transcript}"',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMyOrderDialog() {
    if (_orderCreationSuccess) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
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
              const Icon(
                Icons.check_circle,
                color: Color(0xFF40BBFF),
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'Order Confirmed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your order has been recorded.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dismiss,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _dismiss();
                        navigatorKey.currentState?.push(
                          MaterialPageRoute(
                            builder: (_) => const PendingOrdersScreen(),
                          ),
                        );
                      },
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
                        'View',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

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

            // Item list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: cartProducts.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),
                itemBuilder: (_, index) => _buildOrderItem(cartProducts[index]),
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
                      onPressed: _modifyOrder,
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
                      onPressed: (_cart.isEmpty || _isCreatingOrder)
                          ? null
                          : _confirmOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF40BBFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreatingOrder
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
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
