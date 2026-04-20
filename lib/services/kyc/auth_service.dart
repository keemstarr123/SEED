import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<String?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response.user?.id;
    } on AuthApiException catch (e) {
      // Email rate limit hit — account was created but confirmation email failed.
      // Check if the user is now in session anyway.
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) return userId;
      // Re-throw only if we genuinely have no user
      throw Exception(e.message);
    }
  }
}
