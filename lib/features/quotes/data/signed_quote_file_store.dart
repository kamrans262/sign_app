import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/quote_review_models.dart';
import '../presentation/screens/document_signed_success_screen.dart';

/// A local copy of a PDF *returned by a trusted signing service*.
/// This is not the authoritative remote record or legal audit trail.
class SavedSignedQuoteFile {
  const SavedSignedQuoteFile({
    required this.documentId,
    required this.quoteId,
    required this.quoteNumber,
    required this.jobId,
    required this.signedAt,
    required this.fileName,
  });

  final String documentId;
  final String quoteId;
  final String quoteNumber;
  final String jobId;
  final DateTime signedAt;
  final String fileName;

  Map<String, Object?> toJson() => {
    'documentId': documentId,
    'quoteId': quoteId,
    'quoteNumber': quoteNumber,
    'jobId': jobId,
    'signedAt': signedAt.toUtc().toIso8601String(),
    'fileName': fileName,
  };

  static SavedSignedQuoteFile fromJson(Map<String, dynamic> data) =>
      SavedSignedQuoteFile(
        documentId: data['documentId'] as String,
        quoteId: data['quoteId'] as String,
        quoteNumber: data['quoteNumber'] as String,
        jobId: data['jobId'] as String,
        signedAt: DateTime.parse(data['signedAt'] as String),
        fileName: data['fileName'] as String,
      );
}

/// Writes signed bytes to app-private storage and indexes them by job ID.
///
/// Does not generate signatures, substitute an unsigned PDF, or overwrite a
/// previously stored signed document. The trusted server remains responsible
/// for authorization, audit retention, and immutable long-term storage.
class SignedQuoteFileStore {
  SignedQuoteFileStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ??
            (() async => getApplicationDocumentsDirectory());

  static final SignedQuoteFileStore shared = SignedQuoteFileStore();

  final Future<Directory> Function() _directoryProvider;
  Future<Directory> _folder() async {
    final root = await _directoryProvider();
    final folder = Directory('${root.path}${Platform.pathSeparator}signed_quotes');
    await folder.create(recursive: true);
    return folder;
  }

  static bool isPdf(Uint8List bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 0x25 && bytes[1] == 0x50 &&
      bytes[2] == 0x44 && bytes[3] == 0x46 && bytes[4] == 0x2d;

  Future<List<SavedSignedQuoteFile>> _listIn(Directory folder) async {
    final manifest = File('${folder.path}${Platform.pathSeparator}index.json');
    if (!await manifest.exists()) return const [];
    final decoded = jsonDecode(await manifest.readAsString()) as List<dynamic>;
    return [
      for (final entry in decoded)
        SavedSignedQuoteFile.fromJson(
          Map<String, dynamic>.from(entry as Map),
        ),
    ];
  }

  Future<List<SavedSignedQuoteFile>> list() async =>
      _listIn(await _folder());

  Future<List<SavedSignedQuoteFile>> forJob(String jobId) async =>
      (await list()).where((file) => file.jobId == jobId).toList();

  Future<Uint8List> read(SavedSignedQuoteFile record) async {
    final expected = _safeFileName(record.documentId);
    if (record.fileName != expected) {
      throw const FormatException('Invalid signed document file identity.');
    }
    final folder = await _folder();
    final bytes = await File(
      '${folder.path}${Platform.pathSeparator}${record.fileName}',
    ).readAsBytes();
    if (!isPdf(bytes)) throw const FormatException('Invalid signed PDF.');
    return bytes;
  }

  static String _safeFileName(String id) {
    if (id.isEmpty || id.length > 120) {
      throw const FormatException('Invalid signed document identifier.');
    }
    // Encodes path separators; never derive a filesystem path from raw IDs.
    return '${base64UrlEncode(utf8.encode(id)).replaceAll('=', '')}.pdf';
  }

  /// Returns false when there was no signed artifact from the service.
  /// Does not silently produce a normal unsigned quote as a signed document.
  Future<bool> storeVerified(
    QuoteReviewDraft quote,
    QuoteSignedDisplayData receipt,
  ) async {
    final bytes = receipt.signedPdfBytes;
    if (bytes == null || bytes.isEmpty) return false;
    if (!isPdf(bytes) ||
        quote.jobId == null || quote.jobId!.trim().isEmpty ||
        quote.id.isEmpty ||
        receipt.documentId.isEmpty ||
        quote.quoteNumber != receipt.quoteNumber ||
        (receipt.quoteId != null && receipt.quoteId != quote.id) ||
        (receipt.jobId != null && receipt.jobId != quote.jobId) ||
        (receipt.demoOnly && !quote.isDemo)) {
      throw const FormatException('Signed PDF receipt does not match this job.');
    }
    final folder = await _folder();
    final name = _safeFileName(receipt.documentId);
    final file = File('${folder.path}${Platform.pathSeparator}$name');
    final records = await _listIn(folder);
    final prior = [
      for (final item in records)
        if (item.documentId == receipt.documentId) item,
    ];
    if (prior.isNotEmpty) {
      final old = prior.single;
      if (old.quoteId != quote.id || old.jobId != quote.jobId ||
          !listEquals(await file.readAsBytes(), bytes)) {
        throw StateError('A signed file cannot be overwritten.');
      }
      return true;
    }
    if (await file.exists()) {
      throw StateError('A signed document file already exists.');
    }
    final staged = File('${file.path}.pending');
    await staged.writeAsBytes(bytes, flush: true);
    await staged.rename(file.path);

    records.add(SavedSignedQuoteFile(
      documentId: receipt.documentId,
      quoteId: quote.id,
      quoteNumber: quote.quoteNumber,
      jobId: quote.jobId!,
      signedAt: receipt.signedAt,
      fileName: name,
    ));
    final index = File('${folder.path}${Platform.pathSeparator}index.json');
    final pendingIndex = File('${index.path}.pending');
    await pendingIndex.writeAsString(
      jsonEncode([for (final row in records) row.toJson()]),
      flush: true,
    );
    if (await index.exists()) await index.delete();
    await pendingIndex.rename(index.path);
    return true;
  }
}
