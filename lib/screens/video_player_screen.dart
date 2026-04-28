import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/screens/quiz_modal.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String chapterId;
  final String chapterName;
  final String? videoUrl;
  final String? summary;
  final int sequenceNumber;
  final String moduleName;
  final String moduleId;
  final Map<String, dynamic>? nextChapter;

  const VideoPlayerScreen({
    this.nextChapter,
    super.key,
    required this.chapterId,
    required this.chapterName,
    this.videoUrl,
    this.summary,
    required this.sequenceNumber,
    required this.moduleName,
    required this.moduleId,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  YoutubePlayerController? _ytController;
  bool _hasVideo = false;
  bool _positionRestored = false;
  bool _noQuizCompleteSaved = false;

  // ── Quiz state ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _quizItems = [];
  final List<int> _triggerSeconds = [];
  final Set<int> _shownQuizIndices = {};
  bool _quizVisible = false;
  bool _triggersCalculated = false;
  String? _quizId;
  DateTime? _quizSessionStart;

  // ── Streams (position + player state) ──────────────────────────────────────
  StreamSubscription<YoutubeVideoState>? _videoStateSub;
  StreamSubscription<YoutubePlayerValue>? _playerValueSub;
  double _videoDuration = 0.0;

  @override
  void initState() {
    super.initState();
    _ensureProgressRow(); // create row immediately so it's never empty
    final raw = widget.videoUrl;
    if (raw != null && raw.isNotEmpty) {
      _hasVideo = true;
      _initPlayer(_extractVideoId(raw));
      _fetchQuizItems();
    }
  }

  Future<void> _ensureProgressRow() async {
    final userId = UserService().currentOwnerId;
    if (userId == null) {
      debugPrint('[Progress] ensureRow: userId is NULL — skipping');
      return;
    }
    try {
      final db = Supabase.instance.client;
      final existing = await db
          .from('video_watch_progress')
          .select('id')
          .eq('user_id', userId)
          .eq('module_id', widget.chapterId)
          .maybeSingle();
      if (existing == null) {
        await db.from('video_watch_progress').insert({
          'user_id': userId,
          'module_id': widget.chapterId,
          'watch_percentage': 0.0,
          'is_completed': false,
          'last_watched_second': 0,
          'last_watched_at': DateTime.now().toUtc().toIso8601String(),
        });
        debugPrint('[Progress] row created for chapter ${widget.chapterId}');
      } else {
        debugPrint('[Progress] row already exists: ${existing['id']}');
      }
    } catch (e) {
      debugPrint('[Progress] ensureRow error: $e');
    }
  }

  String _extractVideoId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v']!;
      if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
    }
    return raw;
  }

  void _initPlayer(String videoId) {
    _ytController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        origin: 'https://www.youtube-nocookie.com',
        playsInline: true,
        showControls: false,
        showFullscreenButton: false,
        enableCaption: false,
        strictRelatedVideos: true,
      ),
    );
    _ytController!.loadVideoById(videoId: videoId);
    _videoStateSub = _ytController!.videoStateStream.listen(_onVideoState);
    _playerValueSub = _ytController!.listen(_onPlayerValue);
  }

  void _onVideoState(YoutubeVideoState state) {
    if (!mounted) return;
    final pos = state.position.inSeconds.toDouble();
    if (!_triggersCalculated && _quizItems.isNotEmpty && _videoDuration > 0) {
      _calculateTriggers(_videoDuration.toInt());
    }
    _checkQuizTrigger(pos);
  }

  void _onPlayerValue(YoutubePlayerValue value) {
    if (!mounted) return;
    final dur = value.metaData.duration.inSeconds.toDouble();
    if (dur > 0) {
      _videoDuration = dur;
      if (!_positionRestored) {
        _positionRestored = true;
        _restorePosition();
      }
      if (!_triggersCalculated && _quizItems.isNotEmpty) {
        _calculateTriggers(_videoDuration.toInt());
      }
    }
    // For chapters with no quizzes, mark complete when video ends
    if (value.playerState == PlayerState.ended &&
        _quizItems.isEmpty &&
        !_noQuizCompleteSaved) {
      _noQuizCompleteSaved = true;
      _writeProgress(answered: 1, total: 1);
    }
  }

  // ── Quiz ────────────────────────────────────────────────────────────────────

  Future<void> _fetchQuizItems() async {
    try {
      final supabase = Supabase.instance.client;
      final quizRes = await supabase
          .from('quizzes')
          .select('id')
          .eq('module_chapter_id', widget.chapterId)
          .maybeSingle();

      if (quizRes == null) return;
      _quizId = quizRes['id'] as String;

      final itemsRes = await supabase
          .from('quiz_items')
          .select('id, question, option_a, option_b, option_c, option_d, correct_option, explanation')
          .eq('quiz_id', _quizId!)
          .order('id');

      if (mounted) {
        setState(() => _quizItems = List<Map<String, dynamic>>.from(itemsRes as List));
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Quiz fetch error: $e');
    }
  }

  void _calculateTriggers(int durationSeconds) {
    if (_quizItems.isEmpty || durationSeconds == 0) return;
    final interval = durationSeconds ~/ _quizItems.length;
    _triggerSeconds
      ..clear()
      ..addAll(List.generate(_quizItems.length, (i) => interval * (i + 1)));
    _triggersCalculated = true;
    debugPrint('[Quiz] triggers at: $_triggerSeconds');
  }

  void _checkQuizTrigger(double positionSec) {
    if (_quizVisible || _triggerSeconds.isEmpty) return;
    for (int i = 0; i < _triggerSeconds.length; i++) {
      if (!_shownQuizIndices.contains(i) && positionSec >= _triggerSeconds[i]) {
        _shownQuizIndices.add(i);
        _showQuizModal(i);
        break;
      }
    }
  }

  Future<void> _showQuizModal(int index) async {
    _ytController?.pauseVideo();
    _quizVisible = true;
    _quizSessionStart ??= DateTime.now();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuizModal(
        quizItem: _quizItems[index],
        questionNumber: index + 1,
        totalQuestions: _quizItems.length,
        onCorrect: () => Navigator.pop(context),
      ),
    );

    _quizVisible = false;
    final answered = _shownQuizIndices.length;
    final total = _quizItems.length;

    // Write progress immediately after every correct quiz answer
    await _writeProgress(answered: answered, total: total);

    if (answered == total) {
      await _recordQuizAttempt();
      if (mounted) _showChapterComplete();
      return;
    }
    _ytController?.playVideo();
  }

  // ── Progress DB write (SELECT → INSERT or UPDATE) ───────────────────────────

  Future<void> _writeProgress({required int answered, required int total}) async {
    final userId = UserService().currentOwnerId;
    if (userId == null || total == 0) return;

    final pct = (answered / total * 100.0).clamp(0.0, 100.0);
    final isCompleted = answered >= total;
    final now = DateTime.now().toUtc().toIso8601String();
    final db = Supabase.instance.client;

    try {
      final existing = await db
          .from('video_watch_progress')
          .select('id')
          .eq('user_id', userId)
          .eq('module_id', widget.chapterId)
          .maybeSingle();

      if (existing == null) {
        await db.from('video_watch_progress').insert({
          'user_id': userId,
          'module_id': widget.chapterId,
          'watch_percentage': pct,
          'is_completed': isCompleted,
          'last_watched_second': 0,
          'last_watched_at': now,
        });
        debugPrint('[Progress] INSERT $answered/$total → ${pct.toInt()}%');
      } else {
        await db.from('video_watch_progress').update({
          'watch_percentage': pct,
          'is_completed': isCompleted,
          'last_watched_at': now,
        }).eq('user_id', userId).eq('module_id', widget.chapterId);
        debugPrint('[Progress] UPDATE $answered/$total → ${pct.toInt()}%');
      }
    } catch (e) {
      debugPrint('[Progress] Error: $e');
    }
  }

  Future<void> _restorePosition() async {
    try {
      final userId = UserService().currentOwnerId;
      if (userId == null) return;
      final res = await Supabase.instance.client
          .from('video_watch_progress')
          .select('last_watched_second, is_completed')
          .eq('user_id', userId)
          .eq('module_id', widget.chapterId)
          .maybeSingle();

      if (res != null) {
        final lastSec = (res['last_watched_second'] as int?) ?? 0;
        final isCompleted = res['is_completed'] == true;
        if (!isCompleted && lastSec > 10) {
          _ytController?.seekTo(seconds: lastSec.toDouble(), allowSeekAhead: true);
        }
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Restore error: $e');
    }
  }

  Future<void> _recordQuizAttempt() async {
    final quizId = _quizId;
    final userId = UserService().currentOwnerId;
    if (quizId == null || userId == null) return;
    final timeTaken = _quizSessionStart != null
        ? DateTime.now().difference(_quizSessionStart!).inSeconds
        : 0;
    try {
      await Supabase.instance.client.from('quiz_attempts').insert({
        'quiz_id': quizId,
        'user_id': userId,
        'score': 100.0,
        'has_passed': true,
        'time_taken': timeTaken,
        'date_attempted': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Quiz] attempt record error: $e');
    }
  }

  void _showChapterComplete() {
    final next = widget.nextChapter;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 28.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFF3E0),
                ),
                child: Icon(Icons.stars_rounded,
                    color: const Color(0xFFFF8A00), size: 38.sp),
              ),
              SizedBox(height: 20.h),
              Text(
                'Chapter Complete! 🎉',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'You\'ve finished all quizzes.\nYour progress has been saved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppTheme.smallTextSize.sp,
                    color: Colors.grey[600],
                    height: 1.5),
              ),
              SizedBox(height: 28.h),
              if (next != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.r)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            chapterId: next['id'] as String,
                            chapterName: next['name'] as String? ?? '',
                            videoUrl: next['video_url'] as String?,
                            summary: next['summary'] as String?,
                            sequenceNumber: (next['sequence_number'] as int?) ?? 0,
                            moduleName: widget.moduleName,
                            moduleId: widget.moduleId,
                            nextChapter: next['nextChapter'] as Map<String, dynamic>?,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Next Chapter',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppTheme.smallTextSize.sp)),
                        SizedBox(width: 6.w),
                        Icon(Icons.arrow_forward_rounded, size: 18.sp),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: next != null ? 10.h : 0),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r)),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Back to Course',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.smallTextSize.sp,
                        color: Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoStateSub?.cancel();
    _playerValueSub?.cancel();
    _ytController?.close();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_hasVideo || _ytController == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildNoVideoPlayer(),
            Expanded(child: _buildScrollableContent()),
          ],
        ),
      );
    }

    return YoutubePlayerScaffold(
      controller: _ytController!,
      aspectRatio: 16 / 9,
      builder: (context, player) => Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Stack(
              children: [
                player,
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    bottom: false,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(child: _buildScrollableContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVideoPlayer() {
    return SafeArea(
      bottom: false,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.video_library_outlined,
                        color: Colors.white38, size: 56.sp),
                    SizedBox(height: 12.h),
                    Text('No video available',
                        style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
                  ],
                ),
              ),
              Positioned(
                top: 8.h,
                left: 4.w,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterInfo(),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        _buildActionBar(),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        Expanded(child: _buildVideoSummary()),
      ],
    );
  }

  Widget _buildChapterInfo() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.chapterName,
              style: TextStyle(
                  fontSize: AppTheme.largeTextSize.sp,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 4.h),
          Text('Chapter ${widget.sequenceNumber}',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: AppTheme.extraSmallTextSize.sp)),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.h,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/images/Default_PFP.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(widget.moduleName,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTheme.smallTextSize.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          _actionButton(Icons.thumb_up_outlined, 'Like'),
          _actionButton(Icons.thumb_down_outlined, 'Dislike'),
          _actionButton(Icons.more_vert, 'More'),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return Padding(
      padding: EdgeInsets.only(left: 12.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22.sp, color: Colors.grey[700]),
          SizedBox(height: 2.h),
          Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildVideoSummary() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Video Summary',
              style: TextStyle(
                  fontSize: AppTheme.largeTextSize.sp,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 14.h),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.r),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.smallTextSize.sp)),
                    SizedBox(height: 10.h),
                    Text(
                      widget.summary ?? 'No summary available.',
                      style: TextStyle(
                          fontSize: AppTheme.extraSmallTextSize.sp,
                          color: Colors.grey[700],
                          height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
