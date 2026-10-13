import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_ai_voice_button.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_image_upload.dart';
import '../../../../core/widgets/sign2digital_input_field.dart';
import '../../../../core/widgets/sign2digital_outlined_button.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_selection_field.dart';
import '../../../jobs/presentation/widgets/ai_voice_flow_dialog.dart';
import '../../../jobs/services/voice_job_extraction_service.dart';
import '../../../jobs/services/voice_recorder_service.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../data/demo_document_repository.dart';
import '../../domain/addendum_draft.dart';
import '../../domain/document_record.dart';
import '../../services/addendum_voice_extraction_service.dart';
import 'document_details_screen.dart';

/// Flutter-only addendum editing. Neither "Create" nor AI asserts server approval.
class CreateAddendumScreen extends StatefulWidget {
  const CreateAddendumScreen({
    super.key,
    this.linkedDocument,
    this.repository,
    this.draftId,
    this.voiceRecorderFactory,
    this.voiceExtractionService,
    this.requestTemporaryApiKey,
  });

  final DocumentRecord? linkedDocument;
  final DocumentRepository? repository;
  final String? draftId;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final AddendumVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;

  @override
  State<CreateAddendumScreen> createState() => _CreateAddendumScreenState();
}

class _CreateAddendumScreenState extends State<CreateAddendumScreen> {
  final _number = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final DocumentRepository _repository;
  late final String _id;
  DocumentRecord? _linked;
  DateTime? _effectiveDate;
  PlatformFile? _logo;
  bool _voiceOpen = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const DemoDocumentRepository();
    _id = widget.draftId ?? 'local-addendum-${DateTime.now().microsecondsSinceEpoch}';
    final existing = AddendumDraftSession.load(_id);
    _number.text = existing?.number ?? '';
    _title.text = existing?.title ?? '';
    _description.text = existing?.description ?? '';
    _effectiveDate = existing?.effectiveDate;
    _logo = existing?.logo;
    _linked = widget.linkedDocument;
    if ((existing?.linkedDocumentId ?? '').isNotEmpty &&
        existing!.linkedDocumentId != _linked?.id) {
      _restoreLink(existing.linkedDocumentId!);
    }
  }

  Future<void> _restoreLink(String id) async {
    try {
      final records = await _repository.listDocuments();
      if (!mounted) return;
      for (final doc in records) {
        if (doc.id == id) {
          setState(() => _linked = doc);
          return;
        }
      }
    } catch (_) { _notice('Saved document link could not be restored.'); }
  }

  void _notice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  AddendumDraft _draft() => AddendumDraft(
    id: _id, number: _number.text.trim(),
    title: _title.text.trim(), description: _description.text.trim(),
    effectiveDate: _effectiveDate,
    linkedDocumentId: _linked?.id, logo: _logo,
  );

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseDocument({String? reference}) async {
    try {
      final all = await _repository.listDocuments();
      if (!mounted) return;
      final candidates = all.where((record) =>
          record.category != DocumentCategory.addends).toList();
      if (candidates.isEmpty) {
        _notice('No eligible documents are available to link.');
        return;
      }
      final matching = reference == null ? <DocumentRecord>[] : candidates
          .where((doc) =>
              doc.number.toLowerCase() == reference.trim().toLowerCase() ||
              doc.id.toLowerCase() == reference.trim().toLowerCase())
          .toList();
      // Even an exact AI match requires the user's explicit confirmation.
      final selection = await showModalBottomSheet<DocumentRecord>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Select an existing document')),
                if (reference != null)
                  ListTile(subtitle: Text(matching.length == 1
                      ? 'AI mentioned $reference. Select the matching record to confirm.'
                      : 'No unique match for "$reference". Select manually.')),
                for (final doc in candidates)
                  ListTile(
                    key: Key('addendum-document-choice-${doc.id}'),
                    title: Text(doc.title),
                    subtitle: Text(doc.project),
                    trailing: matching.contains(doc)
                        ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () => Navigator.of(sheet).pop(doc),
                  ),
              ],
            ),
          ),
        ),
      );
      if (selection != null && mounted) setState(() => _linked = selection);
    } catch (_) {
      _notice('Unable to load existing documents.');
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _effectiveDate = picked);
  }

  String _dateText(DateTime? value) {
    if (value == null) return 'August 25, 2026';
    const months = ['January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    return '${months[value.month-1]} ${value.day}, ${value.year}';
  }

  Future<String?> _askApiKey(BuildContext context) async {
    String key = '';
    bool hidden = true;
    return showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: const Text('Connect Addendum AI'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('For personal testing only. Enter a temporary OpenAI API key. '
                'It is not saved or committed. Do not use this approach in a public app.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('addendum-api-key'),
              obscureText: hidden,
              onChanged: (value) => key = value,
              decoration: InputDecoration(
                labelText: 'OpenAI API key',
                suffixIcon: IconButton(
                  onPressed: () => update(() => hidden = !hidden),
                  icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
            FilledButton(
              key: const Key('addendum-api-connect'),
              onPressed: () {
                if (key.trim().isNotEmpty) Navigator.pop(dialog, key.trim());
              },
              child: const Text('Process recording'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applySuggestions(AddendumVoiceSuggestion result) async {
    if (!mounted) return;
    var applied = 0;
    setState(() {
      if (_number.text.trim().isEmpty && result.number != null) {
        _number.text = result.number!; applied++;
      }
      if (_title.text.trim().isEmpty && result.title != null) {
        _title.text = result.title!; applied++;
      }
      if (_description.text.trim().isEmpty && result.description != null) {
        _description.text = result.description!; applied++;
      }
      if (_effectiveDate == null && result.effectiveDate != null) {
        _effectiveDate = result.effectiveDate; applied++;
      }
    });
    if (_linked == null && result.documentReference != null) {
      await _chooseDocument(reference: result.documentReference);
    }
    _notice('AI suggested $applied fields. Review before saving or creating.');
  }

  Future<void> _voice() async {
    if (_voiceOpen) return;
    _voiceOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x80000000),
        useSafeArea: true,
        builder: (_) => AiVoiceFlowDialog(
          recorder: widget.voiceRecorderFactory?.call() ??
              LocalVoiceRecorderService(),
          // Not used in addendum mode; explicit processing callback below.
          extraction: OpenAiVoiceJobExtractionService(),
          recordingTitle: 'Record Addendum Details',
          onAudioProcessed: (path) async {
            final key = await (widget.requestTemporaryApiKey?.call(context) ??
                _askApiKey(context));
            if (key == null) {
              throw StateError('AI processing was cancelled. You can retry.');
            }
            final fields = await (widget.voiceExtractionService ??
                OpenAiAddendumVoiceExtractionService()).extract(path, key);
            await _applySuggestions(fields);
          },
        ),
      );
    } finally {
      _voiceOpen = false;
    }
  }

  void _saveDraft() {
    AddendumDraftSession.save(_draft());
    _notice('Addendum draft saved locally on this device for this session.');
  }

  Future<void> _create() async {
    if (_creating) return;
    final draft = _draft();
    if (draft.validationIssues.isNotEmpty) {
      _notice(draft.validationIssues.first);
      return;
    }
    if (AddendumDraftSession.isNumberUsed(draft.number, exceptId: draft.id)) {
      _notice('This addendum number is already used.');
      return;
    }
    setState(() => _creating = true);
    try {
      final eligible = await _repository.listDocuments();
      final linked = eligible.where((doc) =>
          doc.id == draft.linkedDocumentId &&
          doc.category != DocumentCategory.addends).toList();
      if (linked.length != 1) {
        _notice('The selected document is no longer available.');
        return;
      }
      AddendumDraftSession.create(draft);
      if (!mounted) return;
      final record = DocumentRecord(
        id: draft.id,
        category: DocumentCategory.addends,
        number: draft.number, title: 'Addendum ${draft.number}',
        project: draft.title,
        customer: linked.single.customer,
        timestamp: DateTime.now(),
        status: 'Draft',
        demoOnly: true,
        createdAt: DateTime.now(),
        validUntil: draft.effectiveDate,
        related: [linked.single],
      );
      _notice('Addendum created locally for UI testing; not sent or signed.');
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => DocumentDetailsScreen(
          documentId: record.id, document: record)),
      );
    } catch (error) {
      _notice('Unable to create addendum: $error');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _field(String label, String hint, String asset,
      TextEditingController controller, {int? maxLines}) =>
      Sign2DigitalInputField(
        label: label, hintText: hint, iconAsset: asset,
        controller: controller, maxLines: maxLines ?? 1,
        minLines: maxLines == null ? 1 : 2,
      );

  Widget _footer() => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 315;
      final draft = Sign2DigitalOutlinedButton(
        key: const Key('addendum-save-draft'),
        label: 'Save as Draft', onPressed: _saveDraft,
        primaryOutline: true,
      );
      final create = Sign2DigitalPrimaryButton(
        key: const Key('addendum-create'),
        label: 'Create Addendum', loading: _creating, onPressed: _create,
      );
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [draft, const SizedBox(height: 12), create],
        );
      }
      return Row(children: [
        Expanded(child: draft), const SizedBox(width: 12),
        Expanded(child: create),
      ]);
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: Column(children: [
      Sign2DigitalHeader(title: 'Addendum',
        onBack: () => Navigator.of(context).maybePop()),
      Expanded(child: SingleChildScrollView(
        key: const Key('create-addendum-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Sign2DigitalAiVoiceButton(onPressed: _voice),
              const SizedBox(height: 20),
              const Text('Link to Existing Documents', style: TextStyle(
                fontFamily: 'Inter', fontSize: 18,
                fontWeight: FontWeight.w600, color: AppColors.dark,
                letterSpacing: -0.3,
              )),
              const SizedBox(height: 10),
              if (_linked != null)
                Sign2DigitalQuoteSummaryCard(
                  key: const Key('addendum-linked-document'),
                  quoteNumber: _linked!.number,
                  titleOverride: _linked!.title,
                  projectName: _linked!.project,
                  linkedStyle: true,
                  onRemoveLink: () => setState(() => _linked = null),
                )
              else
                OutlinedButton.icon(
                  key: const Key('addendum-select-document'),
                  onPressed: _chooseDocument,
                  icon: const Icon(Icons.add),
                  label: const Text('Select an existing document'),
                ),
              const SizedBox(height: 22),
              _field('Addendum Number', 'e.g, A-0005',
                'assets/icons/hashtag.svg', _number),
              const SizedBox(height: 20),
              _field('Title', 'e.g, Marc dupont',
                'assets/icons/user.svg', _title),
              const SizedBox(height: 20),
              _field('Description',
                'Complete renovation of the terrace, including new tiles, waterproofing and railings',
                'assets/icons/description.svg', _description, maxLines: 4),
              const SizedBox(height: 20),
              Sign2DigitalSelectionField(
                key: const Key('addendum-effective-date'),
                label: 'Effective Dates',
                iconAsset: 'assets/icons/calendar-outlined.svg',
                hintText: 'August 25, 2026',
                value: _effectiveDate == null ? null : _dateText(_effectiveDate),
                onTap: _chooseDate,
              ),
              const SizedBox(height: 20),
              Sign2DigitalImageUpload(
                key: const Key('addendum-logo-upload'),
                initialFile: _logo,
                onChanged: (file) => setState(() => _logo = file),
              ),
              const SizedBox(height: 30),
              _footer(),
            ],
          ),
        )),
      )),
    ])),
  );
}
