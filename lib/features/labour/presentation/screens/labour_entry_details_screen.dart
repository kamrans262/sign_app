import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../documents/presentation/widgets/sign2digital_document_history.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../../jobs/data/local_job_photo_source.dart';
import '../../data/demo_labour_repository.dart';
import '../../data/remote_labour_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../domain/labour_entry.dart';
import 'add_labour_entry_screen.dart';

/// Details of one selected record. Keeps approval and history data honest:
/// a demo entry with no verified audit events never gets invented events.
class LabourEntryDetailsScreen extends StatefulWidget {
  const LabourEntryDetailsScreen({
    super.key,
    required this.entry,
    this.repository,
  });

  final LabourEntry entry;
  final LabourRepository? repository;

  @override
  State<LabourEntryDetailsScreen> createState() =>
      _LabourEntryDetailsScreenState();
}

class _LabourEntryDetailsScreenState extends State<LabourEntryDetailsScreen> {
  late LabourEntry _record;
  late LabourRepository _repository;
  int _tab = 0;
  bool _busy = false;
  bool _confirmingDeletion = false;
  bool _confirmingApproval = false;
  bool _verifiedRemote = false;
  bool _loadingRemote = false;

  @override
  void initState() {
    super.initState();
    _record = widget.entry;
    _repository = widget.repository ?? (
      !MobileAuthRepository.shared.isSignedIn &&
      ActiveCompanySession.companyId == null
        ? const DemoLabourRepository() : RemoteLabourRepository.shared);
    if (_repository is RemoteLabourRepository) _reload();
  }

  Future<void> _reload() async {
    if (_repository is! RemoteLabourRepository) return;
    if (mounted) {
      setState(() {
        _loadingRemote = true;
        _verifiedRemote = false;
      });
    }
    try {
      final full=await (_repository as RemoteLabourRepository).detail(_record.id);
      if(mounted) {
        setState(() {
          _record=full;
          _verifiedRemote=true;
        });
      }
    } catch (_) {
      _notice('Unable to load verified labour details.');
    } finally {
      if(mounted) setState(()=>_loadingRemote=false);
    }
  }

