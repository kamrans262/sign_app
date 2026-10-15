import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_information_table.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../../documents/presentation/widgets/sign2digital_document_history.dart';
import '../../domain/equipment_record.dart';
import 'add_equipment_screen.dart';

/// Shared Details screen layout with Equipment-specific real local activity.
class EquipmentDetailsScreen extends StatefulWidget {
  const EquipmentDetailsScreen({
    super.key, required this.equipment, required this.repository,
  });
  final EquipmentRecord equipment;
  final EquipmentRepository repository;

  @override
  State<EquipmentDetailsScreen> createState() =>
      _EquipmentDetailsScreenState();
}

class _EquipmentDetailsScreenState extends State<EquipmentDetailsScreen> {
  late EquipmentRecord _record;
  int _tab = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _record = widget.equipment;
  }

  @override
  void didUpdateWidget(covariant EquipmentDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.equipment.id != widget.equipment.id) {
      _record = widget.equipment;
      _tab = 0;
    }
  }

  static String _date(DateTime value) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug',
      'Sep','Oct','Nov','Dec'];
    return '${m[value.month - 1]} ${value.day}, ${value.year}';
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _record.id));
    _notice('Equipment ID copied.');
  }

  Widget _image() => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      height: 50, width: 50,
      child: _record.photos.isEmpty
          ? const ColoredBox(color: Color(0xFFE3ECF0),
              child: Icon(Icons.construction_outlined,
                color: AppColors.primary, size: 28))
          : Image.memory(_record.photos.first.bytes, fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined)),
    ),
  );

  Widget _summary() => Row(
    key: const Key('equipment-detail-summary'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _image(),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_record.name,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 18,
              fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 5),
          Text(_record.id, style: const TextStyle(fontFamily: 'Inter',
            fontSize: 14, color: AppColors.placeholder)),
          Text(_record.category, style: const TextStyle(fontFamily: 'Inter',
            fontSize: 14, color: AppColors.placeholder)),
        ],
      )),
      const SizedBox(width: 8),
      Sign2DigitalStatusBadge(status: _record.status.label),
    ],
  );

  Widget _details() => Sign2DigitalInformationTable(
    key: const Key('equipment-details-table'),
    rows: [
      Sign2DigitalInformationRow('Equipment ID', _record.id, onCopy: _copy),
      Sign2DigitalInformationRow('Name', _record.name),
      Sign2DigitalInformationRow('Category', _record.category),
      Sign2DigitalInformationRow('Brand', _record.brand),
      Sign2DigitalInformationRow('Model', _record.model),
      Sign2DigitalInformationRow('Purchase Date', _date(_record.purchaseDate)),
      Sign2DigitalInformationRow('Status', _record.status.label, isStatus: true),
      Sign2DigitalInformationRow('Current Location',
        _record.location.isEmpty ? 'Not specified' : _record.location),
      Sign2DigitalInformationRow('Hours',
        '${_record.hours == _record.hours.roundToDouble() ? _record.hours.toStringAsFixed(0) : _record.hours.toStringAsFixed(1)}h'),
    ],
  );

  Widget _usage() {
    final items = _record.usage.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (items.isEmpty) {
      return const Text('No usage has been recorded yet.',
        key: Key('equipment-usage-empty'),
        style: TextStyle(color: AppColors.placeholder));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final entry in items) ...[
        Sign2DigitalTrackingRow(
          key: Key('equipment-usage-${entry.id}'),
          title: '${entry.hours.toStringAsFixed(1)} hours',
          dateText: _date(entry.date),
          actorText: [
            if (entry.job.isNotEmpty) 'Job: ${entry.job}',
            if (entry.notes.isNotEmpty) entry.notes,
          ].join('\n'),
          historyStyle: true,
          historyIcon: Icons.timer_outlined),
        const SizedBox(height: 20),
      ],
    ]);
  }

  Widget _maintenance() {
    final items = _record.maintenance.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (items.isEmpty) {
      return const Text('No maintenance has been scheduled yet.',
        key: Key('equipment-maintenance-empty'),
        style: TextStyle(color: AppColors.placeholder));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final entry in items) ...[
        Sign2DigitalTrackingRow(
          key: Key('equipment-maintenance-${entry.id}'),
          title: entry.description,
          dateText: _date(entry.date),
          actorText: entry.completed ? 'Completed' : 'Scheduled',
          completed: entry.completed, historyStyle: true,
          historyIcon: Icons.handyman_outlined),
        const SizedBox(height: 20),
      ],
    ]);
  }

  Widget _history() {
    final events = _record.history.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (events.isEmpty) {
      return const Text('No recorded equipment history yet.',
        key: Key('equipment-history-empty'),
        style: TextStyle(color: AppColors.placeholder));
    }
    return Column(children: [
      for (final event in events) ...[
        Sign2DigitalTrackingRow(
          key: Key('equipment-history-${event.id}'),
          title: event.title,
          dateText: _date(event.date),
          actorText: event.description,
          historyStyle: true, historyIcon: Icons.history_outlined),
        const SizedBox(height: 20),
      ],
    ]);
  }

  Future<DateTime?> _chooseDate(BuildContext ctx, DateTime initial) =>
      showDatePicker(context: ctx, initialDate: initial,
        firstDate: DateTime(2000), lastDate: DateTime(2100));

  Future<void> _edit() async {
    if (_busy) return;
    final next = await Navigator.of(context).push<EquipmentRecord>(
      MaterialPageRoute<EquipmentRecord>(
        builder: (_) => AddEquipmentScreen(initialEquipment: _record)),
    );
    if (!mounted || next == null) return;
    setState(() => _busy = true);
    try {
      if (next.id != _record.id) {
        throw StateError('Equipment ID cannot be changed while editing.');
      }
      final saved = await widget.repository.updateEquipment(next);
      if (mounted) setState(() => _record = saved);
    } catch (_) {
      _notice('Unable to update equipment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logUsage() async {
    if (_busy) return;
    final hours = TextEditingController();
    final job = TextEditingController();
    final notes = TextEditingController();
    var day = DateTime.now();
    EquipmentUsage? result;
    try {
      result = await showDialog<EquipmentUsage>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('Log Equipment Usage'),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('equipment-usage-hours'),
                  controller: hours,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Hours used')),
                TextField(
                  key: const Key('equipment-usage-job'), controller: job,
                  decoration: const InputDecoration(labelText: 'Job (optional)')),
                TextField(
                  key: const Key('equipment-usage-notes'),
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes (optional)')),
                TextButton.icon(
                  key: const Key('equipment-usage-date'),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_date(day)),
                  onPressed: () async {
                    final selected = await _chooseDate(dialog, day);
                    if (selected != null) refresh(() => day = selected);
                  }),
              ],
            )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel')),
              TextButton(
                key: const Key('equipment-confirm-usage'),
                onPressed: () {
                  final value = double.tryParse(hours.text.trim());
                  if (value == null || !value.isFinite ||
                      value <= 0 || value > 100000) return;
                  Navigator.pop(dialog, EquipmentUsage(
                    id: 'usage-${DateTime.now().microsecondsSinceEpoch}',
                    date: day, hours: value, job: job.text.trim(),
                    notes: notes.text.trim()));
                }, child: const Text('Save Usage')),
            ],
          ),
        ),
      );
    } finally {
      // Allow the dialog's closing animation to finish before disposing.
      // Controllers are owned only by this method.
    }
    if (result == null || !mounted) {
      hours.dispose(); job.dispose(); notes.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await widget.repository.logUsage(_record.id, result);
      if (mounted) setState(() => _record = saved);
    } catch (_) {
      _notice('Unable to save usage.');
    } finally {
      hours.dispose(); job.dispose(); notes.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _schedule() async {
    if (_busy) return;
    final description = TextEditingController();
    var day = DateTime.now();
    var completed = false;
    final result = await showDialog<EquipmentMaintenance>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Schedule Maintenance'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              TextField(
                key: const Key('equipment-maintenance-description'),
                controller: description, minLines: 2, maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Maintenance details')),
              TextButton.icon(
                key: const Key('equipment-maintenance-date'),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_date(day)),
                onPressed: () async {
                  final selected = await _chooseDate(dialog, day);
                  if (selected != null) refresh(() => day = selected);
                }),
              CheckboxListTile(
                title: const Text('Already completed'),
                value: completed,
                onChanged: (v) => refresh(() => completed = v ?? false)),
            ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
            TextButton(
              key: const Key('equipment-confirm-maintenance'),
              onPressed: () {
                if (description.text.trim().isEmpty) return;
                Navigator.pop(dialog, EquipmentMaintenance(
                  id: 'maintenance-${DateTime.now().microsecondsSinceEpoch}',
                  date: day, description: description.text.trim(),
                  completed: completed));
              }, child: const Text('Save Maintenance')),
          ],
        ),
      ),
    );
    description.dispose();
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.repository.scheduleMaintenance(_record.id, result);
      if (mounted) setState(() => _record = saved);
    } catch (_) {
      _notice('Unable to save maintenance.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _actions() => Column(children: [
    Row(children: [
      Expanded(child: Sign2DigitalOutlinedButton(
        key: const Key('equipment-details-edit'), label: 'Edit',
        primaryOutline: true, enabled: !_busy, onPressed: _edit)),
      const SizedBox(width: 10),
      Expanded(child: Sign2DigitalOutlinedButton(
        key: const Key('equipment-details-log-usage'),
        label: 'Log Usage', primaryOutline: true,
        enabled: !_busy, onPressed: _logUsage)),
    ]),
    const SizedBox(height: 15),
    FractionallySizedBox(
      widthFactor: .6,
      child: Sign2DigitalPrimaryButton(
        key: const Key('equipment-details-schedule'),
        label: 'Schedule maintenance', enabled: !_busy,
        onPressed: _schedule)),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(
        title: 'Equipment', onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('equipment-details-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            _summary(),
            const SizedBox(height: 20),
            Stack(children: [
              const Positioned(left: 0, right: 0, bottom: 0,
                child: Divider(height: 1, thickness: 1,
                  color: AppColors.lightBorder)),
              Sign2DigitalDetailsTabs(
                labels: const ['Details', 'Usage', 'Maintenance', 'History'],
                selectedIndex: _tab,
                horizontalPadding: 13,
                onSelected: (i) => setState(() => _tab = i)),
            ]),
            const SizedBox(height: 20),
            if (_tab == 0) _details()
            else if (_tab == 1) _usage()
            else if (_tab == 2) _maintenance()
            else _history(),
            const SizedBox(height: 25),
            _actions(),
          ],
        ),
      ))),
    ])),
  );
}
