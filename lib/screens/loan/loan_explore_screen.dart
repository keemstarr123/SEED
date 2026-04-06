import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/models/loan_agent.dart';
import 'package:seed/services/loan/loan_repository.dart';
import 'package:seed/widgets/loan/agent_card.dart';
import 'package:seed/screens/loan/loan_application_screen.dart';
import 'package:seed/services/user_service.dart';

class LoanExploreScreen extends StatefulWidget {
  const LoanExploreScreen({super.key});

  @override
  State<LoanExploreScreen> createState() => _LoanExploreScreenState();
}

class _LoanExploreScreenState extends State<LoanExploreScreen> {
  final _repo = LoanRepository();
  final _searchCtrl = TextEditingController();

  List<LoanAgent> _agents = [];
  List<LoanAgent> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final agents = await _repo.fetchVerifiedAgents();
      if (mounted) {
        setState(() {
          _agents = agents;
          _filtered = agents;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _agents
          .where((a) =>
              a.agentName.toLowerCase().contains(q) ||
              a.bankAffiliated.toLowerCase().contains(q))
          .toList();
    });
  }

  void _onApply(LoanAgent agent) {
    final userId = UserService().currentOwnerId ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoanApplicationScreen(
          agent: agent,
          userId: userId,
          businessId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4)
              ],
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 16.sp),
          ),
        ),
        title: Text(
          'Loan Explore',
          style:
              TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search + filter bar
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6)
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search agents or banks...',
                        hintStyle:
                            TextStyle(fontSize: 13.sp, color: Colors.grey),
                        prefixIcon:
                            Icon(Icons.search, size: 20.sp, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14.h),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA040),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(Icons.tune, color: Colors.white, size: 22.sp),
                ),
              ],
            ),
          ),

          // Agent list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Failed to load agents',
                                style: TextStyle(fontSize: 14.sp)),
                            SizedBox(height: 8.h),
                            TextButton(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _error = null;
                                  });
                                  _load();
                                },
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text('No agents found',
                                style: TextStyle(fontSize: 14.sp, color: Colors.grey)))
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => AgentCard(
                              agent: _filtered[i],
                              onApply: () => _onApply(_filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
