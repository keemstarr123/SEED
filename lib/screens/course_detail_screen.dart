import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/main.dart';
import 'package:seed/screens/video_player_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final String moduleId;
  final String moduleName;
  final String? thumbnailUrl;
  final int streakDays;

  const CourseDetailScreen({
    super.key,
    required this.moduleId,
    required this.moduleName,
    this.thumbnailUrl,
    this.streakDays = 0,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _chapters = [];
  final Map<String, Map<String, dynamic>> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = UserService().currentOwnerId;

      final chaptersRes = await supabase
          .from('module_chapters')
          .select(
            'id, name, description, summary, video_url, duration_minutes, sequence_number',
          )
          .eq('module_id', widget.moduleId)
          .order('sequence_number');

      final chapters = List<Map<String, dynamic>>.from(chaptersRes as List);

      if (userId != null && chapters.isNotEmpty) {
        final chapterIds = chapters
            .map((c) => c['id'] as String?)
            .whereType<String>()
            .toList();
        final progressRes = await supabase
            .from('video_watch_progress')
            .select(
              'module_id, watch_percentage, is_completed, last_watched_at, last_watched_second',
            )
            .eq('user_id', userId)
            .inFilter('module_id', chapterIds);

        _progressMap.clear();
        for (final p in progressRes as List) {
          final mid = p['module_id'] as String?;
          if (mid != null) _progressMap[mid] = p as Map<String, dynamic>;
        }
      }

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CourseDetail] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String chapterId) {
    final p = _progressMap[chapterId];
    if (p == null) return Colors.grey;                        // locked — grey
    if (p['is_completed'] == true) return const Color(0xFF4CAF50); // done — green
    return const Color(0xFFFFC107);                           // in progress — yellow
  }

  Widget _statusIcon(String chapterId) {
    final p = _progressMap[chapterId];
    if (p == null) {
      return _iconBubble(
        Icons.lock,
        Colors.grey[200]!,
        Colors.grey[500]!,
      );
    }
    if (p['is_completed'] == true) {
      return _iconBubble(
        Icons.check_circle,
        const Color(0xFF4CAF50),
        Colors.white,
      );
    }
    return _iconBubble(
      Icons.priority_high,
      const Color(0xFFFFC107),
      Colors.white,
    );
  }

  Widget _iconBubble(IconData icon, Color bg, Color iconColor) {
    return Container(
      width: 32.w,
      height: 32.h,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 18.sp),
    );
  }

  String _buttonLabel(String chapterId) {
    final p = _progressMap[chapterId];
    if (p == null) return 'Start Watching';
    if (p['is_completed'] == true) return 'Watch Again';
    return 'Continue Watching';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          // ── Universal header (transparent bg) ───────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              child: AppHeader(
                subtitle: 'Course',
                title: UserService().currentOwnerName.split(' ').first,
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
                        '${widget.streakDays}',
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
            ),
          ),

          // ── Back button + module title ───────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(8.w, 10.h, 24.w, 4.h),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    widget.moduleName,
                    style: TextStyle(
                      fontSize: AppTheme.largeTextSize.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Chapter list ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chapters.isEmpty
                ? const Center(child: Text('No chapters available'))
                : ListView.builder(
                    padding: EdgeInsets.all(20.r),
                    itemCount: _chapters.length,
                    itemBuilder: (_, i) => _buildChapterCard(_chapters[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(Map<String, dynamic> chapter, int index) {
    final chapterId = chapter['id'] as String;
    final progress = _progressMap[chapterId];
    final pct = (progress?['watch_percentage'] as num?)?.toDouble() ?? 0;
    final duration = (chapter['duration_minutes'] as int?) ?? 0;
    final sequenceNumber = (chapter['sequence_number'] as int?) ?? (index + 1);

    final statusColor = _statusColor(chapterId);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Colored left accent strip ──
            Container(width: 5.w, color: statusColor),

            // ── Card content ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(18.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          // ── Chapter title + status icon ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter['name'] as String? ?? '',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.normalTextSize.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Chapter $sequenceNumber',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: AppTheme.extraSmallTextSize.sp,
                      ),
                    ),
                  ],
                ),
              ),
              _statusIcon(chapterId),
            ],
          ),
          SizedBox(height: 12.h),

          // ── Language + Duration ──
          Row(
            children: [
              Icon(Icons.language, color: Colors.grey[400], size: 14.sp),
              SizedBox(width: 4.w),
              Text(
                'English',
                style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
              ),
              SizedBox(width: 16.w),
              Icon(Icons.access_time, color: Colors.grey[400], size: 14.sp),
              SizedBox(width: 4.w),
              Text(
                '$duration minutes',
                style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // ── Progress ──
          Row(
            children: [
              Text(
                'Current Progress',
                style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
              ),
              const Spacer(),
              Text(
                '${pct.toInt()}%',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              backgroundColor: Colors.grey[200],
              color: statusColor,
              minHeight: 5,
            ),
          ),
          SizedBox(height: 14.h),

          // ── Watch button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.r),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                debugPrint('[CourseDetail] chapter keys: ${chapter.keys.toList()}');
                debugPrint('[CourseDetail] summary value: ${chapter['summary']}');
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      chapterId: chapterId,
                      chapterName: chapter['name'] as String? ?? '',
                      videoUrl: chapter['video_url'] as String?,
                      summary: chapter['summary'] as String?,
                      sequenceNumber: sequenceNumber,
                      moduleName: widget.moduleName,
                      moduleId: widget.moduleId,
                    ),
                  ),
                );
                // Refresh progress after returning from video
                await _fetchData();
              },
              child: Text(
                _buttonLabel(chapterId),
                style: TextStyle(
                  fontSize: AppTheme.smallTextSize.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),            // closes Text
            ),              // closes ElevatedButton
          ),                // closes SizedBox
                  ],        // closes Column children
                ),          // closes Column
              ),            // closes Padding
            ),              // closes Expanded
          ],                // closes Row children
        ),                  // closes Row
        ),                  // closes IntrinsicHeight
      ),                    // closes ClipRRect
    );                      // closes outer Container
  }
}
