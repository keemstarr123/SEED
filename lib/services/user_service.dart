import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Personal info
  String? currentUserId;
  String currentOwnerName = '';
  String currentEmail = '';
  String currentPhone = '';

  // Business info
  String? currentOwnerId; // same as currentUserId — kept for compat
  String currentBusinessName = '';
  String currentBusinessType = '';
  String? triggerWord;

  // KYC status
  bool verifiedStatus = false;
  String kycStatus = 'pending'; // 'approved' | 'pending_review' | 'rejected'

  bool get isLoaded => currentUserId != null;

  Future<void> initUser() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final userId = session.user.id;
      currentUserId = userId;
      currentOwnerId = userId;

      // Load personal info
      final userRes = await supabase
          .from('users')
          .select('name, email, phone_number, verified_status, status')
          .eq('id', userId)
          .maybeSingle();

      if (userRes != null) {
        currentOwnerName = userRes['name'] ?? '';
        currentEmail = userRes['email'] ?? '';
        currentPhone = userRes['phone_number'] ?? '';
        verifiedStatus = userRes['verified_status'] ?? false;
        kycStatus = userRes['status'] ?? 'pending';
      }

      // Load business info
      final bizRes = await supabase
          .from('microbusiness_owners')
          .select('business_name, type, trigger_word')
          .eq('user_id', userId)
          .maybeSingle();

      if (bizRes != null) {
        currentBusinessName = bizRes['business_name'] ?? '';
        currentBusinessType = bizRes['type'] ?? '';
        triggerWord = bizRes['trigger_word'];
      }
    } catch (e) {
      debugPrint('UserService.initUser error: $e');
    }
  }

  void clear() {
    currentUserId = null;
    currentOwnerId = null;
    currentOwnerName = '';
    currentEmail = '';
    currentPhone = '';
    currentBusinessName = '';
    currentBusinessType = '';
    triggerWord = null;
    verifiedStatus = false;
    kycStatus = 'pending';
  }
}
