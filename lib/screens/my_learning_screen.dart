import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/screens/course_detail_screen.dart';
import 'package:seed/main.dart';

class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({super.key});

  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends State<MyLearningScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _ongoingCourses = [];
  int _streakDays = 0;

  // Stacked card state
  List<int> _cardOrder = [];
  double _dragX = 0;
  double _animStart = 0;
  double _animEnd = 0;
  late AnimationController _swipeController;
  AnimationController? _riseController;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Start fully risen (value 1.0) so the initial card looks normal.
    // After each swipe it is rewound to 0 and played forward.
    _riseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _fetchLearningData();
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _riseController?.dispose();
    super.dispose();
  }

  Future<void> _fetchLearningData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = UserService().currentOwnerId;

      final modulesRes = await supabase
          .from('micro_modules')
          .select(
            'id, name, description, thumbnail_url, is_mandatory, '
            'module_chapters(id, name, sequence_number)',
          );

      final allChapterIds = <String>[
        for (final m in modulesRes as List)
          for (final c in m['module_chapters'] as List)
            if (c['id'] != null) c['id'] as String,
      ];

      final progressMap = <String, Map<String, dynamic>>{};
      int streak = 0;

      if (userId != null && allChapterIds.isNotEmpty) {
        final progressRes = await supabase
            .from('video_watch_progress')
            .select('module_id, watch_percentage, is_completed, last_watched_at')
            .eq('user_id', userId)
            .inFilter('module_id', allChapterIds);

        for (final p in progressRes as List) {
          final mid = p['module_id'] as String?;
          if (mid != null) progressMap[mid] = p as Map<String, dynamic>;
        }

        // ── Streak calculation ──────────────────────────────────────────────
        final watchDates = (progressRes as List)
            .where((p) => p['last_watched_at'] != null)
            .map((p) {
              final dt = DateTime.parse(p['last_watched_at'] as String).toLocal();
              return DateTime(dt.year, dt.month, dt.day);
            })
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

        if (watchDates.isNotEmpty) {
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final yesterday = todayDate.subtract(const Duration(days: 1));

          // Streak is only active if user watched today or yesterday
          if (watchDates.first == todayDate || watchDates.first == yesterday) {
            DateTime expected = watchDates.first;
            for (final date in watchDates) {
              if (date == expected) {
                streak++;
                expected = expected.subtract(const Duration(days: 1));
              } else {
                break;
              }
            }
          }
        }
      }

      var courses = <Map<String, dynamic>>[];
      var ongoing = <Map<String, dynamic>>[];

      for (final m in modulesRes) {
        final rawChapters = List<Map<String, dynamic>>.from(
          (m['module_chapters'] as List).map((c) => c as Map<String, dynamic>),
        );
        rawChapters.sort(
          (a, b) => ((a['sequence_number'] as int?) ?? 0)
              .compareTo((b['sequence_number'] as int?) ?? 0),
        );

        double totalPct = 0;
        for (final c in rawChapters) {
          totalPct += (progressMap[c['id']]?['watch_percentage'] as num? ?? 0)
              .toDouble();
        }
        final avgProgress = rawChapters.isEmpty
            ? 0.0
            : (totalPct / rawChapters.length) / 100.0;

        courses.add({
          'moduleId': (m['id'] as String?) ?? '',
          'title': (m['name'] as String?) ?? '',
          'subtitle': (m['description'] as String?) ?? '',
          'progress': avgProgress,
          'progressText': '${(avgProgress * 100).toInt()}% Completed',
          'thumbnailUrl': m['thumbnail_url'] as String?,
        });

        // Ongoing: any chapter has been watched (has progress entry)
        final watchedChapters = rawChapters
            .where((c) => progressMap.containsKey(c['id'] as String?))
            .toList();

        if (watchedChapters.isNotEmpty) {
          // Find the most recently watched chapter
          watchedChapters.sort((a, b) {
            final aDate = progressMap[a['id']]?['last_watched_at'] as String?;
            final bDate = progressMap[b['id']]?['last_watched_at'] as String?;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });
          final lastChapter = watchedChapters.first;
          ongoing.add({
            'moduleId': (m['id'] as String?) ?? '',
            'moduleName': (m['name'] as String?) ?? '',
            'thumbnailUrl': m['thumbnail_url'] as String?,
            'chapterName': (lastChapter['name'] as String?) ?? '',
            'lastVisit': progressMap[lastChapter['id']]?['last_watched_at'] as String?,
            'progress': avgProgress,
          });
        }
      }

      // Sort ongoing by last watched descending
      ongoing.sort((a, b) {
        final aDate = a['lastVisit'] as String?;
        final bDate = b['lastVisit'] as String?;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _courses = courses;
          _ongoingCourses = ongoing;
          _streakDays = streak;
          _cardOrder = List.generate(ongoing.length, (i) => i);
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[Learning] Error: $e');
      debugPrint('[Learning] Stack: $st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Stacked card helpers ───────────────────────────────────────────────────
  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _onSwipeUpdate(DragUpdateDetails details) {
    if (!_swipeController.isAnimating) {
      setState(() => _dragX += details.delta.dx);
    }
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (_swipeController.isAnimating) return;
    final velocity = details.primaryVelocity ?? 0;
    final bool shouldSwipe = _dragX.abs() > 70 || velocity.abs() > 300;
    if (shouldSwipe) {
      final bool toLeft = _dragX < 0 || (velocity < 0 && _dragX == 0);
      _animStart = _dragX;
      _animEnd = toLeft ? -500.0 : 500.0;
      _swipeController.duration = const Duration(milliseconds: 300);
      _swipeController.reset();
      _swipeController.forward().then((_) {
        setState(() {
          final front = _cardOrder.removeAt(0);
          _cardOrder.add(front);
          _dragX = 0;
        });
        _riseController?.forward(from: 0);
      });
    } else {
      _animStart = _dragX;
      _animEnd = 0;
      _swipeController.duration = const Duration(milliseconds: 350);
      _swipeController.reset();
      _swipeController.forward().then((_) {
        setState(() => _dragX = 0);
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final firstName = UserService().currentOwnerName.split(' ').first;

    return AppLayout(
      currentIndex: 2,
      onNavPressed: (i) {
        if (i != 2) Navigator.pop(context);
      },
      onFabPressed: () {},
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 20.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    AppHeader(
                      subtitle: "Let's Learn,",
                      title: firstName,
                      trailing: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: const Color(0xFFFFCC80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_streakDays',
                              style: TextStyle(
                                fontSize: AppTheme.normalTextSize.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFE65100),
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text('🔥', style: TextStyle(fontSize: 16.sp)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // ── Ongoing Courses ───────────────────────────────────
                    if (_ongoingCourses.isNotEmpty) ...[
                      Text(
                        'Continue Learning',
                        style: TextStyle(
                          fontSize: AppTheme.normalTextSize.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildStackedMaterials(),
                      SizedBox(height: 24.h),
                    ],

                    // ── Courses ───────────────────────────────────────────────
                    Text(
                      'Courses',
                      style: TextStyle(
                        fontSize: AppTheme.normalTextSize.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    if (_courses.isEmpty)
                      _buildEmptyState(
                        Icons.menu_book_outlined,
                        'No courses available yet',
                      )
                    else
                      SizedBox(
                        height: 349.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: EdgeInsets.zero,
                          itemCount: _courses.length,
                          itemBuilder: (_, i) => _buildCourseCard(_courses[i]),
                        ),
                      ),
                    SizedBox(height: 24.h),

                    // ── Your Statistics ───────────────────────────────────────
                    Text(
                      'Your Statistics',
                      style: TextStyle(
                        fontSize: AppTheme.normalTextSize.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildStatisticsRow(),
                    SizedBox(height: 120.h),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Stacked materials ──────────────────────────────────────────────────────
  Widget _buildStackedMaterials() {
    if (_cardOrder.isEmpty) return const SizedBox.shrink();

    final double cardHeight = 95.h;
    final double stackPeek = 14.h;
    final int visible = _cardOrder.length.clamp(1, 3);
    final double totalHeight = cardHeight + (visible - 1) * stackPeek;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          for (int depth = visible - 1; depth >= 0; depth--)
            _buildMaterialAtDepth(depth, cardHeight, stackPeek),
        ],
      ),
    );
  }

  Widget _buildMaterialAtDepth(int depth, double cardHeight, double stackPeek) {
    final bool isActive = depth == 0;
    final material = _ongoingCourses[_cardOrder[depth]];
    final double topOffset = depth * stackPeek;
    final double hPad = depth * 10.0.w;
    final double dimOpacity = (depth * 0.22).clamp(0.0, 0.55);

    if (isActive) {
      return Positioned(
        top: topOffset,
        left: 0,
        right: 0,
        child: GestureDetector(
          onHorizontalDragUpdate: _onSwipeUpdate,
          onHorizontalDragEnd: _onSwipeEnd,
          child: AnimatedBuilder(
            animation: Listenable.merge([_swipeController, ?_riseController]),
            builder: (context, child) {
              // ── swipe translation ──
              final dx = _swipeController.isAnimating
                  ? _lerp(
                      _animStart,
                      _animEnd,
                      Curves.easeOut.transform(_swipeController.value),
                    )
                  : _dragX;

              // ── rise-to-front animation ──
              final riseT = Curves.easeOutBack.transform(
                _riseController?.value ?? 1.0,
              );
              final riseHPad = _lerp(10.0.w, 0.0, riseT);
              final riseVOffset = _lerp(stackPeek, 0.0, riseT);
              final riseDim = _lerp(0.22, 0.0, riseT);

              return Transform.translate(
                offset: Offset(dx, riseVOffset),
                child: Transform.rotate(
                  angle: dx / 1000.0,
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: riseHPad),
                    child: SizedBox(
                      height: cardHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          child!,
                          if (riseDim > 0.01)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: riseDim),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            child: _buildMaterialCardFlat(material),
          ),
        ),
      );
    }

    // Inactive card — static dark overlay
    return Positioned(
      top: topOffset,
      left: hPad,
      right: hPad,
      child: SizedBox(
        height: cardHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMaterialCardFlat(material),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: dimOpacity),
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCardFlat(Map<String, dynamic> material) {
    final progress = (material['progress'] as double? ?? 0.0);
    final pct = (progress * 100).toInt();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(
            moduleId: material['moduleId'] as String,
            moduleName: material['moduleName'] as String,
            thumbnailUrl: material['thumbnailUrl'] as String?,
            streakDays: _streakDays,
          ),
        ),
      ).then((_) => _fetchLearningData()),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.play_circle_rounded,
                color: const Color(0xFF7E57C2),
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (material['moduleName'] as String?) ?? '',
                    style: TextStyle(
                      fontSize: AppTheme.extraSmallTextSize.sp,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    (material['chapterName'] as String?) ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.smallTextSize.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[200],
                            color: const Color(0xFF7E57C2),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: AppTheme.extraSmallTextSize.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7E57C2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(Icons.arrow_forward_ios_rounded, size: 14.sp, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ── Course card ────────────────────────────────────────────────────────────
  Widget _buildCourseCard(Map<String, dynamic> course) {
    final thumbnailUrl = course['thumbnailUrl'] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(
            moduleId: course['moduleId'] as String,
            moduleName: course['title'] as String,
            thumbnailUrl: thumbnailUrl,
            streakDays: _streakDays,
          ),
        ),
      ),
      child: Container(
      width: 218.w,
      height: 230.h,
      margin: EdgeInsets.only(right: 16.w),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Lower layer: thumbnail background ──
          ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: thumbnailUrl != null
                ? Image.network(thumbnailUrl, fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.grey,
                        size: 40.sp,
                      ),
                    ),
                  ),
          ),

          // ── Dim overlay on thumbnail ──
          if (thumbnailUrl != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),

          // ── Upper layer: floating info panel ──
          Positioned(
            bottom: 12.h,
            left: 12.w,
            right: 12.w,
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    course['title'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.smallTextSize.sp,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    course['subtitle'] as String,
                    style: TextStyle(
                      fontSize: AppTheme.extraSmallTextSize.sp,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: course['progress'] as double,
                      backgroundColor: Colors.grey[800],
                      color: const Color(0xFF7E57C2),
                      minHeight: 3,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    course['progressText'] as String,
                    style: TextStyle(
                      fontSize: AppTheme.extraSmallTextSize.sp,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),  // closes Container
    );  // closes GestureDetector
  }

  // ── Statistics row ─────────────────────────────────────────────────────────
  Widget _buildStatisticsRow() {
    return SizedBox(
      height: 90.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        children: [
          // ── Congratulations card ──
          Container(
            width: 260.w,
            margin: EdgeInsets.only(right: 16.w),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4DD0E1), Color(0xFF0097A7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    width: 300.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Congratulations!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.normalTextSize.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'You best 60.7% of users with 360 minutes of learning this week!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppTheme.extraSmallTextSize.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.track_changes_rounded,
                    color: Colors.white,
                    size: 26.sp,
                  ),
                ),
              ],
            ),
          ),

          // ── Streak card ──
          Container(
            width: 260.w,
            margin: EdgeInsets.only(right: 16.w),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_streakDays-day streak',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.normalTextSize.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Keep it up! You\'re on a roll.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppTheme.extraSmallTextSize.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 26.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state helper ─────────────────────────────────────────────────────
  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 32.h),
      child: Column(
        children: [
          Icon(icon, size: 48.sp, color: Colors.grey[300]),
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}
