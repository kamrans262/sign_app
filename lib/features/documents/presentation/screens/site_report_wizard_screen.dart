import '../../../../core/widgets/sign2digital_selection_sheet.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_approved_confirmation.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_checkbox.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../../core/widgets/sign2digital_wizard_stepper.dart';
import '../../../jobs/data/local_job_photo_source.dart';
import '../../../jobs/data/mock_jobs.dart';
import '../../../jobs/data/remote_job_repository.dart';
import '../../../../core/services/active_company_session.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../domain/document_record.dart';
import '../widgets/site_report_review_content.dart';

/// UI-only three-step site report wizard, never claims remote submission.
class SiteReportWizardScreen extends StatefulWidget {
  const SiteReportWizardScreen({
    super.key,
    this.initial,
    this.initialJobId,
    this.photoSource,
    this.reportGenerator,
    this.onNavigationSelected,
    this.selectedNavigationIndex = 2,
  });

  final DocumentRecord? initial;
  final String? initialJobId;
  final JobPhotoSource? photoSource;
  /// Optional real report-generation service supplied by production wiring.
  /// No success is assumed when absent; local drafts stay distinct.
  final Future<DocumentRecord> Function(DocumentRecord draft)? reportGenerator;
  final ValueChanged<int>? onNavigationSelected;
  final int selectedNavigationIndex;

  @override
  State<SiteReportWizardScreen> createState() => _SiteReportWizardScreenState();
}

class _SiteReportWizardScreenState extends State<SiteReportWizardScreen> {
  static const _reportTitles = [
    'Site Report', 'Weekly Site Report', 'Site Inspection', 'Custom Title',
  ];
  static const _weatherOptions = [
    'Sunny', 'Cloudy', 'Rainy', 'Snowy', 'Windy', 'Other',
  ];
  static const _riskOptions = <String>[
    'No issues', 'Safety hazard', 'Material delay',
    'Weather delay', 'Quality issue', 'Other',
  ];
  static const _sectionHints = <SiteReportSection, String>{
    SiteReportSection.siteProgress:
        'Kitchen renovations, processes of renovating, color selection, and labour work',
    SiteReportSection.notes:
        'Complete renovation of the terrace, including new tiles, waterproofing and railings',
    SiteReportSection.issues: 'e.g, Site report',
    SiteReportSection.materials: 'Record materials delivered',
    SiteReportSection.labour: 'Record work hours and labour',
  };

