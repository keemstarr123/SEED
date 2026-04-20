import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:seed/models/signup_data.dart';
import 'package:seed/widgets/signup_progress_bar.dart';
import 'package:seed/screens/signup/signup_ic_screen.dart';

class SignupDocumentsScreen extends StatefulWidget {
  final SignupData signupData;
  const SignupDocumentsScreen({super.key, required this.signupData});

  @override
  State<SignupDocumentsScreen> createState() => _SignupDocumentsScreenState();
}

class _SignupDocumentsScreenState extends State<SignupDocumentsScreen> {
  File? _ssmFile;
  String? _ssmFileName;

  bool get _canContinue => _ssmFile != null;

  Future<void> _pickSsmDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _ssmFile = File(result.files.single.path!);
        _ssmFileName = result.files.single.name;
        widget.signupData.ssmDocument = _ssmFile;
      });
    }
  }

  void _onContinue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignupIcScreen(signupData: widget.signupData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _ssmFile != null;
    final isPdf = _ssmFileName?.toLowerCase().endsWith('.pdf') ?? false;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.h),
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
                        SignupProgressBar(currentStep: 3),
                        SizedBox(height: 8.h),
                        Text(
                          'Step 3 of 4',
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          'Upload documents',
                          style: GoogleFonts.poppins(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Please provide your SSM certificate for verification',
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                        SizedBox(height: 28.h),

                        // SSM Certificate card
                        GestureDetector(
                          onTap: _pickSsmDocument,
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(20.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: hasFile
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFF30ACF6),
                                    width: 1.5,
                                  ),
                                ),
                                child: hasFile
                                    ? Column(
                                        children: [
                                          if (!isPdf)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
                                              child: Image.file(
                                                _ssmFile!,
                                                height: 120.h,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          else
                                            Container(
                                              height: 80.h,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEBEE),
                                                borderRadius:
                                                    BorderRadius.circular(10.r),
                                              ),
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .picture_as_pdf_outlined,
                                                      size: 32.sp,
                                                      color: const Color(
                                                          0xFFE53935),
                                                    ),
                                                    SizedBox(width: 10.w),
                                                    Flexible(
                                                      child: Text(
                                                        _ssmFileName ?? 'PDF',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 13.sp,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: const Color(
                                                              0xFFE53935),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          SizedBox(height: 10.h),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.check_circle,
                                                  color:
                                                      const Color(0xFF4CAF50),
                                                  size: 16.sp),
                                              SizedBox(width: 6.w),
                                              Text(
                                                'File selected',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12.sp,
                                                  color:
                                                      const Color(0xFF4CAF50),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            'Tap to change',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.sp,
                                              color: const Color(0xFF9E9E9E),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 56.w,
                                            height: 56.w,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE8F5FE),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.cloud_upload_outlined,
                                              size: 28.sp,
                                              color: const Color(0xFF30ACF6),
                                            ),
                                          ),
                                          SizedBox(height: 12.h),
                                          Text(
                                            'SSM Certificate',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            'Tap to upload your SSM document',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12.sp,
                                              color: const Color(0xFF9E9E9E),
                                            ),
                                          ),
                                          SizedBox(height: 12.h),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5FE),
                                              borderRadius:
                                                  BorderRadius.circular(20.r),
                                            ),
                                            child: Text(
                                              'PDF, PNG, OR JPG',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF30ACF6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              if (hasFile)
                                Positioned(
                                  top: 8.h,
                                  right: 8.w,
                                  child: Container(
                                    width: 24.w,
                                    height: 24.w,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4CAF50),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.check,
                                        color: Colors.white, size: 14.sp),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Data processing note
                        Container(
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 16.sp,
                                color: const Color(0xFF30ACF6),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'Your documents are encrypted and securely stored. They will only be used for business verification purposes.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    color: const Color(0xFF9E9E9E),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 100.h),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom actions
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
                child: ElevatedButton(
                  onPressed: _canContinue ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF30ACF6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    disabledForegroundColor: Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}
