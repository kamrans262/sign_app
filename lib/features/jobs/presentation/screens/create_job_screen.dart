import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_info_banner.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../clients/data/client_repository.dart';
import '../../../clients/data/demo_client_repository.dart';
import '../../../clients/domain/client_profile.dart';
import '../../domain/create_job_draft.dart';
import '../../models/extracted_job_details.dart';
import '../../services/voice_job_extraction_service.dart';
import '../../services/voice_recorder_service.dart';
import '../widgets/ai_voice_flow_dialog.dart';

/// Create Job screen. Voice suggestions are optional; job creation stays manual.
class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({
    super.key,
    this.initialClient,
    this.clientRepository,
    this.onCreateJob,
    this.onCreateWithAiVoice,
    this.voiceRecorderFactory,
    this.voiceExtractionService,
  });

  final ClientProfile? initialClient;
  final ClientRepository? clientRepository;
  final ValueChanged<CreateJobDraft>? onCreateJob;
  final VoidCallback? onCreateWithAiVoice;

  /// Injectable for platform-free widget tests and custom recording providers.
  final VoiceRecorderService Function()? voiceRecorderFactory;

  /// Optional injection for tests. Default: in-memory-key direct OpenAI service.
  final VoiceJobExtractionService? voiceExtractionService;

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _DemoMember {
  const _DemoMember(this.id, this.name);
  final String id;
  final String name;
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _voiceOpen = false;
  late final VoiceJobExtractionService _voiceExtraction;
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  late final ClientRepository _repository;
  ClientProfile? _client;
  DateTime? _start;
  DateTime? _end;
  String? _clientError;
  String? _startError;
  String? _endError;
  final Set<String> _memberIds = <String>{};

  static const _members = <_DemoMember>[
    _DemoMember('demo-member-1', 'Marc Dupont'),
    _DemoMember('demo-member-2', 'Jean Martin'),
    _DemoMember('demo-member-3', 'Sophie Bernard'),
    _DemoMember('demo-member-4', 'Claire Laurent'),
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.clientRepository ?? DemoClientRepository();
    _voiceExtraction =
        widget.voiceExtractionService ?? OpenAiVoiceJobExtractionService();
    _client = widget.initialClient;
    if (_client != null && _client!.address.trim().isNotEmpty) {
      _address.text = _client!.address;
    }
  }

  @override
  void dispose() {
    if (_voiceExtraction is OpenAiVoiceJobExtractionService) {
      _voiceExtraction.clearTemporaryApiKey();
    }
    _address.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _selectClient() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final clients = await _repository.listClients();
    if (!mounted) {
      return;
    }
    final result = await showModalBottomSheet<ClientProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .68,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select client', style: AppTextStyles.heading),
              ),
              Flexible(
                child: clients.isEmpty
                    ? const Center(child: Text('No clients available'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: clients.length,
                        itemBuilder: (context, index) {
                          final item = clients[index];
                          return ListTile(
                            key: ValueKey('select-${item.id}'),
                            title: Text(item.companyName),
                            subtitle: Text(item.email),
                            trailing: _client?.id == item.id
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => Navigator.of(sheet).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _client = result;
      _clientError = null;
      if (_address.text.trim().isEmpty && result.address.isNotEmpty) {
        _address.text = result.address;
      }
    });
  }

  Future<void> _pickDate({required bool start}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final current = start ? _start : _end;
    final chosen = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current ?? DateTime(2026, 8, 25),
    );
    if (!mounted || chosen == null) {
      return;
    }
    setState(() {
      if (start) {
        _start = chosen;
        _startError = null;
      } else {
        _end = chosen;
        _endError = null;
      }
      if (_start != null && _end != null && _end!.isBefore(_start!)) {
        _endError = 'End Date cannot be before Start Date';
      }
    });
  }

  Future<void> _selectTeam() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final working = Set<String>.from(_memberIds);
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select team members', style: AppTextStyles.heading),
                const SizedBox(height: 12),
                for (final member in _members)
                  CheckboxListTile(
                    key: ValueKey('member-${member.id}'),
                    value: working.contains(member.id),
                    activeColor: AppColors.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(member.name),
                    onChanged: (value) => setSheetState(() {
                      if (value == true) {
                        working.add(member.id);
                      } else {
                        working.remove(member.id);
                      }
                    }),
                  ),
                Sign2DigitalPrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(sheet).pop(working),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _memberIds
        ..clear()
        ..addAll(selected);
    });
  }

  void _create() {
    FocusManager.instance.primaryFocus?.unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _clientError = _client == null ? 'Select a client' : null;
      _startError = _start == null ? 'Select a start date' : null;
      _endError = _end == null ? 'Select an end date' : null;
      if (_start != null && _end != null && _end!.isBefore(_start!)) {
        _endError = 'End Date cannot be before Start Date';
      }
    });
    if (!formValid ||
        _clientError != null ||
        _startError != null ||
        _endError != null) {
      return;
    }
    final value = _budget.text.trim();
    final draft = CreateJobDraft(
      clientId: _client!.id,
      clientName: _client!.companyName,
      address: _address.text.trim(),
      description: _description.text.trim(),
      startDate: _start!,
      endDate: _end!,
      budgetChf: value.isEmpty ? null : double.parse(value),
      teamMemberIds: List<String>.unmodifiable(_memberIds),
    );
    if (widget.onCreateJob != null) {
      widget.onCreateJob!(draft);
    } else {
      Navigator.of(context).pop(draft);
    }
  }

  Future<void> _voiceInfo() async {
    if (_voiceOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onCreateWithAiVoice != null) {
      widget.onCreateWithAiVoice!();
      return;
    }
    _voiceOpen = true;
    try {
      final suggested = await AiVoiceFlowDialog.show(
        context,
        recorder:
            widget.voiceRecorderFactory?.call() ?? LocalVoiceRecorderService(),
        extraction: _voiceExtraction,
      );
      if (mounted && suggested != null) {
        await _applyVoiceSuggestions(suggested);
      }
    } finally {
      _voiceOpen = false;
    }
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<void> _applyVoiceSuggestions(ExtractedJobDetails data) async {
    ClientProfile? identifiedClient;
    if (_client == null && data.clientName != null) {
      try {
        final clients = await _repository.listClients();
        final wanted = _normalize(data.clientName!);
        // Never invent client IDs. Duplicate demo names are ambiguous.
        final matches = clients
            .where(
              (client) =>
                  _normalize(client.companyName) == wanted ||
                  _normalize(client.fullName) == wanted ||
                  _normalize(client.email) == wanted,
            )
            .toList();
        if (matches.length == 1) identifiedClient = matches.single;
      } catch (_) {
        // Keep client unselected if repository is temporarily unavailable.
      }
    }
    if (!mounted) return;
    var updated = 0;
    setState(() {
      if (_client == null && identifiedClient != null) {
        _client = identifiedClient;
        _clientError = null;
        updated++;
      }
      if (_address.text.trim().isEmpty && data.address != null) {
        _address.text = data.address!;
        updated++;
      }
      if (_description.text.trim().isEmpty && data.description != null) {
        _description.text = data.description!;
        updated++;
      }
      if (_budget.text.trim().isEmpty && data.budgetChf != null) {
        _budget.text = data.budgetChf!.toStringAsFixed(2);
        updated++;
      }
      // Keep the date range valid; uncertain and conflicting dates stay unset.
      final suggestedStart = _start ?? data.startDate;
      final suggestedEnd = _end ?? data.endDate;
      if (suggestedStart == null ||
          suggestedEnd == null ||
          !suggestedEnd.isBefore(suggestedStart)) {
        if (_start == null && data.startDate != null) {
          _start = data.startDate;
          _startError = null;
          updated++;
        }
        if (_end == null && data.endDate != null) {
          _end = data.endDate;
          _endError = null;
          updated++;
        }
      }
      for (final spokenName in data.teamMemberNames) {
        final matches = _members
            .where(
              (member) => _normalize(member.name) == _normalize(spokenName),
            )
            .toList();
        if (matches.length == 1 && _memberIds.add(matches.single.id)) updated++;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated > 0
              ? 'AI filled $updated job details. Review them before creating the job.'
              : 'No new fields were filled. Your existing details were kept.',
        ),
      ),
    );
  }

  Widget _descriptionField() {
    return Sign2DigitalOutlinedContainer(
      constraints: const BoxConstraints(minHeight: 93),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/icons/description.svg',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 5),
                TextFormField(
                  key: const Key('job-description-input'),
                  controller: _description,
                  minLines: 2,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  scrollPadding: const EdgeInsets.all(100),
                  style: AppTextStyles.fieldInput,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter a description'
                      : null,
                  decoration: const InputDecoration(
                    hintText: 'Complete renovation of the terrace, including new tiles, waterproofing and railings',
                    hintStyle: AppTextStyles.fieldHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiVoiceButton() => Sign2DigitalAiVoiceButton(onPressed: _voiceInfo);

  Widget _submitButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Sign2DigitalPrimaryButton(
          key: const Key('create-new-job-button'),
          label: '',
          onPressed: _create,
        ),
        const IgnorePointer(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 24, color: AppColors.white),
              SizedBox(width: 10),
              Text('Create new job', style: AppTextStyles.primaryButton),
            ],
          ),
        ),
      ],
    );
  }

  String? _validateBudget(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value)) {
      return 'Enter a valid amount (up to 2 decimals)';
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return 'Enter a valid nonnegative amount';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedMembers = _members
        .where((item) => _memberIds.contains(item.id))
        .toList();
    final teamSummary = selectedMembers.isEmpty
        ? null
        : selectedMembers.length == 1
        ? selectedMembers.first.name
        : '${selectedMembers.length} team members selected';
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Sign2DigitalHeader(
              title: 'Create Job',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      key: const Key('create-job-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _aiVoiceButton(),
                          const SizedBox(height: 20),
                          Sign2DigitalSelectionField(
                            key: const Key('job-client-select'),
                            label: 'Client',
                            hintText: 'Select client',
                            iconAsset: 'assets/icons/user.svg',
                            value: _client?.companyName,
                            errorText: _clientError,
                            onTap: _selectClient,
                          ),
                          const SizedBox(height: 20),
                          Sign2DigitalInputField(
                            label: 'Address',
                            hintText: 'e.g. Rue du Centre 12, Lausanne',
                            iconAsset: 'assets/icons/address-book.svg',
                            controller: _address,
                            keyboardType: TextInputType.streetAddress,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          _descriptionField(),
                          const SizedBox(height: 20),
                          Sign2DigitalSelectionField(
                            key: const Key('job-start-date'),
                            label: 'Start Date',
                            hintText: 'August 25, 2026',
                            iconAsset: 'assets/icons/calendar-outlined.svg',
                            value: _start == null ? null : _formatDate(_start!),
                            errorText: _startError,
                            onTap: () => _pickDate(start: true),
                          ),
                          const SizedBox(height: 20),
                          Sign2DigitalSelectionField(
                            key: const Key('job-end-date'),
                            label: 'End Date',
                            hintText: 'August 25, 2026',
                            iconAsset: 'assets/icons/calendar-outlined.svg',
                            value: _end == null ? null : _formatDate(_end!),
                            errorText: _endError,
                            onTap: () => _pickDate(start: false),
                          ),
                          const SizedBox(height: 20),
                          Sign2DigitalInputField(
                            label: 'Budget (CHF)',
                            hintText: '98.00',
                            iconAsset: 'assets/icons/jobs.svg',
                            controller: _budget,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            validator: _validateBudget,
                          ),
                          const SizedBox(height: 20),
                          Sign2DigitalSelectionField(
                            key: const Key('job-team-select'),
                            label: 'Team Members',
                            hintText: 'Select team members',
                            iconAsset: 'assets/icons/team_members.svg',
                            value: teamSummary,
                            onTap: _selectTeam,
                          ),
                          const SizedBox(height: 20),
                          const Sign2DigitalInfoBanner(
                            message: 'You can add more details, documents and settings after creating the job',
                          ),
                          const SizedBox(height: 20),
                          _submitButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
