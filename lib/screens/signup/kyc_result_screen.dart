import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seed/models/kyc_models.dart';
import 'package:seed/models/signup_data.dart';
import 'package:seed/services/kyc/signup_orchestrator.dart';
import 'package:seed/screens/signup/kyc_approved_screen.dart';
import 'package:seed/screens/signup/kyc_pending_screen.dart';
import 'package:seed/screens/signup/signup_personal_screen.dart';

class KYCResultScreen extends StatefulWidget {
  final KYCResult kycResult;
  final SignupData signupData;

  const KYCResultScreen({
    super.key,
    required this.kycResult,
    required this.signupData,
  });

  @override
  State<KYCResultScreen> createState() => _KYCResultScreenState();
}

class _KYCResultScreenState extends State<KYCResultScreen> {
  bool _isCreating = false;

  bool get _isApproved => widget.kycResult.finalScore >= 4;
  bool get _isRejected => widget.kycResult.finalScore <= 2;

  String get _reasoning => [
        widget.kycResult.ssmCheck.reasoning,
        widget.kycResult.icCheck.reasoning,
      ].where((s) => s.isNotEmpty).join(' ');

  Future<void> _createAccount() async {
    setState(() => _isCreating = true);
    try {
      await SignupOrchestrator().registerAndSave(
        formData: widget.signupData,
        ssmDocument: widget.signupData.ssmDocument!,
        kycResult: widget.kycResult,
      );

      if (!mounted) return;

      if (_isApproved) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                KYCApprovedScreen(email: widget.signupData.email),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const KYCPendingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.poppins(fontSize: 13.sp),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCreating,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    color: _isRejected
                        ? const Color(0xFFFFEBEE)
                        : _isApproved
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF8E1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isRejected
                        ? Icons.cancel_rounded
                        : _isApproved
                            ? Icons.verified_rounded
                            : Icons.hourglass_top_rounded,
                    size: 52.sp,
                    color: _isRejected
                        ? const Color(0xFFE53935)
                        : _isApproved
                            ? const Color(0xFF43A047)
                            : const Color(0xFFFFA000),
                  ),
                ),
                SizedBox(height: 28.h),

                // Title
                Text(
                  _isRejected
                      ? 'Verification Failed'
                      : _isApproved
                          ? 'Verification Passed'
                          : 'Manual Review Required',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 12.h),

                // Subtitle
                Text(
                  _isRejected
                      ? 'We were unable to verify your documents. Please review the reason below.'
                      : _isApproved
                          ? 'Your documents have been successfully verified. Tap below to create your account.'
                          : 'Your documents need a manual review by our team. Tap below to submit your application.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: const Color(0xFF9E9E9E),
                    height: 1.6,
                  ),
                ),

                // Reasoning box for rejected
                if (_isRejected && _reasoning.isNotEmpty) ...[
                  SizedBox(height: 20.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                          color: const Color(0xFFEF9A9A), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16.sp, color: const Color(0xFFE53935)),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            _reasoning,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: const Color(0xFFB71C1C),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 40.h),

                // Primary button
                if (_isRejected)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignupPersonalScreen()),
                        (route) => route.isFirst,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF30ACF6),
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 52.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50.r)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.poppins(
                          fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isCreating ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF30ACF6),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFBDBDBD),
                      minimumSize: Size(double.infinity, 52.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50.r)),
                      elevation: 0,
                    ),
                    icon: _isCreating
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(Icons.person_add_outlined, size: 20.sp),
                    label: Text(
                      _isCreating ? 'Creating account...' : 'Create My Account',
                      style: GoogleFonts.poppins(
                          fontSize: 15.sp, fontWeight: FontWeight.w600),
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
