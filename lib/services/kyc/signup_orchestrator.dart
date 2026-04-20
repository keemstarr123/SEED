import 'dart:io';
import 'package:seed/models/kyc_models.dart';
import 'package:seed/models/signup_data.dart';
import 'package:seed/services/kyc/auth_service.dart';
import 'package:seed/services/kyc/kyc_user_service.dart';
import 'package:seed/services/kyc/storage_service.dart';
import 'package:seed/services/kyc/kyc_verification_service.dart';
import 'package:seed/services/kyc/verification_decision_service.dart';

class SignupOrchestrator {
  final _auth = AuthService();
  final _user = KYCUserService();
  final _storage = StorageService();
  final _kyc = KYCVerificationService();
  final _decision = VerificationDecisionService();

  // ── STEP 1: Gemini checks only — no Supabase, no account created ──────────
  Future<KYCResult> checkDocuments({
    required SignupData formData,
    required File icPhoto,
    required File ssmDocument,
  }) async {
    return await _kyc.verifyDocuments(
      fullName: formData.fullName,
      icNumber: formData.icNumber,
      ssmNumber: formData.ssmNumber,
      businessName: formData.businessName,
      businessType: formData.businessType,
      icPhoto: icPhoto,
      ssmDocument: ssmDocument,
    );
  }

  // ── STEP 2: User confirmed result — create account + save everything ───────
  Future<VerificationStatus> registerAndSave({
    required SignupData formData,
    required File ssmDocument,
    required KYCResult kycResult,
  }) async {
    final userId = await _auth.registerWithEmail(
      email: formData.email,
      password: formData.password,
    );
    if (userId == null) throw Exception('Registration failed. Please try again.');

    await _user.savePersonalInfo(
      userId: userId,
      fullName: formData.fullName,
      icNumber: formData.icNumber,
      phoneNumber: formData.phoneNumber,
      email: formData.email,
    );
    await _user.saveBusinessInfo(
      userId: userId,
      businessName: formData.businessName,
      ssmNumber: formData.ssmNumber,
      businessType: formData.businessType,
      businessAddress: formData.businessAddress,
      yearEstablished: int.tryParse(formData.yearEstablished) ?? 0,
      phoneNumber: formData.phoneNumber,
    );

    final ssmUrl = await _storage.uploadDocument(
        file: ssmDocument, userId: userId, docType: 'ssm');

    return await _decision.processKYCResult(
      userId: userId,
      result: kycResult,
      ssmDocUrl: ssmUrl,
    );
  }
}
