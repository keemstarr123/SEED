import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/screens/quiz_modal.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String chapterId;
  final String chapterName;
  final String? videoUrl; // stores the YouTube video ID
  final String? summary;
  final int sequenceNumber;
  final String moduleName;
  final String moduleId;

  const VideoPlayerScreen({
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
  YoutubePlayerController? _controller;
  Timer? _progressTimer;
  bool _hasVideo = false;
  int? _lastSavedPosition;

  // ── Quiz state ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _quizItems = [];
  List<int> _triggerSeconds = [];
  final Set<int> _shownQuizIndices = {};
  bool _quizVisible = false;
  bool _triggersCalculated = false;
  String? _quizId;
  DateTime? _quizSessionStart;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final videoId = widget.videoUrl;
    if (videoId == null || videoId.isEmpty) return;

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        captionLanguage: 'en',
        forceHD: false,
        disableDragSeek: true,
      ),
    )..addListener(_onPlayerChanged);

    setState(() => _hasVideo = true);
    _restorePosition();
    _fetchQuizItems();
    _startProgressTimer();
  }

  // ── Quiz fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetchQuizItems() async {
    try {
      final supabase = Supabase.instance.client;

      // Find the quiz linked to this chapter
      final quizRes = await supabase
          .from('quizzes')
          .select('id')
          .eq('module_chapter_id', widget.chapterId)
          .maybeSingle();

      if (quizRes == null) return;
      _quizId = quizRes['id'] as String;

      // Fetch all quiz items
      final itemsRes = await supabase
          .from('quiz_items')
          .select(
            'id, question, option_a, option_b, option_c, option_d, correct_option, explanation',
          )
          .eq('quiz_id', _quizId!)
          .order('id'); // stable insertion order

      if (mounted) {
        setState(
          () => _quizItems = List<Map<String, dynamic>>.from(itemsRes as List),
        );
        debugPrint(
          '[Quiz] loaded ${_quizItems.length} items for quiz $_quizId',
        );
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Quiz fetch error: $e');
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
        'score': 100.0, // forced correct answers
        'has_passed': true,
        'time_taken': timeTaken,
        'date_attempted': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('[Quiz] attempt recorded');
    } catch (e) {
      debugPrint('[Quiz] attempt record error: $e');
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

  void _checkQuizTrigger() {
    if (_quizVisible || _triggerSeconds.isEmpty || _quizItems.isEmpty) return;
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.playerState != PlayerState.playing) return;

    final positionSec = controller.value.position.inSeconds;
    for (int i = 0; i < _triggerSeconds.length; i++) {
      if (!_shownQuizIndices.contains(i) && positionSec >= _triggerSeconds[i]) {
        _shownQuizIndices.add(i);
        _showQuizModal(i);
        break;
      }
    }
  }

  Future<void> _showQuizModal(int index) async {
    _controller?.pause();
    _quizVisible = true;
    // Start timing from the first quiz
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

    // Record attempt after the final question is answered
    if (_shownQuizIndices.length == _quizItems.length) {
      await _recordQuizAttempt();
    }

    _controller?.play();
  }

  // ── Position restore ───────────────────────────────────────────────────────

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
          _controller?.seekTo(Duration(seconds: lastSec));
        }
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Restore error: $e');
    }
  }

  // ── Progress tracking ──────────────────────────────────────────────────────

  void _onPlayerChanged() {
    if (!mounted) return;

    final controller = _controller;
    if (controller == null) return;

    // Calculate quiz triggers once duration is known
    if (!_triggersCalculated && _quizItems.isNotEmpty) {
      final dur = controller.metadata.duration.inSeconds;
      if (dur > 0) _calculateTriggers(dur);
    }

    // Check if a quiz should pop up
    _checkQuizTrigger();

    // Save progress when video ends
    if (controller.value.playerState == PlayerState.ended) {
      _saveProgress(forceComplete: true);
    }
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  Future<void> _saveProgress({bool forceComplete = false}) async {
    final controller = _controller;
    if (controller == null) return;

    final userId = UserService().currentOwnerId;
    if (userId == null) return;

    final position = controller.value.position;
    final duration = controller.metadata.duration;
    if (duration.inSeconds == 0) return;

    // Skip upsert if nothing has changed (e.g. video is paused)
    if (!forceComplete && position.inSeconds == _lastSavedPosition) return;
    _lastSavedPosition = position.inSeconds;

    final pct = (position.inSeconds / duration.inSeconds * 100.0).clamp(
      0.0,
      100.0,
    );
    final isCompleted = forceComplete || pct >= 90.0;

    try {
      await Supabase.instance.client.from('video_watch_progress').upsert({
        'user_id': userId,
        'module_id': widget.chapterId,
        'last_watched_second': position.inSeconds,
        'watch_percentage': isCompleted ? 100.0 : pct,
        'is_completed': isCompleted,
        'last_watched_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,module_id');
    } catch (e) {
      debugPrint('[VideoPlayer] Save error: $e');
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller?.removeListener(_onPlayerChanged);
    _saveProgress(); // final save on exit
    _controller?.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_hasVideo || _controller == null) {
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

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        // Rebuild after returning from fullscreen
        setState(() {});
      },
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.transparent,
        ),
        topActions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(child: SizedBox()),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
        ],
        aspectRatio: 16 / 9,
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              player,
              Expanded(child: _buildScrollableContent()),
            ],
          ),
        );
      },
    );
  }

  // ── Fallback when no video ID ──────────────────────────────────────────────

  Widget _buildNoVideoPlayer() {
    return SafeArea(
      bottom: false,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      color: Colors.white38,
                      size: 56,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No video available',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                left: 4,
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

  // ── Scrollable content below video ─────────────────────────────────────────

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

  // ── Chapter info ───────────────────────────────────────────────────────────

  Widget _buildChapterInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.chapterName,
            style: const TextStyle(
              fontSize: AppTheme.largeTextSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chapter ${widget.sequenceNumber}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: AppTheme.extraSmallTextSize,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action bar ─────────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/images/Default_PFP.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.moduleName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: AppTheme.smallTextSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Colors.grey[700]),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ── Video summary ──────────────────────────────────────────────────────────

  Widget _buildVideoSummary() {
    final desc = widget.summary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Video Summary',
            style: TextStyle(
              fontSize: AppTheme.largeTextSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.smallTextSize,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        desc ?? 'No summary available.',
                        style: TextStyle(
                          fontSize: AppTheme.extraSmallTextSize,
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
