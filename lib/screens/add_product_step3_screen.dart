import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/services/user_service.dart';

class AddProductStep3Screen extends StatefulWidget {
  final List<Map<String, dynamic>> extractedProducts;

  const AddProductStep3Screen({super.key, required this.extractedProducts});

  @override
  State<AddProductStep3Screen> createState() => _AddProductStep3ScreenState();
}

class _AddProductStep3ScreenState extends State<AddProductStep3Screen> {
  final List<String> _categories = ['Beverages', 'Snacks'];
  int? _addingCategoryForProductId;
  final TextEditingController _newCategoryController = TextEditingController();

  late List<Map<String, dynamic>> _products;

  @override
  void initState() {
    super.initState();
    // Deep copy the parsed products so they can be modified
    _products = List<Map<String, dynamic>>.from(
      widget.extractedProducts.map((p) => Map<String, dynamic>.from(p)),
    );

    // Collect unique categories from the extracted products and add to the list
    for (var p in _products) {
      final String? cat = p['category']?.toString();
      if (cat != null && cat.isNotEmpty && !_categories.contains(cat)) {
        _categories.add(cat);
      }
    }
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _importProducts() async {
    final businessId = UserService().currentOwnerId;
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Business ID not found. Please log in again.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = Supabase.instance.client;
      Map<String, String> categoryCache = {}; // name -> uuid

      for (var product in _products) {
        final categoryName = product['category']?.toString() ?? 'General';

        // 1. Handle Category
        if (!categoryCache.containsKey(categoryName)) {
          final existingCat = await supabase
              .from('categories')
              .select('id')
              .eq('name', categoryName)
              .eq('business_id', businessId)
              .maybeSingle();

          if (existingCat != null) {
            categoryCache[categoryName] = existingCat['id'];
          } else {
            final newCat = await supabase
                .from('categories')
                .insert({'name': categoryName, 'business_id': businessId})
                .select('id')
                .single();
            categoryCache[categoryName] = newCat['id'];
          }
        }

        final categoryId = categoryCache[categoryName];

        // 2. Handle Image Upload (Optional - requires 'product-images' bucket)
        String? imageUrl;
        if (product['imageBytes'] != null) {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${product['id']}.jpg';
          try {
            await supabase.storage
                .from('product-images')
                .uploadBinary(
                  fileName,
                  product['imageBytes'],
                  fileOptions: const FileOptions(contentType: 'image/jpeg'),
                );
            imageUrl = supabase.storage
                .from('product-images')
                .getPublicUrl(fileName);
          } catch (e) {
            debugPrint('Storage upload failed: $e');
          }
        }

        // 3. Insert Product
        await supabase.from('products').insert({
          'name': product['name'],
          'sku': product['sku'] ?? '',
          'unit_price':
              double.tryParse(product['price']?.toString() ?? '0') ?? 0.0,
          'keyword': product['keyword'],
          'description': product['description'],
          'category_id': categoryId,
          'image_url': imageUrl,
        });
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All products imported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      debugPrint('Import Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Review Information',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar Area
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Step 3 of 3',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '100% Complete',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF38B6FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: Color(0xFFE6E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF38B6FF),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Banner Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2F4FD),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF38B6FF),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Confirm information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please review the product details extracted\nby our AI from your uploaded image.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // PRODUCTS Title Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'PRODUCTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // List of Placeholder Products
                    ..._products
                        .map((product) => _buildProductCard(product))
                        .toList(),
                  ],
                ),
              ),
            ),

            // Bottom Button Area
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFFF8F9FE)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _importProducts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF40BBFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Confirm & Import',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You can still edit these details after importing.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    bool isExpanded = product['isExpanded'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Collapsed View (Header)
          InkWell(
            onTap: () {
              setState(() {
                product['isExpanded'] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Icon or Image
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F4FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      image: product['imageBytes'] != null
                          ? DecorationImage(
                              image: MemoryImage(product['imageBytes']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product['imageBytes'] == null
                        ? const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF38B6FF),
                            size: 20,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Title / Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRODUCT ITEM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product['name'],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Edit Button
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        product['isExpanded'] = !isExpanded;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Expanded View
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
                top: 4,
              ),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildEditableRow(
                    'Product Name',
                    product['name'] ?? '',
                    (val) => product['name'] = val,
                  ),
                  const SizedBox(height: 12),
                  _buildEditableRow(
                    'SKU (Optional)',
                    product['sku'] ?? '',
                    (val) => product['sku'] = val,
                  ),
                  const SizedBox(height: 12),
                  _buildEditableRow(
                    'Unit Price',
                    product['price'] ?? '',
                    (val) => product['price'] = val,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixText: '\$',
                  ),
                  const SizedBox(height: 12),
                  _buildEditableRow(
                    'Keyword',
                    product['keyword'] ?? '',
                    (val) => product['keyword'] = val,
                  ),
                  const SizedBox(height: 12),
                  _buildEditableRow(
                    'Description',
                    product['description'] ?? '',
                    (val) => product['description'] = val,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Category Selection for this product
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ..._categories.map((cat) {
                            final isSelected = product['category'] == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  product['category'] = selected ? cat : null;
                                  _addingCategoryForProductId = null;
                                });
                              },
                              selectedColor: const Color(0xFFE2F4FD),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF38B6FF)
                                    : Colors.grey.shade300,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF38B6FF)
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                          if (_addingCategoryForProductId == product['id'])
                            SizedBox(
                              width: 140,
                              height: 38,
                              child: TextField(
                                controller: _newCategoryController,
                                decoration: InputDecoration(
                                  hintText: 'New category...',
                                  hintStyle: const TextStyle(fontSize: 12),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF38B6FF),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF38B6FF),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF38B6FF),
                                      width: 2,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Color(0xFF38B6FF),
                                    ),
                                    onPressed: () {
                                      _saveNewCategory(product);
                                    },
                                  ),
                                ),
                                onSubmitted: (val) {
                                  _saveNewCategory(product);
                                },
                              ),
                            )
                          else
                            ActionChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.add, size: 16, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text('Add New'),
                                ],
                              ),
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.grey,
                                style: BorderStyle.solid,
                              ),
                              onPressed: () {
                                setState(() {
                                  _addingCategoryForProductId = product['id'];
                                  _newCategoryController.clear();
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(
    String label,
    String value,
    Function(String) onChanged, {
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            initialValue: value,
            onChanged: onChanged,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              isDense: true,
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF38B6FF)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _saveNewCategory(Map<String, dynamic> product) {
    final text = _newCategoryController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_categories.contains(text)) {
          _categories.add(text);
        }
        product['category'] = text;
        _addingCategoryForProductId = null;
        _newCategoryController.clear();
      });
    } else {
      setState(() {
        _addingCategoryForProductId = null;
      });
    }
  }
}


<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>
