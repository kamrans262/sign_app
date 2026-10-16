import 'document_record.dart';

enum DocumentBrowseType {
  all('All'),
  quotes('Quotes'),
  signedQuotes('Signed Quotes'),
  addenda('Addenda'),
  reports('Reports'),
  receipts('Receipts'),
  invoices('Invoices'),
  other('Other');

  const DocumentBrowseType(this.label);
  final String label;

  bool matches(DocumentRecord record) => switch (this) {
    DocumentBrowseType.all => true,
    DocumentBrowseType.quotes => record.category == DocumentCategory.quotes,
    DocumentBrowseType.signedQuotes =>
      record.category == DocumentCategory.quotes &&
        record.status.toLowerCase() == 'signed',
    DocumentBrowseType.addenda => record.category == DocumentCategory.addends,
    DocumentBrowseType.reports => record.category == DocumentCategory.reports,
    DocumentBrowseType.receipts => record.category == DocumentCategory.receipts,
    DocumentBrowseType.invoices => record.category == DocumentCategory.invoices,
    DocumentBrowseType.other =>
      record.category == DocumentCategory.other ||
        record.category == DocumentCategory.contacts,
  };
}

enum DocumentSortOrder {
  asListed('Default'),
  newestFirst('Newest first'),
  oldestFirst('Oldest first'),
  titleAscending('Title A–Z');

  const DocumentSortOrder(this.label);
  final String label;
}

List<DocumentRecord> browseDocuments(
  Iterable<DocumentRecord> documents, {
  DocumentCategory? mainTab,
  DocumentBrowseType type = DocumentBrowseType.all,
  DocumentSortOrder order = DocumentSortOrder.asListed,
  String query = '',
}) {
  final result = documents.where((record) =>
      (mainTab == null || record.category == mainTab) &&
      type.matches(record) && record.matches(query)).toList();
  switch (order) {
    case DocumentSortOrder.asListed:
      break;
    case DocumentSortOrder.newestFirst:
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    case DocumentSortOrder.oldestFirst:
      result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    case DocumentSortOrder.titleAscending:
      result.sort((a, b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
  return result;
}
