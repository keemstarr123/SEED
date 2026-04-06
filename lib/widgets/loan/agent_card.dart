import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:seed/models/loan_agent.dart';

class AgentCard extends StatefulWidget {
  final LoanAgent agent;
  final VoidCallback onApply;

  const AgentCard({super.key, required this.agent, required this.onApply});

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  bool _expanded = false;

  Color _bankColor(String bank) {
    final b = bank.toLowerCase();
    if (b.contains('hsbc')) return const Color(0xFFDB0011);
    if (b.contains('rhb')) return const Color(0xFFE65100);
    if (b.contains('maybank')) return const Color(0xFF003087);
    if (b.contains('cimb')) return const Color(0xFF7B0022);
    return Colors.blueGrey;
  }

  Color _cardColor(String bank) {
    final b = bank.toLowerCase();
    if (b.contains('hsbc')) return const Color(0xFFEDE7F6);
    if (b.contains('rhb')) return const Color(0xFFFFF3E0);
    if (b.contains('maybank')) return const Color(0xFFE3F2FD);
    if (b.contains('cimb')) return const Color(0xFFFCE4EC);
    return const Color(0xFFF5F5F5);
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final bankColor = _bankColor(agent.bankAffiliated);
    final cardBg = _cardColor(agent.bankAffiliated);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: bankColor.withValues(alpha: 0.3), width: 1.5),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + Name + Bank
          Row(
            children: [
              CircleAvatar(
                radius: 28.r,
                backgroundColor: bankColor.withValues(alpha: 0.15),
                child: Text(
                  agent.initials,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: bankColor,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.agentName,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: bankColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          agent.bankAffiliated,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: bankColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Chips
          Row(
            children: [
              _chip(Icons.badge_outlined, 'Loan Agent', Colors.black),
              SizedBox(width: 8.w),
              _chip(
                Icons.access_time,
                '${agent.yearsExperience} year${agent.yearsExperience == 1 ? '' : 's'} exp',
                Colors.black,
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Bio
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                children: [
                  TextSpan(
                    text: _expanded
                        ? agent.biodata
                        : (agent.biodata.length > 80
                            ? agent.biodata.substring(0, 80)
                            : agent.biodata),
                  ),
                  if (agent.biodata.length > 80)
                    TextSpan(
                      text: _expanded ? '' : '.... ',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                    ),
                  if (agent.biodata.length > 80)
                    TextSpan(
                      text: _expanded ? ' see less' : 'see more',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // Services
          Text(
            'Services Offered:',
            style: TextStyle(
                fontSize: 12.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: agent.products.map((p) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        size: 14.sp, color: const Color(0xFF1D9E75)),
                    SizedBox(width: 4.w),
                    Text(
                      p.service.title,
                      style: TextStyle(fontSize: 11.sp),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 14.h),

          // Apply Now
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Apply Now',
                style: TextStyle(
                    fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: Colors.white),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