  final _scroll = ScrollController();
  final _preparer = TextEditingController();
  final _customTitle = TextEditingController();
  final _otherCondition = TextEditingController();
  final _otherRisk = TextEditingController();
  String? _riskSelection;
  List<MeetingActionItem> _previousActions = const [];
  final _location = TextEditingController();
  final _attendees = TextEditingController();
  final _absentees = TextEditingController();
  final _decisions = TextEditingController();
  final _outstanding = TextEditingController();
  final _nextSteps = TextEditingController();
  final _actions = TextEditingController();
  final _contents = <SiteReportSection, TextEditingController>{};
  final _selectedSections = <SiteReportSection>{
    SiteReportSection.siteProgress,
    SiteReportSection.notes,
    SiteReportSection.materials,
  };
  List<LocalJobPhotoSelection> _photos = [];
  int _step = 0;
  String? _title;
  String? _weather;
  JobModel? _selectedJob;
  String _projectName = '';
  String _clientName = '';
  DateTime? _reportDate;
  String? _error;
  bool _picking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final section in SiteReportSection.values) {
      if (section != SiteReportSection.photos) {
        _contents[section] = TextEditingController();
      }
    }
    final initial = widget.initial;
    if (initial != null) {
      _projectName = initial.project;
      _clientName = initial.customer;
      for (final job in MockJobsData.jobs) {
        if (job.title == initial.project && job.clientName == initial.customer) {
          _selectedJob = job;
          break;
        }
      }
      if (_reportTitles.contains(initial.title)) {
        _title = initial.title;
      } else {
        _title = 'Custom Title';
        _customTitle.text = initial.title;
      }
      final details = initial.siteReportDetails;
      if (details != null) {
        _reportDate = details.reportDate;
        _preparer.text = details.preparedBy;
        final weather = details.weatherCondition;
        if (weather.startsWith('Other: ')) {
          _weather = 'Other';
          _otherCondition.text = weather.substring(7);
        } else if (_weatherOptions.contains(weather)) {
          _weather = weather;
        } else {
          // Legacy free-text condition remains editable and is not discarded.
          _weather = 'Other';
          _otherCondition.text = weather;
        }
        _location.text = details.location;
        _attendees.text = details.attendees.join('\n');
        _absentees.text = details.absentees.join('\n');
        _decisions.text = details.decisions.join('\n');
        _outstanding.text = details.outstandingPoints.join('\n');
        _nextSteps.text = details.nextSteps.join('\n');
        _previousActions = details.actionItems;
        _actions.text = details.actionItems.map((item) => item.description).join('\n');
        _selectedSections
          ..clear()
          ..addAll(details.selectedSections);
        for (final item in details.sectionContent.entries) {
          _contents[item.key]?.text = item.value;
        }
        final risk = details.sectionContent[SiteReportSection.issues] ?? '';
        if (_riskOptions.contains(risk)) {
          _riskSelection = risk;
        } else if (risk.startsWith('Other: ')) {
          _riskSelection = 'Other';
          _otherRisk.text = risk.substring(7);
        } else if (risk.isNotEmpty) {
          _riskSelection = 'Other';
          _otherRisk.text = risk;
        }
        _photos = List.of(details.photos);
        if (_photos.isNotEmpty) {
          _selectedSections.add(SiteReportSection.photos);
        }
      }
    }
    final linkedId = initial?.jobId ?? widget.initialJobId;
    if (linkedId != null && int.tryParse(linkedId) != null &&
        widget.reportGenerator != null &&
        ActiveCompanySession.companyId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveRealJob(linkedId);
      });
    }
  }

  Future<void> _resolveRealJob(String jobId) async {
    try {
      final jobs = await RemoteJobRepository.shared.listJobs();
      if (!mounted || (_selectedJob != null &&
          _selectedJob!.id != jobId)) return;
      for (final job in jobs) {
        if (job.id == jobId) {
          setState(() {
            _selectedJob = job;
            _projectName = job.title;
            _clientName = job.clientName;
          });
          return;
        }
      }
      setState(() => _error = 'The linked job is unavailable in this company.');
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to verify the linked job: $error');
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _preparer.dispose();
    _customTitle.dispose();
    _otherCondition.dispose();
    _otherRisk.dispose();
    for (final controller in [_location,_attendees,_absentees,_decisions,_outstanding,_nextSteps,_actions]) { controller.dispose(); }
    for (final controller in _contents.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _actualTitle => _title == 'Custom Title'
      ? _customTitle.text.trim() : (_title ?? '');

  List<String> _lines(String value) => value.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  List<MeetingActionItem> _actionRows() {
    final text = _lines(_actions.text);
    return List<MeetingActionItem>.generate(text.length, (index) {
      final description = text[index];
      // Keep owner/date evidence on legacy records even though the new editor
      // deliberately shows only task descriptions.
      final prior = _previousActions.where(
        (item) => item.description == description,
      ).firstOrNull;
      final original = prior ?? (index < _previousActions.length
          ? _previousActions[index] : null);
      return MeetingActionItem(
        description: description,
        assignee: original?.assignee ?? '',
        dueDate: original?.dueDate,
      );
    });
  }

  String _dateText(DateTime value) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  void _showStep(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _step = value; _error = null; });
    if (_scroll.hasClients) { _scroll.jumpTo(0); }
  }

  void _back() {
    if (_step > 0) {
      _showStep(_step - 1);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _navigate(int index) {
    if (index == widget.selectedNavigationIndex) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pop();
    widget.onNavigationSelected?.call(index);
  }

  Future<void> _pickOption({
    required List<String> options,
    required String title,
    required void Function(String) onSelected,
    required String keyPrefix,
    String? selected,
  }) async {
    final option = await Sign2DigitalSelectionSheet.showCustom<String>(
      title: 'Select $title',
      icon: title == 'Weather Condition' ? Icons.cloud_outlined
          : title == 'Issues & Risks' ? Icons.warning_amber_outlined
          : Icons.description_outlined,
      subtitle: 'Choose a $title option',
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < options.length; i++)
              ListTile(
                key: Key('$keyPrefix-$i'),
                selected: options[i] == selected,
                trailing: options[i] == selected
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary) : null,
                title: Text(options[i]),
                onTap: () => Navigator.of(sheet).pop(options[i]),
              ),
          ],
        ),
      )),
    );
    if (option != null && mounted) { setState(() => onSelected(option)); }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) { setState(() => _reportDate = picked); }
  }

  String? _detailsIssue() {
    if (_actualTitle.isEmpty) { return 'Choose a report title.'; }
    if (_reportDate == null) { return 'Choose a report date.'; }
    if (_preparer.text.trim().isEmpty) { return 'Enter who prepared the report.'; }
    if (widget.reportGenerator != null && _location.text.trim().isEmpty) { return 'Enter the site location.'; }
    if ((_weather ?? '').isEmpty) { return 'Choose a weather condition.'; }
    if (_weather == 'Other' && _otherCondition.text.trim().isEmpty) {
      return 'Describe the condition.';
    }
    if (_selectedSections.isEmpty) { return 'Select at least one report section.'; }
    return null;
  }

  String? _contentIssue() {
    if (_picking) { return 'Wait for photo selection to finish.'; }
    if (widget.reportGenerator != null && _photos.length > 8) { return 'Select no more than eight photos.'; }
    if (_selectedSections.contains(SiteReportSection.issues) &&
        _riskSelection == 'Other' && _otherRisk.text.trim().isEmpty) {
      return 'Describe the issues and risks.';
    }
    for (final section in SiteReportSection.values) {
      if (!_selectedSections.contains(section)) { continue; }
      if (section == SiteReportSection.photos) {
        if (_photos.isEmpty) { return 'Add a photo or deselect Photos.'; }
      } else if ((_contents[section]?.text.trim() ?? '').isEmpty) {
        return 'Complete the ${section.label} section.';
      }
    }
    return null;
  }

  Future<void> _choosePhotoSource() async {
    if (_picking) { return; }
    final action = await showSign2DigitalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('site-report-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheet).pop(false),
          ),
          ListTile(
            key: const Key('site-report-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ],
      )),
    );
    if (action != null && mounted) {
      await _pickPhotos(camera: action);
    }
  }

  Future<void> _pickPhotos({required bool camera}) async {
    if (_picking) { return; }
    setState(() => _picking = true);
    try {
      final source = widget.photoSource ?? DeviceJobPhotoSource();
      final files = <LocalJobPhotoSelection>[];
      if (camera) {
        final photo = await source.camera();
        if (photo != null) { files.add(photo); }
      } else {
        files.addAll(await source.upload());
      }
      if (!mounted || files.isEmpty) { return; }
      for (final photo in files) {
        DeviceJobPhotoSource.validate(photo.name, photo.bytes);
      }
      setState(() {
        // Keep original order and prevent accidentally duplicating a file.
        final keys = _photos.map((p) => p.sourceKey).toSet();
        for (final photo in files) {
          if (keys.add(photo.sourceKey)) _photos.add(photo);
        }
        if (_photos.isNotEmpty) {
          _selectedSections.add(SiteReportSection.photos);
        }
        _error = null;
      });
    } on FormatException catch (error) {
      if (mounted) { setState(() => _error = error.message); }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Unable to select photos. Check permissions and try again.');
      }
    } finally {
      if (mounted) { setState(() => _picking = false); }
    }
  }

  Future<void> _selectRisk() async {
    await _pickOption(
      options: _riskOptions,
      title: 'Issues & Risks',
      keyPrefix: 'site-report-risk-option',
      selected: _riskSelection,
      onSelected: (selection) {
        _riskSelection = selection;
        _contents[SiteReportSection.issues]!.text = selection == 'Other'
            ? 'Other: ${_otherRisk.text.trim()}'
            : selection;
      },
    );
  }

  void _next() {
    final error = _step == 0 ? _detailsIssue() : _contentIssue();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_step < 2) { _showStep(_step + 1); }
  }

  Future<void> _save() async {
    if (_saving) { return; }
    final issue = _detailsIssue() ?? _contentIssue();
    if (issue != null) {
      setState(() => _error = issue);
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = _draftRecord();
      if (mounted) { Navigator.of(context).pop(draft); }
    } finally {
      if (mounted) { setState(() => _saving = false); }
    }
  }

  Future<void> _chooseJob() async {
    List<JobModel> choices = MockJobsData.jobs;
    if (widget.reportGenerator != null &&
        ActiveCompanySession.companyId != null) {
      try {
        choices = await RemoteJobRepository.shared.listJobs();
      } catch (error) {
        if (mounted) {
          setState(() => _error = 'Unable to load saved company jobs: $error');
        }
        return;
      }
    }
    if (!mounted) return;
    final selected = await Sign2DigitalSelectionSheet.showCustom<JobModel>(
      title: 'Select Job / Project',
      icon: Icons.work_outline_rounded,
      subtitle: 'Choose a job for the site report',
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final job in choices)
              ListTile(
                key: Key('review-report-job-${job.id}'),
                selected: _selectedJob?.id == job.id,
                trailing: _selectedJob?.id == job.id
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary) : null,
                title: Text(job.title),
                subtitle: Text('${job.referenceNumber} • ${job.clientName}'),
                onTap: () => Navigator.of(sheet).pop(job),
              ),
          ],
        ),
      )),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedJob = selected;
        _projectName = selected.title;
        _clientName = selected.clientName;
        _error = null;
      });
    }
  }

  DocumentRecord _draftRecord() {
    final now = DateTime.now();
    final data = SiteReportDetails(
      reportDate: _reportDate!,
      preparedBy: _preparer.text.trim(),
      weatherCondition: _weather == 'Other'
          ? 'Other: ${_otherCondition.text.trim()}' : _weather!,
      location: _location.text.trim(),
      attendees: _lines(_attendees.text),
      absentees: _lines(_absentees.text),
      decisions: _lines(_decisions.text),
      outstandingPoints: _lines(_outstanding.text),
      nextSteps: _lines(_nextSteps.text),
      actionItems: _actionRows(),
      selectedSections: List.unmodifiable(
          SiteReportSection.values.where(_selectedSections.contains)),
      sectionContent: Map.unmodifiable({
        for (final section in _selectedSections)
          if (section != SiteReportSection.photos)
            section: _contents[section]!.text.trim(),
      }),
      // Keep all selected photos, even if an older draft had Photos unchecked.
      photos: List.unmodifiable(_photos),
    );
    final id = widget.initial?.id ??
        'local-site-report-${now.microsecondsSinceEpoch}';
    return DocumentRecord(
      id: id,
      category: DocumentCategory.reports,
      reportKind: ReportKind.siteReport,
      number: widget.initial?.number ?? id,
      title: _actualTitle,
      project: _projectName,
      customer: _clientName,
      timestamp: widget.initial?.timestamp ?? now,
      status: 'Draft',
      version: widget.initial?.version ?? 1,
      demoOnly: true,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
      createdBy: data.preparedBy,
      siteReportDetails: data,
      jobId: _selectedJob?.id ?? widget.initial?.jobId,
    );
  }

  Future<void> _generateReport() async {
    if (_saving) { return; }
    final issue = _detailsIssue() ?? _contentIssue();
    if (issue != null) {
      setState(() => _error = issue);
      return;
    }
    if (_selectedJob == null ||
        _projectName != _selectedJob!.title ||
        _clientName != _selectedJob!.clientName) {
      setState(() => _error =
          'Select a linked job so its client can be verified.');
      return;
    }
    final generator = widget.reportGenerator;
    if (generator == null) {
      final saveDraft = await showDialog<bool>(
        context: context,
        builder: (dialog) => Sign2DigitalApprovedConfirmation(
          title: const Text('Report generation unavailable'),
          content: const Text(
            'Report generation is not connected yet. '
            'You can save this report as a local draft instead.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              key: const Key('review-report-save-local-draft'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Save local draft'),
            ),
          ],
        ),
      );
      if (saveDraft == true && mounted) { await _save(); }
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final result = await generator(_draftRecord());
      if (!mounted) { return; }
      if (result.id.trim().isEmpty ||
          result.category != DocumentCategory.reports ||
          result.reportKind != ReportKind.siteReport ||
          result.demoOnly) {
        throw StateError('The report service did not return a valid saved report.');
      }
      Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
          'Report generation failed. Your entered information is preserved.');
      }
    } finally {
      if (mounted) { setState(() => _saving = false); }
    }
  }

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Sign2DigitalSelectionField(
        key: const Key('site-report-title'),
        label: 'Report Title',
        iconAsset: 'assets/icons/description.svg',
        hintText: 'e.g, Site report',
        value: _title == 'Custom Title' ? null : _title,
        trailing: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.secondaryText),
        onTap: () => _pickOption(
          options: _reportTitles, title: 'Report Title',
          keyPrefix: 'site-report-title-option',
          selected: _title,
          onSelected: (value) => _title = value,
        ),
      ),
      if (_title == 'Custom Title') ...[
        const SizedBox(height: 15),
        Sign2DigitalInputField(
          key: const Key('site-report-custom-title'),
          label: 'Custom Report Title',
          hintText: 'Enter report title',
          iconAsset: 'assets/icons/description.svg',
          controller: _customTitle,
        ),
      ],
      const SizedBox(height: 15),
      Sign2DigitalSelectionField(
        key: const Key('site-report-date'),
        label: 'Report Date',
        iconAsset: 'assets/icons/calendar-outlined.svg',
        hintText: 'August 25, 2026',
        value: _reportDate == null ? null : _dateText(_reportDate!),
        onTap: _chooseDate,
      ),
      const SizedBox(height: 15),
      Sign2DigitalInputField(
        key: const Key('site-report-preparer'),
        label: 'Prepared By',
        hintText: 'e.g, Jean Dupont',
        iconAsset: 'assets/icons/user.svg',
        controller: _preparer,
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 15),
      Sign2DigitalInputField(
        key: const Key('site-report-location'),
        label: 'Site Location', hintText: 'Enter site location',
        iconAsset: 'assets/icons/description.svg',
        controller: _location,
      ),
      const SizedBox(height: 15),
      Sign2DigitalSelectionField(
        key: const Key('site-report-weather'),
        label: 'Weather Condition',
        iconAsset: 'assets/icons/cloud-upload-outlined.svg',
        leadingIcon: Icons.cloud_outlined,
        hintText: 'e.g, Sunny',
        value: _weather,
        trailing: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.secondaryText),
        onTap: () => _pickOption(
          options: _weatherOptions, title: 'Weather Condition',
          keyPrefix: 'site-report-weather-option',
          selected: _weather,
          onSelected: (value) => _weather = value,
        ),
      ),
      if (_weather == 'Other') ...[
        const SizedBox(height: 15),
        Sign2DigitalInputField(
          key: const Key('site-report-other-condition'),
          label: 'Specify Condition',
          hintText: 'Describe the condition',
          iconAsset: 'assets/icons/description.svg',
          controller: _otherCondition,
        ),
      ],
      const SizedBox(height: 20),
      const Text('Report Sections', style: AppTextStyles.fieldLabel),
      const SizedBox(height: 10),
      for (var i = 0; i < SiteReportSection.values.length; i++) ...[
        Row(children: [
          Sign2DigitalCheckbox(
            key: Key('site-report-section-$i'),
            value: _selectedSections.contains(SiteReportSection.values[i]),
            showLabel: false, boxSize: 16,
            label: SiteReportSection.values[i].label,
            onChanged: (value) => setState(() {
              if (value) {
                _selectedSections.add(SiteReportSection.values[i]);
              } else {
                _selectedSections.remove(SiteReportSection.values[i]);
              }
              _error = null;
            }),
          ),
          const SizedBox(width: 10),
          Expanded(child: InkWell(
            onTap: () => setState(() {
              final section = SiteReportSection.values[i];
              if (!_selectedSections.add(section)) {
                _selectedSections.remove(section);
              }
              _error = null;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(SiteReportSection.values[i].label,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 14, height: 1.0,
                  fontWeight: FontWeight.w500, letterSpacing: -0.3,
                  color: AppColors.placeholder,
                )),
            ),
          )),
        ]),
        if (i < SiteReportSection.values.length - 1)
          const SizedBox(height: 15),
      ],
    ],
  );

  Widget _content() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_selectedSections.contains(SiteReportSection.siteProgress)) ...[
        const Text('Site Programs', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 10),
        Sign2DigitalOutlinedContainer(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(15),
          child: TextFormField(
            key: const Key('site-report-content-siteProgress'),
            controller: _contents[SiteReportSection.siteProgress]!,
            minLines: 3,
            maxLines: null,
            style: AppTextStyles.fieldInput,
            decoration: const InputDecoration(
              hintText: 'Kitchen renovations, processes of renovating, '
                  'color selection, and labour work',
              hintStyle: AppTextStyles.fieldHint,
              isCollapsed: true,
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],

      // The upload control is always available, even when Photos wasn't
      // selected in Details. Uploading automatically selects that section.
      ...[
        const Text('Photos', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 10),
        GridView.builder(
          key: const Key('site-report-photo-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            // No photos: one full-width upload tile, not a half-empty grid.
            crossAxisCount: _photos.isEmpty ? 1 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 15,
            childAspectRatio: _photos.isEmpty ? 390 / 160 : 188 / 118,
          ),
          itemCount: _photos.length + 1,
          itemBuilder: (context, index) {
            if (index == _photos.length) {
              return Material(
                elevation: 0.5,
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: const Key('site-report-add-photos'),
                  onTap: _picking ? null : _choosePhotoSource,
                  borderRadius: BorderRadius.circular(10),
                  child: Sign2DigitalOutlinedContainer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/cloud-upload-outlined.svg',
                          width: 24, height: 24,
                        ),
                        const SizedBox(height: 8),
                        const Text('Add Photo', style: AppTextStyles.outlinedButton),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Sign2DigitalPhotoPreview(
              key: Key('site-report-photo-$index'),
              bytes: _photos[index].bytes,
              showDemo: false,
              compactTile: true,
              onRemove: () => setState(() {
                _photos.removeAt(index);
                if (_photos.isEmpty) {
                  // Last photo removed: return to optional upload-only state.
                  _selectedSections.remove(SiteReportSection.photos);
                }
                _error = null;
              }),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
      if (_selectedSections.contains(SiteReportSection.notes)) ...[
        Sign2DigitalInputField(
          key: const Key('site-report-content-notes'),
          label: 'Notes & Observations',
          hintText: _sectionHints[SiteReportSection.notes]!,
          iconAsset: 'assets/icons/description.svg',
          controller: _contents[SiteReportSection.notes]!,
          minLines: 2, maxLines: null,
        ),
        const SizedBox(height: 20),
      ],
      if (_selectedSections.contains(SiteReportSection.issues)) ...[
        Sign2DigitalSelectionField(
          key: const Key('site-report-content-issues'),
          label: 'Issues & Risks',
          hintText: 'e.g, Site report',
          iconAsset: 'assets/icons/description.svg',
          value: _riskSelection,
          trailing: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.secondaryText),
          onTap: _selectRisk,
        ),
        if (_riskSelection == 'Other') ...[
          const SizedBox(height: 15),
          Sign2DigitalInputField(
            key: const Key('site-report-other-risk'),
            label: 'Describe Issues & Risks',
            hintText: 'Describe the issues and risks',
            iconAsset: 'assets/icons/description.svg',
            controller: _otherRisk,
            minLines: 2, maxLines: null,
            onChanged: (value) {
              _contents[SiteReportSection.issues]!.text =
                  'Other: ${value.trim()}';
            },
          ),
        ],
        const SizedBox(height: 20),
      ],
      for (final field in <(String, TextEditingController)>[
        ('Attendees', _attendees),
        ('Absentees', _absentees),
        ('Decisions', _decisions),
        ('Outstanding Points', _outstanding),
        ('Next Steps', _nextSteps),
        ('Action Items', _actions),
      ]) ...[
        Sign2DigitalInputField(
          label: field.$1, hintText: field.$1,
          iconAsset: 'assets/icons/description.svg',
          controller: field.$2, minLines: 2, maxLines: null,
        ),
        const SizedBox(height: 15),
      ],
      for (final section in [SiteReportSection.materials, SiteReportSection.labour])
        if (_selectedSections.contains(section)) ...[
          Sign2DigitalInputField(
            key: Key('site-report-content-${section.name}'),
            label: section.label,
            hintText: _sectionHints[section]!,
            iconAsset: 'assets/icons/description.svg',
            controller: _contents[section]!,
            minLines: 2, maxLines: null,
          ),
          const SizedBox(height: 20),
        ],
    ],
  );

  Widget _review() => SiteReportReviewContent(
    report: _draftRecord(),
    showInstruction: true,
    onChooseJob: _chooseJob,
    onChooseDate: _chooseDate,
    onEditDetails: () => _showStep(0),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      bottom: false,
      child: Column(children: [
        Sign2DigitalHeader(
          title: _step == 2 ? 'Review Reports' : 'Site Reports',
          onBack: _back,
        ),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            controller: _scroll,
            key: const Key('site-report-wizard-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sign2DigitalWizardStepper(
                  currentStep: _step,
                  labels: const ['Details', 'Content', 'Review'],
                ),
                const SizedBox(height: 20),
                if (_step == 0) _details()
                else if (_step == 1) _content()
                else _review(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('site-report-validation'),
                    style: const TextStyle(fontFamily: 'Inter',
                      color: Color(0xFFB42318), fontSize: 12)),
                ],
                SizedBox(height: _step == 2 ? 20 : 25),
                if (_step == 0)
                  Sign2DigitalPrimaryButton(
                    key: const Key('site-report-next'),
                    label: 'Next',
                    onPressed: _next,
                  )
                else
                  Row(children: [
                    Expanded(child: Sign2DigitalOutlinedButton(
                      key: const Key('site-report-content-back'),
                      label: 'Back',
                      primaryOutline: true,
                      onPressed: _back,
                    )),
                    SizedBox(width: _step == 2 ? 10 : 12),
                    Expanded(child: Sign2DigitalPrimaryButton(
                      key: const Key('site-report-next'),
                      label: _step == 2 ? 'Generate Report' : 'Next',
                      loading: _saving,
                      onPressed: _step == 2 ? _generateReport : _next,
                    )),
                  ]),
              ],
            ),
          ),
        ))),
      ]),
    ),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: widget.selectedNavigationIndex,
      onSelected: _navigate,
    ),
  );
}
