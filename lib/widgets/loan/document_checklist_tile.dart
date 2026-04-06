import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DocumentChecklistTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isSeedPrepared;

  const DocumentChecklistTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.isSeedPrepared,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSeedPrepared
        ? const Color(0xFF1D9E75)
        : const Color(0xFFBA7517);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(
            isSeedPrepared ? Icons.check_circle : Icons.warning_amber_rounded,
            color: color,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
