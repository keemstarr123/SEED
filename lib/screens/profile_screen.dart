import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/services/user_service.dart';
import 'package:seed/theme/app_theme.dart';
import 'package:seed/screens/make_order_screen.dart';
import 'package:seed/screens/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = UserService();

  // ── Edit Profile ────────────────────────────────────────────────────────────
  bool _editMode = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bizNameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _user.currentOwnerName);
    _phoneCtrl = TextEditingController(text: _user.currentPhone);
    _bizNameCtrl = TextEditingController(text: _user.currentBusinessName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bizNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final db = Supabase.instance.client;
      final userId = _user.currentUserId;
      if (userId == null) return;

      await db.from('users').update({
        'name': _nameCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
      }).eq('id', userId);

      if (_user.currentBusinessName.isNotEmpty) {
        await db.from('microbusiness_owners').update({
          'business_name': _bizNameCtrl.text.trim(),
        }).eq('user_id', userId);
      }

      _user.currentOwnerName = _nameCtrl.text.trim();
      _user.currentPhone = _phoneCtrl.text.trim();
      _user.currentBusinessName = _bizNameCtrl.text.trim();

      if (mounted) {
        setState(() => _editMode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    UserService().clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: _editMode ? _buildEditForm() : _buildMenuList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gradient header with avatar ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8D5F5), Color(0xFFFFD6C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Column(
            children: [
              // Back button row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (!_editMode)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.black54),
                      onPressed: () => setState(() => _editMode = true),
                    ),
                ],
              ),
              SizedBox(height: 4.h),
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                      image: const DecorationImage(
                        image: AssetImage('assets/images/Default_PFP.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit, size: 14.sp, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                _user.currentBusinessName.isNotEmpty
                    ? _user.currentBusinessName
                    : _user.currentOwnerName,
                style: TextStyle(
                  fontSize: AppTheme.normalTextSize.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                _user.currentEmail,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings menu ────────────────────────────────────────────────────────────
  Widget _buildMenuList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        // My Menu
        _buildCard(children: [
          _buildTile(
            icon: Icons.favorite_outline,
            iconColor: Colors.red[400]!,
            iconBg: Colors.red[50]!,
            title: 'My Menu',
            subtitle: 'Quick access to your top choices.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MakeOrderScreen()),
            ),
          ),
        ]),
        SizedBox(height: 20.h),
        _buildSectionLabel('Account Settings'),
        SizedBox(height: 8.h),
        _buildCard(children: [
          _buildTile(
            icon: Icons.manage_accounts_outlined,
            iconColor: Colors.blue[400]!,
            iconBg: Colors.blue[50]!,
            title: 'Edit Profile',
            onTap: () => setState(() => _editMode = true),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.shield_outlined,
            iconColor: Colors.green[500]!,
            iconBg: Colors.green[50]!,
            title: 'Linked Account & Security',
            onTap: () => _showComingSoon('Linked Account & Security'),
          ),
        ]),
        SizedBox(height: 20.h),
        _buildSectionLabel('More'),
        SizedBox(height: 8.h),
        _buildCard(children: [
          _buildTile(
            icon: Icons.help_outline_rounded,
            iconColor: Colors.orange[400]!,
            iconBg: Colors.orange[50]!,
            title: 'Help & Support',
            onTap: () => _showComingSoon('Help & Support'),
          ),
          _buildDivider(),
          _buildTile(
            icon: Icons.logout_rounded,
            iconColor: Colors.red[400]!,
            iconBg: Colors.red[50]!,
            title: 'Log out',
            titleColor: Colors.red[400],
            onTap: _confirmLogout,
          ),
        ]),
        SizedBox(height: 40.h),
      ],
    );
  }

  // ── Edit form ────────────────────────────────────────────────────────────────
  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        _buildSectionLabel('Personal Info'),
        SizedBox(height: 12.h),
        _buildField('Full Name', _nameCtrl, Icons.person_outline),
        SizedBox(height: 12.h),
        _buildField('Phone Number', _phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
        if (_user.currentBusinessName.isNotEmpty) ...[
          SizedBox(height: 20.h),
          _buildSectionLabel('Business Info'),
          SizedBox(height: 12.h),
          _buildField('Business Name', _bizNameCtrl, Icons.store_outlined),
        ],
        SizedBox(height: 28.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => setState(() => _editMode = false),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  elevation: 0,
                ),
                child: _saving
                    ? SizedBox(width: 18.w, height: 18.h, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.smallTextSize.sp)),
              ),
            ),
          ],
        ),
        SizedBox(height: 40.h),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10.r)),
        child: Icon(icon, color: iconColor, size: 18.sp),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppTheme.smallTextSize.sp,
          fontWeight: FontWeight.w600,
          color: titleColor ?? Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]))
          : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20.sp),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 68.w, endIndent: 16.w, color: Colors.grey[100]);
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        SizedBox(height: 6.h),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18.sp, color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon'), duration: const Duration(seconds: 2)),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); _logout(); },
            child: Text('Log out', style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
