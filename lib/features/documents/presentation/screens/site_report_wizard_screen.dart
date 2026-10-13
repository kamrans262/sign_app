import 'package:flutter/material.dart';
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
import '../../../jobs/presentation/widgets/sign2digital_photo_preview.dart';
import '../../domain/document_record.dart';

/// UI-only three-step site report wizard, never claims remote submission.
class SiteReportWizardScreen extends StatefulWidget {
  const SiteReportWizardScreen({
    super.key,
    this.initial,
    this.photoSource,
    this.onNavigationSelected,
    this.selectedNavigationIndex = 2,
  });

  final DocumentRecord? initial;
  final JobPhotoSource? photoSource;
  final ValueChanged<int>? onNavigationSelected;
  final int selectedNavigationIndex;

  @override
  State<SiteReportWizardScreen> createState() => _SiteReportWizardScreenState();
}

class _SiteReportWizardScreenState extends State<SiteReportWizardScreen> {
  static const _reportTitles = [
    'Site Report', 'Weekly Site Report', 'Site Inspection', 'Custom title',
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
      if (_reportTitles.contains(initial.title)) {
        _title = initial.title;
      } else {
        _title = 'Custom title';
        _customTitle.text = initial.title;
      }
      final details = initial.siteReportDetails;
      if (details != null) {
        _reportDate = details.reportDate;
        _preparer.text = details.preparedBy;
        _weather = details.weatherCondition;
        _selectedSections
          ..clear()
          ..addAll(details.selectedSections);
        for (final item in details.sectionContent.entries) {
          _contents[item.key]?.text = item.value;
        }
        _photos = List.of(details.photos);
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _preparer.dispose();
    _customTitle.dispose();
    for (final controller in _contents.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _actualTitle => _title == 'Custom title'
      ? _customTitle.text.trim() : (_title ?? '');

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
  }) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(title)),
            for (var i = 0; i < options.length; i++)
              ListTile(
                key: Key('$keyPrefix-$i'),
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
    if ((_weather ?? '').isEmpty) { return 'Choose a weather condition.'; }
    if (_selectedSections.isEmpty) { return 'Select at least one report section.'; }
    return null;
  }

  String? _contentIssue() {
    if (_picking) { return 'Wait for photo selection to finish.'; }
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
    final action = await showModalBottomSheet<bool>(
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
    final prior = _contents[SiteReportSection.issues]!.text;
    await _pickOption(
      options: _riskOptions,
      title: 'Issues & Risks',
      keyPrefix: 'site-report-risk-option',
      onSelected: (selection) =>
          _contents[SiteReportSection.issues]!.text = selection,
    );
    if (!mounted || _contents[SiteReportSection.issues]!.text != 'Other') {
      return;
    }
    var description = '';
    final custom = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Describe the issue or risk'),
        content: TextFormField(
          key: const Key('site-report-custom-risk'),
          initialValue: prior == 'Other' ? '' : prior,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          onChanged: (value) => description = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('site-report-save-risk'),
            onPressed: () => Navigator.of(dialog).pop(description.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) { return; }
    setState(() {
      _contents[SiteReportSection.issues]!.text =
          custom == null || custom.isEmpty ? prior : custom;
    });
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
    final error = _detailsIssue() ?? _contentIssue();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final id = widget.initial?.id ??
          'local-site-report-${now.microsecondsSinceEpoch}';
      final data = SiteReportDetails(
        reportDate: _reportDate!,
        preparedBy: _preparer.text.trim(),
        weatherCondition: _weather!,
        selectedSections: List.unmodifiable(
          SiteReportSection.values.where(_selectedSections.contains)),
        sectionContent: Map.unmodifiable({
          for (final section in _selectedSections)
            if (section != SiteReportSection.photos)
              section: _contents[section]!.text.trim(),
        }),
        photos: List.unmodifiable(_photos),
      );
      final draft = DocumentRecord(
        id: id,
        category: DocumentCategory.reports,
        reportKind: ReportKind.siteReport,
        number: widget.initial?.number ?? id,
        title: _actualTitle,
        // An unlinked job/customer is not represented as a fictitious one.
        project: widget.initial?.project ?? '',
        customer: widget.initial?.customer ?? '',
        timestamp: widget.initial?.timestamp ?? now,
        status: 'Draft',
        demoOnly: true,
        createdAt: widget.initial?.createdAt ?? now,
        updatedAt: now,
        createdBy: data.preparedBy,
        siteReportDetails: data,
      );
      if (mounted) { Navigator.of(context).pop(draft); }
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
        value: _title == 'Custom title' ? null : _title,
        trailing: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.secondaryText),
        onTap: () => _pickOption(
          options: _reportTitles, title: 'Report Title',
          keyPrefix: 'site-report-title-option',
          onSelected: (value) => _title = value,
        ),
      ),
      if (_title == 'Custom title') ...[
        const SizedBox(height: 15),
        Sign2DigitalInputField(
          key: const Key('site-report-custom-title'),
          label: 'Custom report title',
          hintText: 'Enter the report title',
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
          onSelected: (value) => _weather = value,
        ),
      ),
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
      if (_selectedSections.contains(SiteReportSection.photos)) ...[
        const Text('Photos', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 10),
        GridView.builder(
          key: const Key('site-report-photo-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 15,
            childAspectRatio: 188 / 118,
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
              onRemove: () => setState(() => _photos.removeAt(index)),
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
          value: _contents[SiteReportSection.issues]!.text.isEmpty
              ? null : _contents[SiteReportSection.issues]!.text,
          trailing: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.secondaryText),
          onTap: _selectRisk,
        ),
        const SizedBox(height: 20),
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

  Widget _reviewLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600,
          color: AppColors.dark)),
        const SizedBox(height: 5),
        Text(value, style: AppTextStyles.fieldInput),
      ],
    ),
  );

  Widget _review() => Sign2DigitalOutlinedContainer(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Review Site Report', style: AppTextStyles.fieldLabel),
      const SizedBox(height: 20),
      _reviewLine('Report Title', _actualTitle),
      _reviewLine('Report Date', _dateText(_reportDate!)),
      _reviewLine('Prepared By', _preparer.text.trim()),
      _reviewLine('Weather Condition', _weather!),
      for (final section in SiteReportSection.values)
        if (_selectedSections.contains(section))
          _reviewLine(section.label,
            section == SiteReportSection.photos
              ? _photos.map((photo) => photo.name).join(', ')
              : _contents[section]!.text.trim()),
      const Text(
        'This is a local draft only. No report is submitted or approved.',
        key: Key('site-report-demo-notice'),
        style: TextStyle(fontFamily: 'Inter', fontSize: 12,
          color: AppColors.secondaryText),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      bottom: false,
      child: Column(children: [
        Sign2DigitalHeader(title: 'Site Reports', onBack: _back),
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
                const SizedBox(height: 25),
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
                    const SizedBox(width: 12),
                    Expanded(child: Sign2DigitalPrimaryButton(
                      key: const Key('site-report-next'),
                      label: _step == 2 ? 'Save Draft' : 'Next',
                      loading: _saving,
                      onPressed: _step == 2 ? _save : _next,
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
