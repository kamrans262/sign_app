import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/core/theme/app_colors.dart';
import 'package:sign2digital/core/widgets/sign2digital_dashboard_header.dart';
import 'package:sign2digital/features/support/data/support_assistant_repository.dart';
import 'package:sign2digital/features/support/presentation/widgets/support_assistant_sheet.dart';

class _AssistantFake implements SupportAssistantRepository {
  int questions = 0, progressReads = 0;
  @override
  Future<AssistantAnswer> ask({required String message,
      required String screen, required List<AssistantTurn> history}) async {
    questions++;
    return const AssistantAnswer(answer: 'Open Help & Support to file a ticket.',
        screen: 'support');
  }

  @override
  Future<GettingStartedProgress> progress() async {
    progressReads++;
    return const GettingStartedProgress(
      eligible: true, completed: {'company': true, 'client': false,
        'job': false, 'quote': false});
  }
}

void main() {
  testWidgets('Dashboard header replaces profile avatar with primary support icon',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Sign2DigitalDashboardHeader(onSupportTap: () => opened++))));
    await tester.pump();
    expect(find.byKey(const Key('dashboard-support-button')), findsOneWidget);
    expect(find.byIcon(Icons.support_agent_outlined), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
    await tester.tap(find.byKey(const Key('dashboard-support-button')));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI Support uses primary teal, prompts, and a working link',
      (tester) async {
    final fake = _AssistantFake();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SupportAssistantSheet(
        repository: fake, screen: 'home'))));
    await tester.pump();
    expect(find.text('AI Support'), findsOneWidget);
    expect(find.byKey(const Key('support-question-0')), findsOneWidget);
    expect(find.byKey(const Key('support-guide-preview')), findsNothing);
    expect(find.text('Getting Started'), findsNothing);
    final send = tester.widget<IconButton>(
      find.byKey(const Key('support-send')));
    expect(send.style?.backgroundColor?.resolve({}), AppColors.primary);
    await tester.tap(find.byKey(const Key('support-question-0')));
    await tester.pumpAndSettle();
    expect(fake.questions, 1);
    expect(find.textContaining('Open Help & Support to file a ticket.'),
        findsOneWidget);
    expect(find.byKey(const Key('support-open-support')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Getting Started is manually previewed, not automatic',
      (tester) async {
    final fake = _AssistantFake();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SupportAssistantSheet(
        repository: fake, screen: 'home'))));
    await tester.pump();
    expect(fake.progressReads, 0);
    final button = find.byKey(const Key('support-preview-guide'));
    await tester.scrollUntilVisible(button, 150,
      scrollable: find.descendant(
        of: find.byKey(const Key('support-chat')),
        matching: find.byType(Scrollable)).first,
      maxScrolls: 15);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(fake.progressReads, 1);
    expect(find.byKey(const Key('support-guide-preview')), findsOneWidget);
    expect(find.text('1 of 4 completed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('support-guide-back')));
    await tester.pumpAndSettle();
    expect(find.text('AI Support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
