import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/screens/add_product_screen.dart';
import 'package:seed/screens/make_order_screen.dart';
import 'package:seed/screens/pending_orders_screen.dart';
import 'package:seed/screens/completed_orders_screen.dart';
import 'package:seed/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late PageController _quickAccessController;
  double _quickAccessPage = 1000.0;

  final List<Map<String, dynamic>> _quickAccessItems = [
    {
      'title': 'My Learning',
      'subtitle': 'Continue watching:\nChapter 2 - Leveraging AI in Financing',
      'progress': '60%',
      'time': '40 min',
      'color': const Color(0xFFB69AEE),
      'icon': Icons.book,
      'imagePath': 'assets/images/Login_Screen/Thumbnail_Learning.png',
    },
    {
      'title': 'Browsing Loan',
      'subtitle':
          'Secure additional funds with expert guidance from loan agents.',
      'progress': '50 agents',
      'time': '',
      'color': const Color(0xFF81D4FA),
      'icon': Icons.account_balance,
      'imagePath': 'assets/images/Login_Screen/Thumbnail_Finance.png',
    },
    {
      'title': 'My Performance',
      'subtitle':
          'See how your sales are performing and where you\'re improving.',
      'progress': '80%',
      'time': '15 min',
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
      setState(() {
        _quickAccessPage = _quickAccessController.page!;
      });
    });
  }

  @override
  void dispose() {
    _quickAccessController.dispose();
    super.dispose();
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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
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
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F4FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xFF38B6FF),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No product found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Do you want to add a product first?',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF40BBFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
      onNavPressed: (i) => setState(() => _currentIndex = i),
      onFabPressed: _checkProductsAndNavigate,
      backgroundColor: const Color(0xFFF8F9FE), // Light background color
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage('assets/images/Default_PFP.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back! 👋',
                        style: TextStyle(
                          fontSize: AppTheme.extraSmallTextSize,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        UserService().currentOwnerName,
                        style: const TextStyle(
                          fontSize: AppTheme.smallTextSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    padding: const EdgeInsets.all(0),
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        size: AppTheme.largeTextSize,
                      ),
                      color: Colors.black,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Make an Order Banner
              SizedBox(
                height: 240,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Blue Card Background
                    Container(
                      height: 189,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
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
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Inner White Card
                    Positioned(
                      bottom: 16,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Make an order',
                                  style: TextStyle(
                                    fontSize: AppTheme.normalTextSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lorem Ipsum',
                                  style: TextStyle(
                                    fontSize: AppTheme.extraSmallTextSize,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFCCBC), // Peach/Orange
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward,
                                  size: AppTheme.normalTextSize,
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
              const SizedBox(height: 20),

              // Orders Section
              Row(
                children: [
                  const Text(
                    'Orders',
                    style: TextStyle(
                      fontSize: AppTheme.normalTextSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Decorative dots or icon if needed
                  Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                ],
              ),
              const SizedBox(height: 8),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE1BEE7,
                                    ), // Light Purple
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.hourglass_empty,
                                    size: 16,
                                    color: Colors.purple,
                                  ),
                                ),
                                const Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Text(
                                  'Pending',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  '5',
                                  style: TextStyle(
                                    fontSize: AppTheme.largeTextSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '~ 30 items',
                                  style: TextStyle(
                                    fontSize: 12,
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
                  const SizedBox(width: 16),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFB3E5FC,
                                    ), // Light Blue
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                                const Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Completed',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '15',
                              style: TextStyle(
                                fontSize: AppTheme.largeTextSize,
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
              const SizedBox(height: 16),

              // Quick Access
              const Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: AppTheme.normalTextSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 240,
                child: PageView.builder(
                  clipBehavior: Clip.none,
                  controller: _quickAccessController,
                  itemBuilder: (context, index) {
                    final itemIndex = index % _quickAccessItems.length;
                    final item = _quickAccessItems[itemIndex];

                    // Calculate distance from current page for animation
                    double value = (_quickAccessPage - index).abs();
                    // Active card is at distance 0, inactive ones are at distance 1.0+
                    double activeFactor = (1 - (value * 0.3)).clamp(0.0, 1.0);

                    return Transform.translate(
                      offset: Offset(0, -15 * activeFactor), // Active is higher
                      child: Transform.scale(
                        scale: 0.9 + (0.1 * activeFactor), // Active is larger
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
                    );
                  },
                ),
              ),
              const SizedBox(height: 120), // Space for FAB
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
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            // Left Image Section
            Container(
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 16, color: Colors.white),
                        ),
                        const Icon(Icons.more_horiz, color: Colors.grey),
                      ],
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          progress,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Last Visit:',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                        Icon(Icons.arrow_outward, size: 16),
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
