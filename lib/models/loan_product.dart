class LoanService {
  final String id;
  final String title;
  final String description;

  const LoanService({
    required this.id,
    required this.title,
    required this.description,
  });

  factory LoanService.fromMap(Map<String, dynamic> map) {
    return LoanService(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
    );
  }
}

class LoanProduct {
  final String id;
  final String eligibility;
  final LoanService service;

  const LoanProduct({
    required this.id,
    required this.eligibility,
    required this.service,
  });

  factory LoanProduct.fromMap(Map<String, dynamic> map) {
    return LoanProduct(
      id: map['id'] as String,
      eligibility: map['eligibility'] as String? ?? '',
      service: LoanService.fromMap(map['loan_services'] as Map<String, dynamic>),
    );
  }
}
