import 'package:flutter/material.dart';
import 'package:seed/screens/login_screen.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;
import 'package:seed/widgets/seed_logo_header.dart'; // Make sure this is kept!
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoginOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(
                0xFFE1F5FE,
              ), // Lighter base for better blending
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Stack(
                  children: [
                    Positioned(
                      top: -300,
                      right: -250,
                      child: _BlurBlob(
                        color: const Color(0xFFB388FF),
                        size: 700,
                      ), // Purple
                    ),
                    Positioned(
                      bottom: -300,
                      right: -200,
                      child: _BlurBlob(
                        color: const Color(0xFFFFAB91),
                        size: 700,
                      ), // Orange
                    ),
                    Positioned(
                      bottom: 0,
                      left: -400,
                      child: _BlurBlob(
                        color: const Color(0xFF30acf6),
                        size: 700,
                      ), // Purple
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            // Removed decoration
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  if (!_isLoginOpen)
                    Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/White_SEED_Logo.png',
                            width: 150.w,
                            height: 50.h,
                            semanticLabel: 'SEED Logo',
                          ),
                        ],
                      ),
                    ),

                  if (!_isLoginOpen)
                    const Spacer()
                  else
                    const SizedBox.shrink(),

                  // Circular Illustrations Placeholder
                  const SeedLogoHeader(),

                  const Spacer(),

                  // Text Content
                  if (!_isLoginOpen) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.w),
                      child: Column(
                        children: [
                          Text(
                            'Smarter Business',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Start with',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.eco,
                                      color: const Color(0xFFFFCC80),
                                      size: 20.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'SEED',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'Leverage AI to transform your business, where financing, ordering, and insights are always just a few clicks away.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPageIndicator(true),
                        SizedBox(width: 8.w),
                        _buildPageIndicator(false),
                        SizedBox(width: 8.w),
                        _buildPageIndicator(false),
                      ],
                    ),
                    SizedBox(height: 32.h),
                  ],

                  // Get Started Button
                  if (!_isLoginOpen)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 32.w,
                        vertical: 24.h,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoginOpen = true;
                            });
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              barrierColor: Colors
                                  .transparent, // Keeps the background visible
                              builder: (context) => SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.55,
                                child: const LoginScreen(),
                              ),
                            ).whenComplete(() {
                              setState(() {
                                _isLoginOpen = false;
                              });
                            });
                          },
                          child: const Text('Get Started'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return Container(
      width: isActive ? 32.w : 32.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: isActive ? Colors.black45 : Colors.black12,
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  final IconData icon;
  const _IconCard({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60.w,
      height: 60.h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: Colors.blueAccent),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.6), color.withOpacity(0.0)],
          stops: const [0.2, 1.0],
        ),
      ),
      // Adding a BackdropFilter or ImageFilter here is tricky as it affects *behind*
      // Instead, we rely on the gradient and the stack below.
    );
  }
}
