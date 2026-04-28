import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/services/voice_assistant_service.dart';
import 'package:seed/screens/add_product_screen.dart';
import 'package:seed/screens/make_order_screen.dart';
import 'package:seed/screens/pending_orders_screen.dart';
import 'package:seed/screens/completed_orders_screen.dart';
import 'package:seed/screens/loan/loan_explore_screen.dart';
import 'package:seed/screens/my_learning_screen.dart';
import 'package:seed/screens/my_performance_screen.dart';
import 'package:seed/screens/profile_screen.dart';
import 'package:seed/main.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late PageController _quickAccessController;

  // ── Live stats ─────────────────────────────────────────────────────────────
  bool _statsLoading = true;
  int _pendingCount = 0;
  int _completedCount = 0;
  int _pendingItemsCount = 0;
  int _loanAgentCount = 0;
  int _learningInProgress = 0;
  double _totalRevenue = 0.0;

  List<Map<String, dynamic>> get _quickAccessItems => [
    {
      'title': 'My Learning',
      'subtitle': _learningInProgress > 0
          ? '$_learningInProgress chapter${_learningInProgress > 1 ? 's' : ''} in progress'
          : 'Start your first lesson today.',
      'progress': _learningInProgress > 0
          ? '$_learningInProgress active'
          : 'Get started',
      'time': '',
      'color': const Color(0xFFB69AEE),
      'icon': Icons.book,
      'imagePath': 'assets/images/Login_Screen/Thumbnail_Learning.png',
    },
    {
      'title': 'Browsing Loan',
      'subtitle': 'Secure additional funds now.',
      'progress': '$_loanAgentCount agent${_loanAgentCount != 1 ? 's' : ''}',
      'time': '',
      'color': const Color(0xFF81D4FA),
      'icon': Icons.account_balance,
      'imagePath': 'assets/images/Login_Screen/Thumbnail_Finance.png',
    },
    {
      'title': 'My Performance',
      'subtitle': 'Observe your sales performance. ',
      'progress': 'RM ${_totalRevenue.toStringAsFixed(0)}',
      'time': '',
      'color': const Color(0xFFFFCCBC),
      'icon': Icons.bar_chart,
      'imagePath': 'assets/images/Login_Screen/Thumbnail_Dashboard.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _quickAccessController = PageController(
      viewportFraction: 0.85,
      initialPage: 1000,
    );
    _quickAccessController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final ownerId = UserService().currentOwnerId;
    if (ownerId == null) {
      if (mounted) setState(() => _statsLoading = false);
      return;
    }
    final db = Supabase.instance.client;
    try {
      final results = await Future.wait([
        // 0: pending orders
        db
            .from('orders')
            .select('id')
            .eq('business_id', ownerId)
            .eq('transaction_status', 'Pending'),
        // 1: today's completed orders
        db
            .from('orders')
            .select('id, total_amount')
            .eq('business_id', ownerId)
            .or(
              'transaction_status.eq.completed,transaction_status.eq.Completed',
            )
            .gte(
              'created_at',
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ).toIso8601String(),
            ),
        // 2: pending items (sum of quantities)
        db
            .from('order_details')
            .select(
              'quantity, transaction_id, orders!inner(business_id, transaction_status)',
            )
            .eq('orders.business_id', ownerId)
            .eq('orders.transaction_status', 'Pending'),
        // 3: loan agents
        db.from('loan_agents').select('user_id'),
        // 4: learning in-progress chapters
        db
            .from('video_watch_progress')
            .select('watch_percentage')
            .eq('user_id', ownerId)
            .eq('is_completed', false)
            .gt('watch_percentage', 0),
      ]);

      final pending = (results[0] as List).length;
      final completedList = results[1] as List;
      final completed = completedList.length;
      double revenue = 0;
      for (final r in completedList) {
        revenue += (r['total_amount'] as num?)?.toDouble() ?? 0;
      }
      int itemsTotal = 0;
      for (final r in (results[2] as List)) {
        itemsTotal += (r['quantity'] as num?)?.toInt() ?? 0;
      }
      final agents = (results[3] as List).length;
      final inProgress = (results[4] as List).length;

      if (mounted) {
        setState(() {
          _pendingCount = pending;
          _completedCount = completed;
          _pendingItemsCount = itemsTotal;
          _loanAgentCount = agents;
          _learningInProgress = inProgress;
          _totalRevenue = revenue;
          _statsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[HomePage] fetchStats error: $e');
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  void dispose() {
    _quickAccessController.dispose();
    super.dispose();
  }

  void _onNavPressed(int i) {
    if (i == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyPerformanceScreen()),
      );
      return;
    }
    if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyLearningScreen()),
      );
      return;
    }
    if (i == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoanExploreScreen()),
      );
      return;
    }
    setState(() => _currentIndex = i);
  }

  void _onVoiceFabPressed() {
    VoiceAssistantService().startListening(localeId: 'en-MY');
  }

  Future<void> _checkProductsAndNavigate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final ownerId = UserService().currentOwnerId;

      if (ownerId == null) {
        if (mounted) Navigator.pop(context); // Close loading
        _showNoProductDialog();
        return;
      }

      final supabase = Supabase.instance.client;
      // Check if products exist for this owner
      final categoryRes = await supabase
          .from('categories')
          .select('id')
          .eq('business_id', ownerId)
          .limit(1);

      if (mounted) Navigator.pop(context); // Close loading

      if (categoryRes.isEmpty) {
        _showNoProductDialog();
      } else {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MakeOrderScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      // Show dialog as a fallback visually if tables aren't created
      _showNoProductDialog();
      debugPrint('Error: $e');
    }
  }

  void _showNoProductDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90.w,
                  height: 90.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE6F3FC),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.15,
                      child: Container(
                        width: 50.w,
                        height: 50.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F4FD),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: const Color(0xFF38B6FF),
                          size: 32.sp,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'No product found',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Do you want to add a product first?',
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF40BBFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddProductScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '+ Yes, add product',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Not now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentIndex: _currentIndex,
      onNavPressed: _onNavPressed,
      onFabPressed: _onVoiceFabPressed,
      backgroundColor: const Color(0xFFF8F9FE), // Light background color
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/images/Default_PFP.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back! 👋',
                        style: TextStyle(
                          fontSize: AppTheme.extraSmallTextSize.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        UserService().currentBusinessName.isNotEmpty
                            ? UserService().currentBusinessName
                            : UserService().currentOwnerName,
                        style: TextStyle(
                          fontSize: AppTheme.smallTextSize.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 40.w,
                    padding: EdgeInsets.all(0),
                    height: 40.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: AppTheme.largeTextSize.sp,
                      ),
                      color: Colors.black,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Make an Order Banner
              SizedBox(
                height: 200.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Blue Card Background
                    Container(
                      height: 150.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32.r),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF81D4FA), Color(0xFF29B6F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Chef Image
                    // Chef Image
                    Positioned(
                      top: -30,
                      left: 0,
                      right: 0,
                      child: Image.asset(
                        'assets/images/Home_Page/Order_Chef_Deco.png',
                        height: 140.h,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Inner White Card
                    Positioned(
                      bottom: 16,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Make an order',
                                  style: TextStyle(
                                    fontSize: AppTheme.normalTextSize.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Get your order started now',
                                  style: TextStyle(
                                    fontSize: AppTheme.extraSmallTextSize.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 30.w,
                              height: 30.h,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFCCBC), // Peach/Orange
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_forward,
                                  size: AppTheme.normalTextSize.sp,
                                  weight: 800,
                                ),
                                color: Colors.black,
                                onPressed: _checkProductsAndNavigate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Orders Section
              Row(
                children: [
                  Text(
                    'Orders',
                    style: TextStyle(
                      fontSize: AppTheme.normalTextSize.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Decorative dots or icon if needed
                  Icon(Icons.auto_awesome, size: 16.sp, color: Colors.amber),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  // Pending Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PendingOrdersScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE1BEE7,
                                    ), // Light Purple
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(
                                    Icons.hourglass_empty,
                                    size: 16.sp,
                                    color: Colors.purple,
                                  ),
                                ),
                                Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: Colors.grey,
                                  size: 16.sp,
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Pending',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _statsLoading
                                    ? SizedBox(
                                        width: 20.w,
                                        height: 20.h,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        '$_pendingCount',
                                        style: TextStyle(
                                          fontSize: AppTheme.largeTextSize.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                SizedBox(width: 8.w),
                                if (!_statsLoading && _pendingItemsCount > 0)
                                  Text(
                                    '~ $_pendingItemsCount items',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Completed Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompletedOrdersScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFB3E5FC,
                                    ), // Light Blue
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 16.sp,
                                    color: Colors.blue,
                                  ),
                                ),
                                Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: Colors.grey,
                                  size: 16.sp,
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Completed',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            _statsLoading
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    '$_completedCount',
                                    style: TextStyle(
                                      fontSize: AppTheme.largeTextSize.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Quick Access
              Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: AppTheme.normalTextSize.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: SizedBox(
                  height: 190.h,
                  child: PageView.builder(
                    clipBehavior: Clip.none,
                    controller: _quickAccessController,
                    itemBuilder: (context, index) {
                      final itemIndex = index % _quickAccessItems.length;
                      final item = _quickAccessItems[itemIndex];

                      final page =
                          _quickAccessController.hasClients &&
                              _quickAccessController.page != null
                          ? _quickAccessController.page!
                          : 1000.0;
                      double value = (page - index).abs();
                      double activeFactor = (1 - (value * 0.3)).clamp(0.0, 1.0);

                      return Transform.translate(
                        offset: Offset(0, -15 * activeFactor),
                        child: Transform.scale(
                          scale: 0.9 + (0.1 * activeFactor),
                          child: GestureDetector(
                            onTap: () {
                              final title = item['title'] as String;
                              if (title == 'Browsing Loan') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoanExploreScreen(),
                                  ),
                                );
                              } else if (title == 'My Learning') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyLearningScreen(),
                                  ),
                                );
                              } else if (title == 'My Performance') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyPerformanceScreen(),
                                  ),
                                );
                              }
                            },
                            child: _buildQuickAccessCard(
                              title: item['title'],
                              subtitle: item['subtitle'],
                              progress: item['progress'],
                              time: item['time'],
                              color: item['color'],
                              icon: item['icon'],
                              imagePath: item['imagePath'],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 80.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required String title,
    required String subtitle,
    required String progress,
    required String time,
    required Color color,
    required IconData icon,
    required String imagePath,
  }) {
    return Container(
      margin: EdgeInsets.only(right: 16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            // Left Image Section
            Container(
              width: 120.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: color),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
                color: Colors.grey[300],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(icon, size: 16.sp, color: Colors.white),
                        ),
                        const Icon(Icons.more_horiz, color: Colors.grey),
                      ],
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 10.sp, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          progress,
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                        ),
                        if (time.isNotEmpty) ...[
                          SizedBox(width: 12.w),
                          Icon(
                            Icons.timer_outlined,
                            size: 14.sp,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Last Visit:',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                        Icon(Icons.arrow_outward, size: 16.sp),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
