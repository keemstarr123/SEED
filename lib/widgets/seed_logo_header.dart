import 'package:flutter/material.dart';
import 'dart:math' as math;

class SeedLogoHeader extends StatelessWidget {
  const SeedLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      width: 350,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Concentric Circles
          for (int i = 0; i < 3; i++)
            Container(
              width: 140.0 + (i * 95),
              height: 140.0 + (i * 95),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9 - (i * 0.3)),
                border: Border.all(
                  width: 1.5,
                  color: Colors.white.withValues(alpha: 0.8 - (i * 0.3)),
                ),
              ),
            ),
          // Center Item
          Container(
            width: 85,
            height: 85,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            // Placeholder icon for center illustration
            child: Image.asset(
              'assets/images/Landing_Page/Landing_Page_Main_Icon.png',
              width: 60,
              height: 60,
            ),
          ),

          // Surrounding Icons (Fixed)
          LayoutBuilder(
            builder: (context, constraints) {
              double radius = 120.0;
              double centerX = constraints.maxWidth / 2;
              double centerY = constraints.maxHeight / 2;

              return Stack(
                children: [
                  for (int i = 0; i < 6; i++)
                    Builder(
                      builder: (context) {
                        double angle = (210 + (i * 60)) * (math.pi / 180);
                        List<double> rotateAngle = [6, -4, 2, -10, 5, -5];
                        // Ensure index is within bounds for rotateAngle list
                        double currentRotateAngle = i < rotateAngle.length
                            ? rotateAngle[i]
                            : 0;

                        return Positioned(
                          left: centerX + radius * math.cos(angle) - 30,
                          top: centerY + radius * math.sin(angle) - 30,
                          child: Transform.rotate(
                            angle: currentRotateAngle * (math.pi / 180),
                            child: Container(
                              width: 60,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFBEBEBE),
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/Landing_Page/Landing_Page_Icon_${i + 1}.png',
                                  width: 60,
                                  height: 60,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.error,
                                        color: Colors.red,
                                      ),
                                ),
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
