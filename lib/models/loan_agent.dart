import 'package:seed/models/loan_product.dart';

class LoanAgent {
  final String userId;
  final String agentName;
  final String bankAffiliated;
  final int yearsExperience;
  final String biodata;
  final String whatsappNumber;
  final List<LoanProduct> products;

  const LoanAgent({
    required this.userId,
    required this.agentName,
    required this.bankAffiliated,
    required this.yearsExperience,
    required this.biodata,
    required this.whatsappNumber,
    required this.products,
  });

  factory LoanAgent.fromMap(Map<String, dynamic> map) {
    final rawProducts = map['loan_agent_products'] as List<dynamic>? ?? [];
    return LoanAgent(
      userId: map['user_id'] as String,
      agentName: map['agent_name'] as String,
      bankAffiliated: map['bank_affiliated'] as String,
      yearsExperience: map['years_experience'] as int,
      biodata: map['biodata'] as String? ?? '',
      whatsappNumber: map['whatsapp_number'] as String,
      products: rawProducts
          .map((p) => LoanProduct.fromMap(p as Map<String, dynamic>))
          .toList(),
    );
  }

  String get initials {
    final parts = agentName.replaceAll(RegExp(r'^(Mr|Ms|Mrs|Dr)\.?\s*'), '').trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
