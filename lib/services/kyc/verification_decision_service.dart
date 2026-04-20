import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/models/kyc_models.dart';
import 'package:seed/services/kyc/storage_service.dart';

class VerificationDecisionService {
  final _supabase = Supabase.instance.client;
  final _storage = StorageService();

  Future<VerificationStatus> processKYCResult({
    required String userId,
    required KYCResult result,
    required String ssmDocUrl,
  }) async {
    final status = result.finalScore >= 4
        ? 'approved'
        : result.finalScore == 3
            ? 'pending_review'
            : 'rejected';

    // Save verification request with full AI metadata
    final verificationRes = await _supabase
        .from('verification_requests')
        .insert({
          'microbusiness_id': userId,
          'type': 'microbusiness',
          'verification_status': status == 'approved',
          'rejection_reason':
              status == 'rejected' ? result.ssmCheck.reasoning : null,
          'request_date': DateTime.now().toIso8601String(),
          'last_update': DateTime.now().toIso8601String(),
          'metadata': {
            'final_score': result.finalScore,
            'ssm_check': {
              'result': result.ssmCheck.result,
              'score': result.ssmCheck.scoreContribution,
              'reasoning': result.ssmCheck.reasoning,
              'red_flags': result.ssmCheck.redFlags,
              'findings': result.ssmCheck.findings,
            },
            'ic_check': {
              'result': result.icCheck.result,
              'score': result.icCheck.scoreContribution,
              'reasoning': result.icCheck.reasoning,
              'red_flags': result.icCheck.redFlags,
              'findings': result.icCheck.findings,
            },
            'all_red_flags': result.allRedFlags,
          },
        })
        .select()
        .single();

    final verificationId = verificationRes['id'];

    // Save document URLs
    await _supabase.from('verification_documents').insert([
      {
        'verification_id': verificationId,
        'file_url': ssmDocUrl,
        'file_name': 'ssm_certificate',
        'file_type': 'ssm',
      },
    ]);

    // Update user verified_status and status
    await _supabase.from('users').update({
      'verified_status': status == 'approved',
      'status': status,
    }).eq('id', userId);

    // Delete IC from storage — PDPA compliance
    await _storage.deleteICAfterVerification(userId: userId);

    return VerificationStatus(
      status: status,
      score: result.finalScore,
      reasoning: [
        result.ssmCheck.reasoning,
        result.icCheck.reasoning,
      ].where((s) => s.isNotEmpty).join(' '),
    );
  }
}
