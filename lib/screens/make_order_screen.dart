import 'package:flutter/material.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/screens/checkout_screen.dart';
import 'package:seed/main.dart';

class MakeOrderScreen extends StatefulWidget {
  final Map<String, int>? initialCart;
  final String? orderIdToUpdate;

  const MakeOrderScreen({super.key, this.initialCart, this.orderIdToUpdate});

  @override
  State<MakeOrderScreen> createState() => _MakeOrderScreenState();
}

class _MakeOrderScreenState extends State<MakeOrderScreen> {
  int _currentIndex = 0; // for bottom nav bar
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Cart state: map of productId -> quantity
  Map<String, int> _cart = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialCart != null) {
      _cart = Map.from(widget.initialCart!);
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final ownerId = UserService().currentOwnerId;
      if (ownerId == null) return;

      final supabase = Supabase.instance.client;

      // Fetch products for this owner
      // Wait, products table has owner_id or category has business_id?
      // In add_product_step3_screen, we use business_id for categories, but wait...
      final productsRes = await supabase
          .from('products')
          .select('*, categories!inner(name)')
          .eq('categories.business_id', ownerId);

      setState(() {
        _products = List<Map<String, dynamic>>.from(productsRes);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    String lower = categoryName.toLowerCase();
    if (lower.contains('appetizer')) return Icons.kebab_dining;
    if (lower.contains('rice')) return Icons.rice_bowl;
    if (lower.contains('noodle')) return Icons.ramen_dining;
    if (lower.contains('western')) return Icons.fastfood;
    if (lower.contains('beverage') || lower.contains('drink'))
      return Icons.local_drink;
    if (lower.contains('snack')) return Icons.cookie;
    return Icons.restaurant_menu;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          (p['name']?.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);

      String catName = 'General';
      if (p['categories'] != null && p['categories']['name'] != null) {
        catName = p['categories']['name'];
      }
      final matchesCategory =
          _selectedCategory == 'All' || catName == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  int get _totalCartItems {
    return _cart.values.fold(0, (sum, item) => sum + item);
  }

  double get _totalCartPrice {
    double total = 0.0;
    for (var entry in _cart.entries) {
      final product = _products.firstWhere(
        (p) => p['id'].toString() == entry.key,
      );
      final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
      total += price * entry.value;
    }
    return total;
  }

  void _updateCart(String productId, int delta) {
    setState(() {
      int current = _cart[productId] ?? 0;
      int next = current + delta;
      if (next <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentIndex: _currentIndex,
      extendBody: true,
      backgroundColor: const Color(0xFFF8F9FE),
      onNavPressed: (i) {
        if (i == 0) {
          setState(() => _currentIndex = 0);
          Navigator.pop(context);
        } else {
          setState(() => _currentIndex = i);
        }
      },
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 50),
                      _buildCategories(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildProductsList()),
                    ],
                  ),
                ),
                if (_cart.isNotEmpty)
                  Positioned(
                    bottom: 100, // Above bottom nav slightly higher than FAB
                    left: 20,
                    right: 20,
                    child: _buildCartSummary(),
                  ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 169,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 50),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(15),
            ),
            gradient: LinearGradient(
              colors: [
                Color(0xFFBCE3FC),
                Color(0xFFFFDFD6),
              ], // Light cyan to peach
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'What the customer want\nto order?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert, color: Colors.black87),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -24,
          left: 24,
          right: 24,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                hintText: 'Search...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    final allCats = ['All'];
    // Extract unique category names from products just in case categories table is empty or disconnected
    for (var p in _products) {
      if (p['categories'] != null && p['categories']['name'] != null) {
        String catName = p['categories']['name'];
        if (!allCats.contains(catName)) {
          allCats.add(catName);
        }
      }
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: allCats.length,
        itemBuilder: (context, index) {
          final cat = allCats[index];
          final isSelected = _selectedCategory == cat;

          IconData iconData = Icons.grid_view;
          if (cat != 'All') {
            iconData = _getCategoryIcon(cat);
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      iconData,
                      color: isSelected ? Colors.black : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsList() {
    final list = _filteredProducts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _selectedCategory,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total ${list.length} results.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(
                bottom: 160,
              ), // Extra padding for cart and bottom nav
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                return _buildProductCard(list[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productId = product['id'].toString();
    final name = product['name'] ?? 'Unknown';
    final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
    String catName = 'General';
    if (product['categories'] != null &&
        product['categories']['name'] != null) {
      catName = product['categories']['name'];
    }
    final imageUrl = product['image_url'];
    final int qty = _cart[productId] ?? 0;

    return GestureDetector(
      onTap: () => _updateCart(productId, 1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Section
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF7AD3FF,
                    ), // Light blue background behind image
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (imageUrl == null)
                        const Center(
                          child: Icon(
                            Icons.fastfood,
                            size: 40,
                            color: Colors.white54,
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'RM${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Info Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 10.0,
                  right: 10.0,
                  top: 4.0,
                  bottom: 10.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: AppTheme.smallTextSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          catName,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: qty > 0
                          ? GestureDetector(
                              onTap:
                                  () {}, // empty tap to prevent card tap event
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _updateCart(productId, -1),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$qty',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _updateCart(productId, 1),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary() {
    return GestureDetector(
      onTap: () async {
        final updatedCart = await Navigator.push<Map<String, int>>(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              initialCart: _cart,
              products:
                  _products, // pass all items so checkout can access prices
              orderIdToUpdate: widget.orderIdToUpdate,
            ),
          ),
        );

        if (updatedCart != null) {
          setState(() {
            _cart = updatedCart;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_totalCartItems Items selected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  'RM${_totalCartPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB284), // Peach/orange
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
