import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';

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
import '../../../quotes/domain/quote_review_models.dart' show quoteMoney;
import '../../data/demo_document_repository.dart';
import '../../data/remote_addendum_repository.dart';
import '../../data/remote_document_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../domain/addendum_draft.dart';
import '../../domain/addendum_signature_request.dart';
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
    this.requestAddendumSignature,
  });

  final DocumentRecord? linkedDocument;
  final DocumentRepository? repository;
  final String? draftId;
  final VoiceRecorderService Function()? voiceRecorderFactory;
  final AddendumVoiceExtractionService? voiceExtractionService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;
  final AddendumSignatureRequestService? requestAddendumSignature;

  @override
  State<CreateAddendumScreen> createState() => _CreateAddendumScreenState();
}

class _CreateAddendumScreenState extends State<CreateAddendumScreen> {
  final _number = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _additionalWork = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _vat = TextEditingController(text: '0');
  late final DocumentRepository _repository;
  late final String _id;
  DocumentRecord? _linked;
  DateTime? _effectiveDate;
  PlatformFile? _logo;
  bool _voiceOpen = false;
  bool _creating = false;
  AddendumDraft? _serverDraft;

  bool get _live => MobileAuthRepository.shared.isSignedIn &&
      (widget.repository == null ||
          widget.repository is RemoteDocumentRepository);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (_live ? RemoteDocumentRepository.shared
            : const DemoDocumentRepository());
    _id = widget.draftId ?? 'local-addendum-${DateTime.now().microsecondsSinceEpoch}';
    final existing = AddendumDraftSession.load(_id);
    _serverDraft = existing?.serverId != null ? existing : null;
    if (existing == null && _live &&
        RegExp(r'^addendum-[1-9][0-9]*$').hasMatch(_id)) {
      _restoreServerDraft(int.parse(_id.substring('addendum-'.length)));
    }
    _number.text = existing?.number ?? '';
    _title.text = existing?.title ?? '';
    _description.text = existing?.description ?? '';
    _additionalWork.text = existing?.additionalWork ?? '';
    _quantity.text = existing?.quantity ?? '';
    _unitPrice.text = existing?.unitPrice ?? '';
    _vat.text = existing == null
        ? '0' : (existing.vatBasisPoints / 100).toStringAsFixed(2);
    _effectiveDate = existing?.effectiveDate;
    _logo = existing?.logo;
    _linked = widget.linkedDocument;
    if ((existing?.linkedDocumentId ?? '').isNotEmpty &&
        existing!.linkedDocumentId != _linked?.id) {
      _restoreLink(existing.linkedDocumentId!);
    }
  }

  Future<void> _restoreServerDraft(int id) async {
    try {
      final remote = await RemoteAddendumRepository.shared.get(id);
      if (!mounted) return;
      setState(() {
        _serverDraft = remote;
        _number.text = remote.number;
        _title.text = remote.title;
        _description.text = remote.description;
        _additionalWork.text = remote.additionalWork;
        _quantity.text = remote.quantity;
        _unitPrice.text = remote.unitPrice;
        _vat.text = (remote.vatBasisPoints / 100).toStringAsFixed(2);
        _effectiveDate = remote.effectiveDate;
      });
      if (remote.linkedDocumentId != null) {
        await _restoreLink(remote.linkedDocumentId!);
      }
    } catch (_) {
      _notice('Saved addendum could not be loaded.');
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
    id: _serverDraft?.id ?? _id, number: _number.text.trim(),
    serverId: _serverDraft?.serverId,
    serverRevision: _serverDraft?.serverRevision,
    serverStatus: _serverDraft?.serverStatus ?? 'draft',
    currency: _serverDraft?.currency ?? 'CHF',
    quoteServerId: _serverDraft?.quoteServerId,
    title: _title.text.trim(), description: _description.text.trim(),
    effectiveDate: _effectiveDate,
    linkedDocumentId: _linked?.id, logo: _logo,
    additionalWork: _additionalWork.text.trim(),
    quantity: _quantity.text.trim(),
    unitPrice: _unitPrice.text.trim(),
    vatBasisPoints: _vatBasisPoints,
    linkedDocumentNumber: _linked?.number,
    linkedJobId: _linked?.jobId ?? _linked?.quote?.jobId,
    linkedClientId: _serverDraft?.linkedClientId ??
        _linked?.quote?.clientId,
  );

  int get _vatBasisPoints {
    final raw = double.tryParse(_vat.text.trim());
    if (raw == null || !raw.isFinite || raw < 0 || raw > 100 ||
        (raw * 100 - (raw * 100).round()).abs() > 0.00001) {
      return -1;
    }
    return (raw * 100).round();
  }

  void _reviewAddendum() {
    final draft = _draft();
    if (draft.validationIssues.isNotEmpty) {
      _notice(draft.validationIssues.first);
      return;
    }
    final source = _linked;
    if (source == null || source.id != draft.linkedDocumentId) {
      _notice('Select the original document before reviewing.');
      return;
    }
    showSign2DigitalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Review Addendum', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600,
            fontFamily: 'Inter', color: AppColors.dark)),
          const SizedBox(height: 12),
          Text('Original: ${source.number}'),
          Text('Addendum: ${draft.number}'),
          Text(draft.title),
          const SizedBox(height: 10),
          Text(draft.description),
          if (draft.hasPricedWork) ...[
            const SizedBox(height: 10),
            Text('Additional work: ${draft.additionalWork}'),
            Text('Quantity: ${draft.quantity}'),
            Text('Unit price: ${draft.unitPrice} CHF'),
          ],
          const SizedBox(height: 10),
          Text('Subtotal: ${quoteMoney(draft.subtotalMinor, 'CHF')}'),
          Text('VAT (${(draft.vatBasisPoints / 100).toStringAsFixed(2)}%): '
            '${quoteMoney(draft.vatMinor, 'CHF')}'),
          Text('Total: ${quoteMoney(draft.totalMinor, 'CHF')}'),
          const SizedBox(height: 10),
          const Text('Unsigned draft — customer approval has not been requested.'),
          const SizedBox(height: 14),
          Sign2DigitalPrimaryButton(
            key: const Key('addendum-review-close'),
            label: 'Continue Editing',
            onPressed: () => Navigator.pop(sheet),
          ),
        ]),
      )),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    _description.dispose();
    _additionalWork.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _vat.dispose();
    super.dispose();
  }

  Future<void> _chooseDocument({String? reference}) async {
    try {
      final all = await _repository.listDocuments();
      if (!mounted) return;
      final candidates = all.where((record) => _live
          ? record.id.startsWith('signed-') &&
              record.status.toLowerCase() == 'signed' &&
              record.verifiedSignedPdfAvailable
          : record.category != DocumentCategory.addends).toList();
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
      final selection = await showSign2DigitalBottomSheet<DocumentRecord>(
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
      if (_additionalWork.text.trim().isEmpty &&
          result.additionalWork != null) {
        _additionalWork.text = result.additionalWork!; applied++;
      }
      if (_quantity.text.trim().isEmpty && result.quantity != null &&
          RegExp(r'^[1-9][0-9]{0,5}$').hasMatch(result.quantity!) &&
          int.parse(result.quantity!) <= 100000) {
        _quantity.text = result.quantity!; applied++;
      }
      if (_unitPrice.text.trim().isEmpty && result.unitPrice != null &&
          RegExp(r'^\d{1,10}(\.\d{1,2})?$')
              .hasMatch(result.unitPrice!)) {
        _unitPrice.text = result.unitPrice!; applied++;
      }
      if (_vat.text.trim() == '0' && result.vatPercent != null) {
        final bps = double.tryParse(result.vatPercent!);
        if (bps != null && bps.isFinite && bps >= 0 && bps <= 100 &&
            (bps * 100 - (bps * 100).round()).abs() < .00001) {
          _vat.text = result.vatPercent!; applied++;
        }
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
            if (_live) {
              // Authenticated Laravel proxy; no API key exposed to mobile.
              final fields = await RemoteAddendumRepository.shared
                  .prepareVoice(path);
              await _applySuggestions(fields);
              return;
            }
            // Explicitly injected isolated testing service only.
            final key = await widget.requestTemporaryApiKey?.call(context);
            final extractor = widget.voiceExtractionService;
            if (key == null || extractor == null) {
              throw StateError('Sign in to use Addendum AI voice.');
            }
            await _applySuggestions(await extractor.extract(path, key));
          },
        ),
      );
    } finally {
      _voiceOpen = false;
    }
  }

  Future<void> _saveDraft() async {
    if (_creating) return;
    if (!_live) {
      AddendumDraftSession.save(_draft());
      _notice('Addendum draft saved locally on this device for this session.');
      return;
    }
    final draft = _draft();
    if (draft.validationIssues.isNotEmpty) {
      _notice(draft.validationIssues.first);
      return;
    }
    setState(() => _creating = true);
    try {
      final saved = await RemoteAddendumRepository.shared.save(draft);
      if (!mounted) return;
      setState(() => _serverDraft = saved);
      _notice('Addendum draft saved securely to your company.');
    } catch (_) {
      _notice('Unable to save addendum draft. No approval was recorded.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
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
      final original = linked.single;
      final snapshot = draft.copyWith(
        linkedDocumentNumber: original.number,
        linkedJobId: original.jobId ?? original.quote?.jobId,
        linkedClientId: original.quote?.clientId ??
            _serverDraft?.linkedClientId,
      );
      if (_live) {
        if (!RegExp(r'^signed-[1-9][0-9]*$').hasMatch(original.id) ||
            !original.verifiedSignedPdfAvailable ||
            original.status.toLowerCase() != 'signed') {
          _notice('A verified signed original is required to create an addendum.');
          return;
        }
        // M10 persists the distinct draft. Approval and customer consent are
        // separate explicit steps; neither is fabricated by this action.
        final saved = await RemoteAddendumRepository.shared.save(snapshot);
        if (!mounted) return;
        final details = await RemoteDocumentRepository.shared
            .details(saved.id);
        if (!mounted) return;
        _serverDraft = saved;
        _notice('Addendum draft saved to the company; review before approving.');
        unawaited(Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(builder: (_) => DocumentDetailsScreen(
            documentId: details.id,
            document: details,
            loadDocument: RemoteDocumentRepository.shared.details,
            loadSignedPdf: RemoteDocumentRepository.shared.downloadPdf,
            requestAddendumSignature:
                RemoteAddendumRepository.shared.requestSignature,
            onApproveAddendum: (record) async {
              final serverId = int.parse(
                record.id.substring('addendum-'.length));
              final draft = await RemoteAddendumRepository.shared.get(serverId);
              await RemoteAddendumRepository.shared.approve(draft);
              return RemoteDocumentRepository.shared.details(record.id);
            },
          )),
        ));
        return;
      }
      AddendumDraftSession.create(snapshot);
      if (!mounted) return;
      final record = DocumentRecord(
        id: draft.id,
        category: DocumentCategory.addends,
        number: draft.number, title: 'Addendum ${draft.number}',
        project: original.project,
        customer: original.customer,
        timestamp: DateTime.now(),
        status: 'Draft',
        demoOnly: original.demoOnly,
        addendumDraftId: draft.id,
        createdAt: DateTime.now(),
        validUntil: draft.effectiveDate,
        related: [original],
      );
      _notice('Addendum created locally for UI testing; not sent or signed.');
      // Navigation completes only when the details route is later popped;
      // creating the addendum must not await that future.
      unawaited(Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => DocumentDetailsScreen(
          documentId: record.id, document: record,
          requestAddendumSignature: widget.requestAddendumSignature)),
      ));
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
        enabled: !_creating, primaryOutline: true,
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
        // Stretch to the available landscape/tablet width with the same
        // established 20px horizontal padding, no centered fixed-width panel.
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
              _field('Additional Work (optional for non-financial changes)',
                'Describe the additional work',
                'assets/icons/description.svg', _additionalWork),
              const SizedBox(height: 20),
              _field('Quantity', 'e.g, 2',
                'assets/icons/hashtag.svg', _quantity),
              const SizedBox(height: 20),
              _field('Unit Price (${_serverDraft?.currency ?? 'CHF'})', 'e.g, 250.00',
                'assets/icons/hashtag.svg', _unitPrice),
              const SizedBox(height: 20),
              _field('VAT (%)', 'e.g, 8.10',
                'assets/icons/hashtag.svg', _vat),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: Listenable.merge([_additionalWork, _quantity,
                  _unitPrice, _vat]),
                builder: (context, child) {
                  final draft = _draft();
                  return Text(
                    'Addendum Total: ${quoteMoney(draft.totalMinor, draft.currency)}',
                    key: const Key('addendum-total'),
                    style: const TextStyle(fontFamily: 'Inter',
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: AppColors.dark),
                  );
                },
              ),
              const SizedBox(height: 20),
              Sign2DigitalOutlinedButton(
                key: const Key('addendum-review'),
                label: 'Review Addendum',
                onPressed: _reviewAddendum,
                primaryOutline: true,
              ),
              const SizedBox(height: 20),
              Sign2DigitalSelectionField(
                key: const Key('addendum-effective-date'),
                label: 'Effective Dates',
                iconAsset: 'assets/icons/calendar-outlined.svg',
                hintText: 'Select effective date',
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
    ])),
  );
}
