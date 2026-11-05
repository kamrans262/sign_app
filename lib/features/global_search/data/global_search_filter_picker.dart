import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../company/data/remote_company_repository.dart';
import 'global_search_source.dart';
import 'remote_global_search_provider.dart';

class _SelectedFilters {
  const _SelectedFilters(this.filters, this.companyId);
  final GlobalSearchFilters filters;
  final String companyId;
}

class _RecordChoice {
  const _RecordChoice(this.id, this.label);
  final String id, label;
}

/// Searches server-side and pages results. Does not preload a whole customer
/// or job database into an unbounded in-memory dropdown.
class _SearchRecordPicker extends StatefulWidget {
  const _SearchRecordPicker({required this.type});
  final GlobalSearchTab type;

  @override
  State<_SearchRecordPicker> createState() => _SearchRecordPickerState();
}

class _SearchRecordPickerState extends State<_SearchRecordPicker> {
  final _search = TextEditingController();
  final _remote = RemoteGlobalSearchProvider();
  Timer? _debounce;
  List<GlobalSearchResult> _records = const [];
  int _sequence = 0, _page = 1;
  bool _loading = true, _hasMore = false, _paging = false;
  String? _error;

  bool get _isClient => widget.type == GlobalSearchTab.clients;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    ++_sequence;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _queryChanged(String _) {
    ++_sequence;
    _debounce?.cancel();
    setState(() {
      _loading = true;
      _hasMore = false;
      _records = const [];
    });
    _debounce = Timer(const Duration(milliseconds: 350), _fetch);
  }

