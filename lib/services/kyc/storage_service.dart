import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final _supabase = Supabase.instance.client;

  Future<String> uploadDocument({
    required File file,
    required String userId,
    required String docType,
  }) async {
    final fileExt = file.path.split('.').last;
    final fileName = '$userId/$docType.$fileExt';

    await _supabase.storage.from('kyc-documents').upload(
          fileName,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    // Signed URL valid 5 minutes for Gemini to read
    final signedUrl = await _supabase.storage
        .from('kyc-documents')
        .createSignedUrl(fileName, 300);

    return signedUrl;
  }

  /// Delete IC after verification — PDPA compliance
  Future<void> deleteICAfterVerification({required String userId}) async {
    try {
      final list =
          await _supabase.storage.from('kyc-documents').list(path: userId);
      final icFiles = list
          .where((f) => f.name.startsWith('ic'))
          .map((f) => '$userId/${f.name}')
          .toList();
      if (icFiles.isNotEmpty) {
        await _supabase.storage.from('kyc-documents').remove(icFiles);
      }
    } catch (_) {
      // Best-effort deletion — don't fail the whole flow
    }
  }
}
