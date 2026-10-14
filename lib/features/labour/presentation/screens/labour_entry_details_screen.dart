import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../documents/presentation/widgets/sign2digital_document_history.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../data/demo_labour_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _record = widget.entry;
    _repository = widget.repository ?? const DemoLabourRepository();
  }

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
    return '${hours}:${minutes}';
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

  Future<void> _openPhoto(int index) async {
    final selected = _record.photos[index];
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
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
              child: Sign2DigitalPhotoPreview(
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
    if (_record.status != LabourEntryStatus.pending) {
      _notice('Approved entries are locked and cannot be deleted.');
      return;
    }
    _confirmingDeletion = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete labour entry?'),
        content: Text('Delete the entry for ${_record.workerName}? '
          'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel')),
          TextButton(
            key: const Key('labour-confirm-delete'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Delete')),
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
    if (_record.status != LabourEntryStatus.pending) {
      _notice('Approved entries are locked and cannot be edited.');
      return;
    }
    setState(() => _busy = true);
    try {
      final jobs = await _repository.jobs();
      if (!mounted) { return; }
      final edited = await Navigator.of(context).push<LabourEntry>(
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
      final current = (await _repository.list())
          .where((e) => e.id == edited.id).toList();
      if (!mounted) { return; }
      setState(() => _record = current.isEmpty ? edited : current.first);
      _notice('Labour entry updated.');
    } catch (_) {
      _notice('Unable to update this entry. Please try again.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Widget _actions() => Row(
    key: const Key('labour-detail-actions'),
    children: [
      Expanded(child: Sign2DigitalOutlinedButton(
        key: const Key('labour-detail-delete'),
        label: 'Delete',
        primaryOutline: true,
        enabled: !_busy,
        onPressed: _delete,
      )),
      const SizedBox(width: 10),
      Expanded(child: Sign2DigitalPrimaryButton(
        key: const Key('labour-detail-edit'),
        label: 'Edit',
        enabled: !_busy,
        onPressed: _edit,
      )),
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
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
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
        ))),
      ]),
    ),
  );
}
