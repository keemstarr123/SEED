import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;

class SeedLogoHeader extends StatelessWidget {
  const SeedLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320.w,
      width: 320.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 3; i++)
            Container(
              width: (120.0 + (i * 80)).w,
              height: (120.0 + (i * 80)).w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9 - (i * 0.3)),
                border: Border.all(
                  width: 1.5,
                  color: Colors.white.withValues(alpha: 0.8 - (i * 0.3)),
                ),
              ),
            ),
          Container(
            width: 80.w,
            height: 80.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(15.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/Landing_Page/Landing_Page_Main_Icon.png',
              width: 55.w,
              height: 55.w,
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              double radius = constraints.maxWidth * 0.35;
              double centerX = constraints.maxWidth / 2;
              double centerY = constraints.maxHeight / 2;
              double iconSize = constraints.maxWidth * 0.17;

              return Stack(
                children: [
                  for (int i = 0; i < 6; i++)
                    Builder(
                      builder: (context) {
                        double angle = (210 + (i * 60)) * (math.pi / 180);
                        List<double> rotateAngle = [6, -4, 2, -10, 5, -5];
                        double currentRotateAngle = i < rotateAngle.length ? rotateAngle[i] : 0;

                        return Positioned(
                          left: centerX + radius * math.cos(angle) - iconSize / 2,
                          top: centerY + radius * math.sin(angle) - iconSize / 2,
                          child: Transform.rotate(
                            angle: currentRotateAngle * (math.pi / 180),
                            child: Container(
                              width: iconSize,
                              height: iconSize,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFBEBEBE),
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(15.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/Landing_Page/Landing_Page_Icon_${i + 1}.png',
                                width: iconSize,
                                height: iconSize,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.error, color: Colors.red),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
