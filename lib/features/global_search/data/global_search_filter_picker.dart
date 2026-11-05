import 'package:flutter/material.dart';

import '../../../core/services/active_company_session.dart';
import '../../../core/services/sign_api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../company/data/remote_company_repository.dart';
import 'remote_global_search_provider.dart';

class _SelectedFilters {
  const _SelectedFilters(this.filters, this.companyId);
  final GlobalSearchFilters filters;
  final String companyId;
}

/// Existing Switch Company sheet for all six search filters. No new UI skin.
abstract final class GlobalSearchFilterPicker {
  static Future<GlobalSearchFilters?> show(BuildContext context,
      GlobalSearchFilters current) async {
    final active = ActiveCompanySession.companyId;
    if (active == null) {
      throw const SignApiException('Select a company first.');
    }
    final companies = await RemoteCompanyRepository.shared.list();
    if (!context.mounted) return null;
    final validIds = companies.map((e) => e.id).toSet();
    final selectedId = ActiveCompanySession.companyId.toString();
    if (!validIds.contains(selectedId)) {
      throw const SignApiException('Active company is not accessible.');
    }
    final client = TextEditingController(text: current.clientId ?? '');
    final job = TextEditingController(text: current.jobId ?? '');
    final kind = TextEditingController(text: current.documentType ?? '');
    final from = TextEditingController(text: current.dateFrom ?? '');
    final to = TextEditingController(text: current.dateTo ?? '');
    final status = TextEditingController(text: current.status ?? '');
    try {
      var companyId = selectedId;
      final selected = await Sign2DigitalSelectionSheet.showCustom<_SelectedFilters>(
        context: context, title: 'Global Search Filters',
        icon: Icons.tune_rounded,
        subtitle: 'Search only accessible company records',
        builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
          Widget field(TextEditingController controller, String label,
              {bool numeric = false}) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(controller: controller,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(labelText: label,
                border: const OutlineInputBorder()),
              style: const TextStyle(fontFamily: 'Inter',
                fontSize: 14, color: AppColors.dark)),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<String>(
                initialValue: companyId,
                decoration: const InputDecoration(
                  labelText: 'Company', border: OutlineInputBorder()),
                items: [for (final company in companies)
                  DropdownMenuItem(value: company.id,
                    child: Text(company.companyName))],
                onChanged: (value) {
                  if (value != null) update(() => companyId = value);
                },
              ),
              const SizedBox(height: 12),
              field(client, 'Client ID', numeric: true),
              field(job, 'Job ID', numeric: true),
              field(kind, 'Document type'),
              field(from, 'From date (YYYY-MM-DD)'),
              field(to, 'To date (YYYY-MM-DD)'),
              field(status, 'Status'),
              Row(children: [
                TextButton(
                  onPressed: () => Navigator.of(sheet).pop(
                    _SelectedFilters(const GlobalSearchFilters(), companyId)),
                  child: const Text('Clear filters')),
                const Spacer(),
                FilledButton(onPressed: () => Navigator.of(sheet).pop(
                  _SelectedFilters(GlobalSearchFilters(
                    clientId: client.text.trim(), jobId: job.text.trim(),
                    documentType: kind.text.trim().toLowerCase(),
                    dateFrom: from.text.trim(), dateTo: to.text.trim(),
                    status: status.text.trim().toLowerCase(),
                  ), companyId)), child: const Text('Apply filters')),
              ]),
            ]),
          );
        }),
      );
      if (!context.mounted || selected == null) return null;
      final f = selected.filters;
      for (final value in [f.clientId, f.jobId]) {
        if (value != null && value.isNotEmpty &&
            (int.tryParse(value) == null || int.parse(value) <= 0)) {
          throw const SignApiException('Client and Job IDs must be positive numbers.');
        }
      }
      final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      for (final date in [f.dateFrom, f.dateTo]) {
        if (date != null && date.isNotEmpty &&
            (!pattern.hasMatch(date) || DateTime.tryParse(date) == null)) {
          throw const SignApiException('Use YYYY-MM-DD dates.');
        }
      }
      if ((f.dateFrom?.isNotEmpty ?? false) &&
          (f.dateTo?.isNotEmpty ?? false) &&
          f.dateFrom!.compareTo(f.dateTo!) > 0) {
        throw const SignApiException('End date cannot precede start date.');
      }
      if (selected.companyId != ActiveCompanySession.companyId.toString()) {
        await RemoteCompanyRepository.shared.switchTo(selected.companyId);
      }
      return f;
    } finally {
      client.dispose(); job.dispose(); kind.dispose();
      from.dispose(); to.dispose(); status.dispose();
    }
  }
}
