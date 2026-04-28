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
          'id, created_at, total_amount, order_details(quantity, amount, product:products(name, categories!inner(name)))',
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
        final lineTotal = (d['amount'] as num?)?.toDouble() ?? 0.0;
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
        model: 'gemini-3.1-flash-lite-preview',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      final bizName = UserService().currentBusinessName;
      final bizType = UserService().currentBusinessType;

      final prompt =
          '''
You are a smart business advisor for a Malaysian micro-business using a POS app called SEED.

Business profile:
- Business Name: ${bizName.isEmpty ? 'Unknown' : bizName}
- Business Type: ${bizType.isEmpty ? 'General retail/food' : bizType}
- Operating Country: Malaysia
- Customer base: Mix of Malay, Chinese, and Indian ethnics — culturally diverse with varying dietary preferences and spending habits
- Market: Local neighbourhood / small-town / urban micro-business

Performance data ($periodLabel period):
- Total Revenue: RM${_totalSales.toStringAsFixed(2)}
- Total Orders: $_totalOrders
- Top Products by Revenue: ${topStr.isEmpty ? 'No data' : topStr}
- Best Performing Category: $_bestCategory

Generate exactly 3 actionable business insights tailored to this specific business and Malaysian market context.
Each insight should be grounded in the performance data and culturally relevant.

Return ONLY a JSON array with exactly 3 objects, no extra text:
[
  {
    "title": "short title (3-5 words)",
    "description": "2-3 sentences explaining the insight clearly, referencing specific data points where possible",
    "why": "1-2 sentences on why this matters for this type of business in the Malaysian market"
  }
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
              'description': (e['description'] as String?) ?? '',
              'why': (e['why'] as String?) ?? '',
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
                      title: UserService().currentBusinessName.isNotEmpty ? UserService().currentBusinessName : UserService().currentOwnerName,
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
          SizedBox(height: 8.h),
          SizedBox(
            height: 120.h,
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: best product + category — 50/50 height
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ProductHighlight(
                          label: 'Best Selling Product',
                          name: bestProduct,
                          icon: Icons.star_rounded,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Expanded(
                        child: _ProductHighlight(
                          label: 'Best Selling Category',
                          name: bestCategory,
                          icon: Icons.category_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                // Right: fixed image + top 3 products
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image card — wraps to image natural height
                      Container(
                        height: 40.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        padding: EdgeInsets.all(4.w),
                        child: Image.asset(
                          'assets/images/business_dashboard/lucky_pie.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      // Top 3 card — fixed height (always fits 3 rows)
                      SizedBox(
                        height: 110.h,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Top 3 Products',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 10.h),
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                    description: e.value['description'] ?? '',
                    why: e.value['why'] ?? '',
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

class _InsightCard extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final String why;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.index,
    required this.title,
    required this.description,
    required this.why,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _InsightDetailPage(
            index: index,
            title: title,
            description: description,
            why: why,
            icon: icon,
            color: color,
          ),
        ),
      ),
      child: Container(
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
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(icon, size: 16.sp, color: color),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 6.h),
            Text(
              'read more',
              style: TextStyle(
                fontSize: 10.sp,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insight detail page ───────────────────────────────────────────────────────
class _InsightDetailPage extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final String why;
  final IconData icon;
  final Color color;

  const _InsightDetailPage({
    required this.index,
    required this.title,
    required this.description,
    required this.why,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20.w, 56.h, 20.w, 28.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 18.sp),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Icon(icon, color: Colors.white, size: 22.sp),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  'Suggestions $index',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailSection(
                    label: 'Description',
                    text: description,
                    color: color,
                  ),
                  SizedBox(height: 16.h),
                  _DetailSection(
                    label: 'Why this could help?',
                    text: why,
                    color: color,
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

class _DetailSection extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _DetailSection({
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            text.isEmpty ? '—' : text,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
