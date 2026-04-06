import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/models/loan_agent.dart';
import 'package:seed/models/loan_product.dart';

class LoanProductStep extends StatefulWidget {
  final LoanAgent agent;
  final LoanProduct? selectedProduct;
  final ValueChanged<LoanProduct> onProductSelected;
  final VoidCallback onNext;

  const LoanProductStep({
    super.key,
    required this.agent,
    required this.selectedProduct,
    required this.onProductSelected,
    required this.onNext,
  });

  @override
  State<LoanProductStep> createState() => _LoanProductStepState();
}

class _LoanProductStepState extends State<LoanProductStep> {
  LoanProduct? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedProduct;
  }

  IconData _icon(String title) {
    final t = title.toLowerCase();
    if (t.contains('personal')) return Icons.person_outline;
    if (t.contains('business')) return Icons.business_center_outlined;
    if (t.contains('car')) return Icons.directions_car_outlined;
    if (t.contains('home') || t.contains('property')) return Icons.home_outlined;
    return Icons.attach_money_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.agent.products;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13.sp, color: Colors.black87),
              children: [
                const TextSpan(text: 'Loan Services Offered by - '),
                TextSpan(
                  text: widget.agent.agentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: GridView.builder(
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (_, i) {
                final product = products[i];
                final isSelected = _selected?.id == product.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selected = product);
                    widget.onProductSelected(product);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF38B6FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF38B6FF)
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            _icon(product.service.title),
                            size: 22.sp,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          product.service.title,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                        Divider(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.grey.shade200,
                          height: 12.h,
                        ),
                        Text(
                          'Eligibility',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _parseEligibility(product.eligibility)
                                  .map((line) => Padding(
                                        padding: EdgeInsets.only(bottom: 3.h),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.check,
                                                size: 10.sp,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF1D9E75)),
                                            SizedBox(width: 4.w),
                                            Expanded(
                                              child: Text(
                                                line,
                                                style: TextStyle(
                                                  fontSize: 9.sp,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            Icons.arrow_outward,
                            size: 14.sp,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _bottomButton(
          label: 'Next',
          enabled: _selected != null,
          onTap: _selected != null ? widget.onNext : null,
        ),
      ],
    );
  }

  List<String> _parseEligibility(String text) {
    return text
        .split(RegExp(r'[.。]\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Widget _bottomButton(
      {required String label, required bool enabled, VoidCallback? onTap}) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                enabled ? Colors.black : Colors.grey.shade300,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.r),
            ),
            elevation: 0,
          ),
          child: Text(label,
              style:
                  TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

