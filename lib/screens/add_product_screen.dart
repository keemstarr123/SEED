import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/screens/add_product_step2_screen.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  String _selectedMethod = 'import'; // defaulting to import

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Same as home page
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add a Product',
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
                        'Step 1 of 3',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '33%',
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
                      value: 0.33,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a Product',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Choose how you want to add your\nproduct',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Manual Entry Card
                    _buildOptionCard(
                      id: 'manual',
                      icon: Icons.edit_note_rounded,
                      title: 'Manual Entry',
                      subtitle: 'Fill in all details yourself',
                      isSelected: _selectedMethod == 'manual',
                      onTap: () => setState(() => _selectedMethod = 'manual'),
                    ),
                    SizedBox(height: 16.h),

                    // Import Card
                    _buildOptionCard(
                      id: 'import',
                      icon: Icons.camera_alt_outlined,
                      title: 'Import',
                      subtitle: 'From picture or Excel',
                      isRecommended: true,
                      isSelected: _selectedMethod == 'import',
                      onTap: () => setState(() => _selectedMethod = 'import'),
                      child: Container(
                        margin: EdgeInsets.only(top: 16.h),
                        height: 140.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A8B76),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Center(
                          child: Container(
                            width: 100.w,
                            padding: EdgeInsets.symmetric(
                              vertical: 8.h,
                              horizontal: 8.w,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 2,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Inventory',
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                ...List.generate(
                                  10,
                                  (index) => Container(
                                    height: 3.h,
                                    color: index == 0
                                        ? Colors.grey[400]
                                        : Colors.grey[200],
                                    margin: EdgeInsets.only(bottom: 4.h),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Button Area
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: const BoxDecoration(color: Color(0xFFF8F9FE)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddProductStep2Screen(method: _selectedMethod),
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
                  SizedBox(height: 16.h),
                  Text(
                    'You can always go back and change your choice later.',
                    style: TextStyle(color: Colors.grey, fontSize: 11.sp),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    bool isRecommended = false,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF38B6FF) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF38B6FF).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Box
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F4FD),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, color: const Color(0xFF38B6FF), size: 24.sp),
                ),
                SizedBox(width: 16.w),

                // Text Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          if (isRecommended) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2F4FD),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  color: const Color(0xFF38B6FF),
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Radio Button Equivalent
                Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF38B6FF)
                          : Colors.grey.shade300,
                      width: isSelected ? 6 : 2,
                    ),
                  ),
                ),
              ],
            ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }
}
