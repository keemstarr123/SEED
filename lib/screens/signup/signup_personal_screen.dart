import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seed/models/signup_data.dart';
import 'package:seed/widgets/signup_progress_bar.dart';
import 'package:seed/screens/signup/signup_business_screen.dart';

class SignupPersonalScreen extends StatefulWidget {
  const SignupPersonalScreen({super.key});

  @override
  State<SignupPersonalScreen> createState() => _SignupPersonalScreenState();
}

class _SignupPersonalScreenState extends State<SignupPersonalScreen> {
  final _formKey = GlobalKey<FormState>();
  final SignupData _signupData = SignupData();

  final _fullNameController = TextEditingController();
  final _icNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _icNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13.sp,
        color: const Color(0xFFBDBDBD),
      ),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFF30ACF6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12.sp,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  bool _isValidIc(String ic) {
    // Format: ######-##-#### (12 digits with dashes)
    final regex = RegExp(r'^\d{6}-\d{2}-\d{4}$');
    return regex.hasMatch(ic);
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      _signupData.fullName = _fullNameController.text.trim();
      _signupData.icNumber = _icNumberController.text.trim();
      _signupData.phoneNumber = _phoneController.text.trim();
      _signupData.email = _emailController.text.trim();
      _signupData.password = _passwordController.text;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignupBusinessScreen(signupData: _signupData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          // Back arrow
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
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
                          // Progress bar
                          SignupProgressBar(currentStep: 1),
                          SizedBox(height: 8.h),
                          Text(
                            'Step 1 of 4',
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                          SizedBox(height: 24.h),
                          // Title
                          Text(
                            'Tell us about yourself',
                            style: GoogleFonts.poppins(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'This helps us verify your identity',
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                          SizedBox(height: 28.h),

                          // Full Name
                          _buildLabel('Full Name *'),
                          SizedBox(
                            height: 52.h,
                            child: TextFormField(
                              controller: _fullNameController,
                              style: GoogleFonts.poppins(fontSize: 13.sp),
                              decoration: _fieldDecoration('First Name'),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Full name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // IC Number
                          _buildLabel('IC Number *'),
                          SizedBox(
                            height: 52.h,
                            child: TextFormField(
                              controller: _icNumberController,
                              style: GoogleFonts.poppins(fontSize: 13.sp),
                              decoration:
                                  _fieldDecoration('e.g. 900101-14-5566'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d-]')),
                                LengthLimitingTextInputFormatter(14),
                                _IcNumberFormatter(),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'IC number is required';
                                }
                                if (!_isValidIc(v.trim())) {
                                  return 'Format: ######-##-#### (e.g. 900101-14-5566)';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Phone Number
                          _buildLabel('Phone Number *'),
                          SizedBox(
                            height: 52.h,
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12.w, vertical: 14.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F7FA),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Text(
                                    '+60',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    style: GoogleFonts.poppins(fontSize: 13.sp),
                                    decoration: _fieldDecoration('1X-XXXXXXXX'),
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Phone number is required';
                                      }
                                      if (v.trim().length < 9) {
                                        return 'Enter a valid phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Email
                          _buildLabel('Email *'),
                          SizedBox(
                            height: 52.h,
                            child: TextFormField(
                              controller: _emailController,
                              style: GoogleFonts.poppins(fontSize: 13.sp),
                              decoration:
                                  _fieldDecoration('name@business.com'),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!_isValidEmail(v.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Password
                          _buildLabel('Password *'),
                          SizedBox(
                            height: 52.h,
                            child: TextFormField(
                              controller: _passwordController,
                              style: GoogleFonts.poppins(fontSize: 13.sp),
                              decoration: _fieldDecoration(
                                      'Create a password')
                                  .copyWith(
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20.sp,
                                    color: const Color(0xFF9E9E9E),
                                  ),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Confirm Password
                          _buildLabel('Confirm Password *'),
                          SizedBox(
                            height: 52.h,
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              style: GoogleFonts.poppins(fontSize: 13.sp),
                              decoration:
                                  _fieldDecoration('Confirm your password')
                                      .copyWith(
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(() =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword),
                                  child: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20.sp,
                                    color: const Color(0xFF9E9E9E),
                                  ),
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (v != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 100.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom button + nav
              Container(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
                      child: ElevatedButton(
                        onPressed: _onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF30ACF6),
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 52.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Next',
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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

// ── IC Number formatter: auto-inserts dashes ────────────────────────────────
class _IcNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('-', '');
    if (digits.length > 12) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 6 || i == 8) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

