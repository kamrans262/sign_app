import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import 'document_details_screen.dart';
import 'create_addendum_screen.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../../quotes/data/signed_quote_file_store.dart';
import '../../../quotes/domain/quote_review_models.dart';
import '../../data/phase4_document_records.dart';
import '../../data/remote_signed_document_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../data/demo_document_repository.dart';
import '../../domain/document_record.dart';
import '../../domain/document_browse_options.dart';
import '../../domain/addendum_signature_request.dart';
import '../../domain/addendum_draft.dart';

/// Documents tab content inside the existing dashboard header/navigation shell.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    this.repository,
    this.onDocumentTap,
    this.initialCategory,
    this.refreshRevision = 0,
    this.requestAddendumSignature,
    this.jobId,
  });

  final DocumentRepository? repository;
  final ValueChanged<DocumentRecord>? onDocumentTap;
  /// Optional deep link from Home; the usual Documents tab starts at All.
  final DocumentCategory? initialCategory;
  final int refreshRevision;
  final AddendumSignatureRequestService? requestAddendumSignature;
  /// Optional job-scoped route opened from Job Details.
  final String? jobId;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final TextEditingController _search = TextEditingController();
  late final DocumentRepository _repository;
  List<DocumentRecord> _documents = const [];
  Map<int, SignedJobDocument> _signedByServerId = const {};
  DocumentCategory? _category;
  DocumentBrowseType _advancedType = DocumentBrowseType.all;
  DocumentSortOrder _sort = DocumentSortOrder.asListed;
  bool _loading = true;
  String? _error;

  static const _tabs = ['All', 'Quotes', 'Contacts', 'Reports', 'Addends'];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const DemoDocumentRepository();
    _category = widget.initialCategory;
    _load();
  }

  @override
  void didUpdateWidget(covariant DocumentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      setState(() => _category = widget.initialCategory);
    }
    if (oldWidget.refreshRevision != widget.refreshRevision ||
        oldWidget.jobId != widget.jobId) {
      _load();
    }
  }

  Future<List<DocumentRecord>> _liveDocuments() async {
    final signed=await RemoteSignedDocumentRepository.shared.list(jobId:widget.jobId);
    _signedByServerId={for(final item in signed)item.id:item};
    final originalQuotes=phase4DocumentRecords(
      savedQuotes:QuoteReviewSessionStore.savedDrafts,
      signedFiles:const [],
    );
    return [
      ...originalQuotes,
      for(final file in signed)
        DocumentRecord(
          id:'m8-signed-' + file.id.toString(),
          category:DocumentCategory.quotes,
          number:file.quoteNumber,
          title:'Signed Quote ' + file.quoteNumber,
          project:file.jobId ?? 'Not linked to a job',
          customer:file.signerName,
          timestamp:file.signedAt,
          status:'Signed',
          verifiedSignedPdfAvailable:true,
          createdAt:file.signedAt,
          updatedAt:file.signedAt,
          history:[
            DocumentHistoryEvent(
              id:'server-signed-' + file.documentId,
              documentId:file.documentId,
              type:DocumentHistoryType.signed,
              occurredAt:file.signedAt,
              actorName:file.signerName,
              signatureReference:file.documentId,
              description:'Verified by the Sign2Digital signing service',
            ),
          ],
        ),
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = widget.repository == null &&
              MobileAuthRepository.shared.isSignedIn
          ? await _liveDocuments()
          : await _repository.listDocuments();
      if (!mounted) return;
      setState(() {
        _documents = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Documents could not be loaded';
      });
    }
  }

  void _selectCategory(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _category = index == 0 ? null : DocumentCategory.values[index - 1];
      _advancedType = DocumentBrowseType.all;
    });
  }

  void _openDocumentFilters() {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
          ),
          child: ListView(
            key: const Key('documents-filter-sheet'),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 14),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text('Filter documents', style: TextStyle(
                  fontFamily: 'Inter', fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                )),
              ),
              for (final type in DocumentBrowseType.values)
                ListTile(
                  key: Key('documents-filter-${type.name}'),
                  title: Text(type.label),
                  trailing: type == _advancedType
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _advancedType = type;
                      _category = null;
                    });
                    Navigator.pop(sheetContext);
                  },
                ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text('Sort documents', style: TextStyle(
                  fontFamily: 'Inter', fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                )),
              ),
              for (final option in DocumentSortOrder.values)
                ListTile(
                  key: Key('documents-sort-${option.name}'),
                  title: Text(option.label),
                  trailing: option == _sort
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _sort = option);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDocument(DocumentRecord record) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final handler = widget.onDocumentTap;
    if (handler != null) {
      handler(record);
      return;
    }
    // Keep this route above the dashboard. Back restores search and category.
    if (record.addendumDraftId != null &&
        AddendumDraftSession.load(record.addendumDraftId!)?.isCreatedLocally !=
            true) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => CreateAddendumScreen(
          draftId: record.addendumDraftId,
          repository: _repository,
          requestAddendumSignature: widget.requestAddendumSignature,
        ),
      ));
    } else {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => DocumentDetailsScreen(
          documentId: record.id,
          document: record,
          requestAddendumSignature: widget.requestAddendumSignature,
          loadSignedPdf: (signedRecord) async {
            final match=RegExp(r'^m8-signed-(\d+)
            final exact = files.where(
              (file) => file.documentId == signedRecord.id,
            ).toList();
            if (exact.length == 1) {
              return SignedQuoteFileStore.shared.read(exact.single);
            }
            // A verified signed quote and its original draft have different
            // document IDs. Never match a signed PDF by customer/name alone.
            final quote = signedRecord.quote;
            if (quote == null || quote.jobId == null ||
                !signedRecord.verifiedSignedPdfAvailable) {
              return null;
            }
            final linked = files.where((file) =>
                file.quoteId == quote.id && file.jobId == quote.jobId).toList()
              ..sort((a, b) => b.signedAt.compareTo(a.signedAt));
            if (linked.isEmpty) return null;
            return SignedQuoteFileStore.shared.read(linked.first);
          },
        ),
      ));
    }
    if (mounted) { await _load(); }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = browseDocuments(
      _documents,
      mainTab: _category,
      type: _advancedType,
      order: _sort,
      query: _search.text,
    ).where((record) {
      final jobId = widget.jobId;
      if (jobId == null) return true;
      if (record.quote?.jobId == jobId) return true;
      if (record.id.startsWith('m8-signed-') && record.project == jobId) {
        return true;
      }
      final draftId = record.addendumDraftId;
      return draftId != null &&
          AddendumDraftSession.load(draftId)?.linkedJobId == jobId;
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: CustomScrollView(
          key: const Key('documents-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Sign2DigitalSearchField(
                      controller: _search,
                      hintText: 'Search documents',
                      onChanged: (_) => setState(() {}),
                      onTrailingTap: _openDocumentFilters,
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      children: [
                        const Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Divider(height: 1, thickness: 1,
                            color: AppColors.lightBorder),
                        ),
                        Sign2DigitalDetailsTabs(
                          labels: _tabs,
                          selectedIndex: _category == null
                              ? 0 : _category!.index + 1,
                          onSelected: _selectCategory,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('documents-loading'),
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: TextButton(
                    key: const Key('documents-retry'),
                    onPressed: _load,
                    child: Text('$_error. Tap to retry.'),
                  ),
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _search.text.trim().isNotEmpty
                          ? 'No documents match your search'
                          : _category == null &&
                              _advancedType == DocumentBrowseType.all
                              ? 'No documents yet'
                              : 'No documents in this category',
                      key: const Key('documents-empty'),
                      style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final record = visible[index];
                    return Padding(
                      key: ValueKey(record.id),
                      padding: EdgeInsets.only(
                        bottom: index == visible.length - 1 ? 0 : 20,
                      ),
                      child: Sign2DigitalQuoteSummaryCard(
                        key: Key('document-card-${record.id}'),
                        quoteNumber: record.number,
                        titleOverride: record.title,
                        projectName: record.project,
                        customerName: record.customer,
                        documentDate: record.timestamp,
                        status: record.status,
                        subtitleGap: 5,
                        listStyle: true,
                        onTap: () => _openDocument(record),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
).firstMatch(signedRecord.id);
            if(match!=null) {
              final id=int.tryParse(match.group(1) ?? '');
              final verified=id==null ? null : _signedByServerId[id];
              if(verified==null) return null;
              return RemoteSignedDocumentRepository.shared.download(verified);
            }
            final files = await SignedQuoteFileStore.shared.list();
            final exact = files.where(
              (file) => file.documentId == signedRecord.id,
            ).toList();
            if (exact.length == 1) {
              return SignedQuoteFileStore.shared.read(exact.single);
            }
            // A verified signed quote and its original draft have different
            // document IDs. Never match a signed PDF by customer/name alone.
            final quote = signedRecord.quote;
            if (quote == null || quote.jobId == null ||
                !signedRecord.verifiedSignedPdfAvailable) {
              return null;
            }
            final linked = files.where((file) =>
                file.quoteId == quote.id && file.jobId == quote.jobId).toList()
              ..sort((a, b) => b.signedAt.compareTo(a.signedAt));
            if (linked.isEmpty) return null;
            return SignedQuoteFileStore.shared.read(linked.first);
          },
        ),
      ));
    }
    if (mounted) { await _load(); }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = browseDocuments(
      _documents,
      mainTab: _category,
      type: _advancedType,
      order: _sort,
      query: _search.text,
    ).where((record) {
      final jobId = widget.jobId;
      if (jobId == null) return true;
      if (record.quote?.jobId == jobId) return true;
      final draftId = record.addendumDraftId;
      return draftId != null &&
          AddendumDraftSession.load(draftId)?.linkedJobId == jobId;
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: CustomScrollView(
          key: const Key('documents-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Sign2DigitalSearchField(
                      controller: _search,
                      hintText: 'Search documents',
                      onChanged: (_) => setState(() {}),
                      onTrailingTap: _openDocumentFilters,
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      children: [
                        const Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Divider(height: 1, thickness: 1,
                            color: AppColors.lightBorder),
                        ),
                        Sign2DigitalDetailsTabs(
                          labels: _tabs,
                          selectedIndex: _category == null
                              ? 0 : _category!.index + 1,
                          onSelected: _selectCategory,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('documents-loading'),
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: TextButton(
                    key: const Key('documents-retry'),
                    onPressed: _load,
                    child: Text('$_error. Tap to retry.'),
                  ),
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _search.text.trim().isNotEmpty
                          ? 'No documents match your search'
                          : _category == null &&
                              _advancedType == DocumentBrowseType.all
                              ? 'No documents yet'
                              : 'No documents in this category',
                      key: const Key('documents-empty'),
                      style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final record = visible[index];
                    return Padding(
                      key: ValueKey(record.id),
                      padding: EdgeInsets.only(
                        bottom: index == visible.length - 1 ? 0 : 20,
                      ),
                      child: Sign2DigitalQuoteSummaryCard(
                        key: Key('document-card-${record.id}'),
                        quoteNumber: record.number,
                        titleOverride: record.title,
                        projectName: record.project,
                        customerName: record.customer,
                        documentDate: record.timestamp,
                        status: record.status,
                        subtitleGap: 5,
                        listStyle: true,
                        onTap: () => _openDocument(record),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
