class LoanRequest {
  final String id;
  final String agentId;
  final String microbusinessId;
  final String messageTemplate;
  final DateTime createdAt;

  const LoanRequest({
    required this.id,
    required this.agentId,
    required this.microbusinessId,
    required this.messageTemplate,
    required this.createdAt,
  });

  factory LoanRequest.fromMap(Map<String, dynamic> map) {
    return LoanRequest(
      id: map['id'] as String,
      agentId: map['agent_id'] as String,
      microbusinessId: map['microbusiness_id'] as String,
      messageTemplate: map['message_template'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
