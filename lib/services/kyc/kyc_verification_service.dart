import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:seed/models/kyc_models.dart';

class KYCVerificationService {
  GenerativeModel get _model => GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview',
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.0,
        ),
      );

  // ── CHECK 1 — SSM Document ─────────────────────────────────────────────────
  Future<CheckResult> checkSSMDocument({
    required Uint8List ssmBytes,
    required String mimeType,
    required String ssmNumber,
    required String businessName,
    required String businessType,
  }) async {
    final prompt = '''
You are a Malaysian business document verification AI.
You are given 1 image: an SSM Business Registration Certificate.

User declared:
- SSM registration number: $ssmNumber
- Business name: $businessName
- Business type: $businessType

Perform these checks:
1. Does this look like a genuine Malaysian SSM certificate?
2. Does the SSM number on the document match: $ssmNumber?
3. Does the business name on the document match: $businessName?
4. Is the document free from tampering or editing?
5. Is the document still valid (not expired)?

Respond ONLY in this exact JSON format, no other text:
{
  "result": "pass",
  "score_contribution": 4,
  "findings": {
    "is_genuine_ssm": true,
    "ssm_number_matches": true,
    "business_name_matches": true,
    "no_tampering_detected": true,
    "is_valid": true
  },
  "reasoning": "The document appears genuine and all details match.",
  "red_flags": []
}
''';

    final response = await _model.generateContent([
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, ssmBytes),
      ]),
    ]);

    return _parseCheckResult(response.text ?? '');
  }

  // ── CHECK 2 — IC Verification ──────────────────────────────────────────────
  Future<CheckResult> checkICDocument({
    required Uint8List icBytes,
    required String fullName,
    required String icNumber,
  }) async {
    final prompt = '''
You are a Malaysian identity document verification AI.
You are given 1 image: a Malaysian IC (MyKad).

User declared:
- Full name: $fullName
- IC number: $icNumber

Perform these checks:
1. Does this look like a genuine Malaysian MyKad?
2. Does the name on the IC match: $fullName? (Allow minor formatting differences e.g. ALL CAPS vs mixed case)
3. Does the IC number match: $icNumber?
4. Is the IC free from signs of tampering or editing?
5. Is the IC not expired?

Respond ONLY in this exact JSON format, no other text:
{
  "result": "pass",
  "score_contribution": 4,
  "findings": {
    "is_genuine_mykad": true,
    "name_matches": true,
    "ic_number_matches": true,
    "no_tampering_detected": true,
    "is_valid": true
  },
  "reasoning": "The MyKad appears genuine and all details match.",
  "red_flags": []
}
''';

    final response = await _model.generateContent([
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', icBytes),
      ]),
    ]);

    return _parseCheckResult(response.text ?? '');
  }

  // ── MIME type helper ──────────────────────────────────────────────────────
  String _mimeType(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }

  // ── Run 2 checks in parallel ───────────────────────────────────────────────
  Future<KYCResult> verifyDocuments({
    required String fullName,
    required String icNumber,
    required String ssmNumber,
    required String businessName,
    required String businessType,
    required File icPhoto,
    required File ssmDocument,
  }) async {
    final icBytes = await icPhoto.readAsBytes();
    final ssmBytes = await ssmDocument.readAsBytes();

    final results = await Future.wait([
      checkSSMDocument(
        ssmBytes: ssmBytes,
        mimeType: _mimeType(ssmDocument),
        ssmNumber: ssmNumber,
        businessName: businessName,
        businessType: businessType,
      ),
      checkICDocument(
        icBytes: icBytes,
        fullName: fullName,
        icNumber: icNumber,
      ),
    ]);

    final ssmResult = results[0];
    final icResult = results[1];

    // Weighted: SSM 50%, IC 50%
    final weightedScore = ((ssmResult.scoreContribution * 0.5) +
            (icResult.scoreContribution * 0.5))
        .round()
        .clamp(1, 5);

    // Hard fail: if any check scores 1, cap at 2
    final anyHardFail = results.any((r) => r.scoreContribution == 1);
    final finalScore = anyHardFail ? weightedScore.clamp(1, 2) : weightedScore;

    return KYCResult(
      finalScore: finalScore,
      ssmCheck: ssmResult,
      icCheck: icResult,
      allRedFlags: [
        ...ssmResult.redFlags,
        ...icResult.redFlags,
      ],
    );
  }

  // ── Defensive JSON parser ──────────────────────────────────────────────────
  // Defaults to uncertain/score 3 if Gemini fails — never auto-reject on AI error
  CheckResult _parseCheckResult(String rawJson) {
    try {
      final cleaned = rawJson
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return CheckResult(
        result: parsed['result'] as String? ?? 'uncertain',
        scoreContribution: (parsed['score_contribution'] as num?)?.toInt() ?? 3,
        reasoning: parsed['reasoning'] as String? ?? '',
        redFlags: List<String>.from(parsed['red_flags'] as List? ?? []),
        findings:
            Map<String, dynamic>.from(parsed['findings'] as Map? ?? {}),
      );
    } catch (_) {
      return const CheckResult(
        result: 'uncertain',
        scoreContribution: 3,
        reasoning: 'Unable to parse AI response',
        redFlags: ['AI response parsing failed'],
        findings: {},
      );
    }
  }
}
