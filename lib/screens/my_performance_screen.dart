import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/main.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/theme/app_theme.dart';

enum _Period { day, week, month, year }

class MyPerformanceScreen extends StatefulWidget {
  const MyPerformanceScreen({super.key});

  @override
  State<MyPerformanceScreen> createState() => _MyPerformanceScreenState();
}

class _MyPerformanceScreenState extends State<MyPerformanceScreen> {
  _Period _period = _Period.week;
  bool _isLoading = true;
  bool _insightsLoading = false;

  double _totalSales = 0;
  int _totalOrders = 0;
  List<FlSpot> _chartSpots = [];
  List<String> _chartLabels = [];
  double _chartMax = 1;

  // Products
  String _bestProduct = '-';
  String _bestCategory = '-';
  List<Map<String, dynamic>> _topProducts = [];

  // Gemini insights
  List<Map<String, String>> _insights = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await _fetchData();
    setState(() => _isLoading = false);
    _fetchInsights();
  }

  DateTimeRange _range() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.day:
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: now);
      case _Period.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: now,
        );
      case _Period.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case _Period.year:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
    }
  }

  Future<void> _fetchData() async {
    final ownerId = UserService().currentOwnerId;
    if (ownerId == null) return;

    final range = _range();
    final supabase = Supabase.instance.client;

    final rows = await supabase
        .from('orders')
        .select(
          'id, created_at, total_amount, order_details(quantity, product:products(name, categories!inner(name)))',
        )
        .eq('business_id', ownerId)
        .or('transaction_status.eq.completed,transaction_status.eq.Completed')
        .gte('created_at', range.start.toIso8601String())
        .lte('created_at', range.end.toIso8601String())
        .order('created_at');

    final orders = (rows as List).cast<Map<String, dynamic>>();

    _totalOrders = orders.length;
    _totalSales = orders.fold(
      0.0,
      (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0.0),
    );

    // ── Chart data ────────────────────────────────────────────────────────────
    final Map<String, double> buckets = {};

    String Function(DateTime) bucketKey;
    String Function(String) labelFn;

    switch (_period) {
      case _Period.day:
        bucketKey = (dt) => '${dt.hour}';
        labelFn = (k) => '${k}h';
        for (int h = 0; h <= 23; h += 3) {
          buckets['$h'] = 0;
        }
        break;
      case _Period.week:
        bucketKey = (dt) => DateFormat('E').format(dt);
        labelFn = (k) => k;
        for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
          buckets[d] = 0;
        }
        break;
      case _Period.month:
        bucketKey = (dt) => '${dt.day}';
        labelFn = (k) => k;
        final daysInMonth = DateTime(
          range.start.year,
          range.start.month + 1,
          0,
        ).day;
        for (int d = 1; d <= daysInMonth; d += 5) {
          buckets['$d'] = 0;
        }
        break;
      case _Period.year:
        bucketKey = (dt) => DateFormat('MMM').format(dt);
        labelFn = (k) => k;
        for (final m in [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ]) {
          buckets[m] = 0;
        }
        break;
    }

    for (final o in orders) {
      try {
        final dt = DateTime.parse(o['created_at'] as String).toLocal();
        final key = bucketKey(dt);
        final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        if (buckets.containsKey(key)) {
          buckets[key] = (buckets[key] ?? 0) + amount;
        }
      } catch (_) {}
    }

    final keys = buckets.keys.toList();
    _chartLabels = keys.map(labelFn).toList();
    _chartSpots = List.generate(
      keys.length,
      (i) => FlSpot(i.toDouble(), buckets[keys[i]]!),
    );
    _chartMax = _chartSpots.map((s) => s.y).fold(1.0, (a, b) => a > b ? a : b);
    if (_chartMax < 1) _chartMax = 1;

    // ── Product stats ─────────────────────────────────────────────────────────
    final Map<String, double> productSales = {};
    final Map<String, int> productQty = {};
    final Map<String, double> categorySales = {};

    for (final o in orders) {
      final details = (o['order_details'] as List? ?? []);
      for (final d in details) {
        final product = d['product'] as Map?;
        if (product == null) continue;
        final name = product['name'] as String? ?? 'Unknown';
        final catName =
            (product['categories'] as Map?)?['name'] as String? ?? 'General';
        final qty = (d['quantity'] as num?)?.toInt() ?? 1;
        final unitPrice = (d['unit_price'] as num?)?.toDouble() ?? 0.0;
        final lineTotal = qty * unitPrice;
        productSales[name] = (productSales[name] ?? 0) + lineTotal;
        productQty[name] = (productQty[name] ?? 0) + qty;
        categorySales[catName] = (categorySales[catName] ?? 0) + lineTotal;
      }
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedCategories = categorySales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _bestProduct = sortedProducts.isNotEmpty ? sortedProducts.first.key : '-';
    _bestCategory = sortedCategories.isNotEmpty
        ? sortedCategories.first.key
        : '-';
    _topProducts = sortedProducts
        .take(3)
        .map((e) => {'name': e.key, 'amount': e.value})
        .toList();
  }

  Future<void> _fetchInsights() async {
    if (_totalOrders == 0) return;
    setState(() => _insightsLoading = true);

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) return;

      final topStr = _topProducts
          .map(
            (p) =>
                '${p['name']}: RM${(p['amount'] as double).toStringAsFixed(2)}',
          )
          .join(', ');
      final periodLabel = _period.name;

      final model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      final prompt =
          '''
You are a smart business advisor for a Malaysian micro-business using a POS app called SEED.

Business context ($periodLabel period):
- Total Revenue: RM${_totalSales.toStringAsFixed(2)}
- Total Orders: $_totalOrders
- Top Products: ${topStr.isEmpty ? 'No data' : topStr}
- Best Category: $_bestCategory
- Business Type: ${UserService().currentBusinessType}

Generate exactly 3 short, actionable business insights or recommendations based on this performance data.
Each insight must be practical and specific to a small Malaysian food/retail business.

Return ONLY a JSON array with exactly 3 objects:
[
  {"title": "short title (3-5 words)", "summary": "1-2 sentence actionable advice"},
  {"title": "short title (3-5 words)", "summary": "1-2 sentence actionable advice"},
  {"title": "short title (3-5 words)", "summary": "1-2 sentence actionable advice"}
]
''';

      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 12));

      final clean = (response.text ?? '[]')
          .trim()
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();

      final decoded = jsonDecode(clean) as List;
      _insights = decoded
          .map(
            (e) => {
              'title': (e['title'] as String?) ?? '',
              'summary': (e['summary'] as String?) ?? '',
            },
          )
          .toList();
    } catch (e) {
      debugPrint('[Insights] Error: $e');
    } finally {
      if (mounted) setState(() => _insightsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return AppLayout(
      currentIndex: 1,
      onNavPressed: (i) {
        if (i != 1) Navigator.pop(context);
      },
      onFabPressed: () {},
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    AppHeader(
                      subtitle: 'Performance',
                      title: 'My Performance',
                      trailing: IconButton(
                        onPressed: _load,
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 22.sp,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Period tabs
                    _PeriodTabs(
                      selected: _period,
                      onSelect: (p) {
                        setState(() => _period = p);
                        _load();
                      },
                    ),
                    SizedBox(height: 16.h),

                    // Stats + chart card
                    _StatsChartCard(
                      totalSales: _totalSales,
                      totalOrders: _totalOrders,
                      spots: _chartSpots,
                      labels: _chartLabels,
                      maxY: _chartMax,
                      fmt: fmt,
                    ),
                    SizedBox(height: 16.h),

                    // Products card
                    _ProductsCard(
                      bestProduct: _bestProduct,
                      bestCategory: _bestCategory,
                      topProducts: _topProducts,
                      fmt: fmt,
                    ),
                    SizedBox(height: 16.h),

                    // Gemini insights
                    _InsightsSection(
                      insights: _insights,
                      isLoading: _insightsLoading,
                    ),
                    SizedBox(height: 100.h),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Period tabs ───────────────────────────────────────────────────────────────
class _PeriodTabs extends StatelessWidget {
  final _Period selected;
  final void Function(_Period) onSelect;

  const _PeriodTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: _Period.values.map((p) {
          final active = p == selected;
          final label = p.name[0].toUpperCase() + p.name.substring(1);
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF40BBFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTheme.extraSmallTextSize.sp,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Stats + Chart card ────────────────────────────────────────────────────────
class _StatsChartCard extends StatelessWidget {
  final double totalSales;
  final int totalOrders;
  final List<FlSpot> spots;
  final List<String> labels;
  final double maxY;
  final NumberFormat fmt;

  const _StatsChartCard({
    required this.totalSales,
    required this.totalOrders,
    required this.spots,
    required this.labels,
    required this.maxY,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat row
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _StatTile(
                  label: 'Total Sales',
                  value: 'RM ${fmt.format(totalSales)}',
                  color: const Color(0xFF40BBFF),
                ),
              ),
              Container(width: 1, height: 40.h, color: Colors.grey.shade100),
              Expanded(
                flex: 4,
                child: _StatTile(
                  label: 'Orders',
                  value: '$totalOrders Orders',
                  color: const Color(0xFF7E57C2),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: AppTheme.smallTextSize.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            'Visualise your sales performance throughout the duration.',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 140.h,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'No data',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY * 1.2,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36.w,
                            interval: maxY / 4,
                            getTitlesWidget: (v, _) => Text(
                              v >= 1000
                                  ? '${(v / 1000).toStringAsFixed(1)}k'
                                  : v.toInt().toString(),
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (spots.length / 5).ceilToDouble().clamp(
                              1,
                              9999,
                            ),
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= labels.length)
                                return const SizedBox();
                              return Padding(
                                padding: EdgeInsets.only(top: 4.h),
                                child: Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF40BBFF),
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF40BBFF).withValues(alpha: 0.25),
                                const Color(0xFF40BBFF).withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
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

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.normalTextSize.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Products card ─────────────────────────────────────────────────────────────
class _ProductsCard extends StatelessWidget {
  final String bestProduct;
  final String bestCategory;
  final List<Map<String, dynamic>> topProducts;
  final NumberFormat fmt;

  const _ProductsCard({
    required this.bestProduct,
    required this.bestCategory,
    required this.topProducts,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9C7FE0), Color(0xFF7E57C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Products',
                style: TextStyle(
                  fontSize: AppTheme.normalTextSize.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Top Performing',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 14.sp,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: best product + category
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductHighlight(
                      label: 'Best Selling Product',
                      name: bestProduct,
                      icon: Icons.star_rounded,
                    ),
                    SizedBox(height: 10.h),
                    _ProductHighlight(
                      label: 'Best Selling Category',
                      name: bestCategory,
                      icon: Icons.category_rounded,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // Right: top 3 with image peeking above
              Expanded(
                flex: 5,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // White card — padded top to leave room for image overlap
                    Container(
                      margin: EdgeInsets.only(top: 44.h),
                      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top 3 Products',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          if (topProducts.isEmpty)
                            Text(
                              'No data',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.grey,
                              ),
                            )
                          else
                            ...topProducts.asMap().entries.map((e) {
                              final colors = [
                                const Color(0xFFFFD700),
                                const Color(0xFFAAAAAA),
                                const Color(0xFFCD7F32),
                              ];
                              return Padding(
                                padding: EdgeInsets.only(bottom: 6.h),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10.w,
                                      height: 10.w,
                                      decoration: BoxDecoration(
                                        color: colors[e.key],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 5.w),
                                    Expanded(
                                      child: Text(
                                        e.value['name'] as String,
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: const Color(0xFF1E293B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      'RM${fmt.format(e.value['amount'] as double)}',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    // Image peeking above the card
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          'assets/images/business_dashboard/lucky_pie.png',
                          height: 80.h,
                          width: 30.w,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductHighlight extends StatelessWidget {
  final String label;
  final String name;
  final IconData icon;

  const _ProductHighlight({
    required this.label,
    required this.name,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: Colors.white, size: 18.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 9.sp, color: Colors.white60),
                ),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gemini Insights section ───────────────────────────────────────────────────
class _InsightsSection extends StatelessWidget {
  final List<Map<String, String>> insights;
  final bool isLoading;

  const _InsightsSection({required this.insights, required this.isLoading});

  static const _icons = [
    Icons.tips_and_updates_rounded,
    Icons.visibility_rounded,
    Icons.trending_up_rounded,
  ];

  static const _colors = [
    Color(0xFFFF8A65),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 16.sp,
              color: const Color(0xFF7E57C2),
            ),
            SizedBox(width: 6.w),
            Text(
              'Hear from our ',
              style: TextStyle(
                fontSize: AppTheme.normalTextSize.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Virtual Expert!',
              style: TextStyle(
                fontSize: AppTheme.normalTextSize.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF7E57C2),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (isLoading)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Column(
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF7E57C2),
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Analysing your performance...',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else if (insights.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Text(
              'No data yet — complete some orders to get personalised insights.',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: insights.asMap().entries.map((e) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: e.key < insights.length - 1 ? 8.w : 0,
                  ),
                  child: _InsightCard(
                    index: e.key + 1,
                    title: e.value['title'] ?? '',
                    summary: e.value['summary'] ?? '',
                    icon: _icons[e.key % _icons.length],
                    color: _colors[e.key % _colors.length],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _InsightCard extends StatefulWidget {
  final int index;
  final String title;
  final String summary;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.index,
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
  });

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.index}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: widget.color,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Icon(widget.icon, size: 16.sp, color: widget.color),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6.h),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Text(
              widget.summary,
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'read less' : 'read more',
              style: TextStyle(
                fontSize: 10.sp,
                color: widget.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
