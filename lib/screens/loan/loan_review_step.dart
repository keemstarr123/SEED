import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoanReviewStep extends StatelessWidget {
  final VoidCallback onNext;

  const LoanReviewStep({super.key, required this.onNext});

  static const _seedDocs = [
    'Business Profile Document',
    'Monthly Sales Report',
    'Personal Profile Summary',
    'e-Invoice Summary',
    'Activity Log',
  ];

  static const _userDocs = [
    'Bank Statement',
    'Income Tax Document',
    'NRIC (Front and Back)',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                // SEED-prepared documents — blue card
                _docCard(
                  color: const Color(0xFF38B6FF),
                  icon: Icons.check_circle,
                  title: 'Documents prepared by SEED',
                  docs: _seedDocs,
                  isSeed: true,
                ),
                SizedBox(height: 16.h),
                // User-prepared documents — amber/peach card
                _docCard(
                  color: const Color(0xFFFFB347),
                  icon: Icons.check_circle,
                  title: 'Documents prepared by you',
                  docs: _userDocs,
                  isSeed: false,
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
        _bottomButton(context),
      ],
    );
  }

  Widget _docCard({
    required Color color,
    required IconData icon,
    required String title,
    required List<String> docs,
    required bool isSeed,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14.sp, color: Colors.white),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.more_vert, size: 18.sp, color: Colors.black54),
            ],
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: docs.map((doc) => _docChip(doc, color, isSeed)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _docChip(String label, Color color, bool isSeed) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSeed ? Icons.check : Icons.radio_button_unchecked,
              size: 11.sp,
              color: color,
            ),
          ),
          SizedBox(width: 6.w),
          Text(label, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _bottomButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.r)),
            elevation: 0,
          ),
          child: Text('Next',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
