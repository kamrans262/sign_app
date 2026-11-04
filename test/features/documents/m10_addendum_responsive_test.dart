import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/documents/domain/document_record.dart';
import 'package:sign2digital/features/documents/presentation/screens/create_addendum_screen.dart';

class _FixedDocuments implements DocumentRepository {
  const _FixedDocuments(this.records);
  final List<DocumentRecord> records;

  @override
  Future<List<DocumentRecord>> listDocuments() async => records;
}

void main() {
  testWidgets('M10 addendum fills landscape width and keeps original controls',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = DocumentRecord(
      id: 'documents-figma-signed-1',
      category: DocumentCategory.quotes,
      number: 'Q-10',
      title: 'Signed Quote Q-10',
      project: 'Roof',
      customer: 'Customer',
      status: 'Signed',
      timestamp: DateTime(2026, 11, 4),
      demoOnly: true,
    );
    const widths = <(Size, double)>[
      (Size(320, 650), 250),
      (Size(430, 932), 360),
      (Size(720, 390), 650),
      (Size(1024, 768), 940),
    ];
    for (final (screen, minimumInputWidth) in widths) {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(
        home: CreateAddendumScreen(
          repository: _FixedDocuments([original]),
          linkedDocument: original,
          draftId: 'responsive-'+screen.width.toString(),
        ),
      ));
      await tester.pump();
      expect(find.byKey(const Key('create-addendum-scroll')), findsOneWidget);
      expect(find.byKey(const Key('addendum-linked-document')), findsOneWidget);
      expect(find.byKey(const Key('addendum-review')), findsOneWidget);
      final input = find.byType(TextFormField).first;
      expect(tester.getSize(input).width, greaterThan(minimumInputWidth));
      expect(find.text('Select effective date'), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('addendum-create')));
      await tester.pump();
      expect(find.byKey(const Key('addendum-create')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
