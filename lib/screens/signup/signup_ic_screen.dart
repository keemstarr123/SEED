import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seed/models/signup_data.dart';
import 'package:seed/widgets/signup_progress_bar.dart';
import 'package:seed/services/kyc/signup_orchestrator.dart';
import 'package:seed/screens/signup/kyc_result_screen.dart';

class SignupIcScreen extends StatefulWidget {
  final SignupData signupData;
  const SignupIcScreen({super.key, required this.signupData});

  @override
  State<SignupIcScreen> createState() => _SignupIcScreenState();
}

class _SignupIcScreenState extends State<SignupIcScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _captureFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        widget.signupData.icPhoto = File(picked.path);
      });
      await _submitSignup();
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        widget.signupData.icPhoto = File(picked.path);
      });
      await _submitSignup();
    }
  }

  Future<void> _submitSignup() async {
    final signupData = widget.signupData;
    if (signupData.ssmDocument == null || signupData.icPhoto == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final kycResult = await SignupOrchestrator().checkDocuments(
        formData: signupData,
        icPhoto: signupData.icPhoto!,
        ssmDocument: signupData.ssmDocument!,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => KYCResultScreen(
            kycResult: kycResult,
            signupData: signupData,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.poppins(fontSize: 13.sp),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final icPhoto = widget.signupData.icPhoto;

    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.h),
                        // Back arrow
                        GestureDetector(
                          onTap:
                              _isLoading ? null : () => Navigator.pop(context),
                          child: Container(
                            width: 40.w,
                            height: 40.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              size: 18.sp,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        SignupProgressBar(currentStep: 4),
                        SizedBox(height: 8.h),
                        Text(
                          'Step 4 of 4',
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          'Scan your IC',
                          style: GoogleFonts.poppins(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Position your identity card within the frame for a clear scan',
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                        SizedBox(height: 28.h),

                        // Viewfinder area
                        Container(
                          width: double.infinity,
                          height: 220.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: const Color(0xFF30ACF6),
                              width: 2,
                            ),
                          ),
                          child: icPhoto != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14.r),
                                  child: Image.file(
                                    icPhoto,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : Stack(
                                  children: [
                                    // Corner brackets
                                    Positioned(
                                      top: 12.h,
                                      left: 12.w,
                                      child: _CornerBracket(
                                          position: _BracketPosition.topLeft),
                                    ),
                                    Positioned(
                                      top: 12.h,
                                      right: 12.w,
                                      child: _CornerBracket(
                                          position: _BracketPosition.topRight),
                                    ),
                                    Positioned(
                                      bottom: 12.h,
                                      left: 12.w,
                                      child: _CornerBracket(
                                          position:
                                              _BracketPosition.bottomLeft),
                                    ),
                                    Positioned(
                                      bottom: 12.h,
                                      right: 12.w,
                                      child: _CornerBracket(
                                          position:
                                              _BracketPosition.bottomRight),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.credit_card_outlined,
                                            size: 40.sp,
                                            color: const Color(0xFF30ACF6)
                                                .withValues(alpha: 0.5),
                                          ),
                                          SizedBox(height: 10.h),
                                          Text(
                                            'Place your IC here',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13.sp,
                                              color: const Color(0xFF9E9E9E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(height: 16.h),

                        // Privacy disclaimer
                        Container(
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                                color: const Color(0xFFFFE082), width: 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.privacy_tip_outlined,
                                  size: 16.sp,
                                  color: const Color(0xFFFFA000)),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'Your privacy matters: Your IC photo will not be stored. It is deleted immediately after verification is complete.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    color: const Color(0xFF795548),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Tips row
                        Row(
                          children: [
                            Expanded(
                              child: _TipTile(
                                icon: Icons.light_mode_outlined,
                                label: 'Good Lighting',
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _TipTile(
                                icon: Icons.vibration_outlined,
                                label: 'Hold Steady',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 100.h),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom buttons
              Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    // Primary capture button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _captureFromCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30ACF6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFBDBDBD),
                        minimumSize: Size(double.infinity, 52.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50.r),
                        ),
                        elevation: 0,
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.camera_alt_outlined, size: 20.sp),
                      label: Text(
                        _isLoading ? 'Submitting...' : 'Capture',
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    // Secondary gallery link
                    TextButton(
                      onPressed: _isLoading ? null : _pickFromGallery,
                      child: Text(
                        'Upload manually from gallery',
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: const Color(0xFF30ACF6),
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFF30ACF6),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Corner bracket widget for the viewfinder ────────────────────────────────
enum _BracketPosition { topLeft, topRight, bottomLeft, bottomRight }

class _CornerBracket extends StatelessWidget {
  final _BracketPosition position;
  const _CornerBracket({required this.position});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(24.w, 24.h),
      painter: _BracketPainter(position: position),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final _BracketPosition position;
  _BracketPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF30ACF6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    switch (position) {
      case _BracketPosition.topLeft:
        canvas.drawLine(Offset(0, h), Offset(0, 0), paint);
        canvas.drawLine(Offset(0, 0), Offset(w, 0), paint);
        break;
      case _BracketPosition.topRight:
        canvas.drawLine(Offset(0, 0), Offset(w, 0), paint);
        canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
        break;
      case _BracketPosition.bottomLeft:
        canvas.drawLine(Offset(0, 0), Offset(0, h), paint);
        canvas.drawLine(Offset(0, h), Offset(w, h), paint);
        break;
      case _BracketPosition.bottomRight:
        canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
        canvas.drawLine(Offset(0, h), Offset(w, h), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Tip tile widget ──────────────────────────────────────────────────────────
class _TipTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TipTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18.sp, color: const Color(0xFF30ACF6)),
          SizedBox(width: 8.w),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
