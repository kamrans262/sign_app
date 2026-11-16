import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../documents/domain/document_record.dart';

/// The selected job owns the sheet. A quotation without an addendum remains
/// visible even if it still needs customer signing; creation stays restricted
/// to the verified signed source required by the existing M10 workflow.
class JobAddendaSelection {
  const JobAddendaSelection.existing(this.document)
      : signedOriginal = null, isExisting = true;
  const JobAddendaSelection.create(this.document, this.signedOriginal)
      : isExisting = false;

  final DocumentRecord document;
  final DocumentRecord? signedOriginal;
  final bool isExisting;
}

class JobAddendaBottomSheet extends StatefulWidget {
  const JobAddendaBottomSheet({
    super.key,
    required this.jobId,
    required this.jobReference,
    required this.loadDocuments,
    required this.loadDetails,
    required this.live,
    required this.canCreate,
  });

  final String jobId;
  final String jobReference;
  final Future<List<DocumentRecord>> Function(String jobId) loadDocuments;
  final Future<DocumentRecord> Function(String documentId) loadDetails;
  final bool live;
  final bool canCreate;

  @override
  State<JobAddendaBottomSheet> createState() => _JobAddendaBottomSheetState();
}

class _JobAddendaBottomSheetState extends State<JobAddendaBottomSheet> {
  bool _loading = true;
  String? _error;
  List<DocumentRecord> _addenda = const [];
  List<({DocumentRecord quote, DocumentRecord? signed})> _available = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final documents = await widget.loadDocuments(widget.jobId);
      if (!mounted) return;
      final scoped = documents.where((d) =>
          d.jobId == widget.jobId || d.quote?.jobId == widget.jobId).toList();
      final addenda = scoped.where((d) =>
          d.category == DocumentCategory.addends &&
          RegExp(r'^addendum-[1-9][0-9]*$').hasMatch(d.id)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final quotes = scoped.where((d) =>
          d.category == DocumentCategory.quotes &&
          RegExp(r'^quote-[1-9][0-9]*$').hasMatch(d.id) &&
          d.status.toLowerCase() != 'archived').toList();
      final available = <({DocumentRecord quote, DocumentRecord? signed})>[];
      for (final quote in quotes) {
        // Load the authoritative relation for this exact quote. Number-only
        // matching can silently pick the wrong job or hide a valid quotation.
        final current = widget.live
            ? await widget.loadDetails(quote.id) : quote;
        if (current.id != quote.id ||
            (current.jobId != widget.jobId &&
             current.quote?.jobId != widget.jobId)) {
          throw const FormatException('Quote ownership changed.');
        }
        if (current.related.any((relation) =>
            relation.category == DocumentCategory.addends &&
            relation.id.startsWith('addendum-'))) {
          continue;
        }
        final signed = current.related.where((relation) =>
            relation.category == DocumentCategory.quotes &&
            RegExp(r'^signed-[1-9][0-9]*$').hasMatch(relation.id) &&
            relation.status.toLowerCase() == 'signed' &&
            relation.verifiedSignedPdfAvailable).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        available.add((quote: current, signed:
            widget.live ? (signed.isEmpty ? null : signed.first) : current));
      }
      available.sort((a, b) =>
          b.quote.timestamp.compareTo(a.quote.timestamp));
      if (!mounted) return;
      setState(() {
        _addenda = addenda;
        _available = available;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Unable to load job addenda and quotations.';
        _loading = false;
      });
    }
  }

  Widget _section(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
        color: AppColors.dark)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 12,
        fontWeight: FontWeight.w500, color: AppColors.secondaryText)),
    ]),
  );

  Widget _entry({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Sign2DigitalOutlinedContainer(
      padding: EdgeInsets.zero,
      // ListTile needs its own Material above the outlined decoration, or
      // Flutter hides ink effects and flags an accessibility assertion.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
        key: key,
        leading: Icon(icon, color: AppColors.primary, size: 24),
        title: Text(title,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
            fontWeight: FontWeight.w600, color: AppColors.dark)),
        subtitle: Text(subtitle,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
            color: AppColors.secondaryText)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
        onTap: onTap,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: (MediaQuery.sizeOf(context).height * .72).clamp(290.0, 590.0).toDouble(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(children: [
          Row(children: [
            const CircleAvatar(
              radius: 24, backgroundColor: Color(0xFFE3ECF0),
              child: Icon(Icons.description_outlined,
                color: AppColors.primary, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Job Addenda', style: TextStyle(
                  fontFamily: 'Inter', fontSize: 18,
                  fontWeight: FontWeight.w600, color: AppColors.dark)),
                Text(widget.jobReference, style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 12,
                  color: AppColors.secondaryText)),
              ],
            )),
            IconButton(
              key: const Key('job-addenda-close'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: AppColors.dark)),
          ]),
          const SizedBox(height: 8),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(
                  key: Key('job-addenda-loading')))
              : _error != null
                  ? Center(child: TextButton(
                      key: const Key('job-addenda-retry'),
                      onPressed: _load,
                      child: Text('$_error Tap to retry.')))
                  : ListView(children: [
                      _section('View Addenda',
                          'Addenda belonging to this job'),
                      if (_addenda.isEmpty)
                        const Text('No addenda created for this job.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                            color: AppColors.secondaryText)),
                      for (final entry in _addenda)
                        _entry(
                          key: Key('job-addenda-existing-${entry.id}'),
                          icon: Icons.description_outlined,
                          title: entry.number,
                          subtitle: entry.status,
                          onTap: () => Navigator.of(context).pop(
                              JobAddendaSelection.existing(entry)),
                        ),
                      _section('Quotes Without Addenda',
                          'Choose a quotation to create an addendum'),
                      if (_available.isEmpty)
                        const Text('No quotations without addenda.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                            color: AppColors.secondaryText)),
                      for (final entry in _available)
                        _entry(
                          key: Key('job-addenda-quote-${entry.quote.id}'),
                          icon: entry.signed == null
                              ? Icons.lock_outline : Icons.request_quote_outlined,
                          title: entry.quote.number,
                          subtitle: entry.signed == null && widget.live
                              ? 'Sign this quotation before creating an addendum'
                              : entry.quote.status,
                          onTap: !widget.canCreate ? null : () {
                            if (widget.live && entry.signed == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text(
                                  'A verified signed quotation is required '
                                  'before creating an addendum.')));
                              return;
                            }
                            Navigator.of(context).pop(
                                JobAddendaSelection.create(
                                    entry.quote, entry.signed));
                          },
                        ),
                    ])),
        ]),
      ),
    ),
  );
}
