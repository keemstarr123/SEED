import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> _mandatoryMaterials = [];
  final int _streakDays = 5;

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

      // 1. Fetch all modules with their chapters (id + name + sequence for ordering)
      final modulesRes = await supabase
          .from('micro_modules')
          .select(
            'id, name, description, thumbnail_url, is_mandatory, '
            'module_chapters(id, name, sequence_number)',
          );

      debugPrint('[Learning] modules fetched: ${(modulesRes as List).length}');

      // 2. Collect every chapter ID across all modules for a single batch query
      final allChapterIds = <String>[
        for (final m in modulesRes as List)
          for (final c in m['module_chapters'] as List)
            if (c['id'] != null) c['id'] as String,
      ];

      // 3. Batch-fetch progress for current user across all chapters
      final progressMap = <String, Map<String, dynamic>>{};
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
      }

      // 4. Build courses list + mandatory materials list
      var courses = <Map<String, dynamic>>[];
      var mandatory = <Map<String, dynamic>>[];

      for (final m in modulesRes) {
        final rawChapters = List<Map<String, dynamic>>.from(
          (m['module_chapters'] as List).map((c) => c as Map<String, dynamic>),
        );

        // Sort chapters by sequence_number so we always get the right "first" one
        rawChapters.sort(
          (a, b) => ((a['sequence_number'] as int?) ?? 0).compareTo(
            (b['sequence_number'] as int?) ?? 0,
          ),
        );

        // Average watch_percentage across all chapters → module progress (0–1)
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

        // For mandatory modules, surface the first incomplete chapter
        if (m['is_mandatory'] == true && rawChapters.isNotEmpty) {
          final firstIncomplete = rawChapters.firstWhere(
            (c) => progressMap[c['id']]?['is_completed'] != true,
            orElse: () => rawChapters.first,
          );
          mandatory.add({
            'moduleName': (m['name'] as String?) ?? '',
            'chapterName':
                (firstIncomplete['name'] as String?) ??
                (m['description'] as String?) ??
                '',
            'lastVisit':
                progressMap[firstIncomplete['id']]?['last_watched_at'] as String?,
          });
        }
      }

      debugPrint(
        '[Learning] courses: ${courses.length}, mandatory: ${mandatory.length}',
      );

      if (mounted) {
        setState(() {
          _courses = courses;
          _mandatoryMaterials = mandatory;
          _cardOrder = List.generate(mandatory.length, (i) => i);
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[Learning] Error: $e');
      debugPrint('[Learning] Stack: $st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '-';
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    AppHeader(
                      subtitle: "Let's Learn,",
                      title: firstName,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFCC80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_streakDays',
                              style: const TextStyle(
                                fontSize: AppTheme.normalTextSize,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('🔥', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Important Materials ───────────────────────────────────
                    if (_mandatoryMaterials.isNotEmpty) ...[
                      Text(
                        'You have ${_mandatoryMaterials.length} important '
                        'material${_mandatoryMaterials.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: AppTheme.normalTextSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStackedMaterials(),
                      const SizedBox(height: 24),
                    ],

                    // ── Courses ───────────────────────────────────────────────
                    const Text(
                      'Courses',
                      style: TextStyle(
                        fontSize: AppTheme.normalTextSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_courses.isEmpty)
                      _buildEmptyState(
                        Icons.menu_book_outlined,
                        'No courses available yet',
                      )
                    else
                      SizedBox(
                        height: 349,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: EdgeInsets.zero,
                          itemCount: _courses.length,
                          itemBuilder: (_, i) => _buildCourseCard(_courses[i]),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // ── Your Statistics ───────────────────────────────────────
                    const Text(
                      'Your Statistics',
                      style: TextStyle(
                        fontSize: AppTheme.normalTextSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatisticsRow(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Stacked materials ──────────────────────────────────────────────────────
  Widget _buildStackedMaterials() {
    if (_cardOrder.isEmpty) return const SizedBox.shrink();

    const double cardHeight = 95.0;
    const double stackPeek = 14.0;
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
    final material = _mandatoryMaterials[_cardOrder[depth]];
    final double topOffset = depth * stackPeek;
    final double hPad = depth * 10.0;
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
              final riseHPad = _lerp(10.0, 0.0, riseT);
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
                                borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCardFlat(Map<String, dynamic> material) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFF7E57C2),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top: module title
                Text(
                  (material['moduleName'] as String?) ?? '',
                  style: TextStyle(
                    fontSize: AppTheme.extraSmallTextSize,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Middle: chapter name
                Text(
                  (material['chapterName'] as String?) ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTheme.smallTextSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Bottom: last visit date
                Text(
                  'Last visit: ${_formatDate(material['lastVisit'] as String?)}',
                  style: TextStyle(
                    fontSize: AppTheme.extraSmallTextSize / 1.3,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
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
      width: 218,
      height: 230,
      margin: const EdgeInsets.only(right: 16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Lower layer: thumbnail background ──
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: thumbnailUrl != null
                ? Image.network(thumbnailUrl, fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
          ),

          // ── Dim overlay on thumbnail ──
          if (thumbnailUrl != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),

          // ── Upper layer: floating info panel ──
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.smallTextSize,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    course['subtitle'] as String,
                    style: TextStyle(
                      fontSize: AppTheme.extraSmallTextSize,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: course['progress'] as double,
                      backgroundColor: Colors.grey[800],
                      color: const Color(0xFF7E57C2),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    course['progressText'] as String,
                    style: TextStyle(
                      fontSize: AppTheme.extraSmallTextSize,
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
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        children: [
          // ── Congratulations card ──
          Container(
            width: 260,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4DD0E1), Color(0xFF0097A7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Congratulations!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.normalTextSize,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'You best 60.7% of users with 360 minutes of learning this week!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppTheme.extraSmallTextSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.track_changes_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),

          // ── Streak card ──
          Container(
            width: 260,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D),
              borderRadius: BorderRadius.circular(20),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.normalTextSize,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Keep it up! You\'re on a roll.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppTheme.extraSmallTextSize,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 26,
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
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
