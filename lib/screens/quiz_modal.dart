import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/theme/app_theme.dart';

class QuizModal extends StatefulWidget {
  final Map<String, dynamic> quizItem;
  final int questionNumber;
  final int totalQuestions;
  final VoidCallback onCorrect;

  const QuizModal({
    super.key,
    required this.quizItem,
    required this.questionNumber,
    required this.totalQuestions,
    required this.onCorrect,
  });

  @override
  State<QuizModal> createState() => _QuizModalState();
}

class _QuizModalState extends State<QuizModal>
    with SingleTickerProviderStateMixin {
  String? _selected;
  bool _showWrong = false;
  bool _showCorrect = false;
  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  static const _purple = Color(0xFF7E57C2);
  static const _purpleLight = Color(0xFFEDE7F6);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-0.04, 0), end: const Offset(0.04, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0.04, 0), end: Offset.zero),
          weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Widget _buildCongrats() {
    final explanation = widget.quizItem['explanation'] as String?;
    final isLast = widget.questionNumber == widget.totalQuestions;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy / check icon
            Container(
              width: 72.w,
              height: 72.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE8F5E9),
              ),
              child: Icon(Icons.emoji_events_rounded,
                  color: const Color(0xFF4CAF50), size: 38.sp),
            ),
            SizedBox(height: 20.h),

            Text(
              'Correct! 🎉',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isLast
                  ? 'Amazing! You\'ve completed all questions!'
                  : 'Well done! Keep up the great work.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.smallTextSize.sp,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),

            // Explanation if available
            if (explanation != null && explanation.isNotEmpty) ...[
              SizedBox(height: 20.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFCE93D8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Explanation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.extraSmallTextSize.sp,
                        color: _purple,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      explanation,
                      style: TextStyle(
                        fontSize: AppTheme.extraSmallTextSize.sp,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 28.h),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  elevation: 0,
                ),
                onPressed: widget.onCorrect,
                child: Text(
                  isLast ? 'Finish & Continue Video' : 'Next Question',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTheme.smallTextSize.sp,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_selected == null) return;
    final correct =
        (widget.quizItem['correct_option'] as String? ?? '').toUpperCase().trim();
    if (_selected == correct) {
      setState(() => _showCorrect = true);
    } else {
      _shakeController.forward(from: 0).then((_) {
        if (mounted) setState(() => _selected = null);
      });
      setState(() => _showWrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = <(String, String)>[
      ('A', widget.quizItem['option_a'] as String? ?? ''),
      ('B', widget.quizItem['option_b'] as String? ?? ''),
      ('C', widget.quizItem['option_c'] as String? ?? ''),
      ('D', widget.quizItem['option_d'] as String? ?? ''),
    ];

    if (_showCorrect) return _buildCongrats();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.arrow_back, color: _purple, size: 20.sp),
                Expanded(
                  child: Text(
                    'QUIZ ROUND',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.smallTextSize.sp,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Icon(Icons.bookmark_border, color: _purple, size: 20.sp),
              ],
            ),
            SizedBox(height: 18.h),

            // ── Question card ───────────────────────────────────────────────
            SlideTransition(
              position: _shakeAnimation,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7E57C2), Color(0xFFAB47BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Column(
                  children: [
                    Text(
                      '${widget.questionNumber} / ${widget.totalQuestions}',
                      style: TextStyle(color: Colors.white60, fontSize: 11.sp),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      widget.quizItem['question'] as String? ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.normalTextSize.sp,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // ── Options ─────────────────────────────────────────────────────
            ...options.map(((String, String) opt) {
              final letter = opt.$1;
              final text = opt.$2;
              if (text.isEmpty) return const SizedBox.shrink();
              final isSelected = _selected == letter;

              return GestureDetector(
                onTap: () => setState(() {
                  _selected = letter;
                  _showWrong = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 72.h,
                  margin: EdgeInsets.only(bottom: 10.h),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isSelected ? _purpleLight : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected ? _purple : const Color(0xFFE0E0E0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          color: isSelected ? _purple : const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: AppTheme.smallTextSize.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: 22.w,
                        height: 22.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? _purple : Colors.grey[400]!,
                            width: 2,
                          ),
                          color: isSelected ? _purple : Colors.transparent,
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: Colors.white, size: 13.sp)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ── Wrong answer banner ─────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _showWrong
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red.shade400, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Incorrect! Please try again.',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: AppTheme.extraSmallTextSize.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // ── Submit button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selected != null ? Colors.black : Colors.grey[300],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  elevation: 0,
                ),
                onPressed: _selected != null ? _submit : null,
                child: Text(
                  'SUBMIT ANSWER',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: AppTheme.smallTextSize,
                    color: _selected != null ? Colors.white : Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
