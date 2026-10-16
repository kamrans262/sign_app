// Flutter web has no application-documents filesystem. Native platforms
// cache verified signed PDFs; web relies on the signing service's storage.
export 'signed_quote_file_store_io.dart'
    if (dart.library.js_interop) 'signed_quote_file_store_web.dart';