  Future<void> _fetch({bool more = false}) async {
    if (more && (_loading || _paging || !_hasMore)) return;
    final request = ++_sequence;
    if (mounted) {
      setState(() {
        if (more) { _paging = true; }
        else { _loading = true; _error = null; }
      });
    }
    try {
      final next = await _remote.search(
        query: _search.text, tab: widget.type,
        page: more ? _page + 1 : 1, perPage: 25);
      if (!mounted || request != _sequence) return;
      setState(() {
        _records = more ? [..._records, ...next.records] : next.records;
        _page = next.page;
        _hasMore = next.hasMore;
        _loading = false;
        _paging = false;
      });
    } catch (_) {
      if (!mounted || request != _sequence) return;
      setState(() {
        _loading = false;
        _paging = false;
        _error = 'Could not load records';
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: Key(_isClient ? 'search-client-picker' : 'search-job-picker'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
    children: [
      TextField(
        key: const Key('search-filter-record-query'),
        controller: _search,
        maxLength: 120,
        onChanged: _queryChanged,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
          color: AppColors.dark),
        decoration: InputDecoration(
          hintText: _isClient ? 'Find client by name' : 'Find job by title',
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          border: const OutlineInputBorder(),
          counterText: '',
        ),
      ),
      ListTile(
        title: Text(_isClient ? 'All clients' : 'All jobs'),
        onTap: () => Navigator.of(context).pop(
          _RecordChoice('', _isClient ? 'All clients' : 'All jobs')),
      ),
      if (_loading)
        const Padding(padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()))
      else if (_error != null)
        TextButton(onPressed: _fetch, child: Text('$_error. Retry'))
      else if (_records.isEmpty)
        const Padding(padding: EdgeInsets.all(24),
          child: Center(child: Text('No matching records')))
      else
        for (final record in _records)
          ListTile(
            key: Key('search-filter-option-${record.id}'),
            title: Text(record.title, maxLines: 1,
              overflow: TextOverflow.ellipsis),
            subtitle: Text(record.details, maxLines: 1,
              overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.of(context).pop(
              _RecordChoice(record.id, record.title)),
          ),
      if (_hasMore)
        TextButton(
          onPressed: _paging ? null : () => _fetch(more: true),
          child: Text(_paging ? 'Loading…' : 'Load more'),
        ),
    ],
  );
}

/// The existing unified Switch Company bottom-sheet chrome is reused.
/// Client/Job selectors are server-searched, permission checked, and paged;
/// no manual numeric IDs are required by ordinary users.
abstract final class GlobalSearchFilterPicker {
  static const documentTypes = [
    '', 'contacts', 'reports', 'receipts', 'invoices', 'other',
    'letter', 'statement', 'power_of_attorney', 'acceptance',
    'custom', 'site_report', 'meeting_minutes',
  ];

  static const statuses = [
    '', 'draft', 'planning', 'in_progress', 'completed', 'overdue',
    'archived', 'approved', 'reviewed', 'sent', 'signed', 'file',
    'active', 'available', 'in_use', 'maintenance', 'pending',
    'partially_paid', 'paid', 'received', 'refunded', 'void',
    'to_review', 'reimbursed',
  ];

  static bool validDay(String date) {
    if (date.isEmpty) return true;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return false;
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return false;
    return '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}' == date;
  }

  static Future<GlobalSearchFilters?> show(
      BuildContext context, GlobalSearchFilters current) async {
    final active = ActiveCompanySession.companyId;
    if (active == null) {
      throw const SignApiException('Select a company first.');
    }
    final companies = await RemoteCompanyRepository.shared.list();
    if (!context.mounted || ActiveCompanySession.companyId != active) return null;
    final selectedId = '$active';
    if (!companies.any((company) => company.id == selectedId)) {
      throw const SignApiException('Active company is not accessible.');
    }
    var companyId = selectedId;
    var clientId = current.clientId ?? '';
    var jobId = current.jobId ?? '';
    var clientLabel = clientId.isEmpty ? 'All clients' : 'Client #$clientId';
    var jobLabel = jobId.isEmpty ? 'All jobs' : 'Job #$jobId';
    var kind = current.documentType ?? '';
    var status = current.status ?? '';
    var from = current.dateFrom ?? '';
    var to = current.dateTo ?? '';
    final selected = await Sign2DigitalSelectionSheet.showCustom<_SelectedFilters>(
        context: context,
        title: 'Global Search Filters',
        icon: Icons.tune_rounded,
        subtitle: 'Choose available records in your company',
        builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
          Future<void> chooseRecord(GlobalSearchTab tab) async {
            if (companyId != selectedId) return;
            final choice = await Sign2DigitalSelectionSheet.showCustom<_RecordChoice>(
              context: sheet,
              title: tab == GlobalSearchTab.clients ? 'Client' : 'Job',
              icon: tab == GlobalSearchTab.clients
                ? Icons.people_outline : Icons.work_outline,
              subtitle: 'Search existing company records',
              builder: (_) => _SearchRecordPicker(type: tab),
            );
            if (!sheet.mounted || choice == null) return;
            update(() {
              if (tab == GlobalSearchTab.clients) {
                clientId = choice.id;
                clientLabel = choice.label;
              } else {
                jobId = choice.id;
                jobLabel = choice.label;
              }
            });
          }

          Widget dateField(String initial, ValueChanged<String> changed, String label) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                initialValue: initial,
                onChanged: changed,
                key: Key(label == 'From date' ? 'search-date-from' : 'search-date-to'),
                keyboardType: TextInputType.datetime,
                style: const TextStyle(fontFamily: 'Inter',
                  fontSize: 14, color: AppColors.dark),
                decoration: InputDecoration(
                  labelText: '$label (YYYY-MM-DD)',
                  border: const OutlineInputBorder()),
              ),
            );

          Widget choiceField(String label, String value, VoidCallback? select,
              IconData icon) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: AppColors.primary),
            title: Text(label, style: const TextStyle(
              fontFamily: 'Inter', fontSize: 14)),
            subtitle: Text(value, maxLines: 1,
              overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.keyboard_arrow_down_rounded),
            onTap: select,
          );

          return ListView(
            key: const Key('global-search-filter-sheet'),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              DropdownButtonFormField<String>(
                key: const Key('search-filter-company'),
                initialValue: companyId,
                decoration: const InputDecoration(
                  labelText: 'Company', border: OutlineInputBorder()),
                isExpanded: true,
                items: [for (final company in companies)
                  DropdownMenuItem(value: company.id,
                    child: Text(company.companyName, overflow: TextOverflow.ellipsis))],
                onChanged: (value) {
                  if (value != null) update(() {
                    companyId = value;
                    clientId = '';
                    jobId = '';
                    clientLabel = 'All clients';
                    jobLabel = 'All jobs';
                  });
                },
              ),
              const SizedBox(height: 8),
              if (companyId != selectedId)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Apply the company switch, then reopen filters '
                    'to choose its clients or jobs.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                      color: AppColors.placeholder))),
              choiceField('Client', clientLabel,
                companyId == selectedId
                  ? () => chooseRecord(GlobalSearchTab.clients) : null,
                Icons.people_outline),
              choiceField('Job', jobLabel,
                companyId == selectedId
                  ? () => chooseRecord(GlobalSearchTab.jobs) : null,
                Icons.work_outline),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('search-filter-document-type'),
                initialValue: kind,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Document type', border: OutlineInputBorder()),
                items: [for (final value in documentTypes)
                  DropdownMenuItem(value: value,
                    child: Text(value.isEmpty ? 'All document types'
                      : value.replaceAll('_', ' ')))],
                onChanged: (value) => update(() => kind = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('search-filter-status'),
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status', border: OutlineInputBorder()),
                items: [for (final value in statuses)
                  DropdownMenuItem(value: value,
                    child: Text(value.isEmpty ? 'All statuses'
                      : value.replaceAll('_', ' ')))],
                onChanged: (value) => update(() => status = value ?? ''),
              ),
              const SizedBox(height: 12),
              dateField(from, (value) => from = value, 'From date'),
              dateField(to, (value) => to = value, 'To date'),
              Row(children: [
                TextButton(
                  key: const Key('search-clear-filters'),
                  onPressed: () => Navigator.of(sheet).pop(
                    _SelectedFilters(const GlobalSearchFilters(), companyId)),
                  child: const Text('Clear filters')),
                const Spacer(),
                FilledButton(
                  key: const Key('search-apply-filters'),
                  onPressed: () => Navigator.of(sheet).pop(
                    _SelectedFilters(GlobalSearchFilters(
                      clientId: clientId, jobId: jobId,
                      documentType: kind, status: status,
                      dateFrom: from.trim(), dateTo: to.trim(),
                    ), companyId)),
                  child: const Text('Apply filters')),
              ]),
            ],
          );
        }),
      );
      if (!context.mounted || selected == null) return null;
      final filters = selected.filters;
      if (!validDay(filters.dateFrom ?? '') ||
          !validDay(filters.dateTo ?? '') ||
          ((filters.dateFrom?.isNotEmpty ?? false) &&
           (filters.dateTo?.isNotEmpty ?? false) &&
           filters.dateFrom!.compareTo(filters.dateTo!) > 0)) {
        throw const SignApiException('Invalid date range.');
      }
      if (selected.companyId != selectedId) {
        await RemoteCompanyRepository.shared.switchTo(selected.companyId);
        // Never reuse the previous company's Client/Job selections.
        return const GlobalSearchFilters();
      }
      if (ActiveCompanySession.companyId != active) {
        throw const SignApiException('Company changed during filter selection.');
      }
      return filters;
  }
}
