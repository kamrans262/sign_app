import '../../../../core/navigation/sign2digital_navigation.dart';
import '../../../../core/widgets/sign2digital_subscription_gate.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../data/remote_site_report_repository.dart';
import '../../data/remote_document_repository.dart';
import '../../domain/document_record.dart';
import 'document_details_screen.dart';
import 'site_report_wizard_screen.dart';
import 'meeting_minutes_editor_screen.dart';

/// Existing Sign2Digital layout applied to the real report review lifecycle.
/// AI never approves or sends a document on behalf of the professional.
class ReportReviewScreen extends StatefulWidget {
  const ReportReviewScreen({
    super.key,
    required this.report,
    this.repository,
    this.documents,
  });

  final DocumentRecord report;
  final RemoteSiteReportRepository? repository;
  final RemoteDocumentRepository? documents;

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  late DocumentRecord _report;
  late final RemoteSiteReportRepository _repository;
  Map<String, dynamic>? _suggestion;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _repository = widget.repository ?? RemoteSiteReportRepository.shared;
    _reload();
  }

  bool get _isDraft => _report.status.toLowerCase() == 'draft';

  Future<void> _reload() async {
    try {
      final result = await _repository.details(_report.id);
      if (mounted) setState(() => _report = result);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to refresh report: $error');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _editDraft() async {
    if (_busy || !_isDraft) return;
    setState(() { _busy = true; _error = null; });
    DocumentRecord current;
    try {
      current = await _repository.details(_report.id);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to open saved draft: $error');
      }
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final updated = await Sign2DigitalNavigation.push<DocumentRecord>(context,
      MaterialPageRoute(builder: (_) =>
        current.reportKind == ReportKind.meetingMinutes
            ? MeetingMinutesEditorScreen(
                initial: current, reportGenerator: _repository.saveDraft)
            : SiteReportWizardScreen(
                initial: current, reportGenerator: _repository.saveDraft)),
    );
    if (mounted && updated != null) {
      setState(() { _report = updated; _suggestion = null; });
      _notify('Draft saved. Review again before approval.');
    }
  }

  Future<void> _prepare() async {
    if (_busy || !_isDraft) return;
    if (!await _confirm('Prepare AI Draft',
        'Use the saved report details to suggest an editable draft? No report will be approved or sent.')) {
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final suggestion = await _repository.suggestAi(_report);
      if (mounted) {
        setState(() => _suggestion = suggestion);
        _notify('AI suggestion ready. Please review every detail.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'AI preparation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    if (_busy || !_isDraft || _suggestion == null) return;
    if (!await _confirm('Apply Suggested Changes',
        'Save the reviewed AI text to this editable report? This does not approve or send the report.')) {
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _repository.applyAi(_report, _suggestion!);
      if (mounted) {
        setState(() { _report = result; _suggestion = null; });
        _notify('Draft updated. Review again before approval.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to apply AI suggestion: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    if (_busy || !_isDraft) return;
    if (!await _confirm('Approve Report',
        'Freeze this exact revision as a verified PDF in Documents? Approved reports cannot be edited.')) {
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final approved = await _repository.approve(_report);
      if (mounted) {
        setState(() { _report = approved; _suggestion = null; });
        _notify('Approved PDF saved securely in Documents.');
      }
    } catch (error) {
      if (mounted && !await Sign2DigitalSubscriptionGate.handle(
          context, error)) {
        setState(() => _error = 'Unable to approve report: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _isDraft) return;
    if (!await _confirm('Send Report',
        'Send the approved PDF to the email address saved for the linked client?')) {
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final sent = await _repository.send(_report);
      if (mounted) {
        setState(() => _report = sent);
        _notify('Approved report sent to the linked client.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Report was not sent: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    if (_busy || _report.status == 'archived') return;
    if (!await _confirm('Archive Report',
        'Archive this report? The approved PDF and audit history will remain unchanged.')) {
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _repository.archive(_report);
      if (!mounted) return;
      final fresh = await _repository.details(_report.id);
      if (mounted) {
        setState(() { _report = fresh; _suggestion = null; });
        _notify('Report archived. Original documents remain saved.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to archive report: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPdf() async {
    final id = _report.reportManagedDocumentId;
    if (_busy || id == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final documents = widget.documents ?? RemoteDocumentRepository.shared;
      final doc = await documents.details('managed-$id');
      if (!mounted) return;
      await Sign2DigitalNavigation.push<void>(context,MaterialPageRoute(
        builder: (_) => DocumentDetailsScreen(
          documentId: doc.id, document: doc,
          loadDocument: documents.details,
          loadSignedPdf: documents.downloadPdf,
        ),
      ));
    } catch (error) {
      if (mounted) setState(() => _error = 'Verified document unavailable: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String heading, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(heading, style: const TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w600,
          fontSize: 15, color: AppColors.dark)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(
          fontFamily: 'Inter', fontSize: 14, color: AppColors.secondaryText)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _report.meetingMinutesDetails;
    final site = _report.siteReportDetails;
    final siteSections = site?.sectionContent ?? const <SiteReportSection, String>{};
    final suggestions = _suggestion?['sections'];
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(children: [
          Sign2DigitalHeader(title: 'Review Reports'),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                _section('Report', _report.number),
                _section('Title', _report.title),
                _section('Status', _report.status.toUpperCase()),
                _section('Project', _report.project),
                _section('Customer', _report.customer),
                _section('Prepared By', _report.createdBy ?? ''),
                if (site != null) ...[
                  _section('Site Location', site.location),
                  _section('Attendees', site.attendees.join('\n')),
                  _section('Absentees', site.absentees.join('\n')),
                  _section('Decisions', site.decisions.join('\n')),
                  _section('Outstanding Points', site.outstandingPoints.join('\n')),
                  _section('Next Steps', site.nextSteps.join('\n')),
                  _section('Action Items', site.actionItems.map((item) =>
                    item.description).join('\n')),
                ],
                if (site != null)
                  for (final section in siteSections.entries)
                    _section(section.key.label, section.value),
                if (minutes != null) ...[
                  _section('Location', minutes.location),
                  _section('Summary', minutes.summary),
                  _section('Attendees', minutes.attendees.join('\n')),
                  _section('Absentees', minutes.absentees.join('\n')),
                  _section('Decisions', minutes.decisions.join('\n')),
                  _section('Next Steps', minutes.nextSteps.join('\n')),
                  _section('Outstanding Points', minutes.outstandingPoints.join('\n')),
                  _section('Action Items', minutes.actionDetails.isNotEmpty
                    ? minutes.actionDetails.map((item) => [
                        item.description,
                        if (item.assignee.isNotEmpty) 'Owner: ${item.assignee}',
                        if (item.dueDate != null)
                          'Due: ${RemoteSiteReportRepository.dateValue(item.dueDate!)}',
                      ].join(' • ')).join('\n')
                    : minutes.actionItems.join('\n')),
                ],
                if (_suggestion != null) ...[
                  const Divider(height: 25),
                  _section('AI Suggested Title', (_suggestion!['title'] ?? '').toString()),
                  if (suggestions is Map)
                    for (final entry in suggestions.entries)
                      _section(entry.key.toString(), entry.value.toString()),
                  _section('Review Required',
                      'AI text is not applied, approved, or sent. Check each detail first.'),
                  Sign2DigitalOutlinedButton(
                    label: 'Apply Reviewed Suggestion',
                    onPressed: _apply,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(
                      fontFamily: 'Inter', color: Color(0xFFB42318))),
                  ),
                if (_isDraft) ...[
                  Sign2DigitalOutlinedButton(
                    label: 'Edit Draft', onPressed: _editDraft,
                  ),
                  const SizedBox(height: 12),
                  Sign2DigitalOutlinedButton(
                    label: 'Prepare with AI',
                    onPressed: _prepare,
                  ),
                  const SizedBox(height: 12),
                  Sign2DigitalPrimaryButton(
                    label: 'Approve Report', loading: _busy,
                    onPressed: _approve,
                  ),
                ] else if (_report.reportManagedDocumentId != null) ...[
                  Sign2DigitalOutlinedButton(
                    label: 'View Approved PDF',
                    onPressed: _openPdf,
                  ),
                  if (_report.status != 'archived') ...[
                    const SizedBox(height: 12),
                    Sign2DigitalPrimaryButton(
                      label: 'Send to Client', loading: _busy,
                      onPressed: _send,
                    ),
                  ],
                ],
                if (_report.status != 'archived') ...[
                  const SizedBox(height: 12),
                  Sign2DigitalOutlinedButton(
                    label: 'Archive Report', onPressed: _archive,
                  ),
                ],
              ],
            ),
          ))),
        ]),
      ),
    );
  }
}
