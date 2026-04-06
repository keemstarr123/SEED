import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/main.dart';

class OrderStatusScreen extends StatelessWidget {
  final bool isSuccess;
  final String? errorMessage;

  const OrderStatusScreen({
    super.key,
    required this.isSuccess,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentIndex: 0,
      onNavPressed: (_) => Navigator.of(context).popUntil((r) => r.isFirst),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96.w,
                  height: 96.w,
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.cancel,
                    size: 56.sp,
                    color: isSuccess
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE53935),
                  ),
                ),
                SizedBox(height: 28.h),
                Text(
                  isSuccess ? 'Order Placed!' : 'Order Failed',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  isSuccess
                      ? 'Your order has been successfully submitted.'
                      : (errorMessage ?? 'Something went wrong. Please try again.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 40.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF40BBFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isSuccess ? 'Back to Home' : 'Try Again',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
