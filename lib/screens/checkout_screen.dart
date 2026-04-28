import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/main.dart'; // For AppLayout
import 'package:seed/screens/order_status_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/services/user_service.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, int> initialCart;
  final List<Map<String, dynamic>> products;
  final String? orderIdToUpdate;

  const CheckoutScreen({
    super.key,
    required this.initialCart,
    required this.products,
    this.orderIdToUpdate,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late Map<String, int> _cart;
  int _currentIndex = 0; // Or whatever is appropriate for the active tab
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Copy the map to avoid direct mutation of the parent's map initially
    // though we want to modify it, but we can return it when navigating back
    _cart = Map<String, int>.from(widget.initialCart);
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

  double get _itemsTotal {
    double total = 0.0;
    for (var entry in _cart.entries) {
      final product = widget.products.firstWhere(
        (p) => p['id'].toString() == entry.key,
      );
      final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
      total += price * entry.value;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final itemsTotal = _itemsTotal;
    final sst = itemsTotal * 0.06;
    final discount = 0.0;
    final totalPayment = itemsTotal + sst - discount;

    List<Map<String, dynamic>> cartProducts = widget.products.where((p) {
      return _cart.containsKey(p['id'].toString());
    }).toList();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _cart);
        return false;
      },
      child: AppLayout(
        currentIndex: _currentIndex,
        extendBody: true,
        showNav: false,
        backgroundColor: const Color(0xFFF8F9FE),
        onNavPressed: (i) {
          setState(() => _currentIndex = i);
        },
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24.h),
                      Text(
                        'New Order',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // List of Items
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cartProducts.length,
                        itemBuilder: (context, index) {
                          return _buildCartItem(cartProducts[index]);
                        },
                      ),
                      if (cartProducts.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          child: Center(
                            child: Text(
                              'Cart is empty',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
              // Bottom Section (Summary + Button)
              if (cartProducts.isNotEmpty)
                Container(
                  padding: EdgeInsets.only(
                    left: 24.w,
                    right: 24.w,
                    top: 16.h,
                    bottom: 110.h, // Breathing space over navbar
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FE), // Same as app background
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(20.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryRow('Total Items', itemsTotal),
                            SizedBox(height: 12.h),
                            _buildSummaryRow('SST (6%)', sst),
                            SizedBox(height: 12.h),
                            _buildSummaryRow('Discount', discount),
                            SizedBox(height: 12.h),
                            const Divider(color: Colors.grey),
                            SizedBox(height: 12.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Payment',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'RM${totalPayment.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  setState(() => _isProcessing = true);

                                  bool success = false;
                                  String? errorMsg;

                                  try {
                                    final ownerId =
                                        UserService().currentOwnerId;
                                    if (ownerId == null)
                                      throw Exception('No business ID found.');

                                    final supabase = Supabase.instance.client;

                                    dynamic orderId = widget.orderIdToUpdate;

                                    if (orderId == null) {
                                      // Insert new order and return it to get the ID
                                      final orderRes = await supabase
                                          .from('orders')
                                          .insert({
                                            'subtotal': itemsTotal,
                                            'tax_amount': sst,
                                            'discount_amount': discount,
                                            'total_amount': totalPayment,
                                            'order_source': 'POS',
                                            'location': 'Main Counter',
                                            'transaction_status': 'Pending',
                                            'business_id': ownerId,
                                          })
                                          .select()
                                          .single();

                                      orderId = orderRes['id'];
                                    } else {
                                      // Update existing order
                                      await supabase
                                          .from('orders')
                                          .update({
                                            'subtotal': itemsTotal,
                                            'tax_amount': sst,
                                            'discount_amount': discount,
                                            'total_amount': totalPayment,
                                          })
                                          .eq('id', orderId);

                                      // clear old items for easy recreation
                                      await supabase
                                          .from('order_details')
                                          .delete()
                                          .eq('transaction_id', orderId);
                                    }

                                    // Attempt to insert order items
                                    try {
                                      List<Map<String, dynamic>> itemsToInsert =
                                          [];
                                      for (var entry in _cart.entries) {
                                        final product = widget.products
                                            .firstWhere(
                                              (p) =>
                                                  p['id'].toString() ==
                                                  entry.key,
                                            );
                                        final price =
                                            (product['unit_price'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        itemsToInsert.add({
                                          'transaction_id': orderId,
                                          'product_id': entry.key,
                                          'quantity': entry.value,
                                          'amount': price * entry.value,
                                        });
                                      }

                                      if (itemsToInsert.isNotEmpty) {
                                        await supabase
                                            .from('order_details')
                                            .insert(itemsToInsert);
                                      }
                                    } catch (itemError) {
                                      debugPrint(
                                        'Failed to insert order details: $itemError',
                                      );
                                    }

                                    success = true;
                                  } catch (e) {
                                    success = false;
                                    errorMsg = e.toString();
                                  }

                                  if (!mounted) return;

                                  setState(() => _isProcessing = false);

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrderStatusScreen(
                                        isSuccess: success,
                                        errorMessage: success
                                            ? null
                                            : 'Failed to process the order. Please make sure your internet is stable and try again. Details: $errorMsg',
                                      ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF40BBFF),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                          child: _isProcessing
                              ? SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  widget.orderIdToUpdate != null
                                      ? 'Update Order'
                                      : 'Confirm Order',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'RM${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(Map<String, dynamic> product) {
    final productId = product['id'].toString();
    final name = product['name'] ?? 'Unknown';
    final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
    String catName = 'General';
    if (product['categories'] != null &&
        product['categories']['name'] != null) {
      catName = product['categories']['name'];
    }
    final imageUrl = product['image_url'];
    final qty = _cart[productId] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(8.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Image Box
          Container(
            width: 60.w,
            height: 60.h,
            decoration: BoxDecoration(
              color: const Color(
                0xFFFFB284,
              ), // Light orange background behind image
              borderRadius: BorderRadius.circular(12.r),
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl == null
                ? const Icon(Icons.fastfood, color: Colors.white54)
                : null,
          ),
          SizedBox(width: 12.w),
          // Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  catName,
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: AppTheme.smallTextSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  'RM ${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Quantity Controls
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _updateCart(productId, -1),
                  child: Container(
                    margin: EdgeInsets.all(4.r),
                    padding: EdgeInsets.all(4.r),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 14.sp,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    '$qty',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _updateCart(productId, 1),
                  child: Container(
                    margin: EdgeInsets.all(4.r),
                    padding: EdgeInsets.all(4.r),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: Colors.white, size: 14.sp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context, _cart),
            child: Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black87,
                size: 18.sp,
              ),
            ),
          ),
          Text(
            'Check Out',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.more_vert, color: Colors.black87, size: 20.sp),
          ),
        ],
      ),
    );
  }
}
