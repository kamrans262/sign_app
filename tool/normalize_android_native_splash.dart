import 'dart:io';

/// Run after flutter_native_splash:create. The generator restores the system
/// (black) NormalTheme on Android 12+ in dark mode; keep the transition white
/// so there is never a black frame between the native logo and Flutter.
void main() {
  const paths = <String>[
    'android/app/src/main/res/values-v31/styles.xml',
    'android/app/src/main/res/values-night-v31/styles.xml',
  ];
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('Missing generated Android 12 splash theme: $path');
      exitCode = 1;
      return;
    }
    var xml = file.readAsStringSync();
    if (!xml.contains('android:windowSplashScreenAnimatedIcon') ||
        !xml.contains('android:windowSplashScreenBackground">#FFFFFF')) {
      stderr.writeln('Android 12 logo or white splash is missing: $path');
      exitCode = 1;
      return;
    }
    xml = xml.replaceAll(
      'parent="@android:style/Theme.Black.NoTitleBar"',
      'parent="@android:style/Theme.Light.NoTitleBar"',
    ).replaceAll(
      '<item name="android:windowBackground">?android:colorBackground</item>',
      '<item name="android:windowBackground">@android:color/white</item>',
    );
    if (xml.contains('Theme.Black.NoTitleBar') ||
        xml.contains('?android:colorBackground')) {
      stderr.writeln('Android splash still has a dark transition: $path');
      exitCode = 1;
      return;
    }
    file.writeAsStringSync(xml);
  }
  stdout.writeln('Android 12+ light/dark launch and transition: white with logo.');
}
