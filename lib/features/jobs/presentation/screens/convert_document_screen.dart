import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../quotes/domain/quote_draft_input.dart';
import '../../../quotes/domain/quote_extraction_models.dart';
import '../../../quotes/domain/quote_preparation_service.dart';
import '../../../quotes/presentation/screens/quote_ai_processing_screen.dart';
import '../../../quotes/presentation/widgets/sign2digital_document_status_timeline.dart';
import '../../../quotes/presentation/widgets/sign2digital_signature_action_card.dart';
import '../../../quotes/presentation/widgets/sign2digital_temporary_ai_key_dialog.dart';
import '../../../quotes/services/openai_quote_preparation_service.dart';
import '../../domain/job_note_model.dart';
import '../../domain/note_document_draft.dart';
import '../../services/openai_note_document_preparation_service.dart';
import '../widgets/sign2digital_job_note_card.dart';

enum ConvertedDocumentType { quote, report, letter, custom }

/// Takes an actual Job Note to the existing AI preparation workflow.
/// No generated document, price, progress percentage, or approval is invented.
class ConvertDocumentScreen extends StatefulWidget {
  const ConvertDocumentScreen({
    super.key,
    required this.note,
    this.onTabSelected,
    this.quotePreparationService,
    this.notePreparationService,
    this.requestTemporaryApiKey,
    this.typeLabels = const ['Quote', 'Report', 'Latter', 'Custom'],
  });

  final JobNoteModel note;
  final ValueChanged<int>? onTabSelected;
  final QuotePreparationService? quotePreparationService;
  final NoteDocumentPreparationService? notePreparationService;
  final Future<String?> Function(BuildContext)? requestTemporaryApiKey;
  final List<String> typeLabels;

  @override
  State<ConvertDocumentScreen> createState() => _ConvertDocumentScreenState();
}

class _ConvertDocumentScreenState extends State<ConvertDocumentScreen> {
  ConvertedDocumentType _type = ConvertedDocumentType.quote;
  QuotePreparationStage? _stage;
  bool _reviewOpened = false;
  bool _approved = false;
  bool _starting = false;
  String? _error;
  NoteDocumentDraft? _genericDraft;

  static const _icons = [
    Icons.description_outlined,
    Icons.show_chart_rounded,
    Icons.mail_outline_rounded,
    Icons.more_horiz_rounded,
  ];

  void _selectNavigation(int index) {
    if (index == 1) return;
    Navigator.of(context).maybePop();
    widget.onTabSelected?.call(index);
  }

  void _selectType(int value) {
    if (_starting) return;
    setState(() {
      _type = ConvertedDocumentType.values[value];
      // An earlier quote run is not evidence for the newly selected type.
      _stage = null;
      _reviewOpened = false;
      _approved = false;
      _genericDraft = NoteDocumentDraftSession.forNote(
        widget.note.id, _type.name);
      if (_genericDraft != null) {
        _stage = QuotePreparationStage.completed;
        _approved = _genericDraft!.approvedLocally;
      }
      _error = null;
    });
  }

