import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seed/models/loan_agent.dart';
import 'package:seed/models/loan_request.dart';

class LoanRepository {
  final _supabase = Supabase.instance.client;

  Future<List<LoanAgent>> fetchVerifiedAgents() async {
    // Fetch agents
    final agentsData = await _supabase.from('loan_agents').select(
        'user_id, agent_name, bank_affiliated, years_experience, biodata, whatsapp_number');
    debugPrint('[LoanRepo] raw agents: ${(agentsData as List).length}');

    // Fetch products (without nested loan_services to avoid FK issues)
    final productsData = await _supabase
        .from('loan_agent_products')
        .select('id, agent_id, services_id, eligibility');
    debugPrint('[LoanRepo] raw products: ${(productsData as List).length}');

    // Fetch all loan services
    final servicesData =
        await _supabase.from('loan_services').select('id, title, description');
    debugPrint('[LoanRepo] raw services: ${(servicesData as List).length}');

    // Build service map
    final serviceMap = {
      for (final s in (servicesData as List))
        s['id'] as String: s as Map<String, dynamic>
    };

    // Build products per agent
    final productsByAgent = <String, List<Map<String, dynamic>>>{};
    for (final p in (productsData as List)) {
      final agentId = p['agent_id'] as String;
      final serviceId = p['services_id'] as String?;
      final service = serviceId != null
          ? serviceMap[serviceId]
          : {'id': '', 'title': 'Unknown', 'description': ''};
      productsByAgent.putIfAbsent(agentId, () => []).add({
        'id': p['id'],
        'eligibility': p['eligibility'],
        'loan_services': service,
      });
    }

    // Fetch verified agent IDs
    final verified = await _supabase
        .from('verification_requests')
        .select('agent_id')
        .eq('verification_status', true);
    final verifiedIds =
        (verified as List).map((v) => v['agent_id'] as String).toSet();
    debugPrint('[LoanRepo] verifiedIds: $verifiedIds');

    final agents = <LoanAgent>[];
    for (final a in (agentsData)) {
      final userId = a['user_id'] as String;
      // Skip verification filter if no records exist
      if (verifiedIds.isNotEmpty && !verifiedIds.contains(userId)) continue;
      try {
        final agentMap = Map<String, dynamic>.from(a);
        agentMap['loan_agent_products'] = productsByAgent[userId] ?? [];
        agents.add(LoanAgent.fromMap(agentMap));
      } catch (err) {
        debugPrint('[LoanRepo] fromMap error for $userId: $err');
      }
    }

    debugPrint('[LoanRepo] final agents: ${agents.length}');
    return agents;
  }

  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    return await _supabase.from('users').select('*').eq('id', userId).single();
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await _supabase.from('users').update(data).eq('id', userId);
  }

  Future<Map<String, dynamic>> fetchBusinessProfile(String userId) async {
    return await _supabase
        .from('microbusiness_owners')
        .select('*')
        .eq('user_id', userId)
        .single();
  }

  Future<void> updateBusinessProfile(String userId, Map<String, dynamic> data) async {
    await _supabase
        .from('microbusiness_owners')
        .update(data)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> fetchMonthlySales(String businessId) async {
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    final data = await _supabase
        .from('orders')
        .select('created_at, total_amount')
        .eq('business_id', businessId)
        .eq('transaction_status', 'completed')
        .gte('created_at', sixMonthsAgo.toIso8601String());

    // Group by month in Dart
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final row in (data as List)) {
      final dt = DateTime.parse(row['created_at'] as String);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => {'month': key, 'total_orders': 0, 'revenue': 0.0, 'amounts': <double>[]});
      grouped[key]!['total_orders'] = (grouped[key]!['total_orders'] as int) + 1;
      final amount = (row['total_amount'] as num).toDouble();
      grouped[key]!['revenue'] = (grouped[key]!['revenue'] as double) + amount;
      (grouped[key]!['amounts'] as List<double>).add(amount);
    }

    return grouped.values.map((m) {
      final amounts = m['amounts'] as List<double>;
      return {
        'month': m['month'],
        'total_orders': m['total_orders'],
        'revenue': m['revenue'],
        'avg_order_value': amounts.isEmpty ? 0.0 : (m['revenue'] as double) / amounts.length,
      };
    }).toList()
      ..sort((a, b) => (b['month'] as String).compareTo(a['month'] as String));
  }

  Future<List<Map<String, dynamic>>> fetchEInvoices(String businessId) async {
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    final data = await _supabase
        .from('orders')
        .select(
          'id, created_at, total_amount, transaction_status, '
          'order_details(quantity, amount, product:products(name, unit_price))',
        )
        .eq('business_id', businessId)
        .gte('created_at', threeMonthsAgo.toIso8601String())
        .order('created_at', ascending: false);

    return (data as List).map((row) {
      final rawDetails = row['order_details'] as List? ?? [];
      final items = rawDetails.map((d) {
        final qty = (d['quantity'] as num?)?.toInt() ?? 1;
        final product = d['product'] as Map?;
        final unitPrice = (product?['unit_price'] as num?)?.toDouble() ?? 0.0;
        final lineTotal = (d['amount'] as num?)?.toDouble() ?? (qty * unitPrice);
        return {
          'name': product?['name'] ?? 'Item',
          'qty': qty,
          'unit_price': unitPrice,
          'subtotal': lineTotal,
        };
      }).toList();
      return {
        'id': row['id'],
        'created_at': row['created_at'],
        'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0.0,
        'transaction_status': row['transaction_status'],
        'items': items,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchActivityLog(String userId) async {
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    final data = await _supabase
        .from('activity_log')
        .select('timestamp, action, resource_type, duration_seconds')
        .eq('user_id', userId)
        .gte('timestamp', threeMonthsAgo.toIso8601String())
        .order('timestamp', ascending: false)
        .limit(100);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<LoanRequest> insertLoanRequest({
    required String agentId,
    required String microbusinessId,
    required String messageTemplate,
  }) async {
    final data = await _supabase
        .from('loan_requests')
        .insert({
          'agent_id': agentId,
          'microbusiness_id': microbusinessId,
          'message_template': messageTemplate,
        })
        .select()
        .single();

    return LoanRequest.fromMap(data);
  }

  Future<void> insertLoanDocument({
    required String loanRequestId,
    required String docType,
    required String fileUrl,
    required int fileSizeKb,
  }) async {
    await _supabase.from('loan_documents').insert({
      'loan_request_id': loanRequestId,
      'doc_type': docType,
      'file_url': fileUrl,
      'status': 'generated',
      'generated_at': DateTime.now().toIso8601String(),
      'file_size_kb': fileSizeKb,
    });
  }

  Future<String> uploadFile({
    required String userId,
    required String loanRequestId,
    required String filename,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = '$userId/$loanRequestId/$filename';
    await _supabase.storage.from('loan-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return _supabase.storage.from('loan-documents').getPublicUrl(path);
  }

  Future<String> getSignedUrl({
    required String userId,
    required String loanRequestId,
    required String filename,
  }) async {
    return await _supabase.storage
        .from('loan-documents')
        .createSignedUrl('$userId/$loanRequestId/$filename', 3600);
  }
}
