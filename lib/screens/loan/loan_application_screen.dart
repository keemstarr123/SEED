import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/models/loan_agent.dart';
import 'package:seed/models/loan_product.dart';
import 'package:seed/screens/loan/loan_product_step.dart';
import 'package:seed/screens/loan/loan_personal_step.dart';
import 'package:seed/screens/loan/loan_review_step.dart';
import 'package:seed/screens/loan/loan_submit_step.dart';
import 'package:seed/widgets/loan/step_progress_indicator.dart';

class LoanApplicationScreen extends StatefulWidget {
  final LoanAgent agent;
  final String userId;
  final String businessId;

  const LoanApplicationScreen({
    super.key,
    required this.agent,
    required this.userId,
    required this.businessId,
  });

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  int _step = 1; // 1-4
  LoanProduct? _selectedProduct;

  void _nextStep() => setState(() => _step++);
  void _prevStep() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: _prevStep,
          child: Container(
            margin: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4)
              ],
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 16.sp),
          ),
        ),
        title: Text(
          'Submitting Loan Request',
          style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Step progress (steps 1–3 show stepper; step 4 still shows it)
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
            child: StepProgressIndicator(currentStep: _step),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return LoanProductStep(
          key: const ValueKey(1),
          agent: widget.agent,
          selectedProduct: _selectedProduct,
          onProductSelected: (p) => setState(() => _selectedProduct = p),
          onNext: _nextStep,
        );
      case 2:
        return LoanPersonalStep(
          key: const ValueKey(2),
          userId: widget.userId,
          businessId: widget.businessId,
          onNext: _nextStep,
        );
      case 3:
        return LoanReviewStep(
          key: const ValueKey(3),
          onNext: _nextStep,
        );
      case 4:
        return LoanSubmitStep(
          key: const ValueKey(4),
          agent: widget.agent,
          userId: widget.userId,
          businessId: widget.businessId,
          selectedProduct: _selectedProduct,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