  bool get _canModifyRemote => _repository is! RemoteLabourRepository ||
      (_verifiedRemote && !_loadingRemote);

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _date(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  static String _timestamp(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${_date(local)}, ${hour.toString()}:'
        '${local.minute.toString().padLeft(2, '0')} '
        '${local.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _clock(int? value) {
    if (value == null) { return 'Not recorded'; }
    final hours = value ~/ 60;
    final minutes = (value % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  static String _cost(double? number) =>
      number == null ? 'Not recorded' : 'CHF ${number.toStringAsFixed(2)}';

  void _notice(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyJob() async {
    await Clipboard.setData(ClipboardData(text: _record.jobName));
    _notice('Job copied to clipboard.');
  }

  Widget _worker() => Row(
    key: const Key('labour-detail-worker'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFE3ECF0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_record.initials,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 16,
              fontWeight: FontWeight.w600, color: AppColors.white)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_record.workerName,
            key: const Key('labour-detail-name'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 16,
              fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 5),
          Text(_record.role,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 14,
              color: AppColors.placeholder)),
        ],
      )),
      const SizedBox(width: 8),
      Sign2DigitalStatusBadge(status: _record.statusLabel),
    ],
  );

  Widget _summary() => Row(
    key: const Key('labour-detail-summary'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_record.hours.toStringAsFixed(2)} hours',
            key: const Key('labour-detail-hours'),
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 20,
              fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 5),
          Text(_date(_record.date), softWrap: true,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 14,
              color: AppColors.placeholder)),
        ],
      )),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_record.hourlyRate == null
              ? 'Rate not recorded'
              : 'CHF ${_record.hourlyRate!.toStringAsFixed(2)} / hours',
            textAlign: TextAlign.end, softWrap: true,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 12,
              fontWeight: FontWeight.w500, letterSpacing: -0.3,
              color: AppColors.dark)),
          const SizedBox(height: 5),
          Text(_record.totalLabourCost == null
              ? 'Total not available'
              : 'Total: ${_cost(_record.totalLabourCost)}',
            key: const Key('labour-detail-total-cost'),
            textAlign: TextAlign.end, softWrap: true,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 12,
              fontWeight: FontWeight.w500, color: AppColors.dark)),
        ],
      )),
    ],
  );

  Widget _details() {
    final record = _record;
    final rows = <Sign2DigitalInformationRow>[
      Sign2DigitalInformationRow('Job', record.jobName, onCopy: _copyJob),
      Sign2DigitalInformationRow('Date', _date(record.date)),
      Sign2DigitalInformationRow('Start time',
        _clock(record.startMinutes)),
      Sign2DigitalInformationRow('End time', _clock(record.endMinutes)),
      Sign2DigitalInformationRow('Total hours',
        LabourTimeRange.display((record.hours * 60).round())),
      Sign2DigitalInformationRow('Labour Type', record.role),
      Sign2DigitalInformationRow('Hourly Rate',
        _cost(record.hourlyRate)),
      Sign2DigitalInformationRow('Total cost',
        _cost(record.totalLabourCost)),
      Sign2DigitalInformationRow('Status', record.statusLabel, isStatus: true),
      if (record.approvedBy?.trim().isNotEmpty == true)
        Sign2DigitalInformationRow('Approved by', record.approvedBy!),
      if (record.approvedAt != null)
        Sign2DigitalInformationRow('Approved Date',
          _timestamp(record.approvedAt!)),
      if (record.task.trim().isNotEmpty)
        Sign2DigitalInformationRow('Description', record.task),
    ];
    return Sign2DigitalInformationTable(
      key: const Key('labour-detail-table'), rows: rows);
  }

  bool _isPdf(LocalJobPhotoSelection proof) {
    final bytes=proof.bytes;
    return proof.name.toLowerCase().endsWith('.pdf') ||
      (bytes.length>=5 && bytes[0]==37 && bytes[1]==80 &&
       bytes[2]==68 && bytes[3]==70 && bytes[4]==45);
  }

  Future<void> _openPhoto(int index) async {
    final selected = _record.photos[index];
    if(_isPdf(selected)) {
      await Sign2DigitalNavigation.push<void>(context,MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(title: Text(selected.name),
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.dark),
          body: SafeArea(child: PdfPreview(
            build: (_) async => selected.bytes,
            allowPrinting:false,
            allowSharing:false,
            canChangePageFormat:false,
            canChangeOrientation:false,
          )),
        ),
      ));
      return;
    }
    await Sign2DigitalNavigation.push<void>(context,MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(selected.name, maxLines: 1,
            overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.memory(selected.bytes,
              key: const Key('labour-photo-full-preview'),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined, color: Colors.white)),
          ),
        )),
      ),
    ));
  }

  Widget _photos() {
    final photos = _record.photos;
    if (photos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No photos attached to this labour entry.',
          key: Key('labour-detail-photos-empty'),
          style: TextStyle(
            fontFamily: 'Inter', fontSize: 14,
            color: AppColors.placeholder)),
      );
    }
    return Sign2DigitalOutlinedContainer(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(builder: (context, box) =>
          GridView.builder(
            key: const Key('labour-detail-photo-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: box.maxWidth < 250 ? 1 : 2,
              crossAxisSpacing: 15, mainAxisSpacing: 15,
              childAspectRatio: 188 / 118,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) => InkWell(
              key: Key('labour-detail-photo-$index'),
              onTap: () => _openPhoto(index),
              child: _isPdf(photos[index])
                ? Sign2DigitalOutlinedContainer(
                    key: Key('labour-pdf-tile-$index'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined,
                            color: AppColors.primary, size: 28),
                          const SizedBox(height: 8),
                          Text(photos[index].name, maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily:'Inter',fontSize:13,
                              color:AppColors.dark)),
                        ],
                      ),
                    ),
                  )
                : Sign2DigitalPhotoPreview(
                    bytes: photos[index].bytes,
                    showDemo: false,
                    compactTile: true,
                    showRemove: false,
                    onRemove: () {},
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _history() {
    final events = _record.history.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No recorded labour history is available.',
          key: Key('labour-detail-history-empty'),
          style: TextStyle(
            fontFamily: 'Inter', fontSize: 14,
            color: AppColors.placeholder)),
      );
    }
    return Column(
      key: const Key('labour-detail-history-list'),
      children: [
        for (final event in events) ...[
          Sign2DigitalTrackingRow(
            key: Key('labour-history-${event.id}'),
            historyStyle: true,
            historyIcon: Icons.history_rounded,
            title: event.title,
            dateText: _timestamp(event.occurredAt),
            actorText: [
              if (event.description?.trim().isNotEmpty == true)
                event.description!.trim(),
              if (event.actorName?.trim().isNotEmpty == true)
                'By ${event.actorName}',
            ].join(' • '),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _delete() async {
    if (_busy || _confirmingDeletion) { return; }
    if (!_canModifyRemote) {
      _notice('Verify labour details and private evidence before changing this entry.');
      return;
    }
    if (_record.status != LabourEntryStatus.pending) {
      _notice('Approved entries are locked and cannot be deleted.');
      return;
    }
    _confirmingDeletion = true;
    final real=_repository is RemoteLabourRepository;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(real ? 'Void labour entry?' : 'Delete labour entry?'),
        content: Text(real
          ? 'Void the entry for ${_record.workerName}? The original remains in the audit trail.'
          : 'Delete the entry for ${_record.workerName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel')),
          TextButton(
            key: const Key('labour-confirm-delete'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(real ? 'Void Entry' : 'Delete')),
        ],
      ),
    );
    _confirmingDeletion = false;
    if (confirmed != true || !mounted) { return; }
    setState(() => _busy = true);
    try {
      await _repository.delete(_record.id);
      if (!mounted) { return; }
      Navigator.of(context).pop(true);
    } catch (_) {
      _notice('Unable to delete this entry. Please try again.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _edit() async {
    if (_busy) { return; }
    if (!_canModifyRemote) {
      _notice('Verify labour details and private evidence before editing.');
      return;
    }
    if (_record.status != LabourEntryStatus.pending ||
        (_repository is RemoteLabourRepository && _record.source != 'manual')) {
      _notice('Reviewed or timer-created entries require an audited correction.');
      return;
    }
    setState(() => _busy = true);
    try {
      final jobs = await _repository.jobs();
      if (!mounted) { return; }
      final edited = await Sign2DigitalNavigation.push<LabourEntry>(context,
        MaterialPageRoute<LabourEntry>(
          builder: (_) => AddLabourEntryScreen(
            kind: _record.kind,
            jobs: jobs,
            initialEntry: _record,
          ),
        ),
      );
      if (!mounted || edited == null) { return; }
      if (edited.id != _record.id || edited.status != _record.status) {
        _notice('Entry identity changed. No updates were saved.');
        return;
      }
      await _repository.update(edited);
      if (_repository is RemoteLabourRepository) {
        await _reload();
      } else {
        final current = (await _repository.list())
            .where((e) => e.id == edited.id).toList();
        if (!mounted) return;
        setState(() => _record = current.isEmpty ? edited : current.first);
      }
      _notice('Labour entry updated.');
    } catch (_) {
      _notice('Unable to update this entry. Please try again.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _approve() async {
    if (_busy || _confirmingApproval || !_canModifyRemote ||
        !_record.canApprove || _record.status != LabourEntryStatus.pending ||
        _repository is! RemoteLabourRepository) return;
    _confirmingApproval = true;
    try {
      final choice = await Sign2DigitalSelectionSheet.show(
        context, title: 'Approve Time Entry',
        subtitle: 'Confirm approval for ${_record.workerName}. This locks the entry.',
        icon: Icons.check_circle_outline,
        options: const ['Cancel', 'Approve'],
      );
      if (!mounted || choice != 'Approve') return;
      setState(() => _busy = true);
      final approved = await (_repository as RemoteLabourRepository)
          .approveEntry(_record);
      if (!mounted) return;
      if (approved.id != _record.id || approved.status != LabourEntryStatus.approved) {
        throw StateError('Invalid approval response.');
      }
      setState(() => _record = approved);
      _notice('Time entry approved.');
    } catch (_) {
      _notice('Unable to approve time entry. Refresh and retry.');
    } finally {
      _confirmingApproval = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _actions() => Column(
    key: const Key('labour-detail-actions'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_record.status == LabourEntryStatus.pending &&
          _record.canApprove && _repository is RemoteLabourRepository) ...[
        Sign2DigitalPrimaryButton(
          key: const Key('labour-detail-approve'),
          label: 'Approve',
          enabled: !_busy && !_confirmingApproval && _canModifyRemote,
          loading: _busy,
          onPressed: _approve,
        ),
        const SizedBox(height: 10),
      ],
      Row(
    key: const Key('labour-detail-actions'),
    children: [
      Expanded(child: Sign2DigitalOutlinedButton(
        key: const Key('labour-detail-delete'),
        label: _repository is RemoteLabourRepository ? 'Void' : 'Delete',
        primaryOutline: true,
        enabled: !_busy && _canModifyRemote &&
            _record.status == LabourEntryStatus.pending,
        onPressed: _delete,
      )),
      const SizedBox(width: 10),
      Expanded(child: Sign2DigitalPrimaryButton(
        key: const Key('labour-detail-edit'),
        label: 'Edit',
        enabled: !_busy && _canModifyRemote &&
            _record.status == LabourEntryStatus.pending &&
            (_repository is! RemoteLabourRepository || _record.source == 'manual'),
        onPressed: _edit,
      )),
    ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(
      child: Column(children: [
        Sign2DigitalHeader(
          logoAsset: 'assets/header_logo.png',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(child: ListView(
            key: const Key('labour-detail-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              _worker(),
              const SizedBox(height: 20),
              _summary(),
              const SizedBox(height: 20),
              Stack(children: [
                const Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Divider(height: 1, thickness: 1,
                    color: AppColors.lightBorder),
                ),
                Sign2DigitalDetailsTabs(
                  labels: const ['Details', 'Photos', 'History'],
                  selectedIndex: _tab,
                  onSelected: (value) => setState(() => _tab = value),
                ),
              ]),
              const SizedBox(height: 20),
              if (_tab == 0) _details()
              else if (_tab == 1) _photos()
              else _history(),
              const SizedBox(height: 25),
              _actions(),
            ],
          ),
      ),
      ]),
    ),
  );
}
