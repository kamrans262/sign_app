import 'package:crypto/crypto.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../jobs/data/local_job_photo_source.dart';
import '../domain/expense_record.dart';

/// Authenticated tenant-scoped expense records, never demo data.
class RemoteExpenseRepository implements ExpenseRepository {
  RemoteExpenseRepository({SignApiClient? api})
      : _api = api ?? MobileAuthRepository.shared.api;

  static final shared = RemoteExpenseRepository();
  final SignApiClient _api;

  int _company() {
    final value = ActiveCompanySession.companyId;
    if (value == null || value <= 0) {
      throw const SignApiException('Select a company before managing expenses.');
    }
    return value;
  }

  void _assertCompany(int expected) {
    if (ActiveCompanySession.companyId != expected) {
      throw const SignApiException('Company changed during expense request.');
    }
  }

  static int _integer(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map) {
      throw const SignApiException('Invalid expense server data.');
    }
    return Map<String, dynamic>.from(raw);
  }

  static Map<String, dynamic> _data(Map<String, dynamic> response) =>
      _map(response['data']);

  static DateTime _date(Object? raw) {
    final result = DateTime.tryParse('${raw ?? ''}');
    if (result == null) {
      throw const SignApiException('Invalid server expense date.');
    }
    return result;
  }

  static int idOf(ExpenseRecord r) {
    final match = RegExp(r'^expense-([1-9]\d*)$').firstMatch(r.id);
    if (match == null) {
      throw const SignApiException('Invalid expense identifier.');
    }
    return int.parse(match.group(1)!);
  }

  static int _receiptId(String sourceKey) {
    final match = RegExp(r'^remote-receipt-([1-9]\d*)$').firstMatch(sourceKey);
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  ExpenseRecord _record(Object? data, int company, {
    List<LocalJobPhotoSelection> files = const [],
    List<ExpenseHistoryEvent> history = const [],
  }) {
    final row = _map(data);
    final id = _integer(row['id']);
    final job = _integer(row['job_id']);
    final minor = _integer(row['amount_minor']);
    final version = _integer(row['lock_version']);
    final status = switch (row['status']) {
      'to_review' => ExpenseStatus.toReview,
      'approved' => ExpenseStatus.approved,
      'reimbursed' => ExpenseStatus.reimbursed,
      _ => throw const SignApiException('Invalid expense status.'),
    };
    final category = ExpenseCategory.values.where(
      (item) => item.name == row['category'],
    ).firstOrNull;
    if (id <= 0 || job <= 0 ||
        _integer(row['company_id']) != company ||
        minor <= 0 || version <= 0 || category == null ||
        row['currency'] != 'CHF') {
      throw const SignApiException('Invalid or cross-company expense.');
    }
    final tags = row['tags'] is List
        ? (row['tags'] as List).whereType<String>().toList()
        : <String>[];
    return ExpenseRecord(
      id: 'expense-$id',
      category: category,
      title: category.label,
      jobId: '$job',
      job: '${row['job'] ?? ''}',
      report: '',
      amount: minor / 100.0,
      date: _date(row['expense_date']),
      status: status,
      description: '${row['description'] ?? ''}',
      supplier: '${row['supplier'] ?? ''}',
      lockVersion: version,
      demoOnly: false,
      photos: files,
      tags: tags,
      clientName: '${row['client_name'] ?? ''}',
      approvedAt: row['approved_at'] == null
          ? null : _date(row['approved_at']),
      approvedBy: row['approved_by'] == null
          ? null : 'User #${row['approved_by']}',
      updatedAt: _date(row['updated_at']),
      history: history,
      reimbursementRequested: row['reimbursement_requested_at'] != null,
    );
  }

  @override
  Future<List<ExpenseRecord>> listExpenses() async {
    final company = _company();
    final records = <ExpenseRecord>[];
    var page = 1;
    while (true) {
      final response = _data(await _api.get('/api/v1/expenses',
        companyScoped: true,
        queryParameters: {'page': '$page', 'per_page': '100'}));
      _assertCompany(company);
      final raw = response['records'];
      if (raw is! List) {
        throw const SignApiException('Invalid expense listing.');
      }
      records.addAll(raw.map((r) => _record(r, company)));
      if (page >= _integer(response['last_page'])) break;
      if (page >= 100) {
        throw const SignApiException('Expense listing exceeds the supported range.');
      }
      page++;
    }
    return records;
  }

  Future<ExpenseRecord> getExpense(String expenseId) async {
    final match = RegExp(r'^expense-([1-9]\d*)$').firstMatch(expenseId);
    if (match == null) throw const SignApiException('Invalid expense ID.');
    final id = int.parse(match.group(1)!);
    final company = _company();
    final response = _data(await _api.get('/api/v1/expenses/$id',
        companyScoped: true));
    _assertCompany(company);
    final rows = response['receipts'];
    final files = <LocalJobPhotoSelection>[];
    if (rows is! List) {
      throw const SignApiException('Expense receipts response missing.');
    }
    for (final item in rows) {
      final meta = _map(item);
      final receiptId = _integer(meta['id']);
      final mime = '${meta['mime_type'] ?? ''}';
      if (receiptId < 1 || !const [
        'image/jpeg', 'image/png', 'application/pdf',
      ].contains(mime)) {
        throw const SignApiException('Invalid receipt metadata.');
      }
      final bytes = await _api.getPrivateAttachment(
        '/api/v1/expenses/$id/receipts/$receiptId',
        mimeType: mime, maxBytes: 10 * 1024 * 1024);
      if (sha256.convert(bytes).toString() != '${meta['sha256']}' ||
          bytes.length != _integer(meta['byte_size'])) {
        throw const SignApiException('Receipt integrity verification failed.');
      }
      _assertCompany(company);
      files.add(LocalJobPhotoSelection(
        name: '${meta['name'] ?? 'receipt'}',
        bytes: bytes,
        sourceKey: 'remote-receipt-$receiptId',
      ));
    }
    final events = response['history'];
    if (events is! List) {
      throw const SignApiException('Expense history response missing.');
    }
    final history = <ExpenseHistoryEvent>[
      for (final row in events)
        ExpenseHistoryEvent(
          id: '${_map(row)['id']}',
          title: '${_map(row)['type']}'.replaceAll('_', ' '),
          occurredAt: _date(_map(row)['created_at']),
          actorName: _map(row)['actor_id'] == null
              ? null : 'User #${_map(row)['actor_id']}',
        ),
    ];
    return _record(response['expense'], company,
        files: files, history: history);
  }

  static Map<String, dynamic> _fields(ExpenseRecord expense) {
    final jobId = int.tryParse('${expense.jobId}');
    if (jobId == null || jobId < 1 ||
        expense.amount <= 0 || !expense.amount.isFinite ||
        (expense.amount * 100 - (expense.amount * 100).round()).abs() > 0.001) {
      throw const SignApiException('Select a saved job and a valid CHF amount.');
    }
    return {
      'job_id': jobId,
      if (expense.id.startsWith('local-expense-'))
        'request_key': expense.id,
      'category': expense.category.name,
      'supplier': expense.supplier.trim(),
      'description': expense.description.trim(),
      'expense_date': [
        expense.date.year.toString().padLeft(4, '0'),
        expense.date.month.toString().padLeft(2, '0'),
        expense.date.day.toString().padLeft(2, '0'),
      ].join('-'),
      'amount': expense.amount.toStringAsFixed(2),
      'tags': expense.tags,
      if (!expense.id.startsWith('local-expense-'))
        'lock_version': expense.lockVersion,
    };
  }

  @override
  Future<void> saveDraft(ExpenseRecord expense) async {
    final company = _company();
    // Validate all receipt sizes before creating a permanent expense.
    if (expense.photos.length > 10) {
      throw const SignApiException('Maximum 10 receipts per expense.');
    }
    for (final file in expense.photos) {
      _validateReceiptSize(file);
    }
    final response = _data(await _api.post('/api/v1/expenses',
      companyScoped: true, data: _fields(expense)));
    _assertCompany(company);
    final saved = _record(response['expense'], company);
    final createdId = idOf(saved);
    try {
      for (final file in expense.photos) {
        await _upload(createdId, file);
        _assertCompany(company);
      }
    } catch (_) {
      // The expense POST already committed: avoid duplicate records on retry.
      throw SignApiException(
        'Expense #$createdId was saved, but a receipt upload failed. '
        'Open that expense to check or attach receipts; do not create it again.',
      );
    }
  }

  static void _validateReceiptSize(LocalJobPhotoSelection file) {
    if (file.bytes.isEmpty || file.bytes.length > 10 * 1024 * 1024) {
      throw const SignApiException('Receipt must not exceed 10 MB.');
    }
  }

  Future<void> _upload(int id, LocalJobPhotoSelection file) async {
    _validateReceiptSize(file);
    await _api.postMultipart('/api/v1/expenses/$id/receipts',
      filename: file.name, bytes: file.bytes,
      companyScoped: true, maxBytes: 10 * 1024 * 1024);
  }

  @override
  Future<void> updateExpense(ExpenseRecord expense) async {
    final company = _company();
    final id = idOf(expense);
    final original = _data(await _api.get('/api/v1/expenses/$id',
        companyScoped: true));
    _assertCompany(company);
    final current = _record(original['expense'], company);
    if (current.status != ExpenseStatus.toReview ||
        current.lockVersion != expense.lockVersion) {
      throw const SignApiException('Expense changed or is already reviewed.');
    }
    await _api.request('PATCH','/api/v1/expenses/$id',
        companyScoped: true,data: _fields(expense));
    _assertCompany(company);
    final remoteIds = <int>{};
    if (original['receipts'] is List) {
      for (final receipt in (original['receipts'] as List)) {
        remoteIds.add(_integer(_map(receipt)['id']));
      }
    }
    final retained = <int>{};
    for (final file in expense.photos) {
      final receipt = _receiptId(file.sourceKey);
      if (receipt > 0) {
        if (!remoteIds.contains(receipt)) {
          throw const SignApiException('Receipt belongs to another expense.');
        }
        retained.add(receipt);
      } else {
        await _upload(id, file);
      }
      _assertCompany(company);
    }
    for (final receipt in remoteIds.difference(retained)) {
      await _api.delete('/api/v1/expenses/$id/receipts/$receipt',
        companyScoped: true);
      _assertCompany(company);
    }
  }

  Future<ExpenseRecord> requestReimbursement(ExpenseRecord expense) async {
    final company = _company();
    final result = _data(await _api.post(
      '/api/v1/expenses/${idOf(expense)}/request-reimbursement',
      data: {'confirm': true}, companyScoped: true));
    _assertCompany(company);
    final updated = _record(result['expense'], company);
    if (updated.id != expense.id) {
      throw const SignApiException('Reimbursement response ID mismatch.');
    }
    return getExpense(expense.id);
  }

  Future<Map<String, dynamic>> jobTotals(int jobId) async {
    final company = _company();
    if (jobId < 1) throw const SignApiException('Invalid job ID.');
    final result = _data(await _api.get('/api/v1/jobs/$jobId/expense-totals',
      companyScoped: true));
    _assertCompany(company);
    if (_integer(result['job_id']) != jobId ||
        result['currency'] != 'CHF') {
      throw const SignApiException('Invalid job totals response.');
    }
    return result;
  }
}