  void _notify(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _reviewGeneric() async {
    final current = _genericDraft;
    if (current == null || !mounted) return;
    final title = TextEditingController(text: current.title);
    final content = TextEditingController(text: current.content);
    setState(() => _reviewOpened = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Review document draft'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Review every detail. Nothing is sent or signed.'),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('note-document-title'),
                  controller: title,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('note-document-content'),
                  controller: content,
                  minLines: 5, maxLines: 12, maxLength: 20000,
                  decoration: const InputDecoration(
                    labelText: 'Document text', border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Keep editing later'),
            ),
            TextButton(
              key: const Key('note-document-save-draft'),
              onPressed: () {
                final next = current.copyWith(
                  title: title.text.trim(),
                  content: content.text.trim(),
                  approvedLocally: false,
                );
                try {
                  NoteDocumentDraftSession.save(next);
                  setState(() { _genericDraft = next; _approved = false; });
                  Navigator.pop(dialog);
                } on FormatException {
                  _notify('Enter a document title and content.');
                }
              },
              child: const Text('Save Draft'),
            ),
            FilledButton(
              key: const Key('note-document-approve'),
              onPressed: () {
                final next = current.copyWith(
                  title: title.text.trim(),
                  content: content.text.trim(),
                  approvedLocally: true,
                );
                try {
                  NoteDocumentDraftSession.save(next);
                  setState(() { _genericDraft = next; _approved = true; });
                  Navigator.pop(dialog);
                  _notify('Approved locally. No document was sent or signed.');
                } on FormatException {
                  _notify('Enter a document title and content.');
                }
              },
              child: const Text('Approve Locally'),
            ),
          ],
        ),
      );
    } finally {
      title.dispose();
      content.dispose();
    }
  }

  Future<void> _generate() async {
    if (_starting) return;
    if (widget.note.id.trim().isEmpty || widget.note.jobId.trim().isEmpty) {
      _notify('A valid job note is required to prepare a document.');
      return;
    }
    if (widget.note.body.trim().isEmpty) {
      _notify('This note has no text to prepare. Add note content first.');
      return;
    }
    if (widget.note.visibility != JobNoteVisibility.privateNote) {
      const message = 'Convert a private note only. Customer-facing notes '
          'must not be used as private AI source material.';
      setState(() => _error = message);
      _notify(message);
      return;
    }
    if (_type != ConvertedDocumentType.quote) {
      setState(() { _starting = true; _error = null; });
      try {
        NoteDocumentPreparationService? service = widget.notePreparationService;
        if (service == null) {
          final key = await (widget.requestTemporaryApiKey?.call(context) ??
              Sign2DigitalTemporaryAiKeyDialog.request(
                context,
                title: 'Connect Document AI',
                message: 'For personal development testing only. A temporary '
                    'OpenAI key sends this private note to OpenAI for document '
                    'preparation. The key is not saved. Production requires '
                    'a secure backend.',
              ));
          if (!mounted || key == null) return;
          service = OpenAiNoteDocumentPreparationService(
              temporaryApiKey: key);
        }
        setState(() {
          _stage = QuotePreparationStage.preparing;
          _approved = false;
          _reviewOpened = false;
        });
        final prepared = await service.prepare(widget.note, _type.name);
        if (!mounted) return;
        if (prepared.noteId != widget.note.id ||
            prepared.jobId != widget.note.jobId ||
            prepared.documentType != _type.name) {
          throw const FormatException('AI document references do not match the note.');
        }
        setState(() {
          _genericDraft = prepared;
          _stage = QuotePreparationStage.completed;
        });
        NoteDocumentDraftSession.save(prepared);
        await _reviewGeneric();
      } catch (error) {
        if (mounted) {
          setState(() {
            _stage = QuotePreparationStage.failed;
            _error = 'Unable to prepare the selected note: $error';
          });
          _notify(_error!);
        }
      } finally {
        if (mounted) setState(() => _starting = false);
      }
      return;
    }

    setState(() { _starting = true; _error = null; });
    try {
      QuotePreparationService? service = widget.quotePreparationService;
      if (service == null) {
        final key = await (widget.requestTemporaryApiKey?.call(context) ??
            Sign2DigitalTemporaryAiKeyDialog.request(
              context,
              title: 'Connect Quote AI',
              message: 'For personal development testing only. '
                  'Provide a temporary OpenAI key to prepare a Quote '
                  'from the selected Job Note. The key is not saved.',
            ));
        if (!mounted || key == null) return;
        service = OpenAiQuotePreparationService(temporaryApiKey: key);
      }
      if (!mounted) return;
      final input = QuoteDraftInput(
        method: QuoteInputMethod.text,
        createdAt: DateTime.now(),
        description: widget.note.body.trim(),
        jobId: widget.note.jobId,
        sourceNoteId: widget.note.id,
      );
      setState(() {
        _stage = QuotePreparationStage.preparing;
        _reviewOpened = false;
        _approved = false;
      });
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => QuoteAiProcessingScreen(
          input: input,
          service: service,
          onStageChanged: (stage) {
            if (mounted && _type == ConvertedDocumentType.quote) {
              setState(() { _stage = stage; if (stage == QuotePreparationStage.failed) {
                _error = 'AI preparation failed. Retry when ready.';
              } });
            }
          },
          onReviewStarted: () {
            if (mounted) setState(() => _reviewOpened = true);
          },
          onQuoteApproved: (_) {
            if (mounted) setState(() { _reviewOpened = true; _approved = true; });
          },
        ),
      ));
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = QuotePreparationStage.failed;
          _error = 'Unable to start document preparation: $error';
        });
        _notify(_error!);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  List<DocumentPreparationStep> get _steps {
    final completed = _stage == QuotePreparationStage.completed;
    final working = _stage == QuotePreparationStage.preparing ||
        _stage == QuotePreparationStage.extracting ||
        _stage == QuotePreparationStage.partial;
    final failed = _stage == QuotePreparationStage.failed;
    return [
      const DocumentPreparationStep(
        title: 'Select document Type',
        description: 'Choose type of document to generate',
        completed: true,
      ),
      DocumentPreparationStep(
        title: 'AI Draft',
        description: completed ? 'AI draft is ready for review'
            : failed ? 'Preparation failed. Try generating again.'
            : working ? 'Preparing the selected note'
            : 'Choose type of document to generate',
        completed: completed,
        active: working,
        failed: failed,
      ),
      DocumentPreparationStep(
        title: 'Review',
        description: _approved ? 'Draft reviewed before local approval'
            : _reviewOpened ? 'Review the editable prepared draft'
            : 'Choose type of document to generate',
        completed: _approved,
        active: _reviewOpened && !_approved,
      ),
      DocumentPreparationStep(
        title: 'Approve',
        description: _approved ? 'Approved locally; not sent or signed'
            : 'Choose type of document to generate',
        completed: _approved,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _genericDraft = NoteDocumentDraftSession.forNote(
        widget.note.id, _type.name);
    _approved = _genericDraft?.approvedLocally ?? false;
    if (_genericDraft != null) _stage = QuotePreparationStage.completed;
  }

  Widget _sectionTitle(String value) => Text(value, style: const TextStyle(
    fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600,
    letterSpacing: -0.3, color: AppColors.dark,
  ));

  Widget _typeCards() => LayoutBuilder(builder: (context, constraints) {
    final labels = widget.typeLabels.length == 4
        ? widget.typeLabels
        : const ['Quote', 'Report', 'Latter', 'Custom'];
    final narrow = constraints.maxWidth < 360;
    final cards = [
      for (var i = 0; i < 4; i++)
        SizedBox(
          width: narrow ? 83 : (constraints.maxWidth - 36) / 4,
          child: Sign2DigitalSignatureActionCard(
            key: Key('convert-document-type-$i'),
            label: labels[i],
            icon: _icons[i],
            selected: _type.index == i,
            documentStyling: true,
            height: 74,
            onTap: () => _selectType(i),
          ),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          cards[i],
        ],
      ]),
    );
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    body: SafeArea(
      bottom: false,
      child: Column(children: [
        Sign2DigitalHeader(
          title: 'Convert Document',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(child: SingleChildScrollView(
          key: const Key('convert-document-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('Selected Note'),
                const SizedBox(height: 10),
                Sign2DigitalJobNoteCard(
                  key: const Key('convert-selected-note'),
                  note: widget.note,
                  onTap: () {},
                  selectedDetail: true,
                ),
                const SizedBox(height: 20),
                _sectionTitle('Document Type'),
                const SizedBox(height: 10),
                _typeCards(),
                const SizedBox(height: 20),
                _sectionTitle('AI Document Preparation'),
                const SizedBox(height: 40),
                Sign2DigitalDocumentStatusTimeline(
                  preparationSteps: _steps,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('convert-document-error'),
                    style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 12,
                      color: Color(0xFFB42318),
                    )),
                ],
                const SizedBox(height: 25),
                Sign2DigitalPrimaryButton(
                  key: const Key('convert-generate-draft'),
                  label: _type != ConvertedDocumentType.quote &&
                          _genericDraft != null ? 'Review Draft' : 'Generate Draft',
                  loading: _starting,
                  leading: const Icon(Icons.auto_awesome_rounded,
                    size: 22, color: Colors.white),
                  onPressed: _type != ConvertedDocumentType.quote &&
                          _genericDraft != null ? _reviewGeneric : _generate,
                ),
              ],
            ),
          )),
        )),
      ]),
    ),
    bottomNavigationBar: Sign2DigitalBottomNavigationBar(
      selectedIndex: 1,
      onSelected: _selectNavigation,
    ),
  );
}
