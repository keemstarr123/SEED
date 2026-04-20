import 'package:supabase_flutter/supabase_flutter.dart';

class KYCUserService {
  final _supabase = Supabase.instance.client;

  Future<void> savePersonalInfo({
    required String userId,
    required String fullName,
    required String icNumber,
    required String phoneNumber,
    required String email,
  }) async {
    await _supabase.from('users').upsert({
      'id': userId,
      'name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'ic_number': icNumber,
      'verified_status': false,
      'status': 'pending',
      'password_hash': 'supabase_auth',
    });
  }

  Future<void> saveBusinessInfo({
    required String userId,
    required String businessName,
    required String ssmNumber,
    required String businessType,
    required String businessAddress,
    required int yearEstablished,
    required String phoneNumber,
  }) async {
    await _supabase.from('microbusiness_owners').upsert(
      {
        'user_id': userId,
        'business_name': businessName,
        'ssm_registration_number': ssmNumber,
        'type': businessType,
        'business_address': businessAddress,
        'year_of_establishment': yearEstablished,
        'contact_number': phoneNumber,
      },
      onConflict: 'ssm_registration_number',
    );
  }
}
