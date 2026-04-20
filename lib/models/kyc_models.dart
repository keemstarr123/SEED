class CheckResult {
  final String result; // 'pass' | 'fail' | 'uncertain'
  final int scoreContribution; // 1-5
  final String reasoning;
  final List<String> redFlags;
  final Map<String, dynamic> findings;

  const CheckResult({
    required this.result,
    required this.scoreContribution,
    required this.reasoning,
    required this.redFlags,
    required this.findings,
  });
}

class KYCResult {
  final int finalScore;
  final CheckResult ssmCheck;
  final CheckResult icCheck;
  final List<String> allRedFlags;

  const KYCResult({
    required this.finalScore,
    required this.ssmCheck,
    required this.icCheck,
    required this.allRedFlags,
  });
}

class VerificationStatus {
  final String status; // 'approved' | 'pending_review' | 'rejected'
  final int score;
  final String reasoning;

  const VerificationStatus({
    required this.status,
    required this.score,
    required this.reasoning,
  });
}
