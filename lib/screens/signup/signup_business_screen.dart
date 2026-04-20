import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seed/models/signup_data.dart';
import 'package:seed/widgets/signup_progress_bar.dart';
import 'package:seed/screens/signup/signup_documents_screen.dart';

class SignupBusinessScreen extends StatefulWidget {
  final SignupData signupData;
  const SignupBusinessScreen({super.key, required this.signupData});

  @override
  State<SignupBusinessScreen> createState() => _SignupBusinessScreenState();
}

class _SignupBusinessScreenState extends State<SignupBusinessScreen> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameController = TextEditingController();
  final _ssmController = TextEditingController();
  final _addressController = TextEditingController();
  final _yearController = TextEditingController();

  String? _selectedBusinessType;

  final List<String> _businessTypes = [
    'Sole Proprietorship',
    'Partnership',
    'Sdn Bhd',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _ssmController.dispose();
    _addressController.dispose();
    _yearController.dispose();
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

  void _onContinue() {
    if (_formKey.currentState!.validate()) {
      widget.signupData.businessName = _businessNameController.text.trim();
      widget.signupData.ssmNumber = _ssmController.text.trim();
      widget.signupData.businessType = _selectedBusinessType ?? '';
      widget.signupData.businessAddress = _addressController.text.trim();
      widget.signupData.yearEstablished = _yearController.text.trim();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SignupDocumentsScreen(signupData: widget.signupData),
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
                          SignupProgressBar(currentStep: 2),
                          SizedBox(height: 8.h),
                          Text(
                            'Step 2 of 4',
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'Your business details',
                            style: GoogleFonts.poppins(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            "We'll use this to match you with the right resources",
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                          SizedBox(height: 28.h),

                          // Business Name
                          _buildLabel('Business Name *'),
                          SizedBox(
                            height: 52.h,
                            child: TextFormField(
                              controller: _businessNameController,
                              style: GoogleFonts.poppins(fontSize: 13.sp),
                              decoration: _fieldDecoration('Business Name'),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Business name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // SSM Registration Number
                          _buildLabel('SSM Registration Number *'),
                          SizedBox(
                            height: 52.h,
                            child: TextFormField(
                              controller: _ssmController,
                              style: GoogleFonts.poppins(fontSize: 13.sp),
                              decoration:
                                  _fieldDecoration('202301xxxxxx'),
                              keyboardType: TextInputType.text,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'SSM registration number is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Business Type
                          _buildLabel('Business Type *'),
                          DropdownButtonFormField<String>(
                            value: _selectedBusinessType,
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              color: const Color(0xFF1A1A1A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Select business type',
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
                                borderSide: const BorderSide(
                                    color: Color(0xFF30ACF6), width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide:
                                    const BorderSide(color: Colors.red, width: 1),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide:
                                    const BorderSide(color: Colors.red, width: 1.5),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 14.h),
                            ),
                            items: _businessTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type,
                                  style: GoogleFonts.poppins(fontSize: 13.sp),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedBusinessType = val),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please select a business type';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),

                          // Business Address
                          _buildLabel('Business Address *'),
                          TextFormField(
                            controller: _addressController,
                            style: GoogleFonts.poppins(fontSize: 13.sp),
                            decoration: _fieldDecoration(
                                'Street name, District, State'),
                            maxLines: 2,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Business address is required';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),

                          // Year of Establishment
                          _buildLabel('Year of Establishment *'),
                          SizedBox(
                            height: 52.h,
                            child: TextFormField(
                              controller: _yearController,
                              style: GoogleFonts.poppins(fontSize: 13.sp),
                              decoration: _fieldDecoration('YYYY'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Year of establishment is required';
                                }
                                final year = int.tryParse(v.trim());
                                if (year == null ||
                                    year < 1900 ||
                                    year > DateTime.now().year) {
                                  return 'Enter a valid year (e.g. 2015)';
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

              // Bottom button + footer
              Container(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
                      child: ElevatedButton(
                        onPressed: _onContinue,
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
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.h),
                      child: Text(
                        'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: const Color(0xFF9E9E9E),
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
