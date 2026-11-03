import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/widgets/sign2digital_country_selector.dart';

void main() {
  testWidgets('phone prefix uses a vector flag instead of emoji glyphs',
      (tester) async {
    var selected = Sign2DigitalCountries.switzerland;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Sign2DigitalCountrySelector(
            selected: selected,
            onChanged: (country) => setState(() => selected = country),
          ),
        ),
      ),
    ));

    expect(find.byType(CountryFlag), findsOneWidget);
    expect(find.text(selected.flag), findsNothing);
    expect(find.text('+41'), findsOneWidget);

    await tester.tap(find.byKey(const Key('country-selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('country-search')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('country-search')), 'Pakistan');
    await tester.pump();
    expect(find.byKey(const Key('country-PK')), findsOneWidget);
    expect(find.text('🇵🇰'), findsNothing);
    expect(find.byType(CountryFlag), findsWidgets);

    await tester.tap(find.byKey(const Key('country-PK')));
    await tester.pumpAndSettle();
    expect(selected.isoCode, 'PK');
    expect(selected.dialCode, '+92');
    expect(find.text('+92'), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared selector keeps Canada calling code and vector flag',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Sign2DigitalCountrySelector(
          selected: Sign2DigitalCountries.canada,
          onChanged: (_) {},
        ),
      ),
    ));
    expect(find.text('+1'), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
    expect(find.text('🇨🇦'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
