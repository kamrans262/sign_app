import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../jobs/domain/job_model.dart';
import '../../domain/labour_entry.dart';

class AddLabourEntryScreen extends StatefulWidget {
  const AddLabourEntryScreen({
    super.key,
    required this.kind,
    required this.jobs,
    this.initialJob,
    this.selectedNavigationIndex = 4,
  });

  final LabourEntryKind kind;
  final List<JobModel> jobs;
  final JobModel? initialJob;
  final int selectedNavigationIndex;

  @override
  State<AddLabourEntryScreen> createState() => _AddLabourEntryScreenState();
}

class _AddLabourEntryScreenState extends State<AddLabourEntryScreen> {
  final _worker = TextEditingController();
  final _role = TextEditingController();
  final _task = TextEditingController();
  final _hours = TextEditingController();
  JobModel? _job;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
  }

  @override
  void dispose() {
    _worker.dispose(); _role.dispose(); _task.dispose(); _hours.dispose();
    super.dispose();
  }

  Future<void> _selectJob() async {
    final controller = TextEditingController();
    try {
      final job = await showModalBottomSheet<JobModel>(
        context: context, isScrollControlled: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheet).height * 0.65,
              child: Column(children: [
                const ListTile(title: Text('Select Job')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    key: const Key('labour-job-search'),
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Search jobs'),
                    onChanged: (_) => update(() {}),
                  ),
                ),
                Expanded(child: ListView(children: [
                  for (final job in widget.jobs.where(
                      (j) => j.matches(controller.text)))
                    ListTile(
                      key: Key('labour-select-job-${job.id}'),
                      title: Text(job.title),
                      subtitle: Text(job.referenceNumber),
                      onTap: () => Navigator.of(sheet).pop(job),
                    ),
                ])),
              ]),
            ),
          ),
        ),
      );
      if (job != null && mounted) setState(() => _job = job);
    } finally { controller.dispose(); }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _save() {
    final hours = double.tryParse(_hours.text.trim().replaceAll(',', '.'));
    if (_job == null || _worker.text.trim().isEmpty ||
        _role.text.trim().isEmpty || hours == null ||
        !hours.isFinite || hours <= 0 || hours > 24 ||
        ((hours * 100) - (hours * 100).round()).abs() > 0.001) {
      setState(() => _error =
          'Choose a job, worker, role and valid hours (0–24, two decimals).');
      return;
    }
    Navigator.of(context).pop(LabourEntry(
      id: 'local-time-${DateTime.now().microsecondsSinceEpoch}',
      kind: widget.kind,
      workerName: _worker.text.trim(),
      role: _role.text.trim(),
      jobId: _job!.id,
      jobName: _job!.title,
      date: _date,
      hours: hours,
      status: LabourEntryStatus.pending,
      task: _task.text.trim(),
    ));
  }

  Widget _field(String title, TextEditingController controller, {
      required Key key, TextInputType? keyboard}) => TextField(
    key: key, controller: controller, keyboardType: keyboard,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: title,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightBorder)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(bottom: false, child: Column(children: [
      Sign2DigitalHeader(
        title: widget.kind == LabourEntryKind.labour
            ? 'Add Labour' : 'Add Time Entry',
        onBack: () => Navigator.of(context).pop(),
      ),
      Expanded(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('labour-entry-form-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          children: [
            Sign2DigitalSelectionField(
              key: const Key('labour-form-job'),
              label: 'Job', iconAsset: 'assets/icons/description.svg',
              hintText: 'Select an existing job',
              value: _job?.title,
              trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondaryText),
              onTap: _selectJob,
            ),
            const SizedBox(height: 20),
            _field('Worker name', _worker,
              key: const Key('labour-form-worker')),
            const SizedBox(height: 20),
            _field('Role / Trade', _role,
              key: const Key('labour-form-role')),
            const SizedBox(height: 20),
            Sign2DigitalSelectionField(
              key: const Key('labour-form-date'),
              label: 'Date', iconAsset: 'assets/icons/calendar-outlined.svg',
              hintText: 'Choose date',
              value: '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}',
              onTap: _pickDate,
            ),
            const SizedBox(height: 20),
            _field('Hours', _hours,
              key: const Key('labour-form-hours'),
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 20),
            _field('Task / Notes (optional)', _task,
              key: const Key('labour-form-task')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const Key('labour-form-error'),
                style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 25),
            Sign2DigitalPrimaryButton(
              key: const Key('labour-form-save'),
              label: 'Save Entry', onPressed: _save),
          ],
        ),
      ))),
    ])),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: widget.selectedNavigationIndex,
      onSelected: (index) {
        if (index != widget.selectedNavigationIndex) {
          Navigator.of(context).pop();
        }
      },
    ),
  );
}
