import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/widgets/sign2digital_input_field.dart';
import 'package:sign2digital/core/widgets/sign2digital_selection_field.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'Profile and Settings leading icons stay visible in '
      '${brightness.name} theme even if the theme icon color is white',
      (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          home: Scaffold(
            body: ListView(children: [
              Sign2DigitalInputField(
                key: const Key('first-name-input'),
                label: 'First Name',
                hintText: 'Enter first name',
                iconAsset: '',
                leadingIcon: Icons.person_outline_rounded,
                leadingIconSize: 24,
                controller: TextEditingController(text: 'Kamran'),
              ),
              Sign2DigitalInputField(
                key: const Key('email-input'),
                label: 'E-mail',
                hintText: 'Enter email',
                iconAsset: '',
                leadingIcon: Icons.mail_outline_rounded,
                leadingIconSize: 24,
              ),
              Sign2DigitalSelectionField(
                key: const Key('title-selection'),
                label: 'Title',
                value: 'Project Manager',
                hintText: 'Choose title',
                iconAsset: '',
                leadingIcon: Icons.badge_outlined,
                leadingIconSize: 24,
                onTap: () {},
                trailing: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.secondaryText,
                ),
              ),
            ]),
          ),
        ));

        for (final (key, iconData) in [
          (const Key('first-name-input'), Icons.person_outline_rounded),
          (const Key('email-input'), Icons.mail_outline_rounded),
          (const Key('title-selection'), Icons.badge_outlined),
        ]) {
          final icon = tester.widget<Icon>(find.descendant(
            of: find.byKey(key),
            matching: find.byIcon(iconData),
          ));
          expect(icon.color, AppColors.dark,
              reason: 'Leading icon must contrast with the white field.');
          expect(icon.size, 24);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
