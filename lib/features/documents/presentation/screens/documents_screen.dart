import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import 'document_details_screen.dart';
import 'create_addendum_screen.dart';
import '../../../quotes/presentation/widgets/sign2digital_quote_summary_card.dart';
import '../../data/demo_document_repository.dart';
import '../../domain/document_record.dart';

/// Documents tab content inside the existing dashboard header/navigation shell.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    this.repository,
    this.onDocumentTap,
    this.initialCategory,
  });

  final DocumentRepository? repository;
  final ValueChanged<DocumentRecord>? onDocumentTap;
  /// Optional deep link from Home; the usual Documents tab starts at All.
  final DocumentCategory? initialCategory;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final TextEditingController _search = TextEditingController();
  late final DocumentRepository _repository;
  List<DocumentRecord> _documents = const [];
  DocumentCategory? _category;
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
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.listDocuments();
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
    });
  }

  Future<void> _openDocument(DocumentRecord record) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final handler = widget.onDocumentTap;
    if (handler != null) {
      handler(record);
      return;
    }
    // Keep this route above the dashboard. Back restores search and category.
    if (record.addendumDraftId != null) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => CreateAddendumScreen(
          draftId: record.addendumDraftId,
          repository: _repository,
        ),
      ));
    } else {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => DocumentDetailsScreen(
          documentId: record.id,
          document: record,
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
    final visible = _documents.where((record) =>
        (_category == null || record.category == _category) &&
        record.matches(_search.text)).toList(growable: false);

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
                      onTrailingTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
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
                          : _category == null
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
