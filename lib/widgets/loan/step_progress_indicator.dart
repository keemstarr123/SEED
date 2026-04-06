import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StepProgressIndicator extends StatelessWidget {
  final int currentStep; // 1-based

  const StepProgressIndicator({super.key, required this.currentStep});

  static const _labels = ['Product', 'Personal', 'Review', 'Submit'];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (i) {
        // Even indices = step circles, odd indices = connectors
        if (i.isOdd) {
          final stepIndex = i ~/ 2; // 0-based step to the left
          final isCompleted = (stepIndex + 1) < currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 14.h),
              child: Row(
                children: List.generate(
                  5,
                  (j) => Expanded(
                    child: Container(
                      height: 1.5,
                      color: j.isEven
                          ? (isCompleted
                              ? Colors.black
                              : Colors.grey.shade300)
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final step = i ~/ 2 + 1;
        final isActive = step == currentStep;
        final isCompleted = step < currentStep;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? const Color(0xFF38B6FF)
                    : isCompleted
                        ? Colors.black
                        : Colors.white,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF38B6FF)
                      : isCompleted
                          ? Colors.black
                          : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  '$step',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: (isActive || isCompleted)
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              _labels[step - 1],
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? const Color(0xFF38B6FF)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        );
      }),
    );
  }
}
