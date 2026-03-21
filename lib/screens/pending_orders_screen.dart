import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/screens/make_order_screen.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = UserService().currentOwnerId;
      if (ownerId == null) throw Exception('No business ID found.');

      final supabase = Supabase.instance.client;

      // Fetch pending orders. We assume the transaction_status 'Pending' is used for new orders.
      // (If checkout sets it to Completed, you might need to change it there, but we'll fetch 'Pending' for kitchen).
      // If order_items exists, we fetch that too. If not, we might fail or return no items.

      // Attempting to fetch orders with their items.
      // Supabase format for relation: order_details(*)
      // Assuming foreign key exists. If it fails, we fall back to just orders.

      List<dynamic> response = [];
      try {
        response = await supabase
            .from('orders')
            .select('*, order_details(*, product:products(name, image_url))')
            .eq('business_id', ownerId)
            .eq('transaction_status', 'Pending')
            .order('created_at', ascending: true);
      } catch (e) {
        // Fallback if order_details relation fails
        response = await supabase
            .from('orders')
            .select('*')
            .eq('business_id', ownerId)
            .eq('transaction_status', 'Pending')
            .order('created_at', ascending: true);
      }

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeOrder(String orderId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('orders')
          .update({'transaction_status': 'Completed'})
          .eq('id', orderId);

      // Refresh list
      _fetchOrders();
    } catch (e) {
      debugPrint('Error completing order: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to complete order')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFFCF8F3,
      ), // Pale orange/peach bg from mockup
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kitchen View',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.orange),
              onPressed: () {},
              iconSize: 20,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(
              child: Text(
                'No pending orders.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LIVE ORDERS (${_orders.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569), // Slate grey
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Real-time Feed',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return _buildOrderCard(order, index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    // Generate a shorter ID for display
    final String fullId = order['id']?.toString() ?? 'Unknown';
    final String shortId = fullId.length > 8 ? fullId.substring(0, 8) : fullId;

    // Parse time
    String timeStr = 'N/A';
    if (order['created_at'] != null) {
      try {
        final dt = DateTime.parse(order['created_at']).toLocal();
        timeStr = DateFormat('h:mm a').format(dt);
      } catch (_) {}
    }

    final double totalAmount =
        (order['total_amount'] as num?)?.toDouble() ?? 0.0;

    // Items building
    List<dynamic> items = order['order_details'] ?? [];
    int itemCount =
        items.length; // Number of distinct item lines, or sum of quantities

    // Prepare item descriptions based on your request: "burger - 1\nfries - 1"
    List<Widget> itemWidgets = [];
    Map<String, int> initialCart = {};
    if (items.isNotEmpty) {
      for (var item in items) {
        String name = 'Unknown Item';
        if (item['product'] != null && item['product']['name'] != null) {
          name = item['product']['name'];
        } else if (item['product_name'] != null) {
          name = item['product_name'];
        }
        int qty = (item['quantity'] as num?)?.toInt() ?? 1;
        String productId = item['product_id']?.toString() ?? '';
        if (productId.isNotEmpty) {
          initialCart[productId] = qty;
        }

        itemWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              '$name - $qty',
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
          ),
        );
      }
    } else {
      // Mock items fallback if order_details logic failed to fetch any items
      itemWidgets = [
        const Text(
          'Items not recorded in database',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ];
    }

    // Determine color icon based on index or time to mock the design
    Color iconColor = index % 2 == 0 ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Time and Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.access_time, size: 14, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Text(
                'RM${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706), // Orange-brown
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Order ID
          Text(
            '#ORD-$shortId',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          // Row 3: Items section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$itemCount ITEMS',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: itemWidgets,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Row 4: Action Buttons
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF475569)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MakeOrderScreen(
                          initialCart: initialCart,
                          orderIdToUpdate: fullId,
                        ),
                      ),
                    ).then((_) => _fetchOrders());
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _completeOrder(fullId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2FE), // Very light blue
                    foregroundColor: const Color(
                      0xFF0284C7,
                    ), // Text blue (app theme)
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Complete Order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF40BBFF), // Match app theme blue color
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
