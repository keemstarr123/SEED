import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  String currentOwnerName = 'Charlies Coffee';
  String? currentOwnerId;
  String? triggerWord;

  Future<void> initUser() async {
    try {
      final supabase = Supabase.instance.client;
      final ownerRes = await supabase
          .from('microbusiness_owners')
          .select('user_id, trigger_word')
          .eq('business_name', currentOwnerName)
          .maybeSingle();

      if (ownerRes != null) {
        currentOwnerId = ownerRes['user_id'];
        triggerWord = ownerRes['trigger_word'];
      }
    } catch (e) {
      debugPrint('Error fetching user on launch: $e');
    }
  }
}
