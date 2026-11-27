import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Run before each Flutter widget-test entrypoint. The production app loads
/// bundled date symbols in main(); tests construct individual screens without
/// going through main(), so they need the same offline locale initialization.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  await testMain();
}
