import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seed/screens/add_product_step3_screen.dart';
import 'package:seed/services/ai_extraction_service.dart';

class AddProductStep2Screen extends StatefulWidget {
  final String method; // 'import' or 'manual'

  const AddProductStep2Screen({super.key, required this.method});

  @override
  State<AddProductStep2Screen> createState() => _AddProductStep2ScreenState();
}

class _ManualItemState {
  bool isExpanded = true;
  String? selectedCategory;
  bool isAddingNewCategory = false;
  Uint8List? imageBytes;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController keywordController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController newCategoryController = TextEditingController();

  void dispose() {
    nameController.dispose();
    skuController.dispose();
    priceController.dispose();
    keywordController.dispose();
    descriptionController.dispose();
    newCategoryController.dispose();
  }
}

class _AddProductStep2ScreenState extends State<AddProductStep2Screen> {
  final List<String> _categories = ['Beverages', 'Snacks'];
  final List<_ManualItemState> _manualItems = [_ManualItemState()];

  @override
  void dispose() {
    for (var item in _manualItems) {
      item.dispose();
    }
    super.dispose();
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
        title: Text(
          widget.method == 'import' ? 'Import Products' : 'Add Product',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar Area
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 8.h,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step 2 of 3',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '66%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF38B6FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: 0.66,
                      backgroundColor: const Color(0xFFE6E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF38B6FF),
                      ),
                      minHeight: 6.h,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: widget.method == 'import'
                    ? _buildImportView()
                    : _buildManualView(),
              ),
            ),

            // Bottom Button Area
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: const BoxDecoration(color: Color(0xFFF8F9FE)),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (widget.method == 'import') {
                          // In import mode, force them to use the Browse Files button instead of the bottom Continue button
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please upload a menu image or file using the import area above.',
                              ),
                            ),
                          );
                          return;
                        }

                        // For manual, gather all data
                        List<Map<String, dynamic>> finalProducts = [];
                        for (int i = 0; i < _manualItems.length; i++) {
                          final item = _manualItems[i];
                          finalProducts.add({
                            'id': i,
                            'name': item.nameController.text.isEmpty
                                ? 'New Product'
                                : item.nameController.text,
                            'sku': item.skuController.text,
                            'price': item.priceController.text.isEmpty
                                ? '0'
                                : item.priceController.text,
                            'keyword': item.keywordController.text,
                            'description': item.descriptionController.text,
                            'category': item.selectedCategory,
                            'imageBytes': item.imageBytes,
                            'isExpanded': false,
                          });
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddProductStep3Screen(
                              extractedProducts: finalProducts,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(Icons.arrow_forward, size: 20.sp),
                        ],
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

  Widget _buildImportView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 24.h),
        DottedBorder(
          options: RoundedRectDottedBorderOptions(
            color: const Color(0xFF38B6FF).withValues(alpha: 0.5),

            strokeWidth: 1.5,
            dashPattern: const [8, 4],
            radius: const Radius.circular(16),
            padding: EdgeInsets.all(8.w),
          ),

          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F4FD).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD6EFFF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_upload_rounded,
                    color: const Color(0xFF38B6FF),
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Drag & drop files here',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Excel, CSV, or Image files supported',
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                ),
                SizedBox(height: 24.h),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final files = await picker.pickMultiImage();

                    if (files.isNotEmpty) {
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            const Center(child: CircularProgressIndicator()),
                      );

                      try {
                        final List<Uint8List> allImagesBytes = [];
                        for (var f in files) {
                          allImagesBytes.add(await f.readAsBytes());
                        }

                        final service = AiExtractionService();
                        final result = await service.extractAndGroupMenu(
                          allImagesBytes,
                        );
                        final extracted = result['menu_extraction'] as List;

                        List<Map<String, dynamic>> finalProducts = [];
                        for (int i = 0; i < extracted.length; i++) {
                          final p = extracted[i] as Map<String, dynamic>;
                          final cropBox =
                              p['image_crop_box'] as Map<String, dynamic>?;
                          final int sourceIdx =
                              (p['source_image_index'] as num? ?? 0).toInt();

                          Uint8List? imgBytes;
                          if (cropBox != null &&
                              sourceIdx < allImagesBytes.length) {
                            imgBytes = service.cropProductImage(
                              allImagesBytes[sourceIdx],
                              cropBox,
                            );
                          }

                          finalProducts.add({
                            'id': i,
                            'name': p['product_name'] ?? '',
                            'sku': p['sku'] ?? '',
                            'price': (p['unit_price'] ?? 0).toString(),
                            'keyword': p['keyword'] ?? '',
                            'description': p['description'] ?? '',
                            'category': p['category'],
                            'imageBytes': imgBytes,
                            'isExpanded': false,
                          });
                        }

                        if (mounted) {
                          Navigator.pop(context); // Close loading
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddProductStep3Screen(
                                extractedProducts: finalProducts,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context); // Close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error analyzing menu: $e')),
                          );
                        }
                      }
                    }
                  },
                  icon: Icon(Icons.file_present_rounded, size: 18.sp),
                  label: const Text(
                    'Browse files',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38B6FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._manualItems.asMap().entries.map((entry) {
          int index = entry.key;
          _ManualItemState itemState = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: _buildManualItemCard(index, itemState),
          );
        }).toList(),

        SizedBox(height: 8.h),
        // Add another item circular button
        Center(
          child: Column(
            children: [
              Container(
                width: 50.w,
                height: 50.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF38B6FF)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38B6FF).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF38B6FF)),
                  onPressed: () {
                    // Add a new item block
                    setState(() {
                      _manualItems.add(_ManualItemState());
                    });
                  },
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Add another item',
                style: TextStyle(
                  color: const Color(0xFF38B6FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildManualItemCard(int index, _ManualItemState itemState) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                itemState.isExpanded = !itemState.isExpanded;
              });
            },
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: const Color(0xFF38B6FF),
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'ITEM ${index + 1} DETAILS',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Icon(
                  itemState.isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          if (itemState.isExpanded) ...[
            SizedBox(height: 20.h),

            // Image Upload
            InkWell(
              onTap: () async {
                final picker = ImagePicker();
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (file != null) {
                  final bytes = await file.readAsBytes();
                  setState(() {
                    itemState.imageBytes = bytes;
                  });
                }
              },
              child: Row(
                children: [
                  Container(
                    width: 70.w,
                    height: 70.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FE),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid,
                      ),
                      image: itemState.imageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(itemState.imageBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: itemState.imageBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Image',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Text(
                      'Provide a clear image for this product (Optional).',
                      style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Product Name
            _buildTextField(
              label: 'Product Name',
              hint: 'e.g. Wireless Headphones',
              controller: itemState.nameController,
            ),

            // SKU
            _buildTextField(
              label: 'SKU (Optional)',
              hint: 'e.g. WH-1002',
              controller: itemState.skuController,
            ),

            Row(
              children: [
                // Unit Price
                Expanded(
                  child: _buildTextField(
                    label: 'Unit Price',
                    hint: '\$ 0.00',
                    controller: itemState.priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                // Keyword
                Expanded(
                  child: _buildTextField(
                    label: 'Voice Keyword',
                    hint: 'e.g. Headphone',
                    controller: itemState.keywordController,
                  ),
                ),
              ],
            ),

            // Description
            _buildTextField(
              label: 'Description (Optional)',
              hint: 'Describe the main features/ingredients...',
              controller: itemState.descriptionController,
              maxLines: 3,
            ),

            // Category Section
            Text(
              'Category',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._categories
                    .map(
                      (cat) => ChoiceChip(
                        label: Text(cat),
                        selected: itemState.selectedCategory == cat,
                        onSelected: (selected) {
                          setState(() {
                            itemState.selectedCategory = selected ? cat : null;
                            itemState.isAddingNewCategory = false;
                          });
                        },
                        selectedColor: const Color(0xFFE2F4FD),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: itemState.selectedCategory == cat
                              ? const Color(0xFF38B6FF)
                              : Colors.grey.shade300,
                        ),
                        labelStyle: TextStyle(
                          color: itemState.selectedCategory == cat
                              ? const Color(0xFF38B6FF)
                              : Colors.black87,
                          fontWeight: itemState.selectedCategory == cat
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    )
                    .toList(),
                if (itemState.isAddingNewCategory)
                  SizedBox(
                    width: 200.w,
                    height: 38.h,
                    child: TextField(
                      controller: itemState.newCategoryController,
                      style: TextStyle(fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: 'Eg. Rice',
                        hintStyle: TextStyle(
                          fontSize: 12.sp,
                          fontStyle: FontStyle.italic,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFF38B6FF),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFF38B6FF),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFF38B6FF),
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.check,
                            size: 18.sp,
                            color: const Color(0xFF38B6FF),
                          ),
                          onPressed: () {
                            if (itemState.newCategoryController.text
                                .trim()
                                .isNotEmpty) {
                              setState(() {
                                _categories.add(
                                  itemState.newCategoryController.text.trim(),
                                );
                                itemState.selectedCategory = itemState
                                    .newCategoryController
                                    .text
                                    .trim();
                                itemState.isAddingNewCategory = false;
                                itemState.newCategoryController.clear();
                              });
                            } else {
                              setState(() {
                                itemState.isAddingNewCategory = false;
                              });
                            }
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          setState(() {
                            if (!_categories.contains(val.trim())) {
                              _categories.add(val.trim());
                            }
                            itemState.selectedCategory = val.trim();
                            itemState.isAddingNewCategory = false;
                            itemState.newCategoryController.clear();
                          });
                        }
                      },
                    ),
                  )
                else
                  ActionChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16.sp, color: Colors.grey),
                        SizedBox(width: 4.w),
                        const Text('Add New'),
                      ],
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Colors.grey,
                      style: BorderStyle.solid,
                    ),
                    onPressed: () {
                      setState(() {
                        itemState.isAddingNewCategory = true;
                        itemState.selectedCategory = null;
                      });
                    },
                  ),
              ],
            ),
            SizedBox(height: 24.h),

            // Description
            _buildTextField(
              label: 'Description',
              hint: 'Write a short description...',
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: Color(0xFF38B6FF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
