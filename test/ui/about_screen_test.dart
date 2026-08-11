import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/ui/screens/about_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mostra versão e política offline empacotada', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sobre o LexiNexo'), findsOneWidget);
    expect(find.text('Versão 1.0.0'), findsOneWidget);
    expect(find.text('Privacidade e funcionamento offline'), findsOneWidget);
    expect(find.textContaining('não coleta, envia, vende'), findsOneWidget);
    expect(
      find.textContaining('não solicita permissão de internet'),
      findsOneWidget,
    );
  });

  testWidgets('mostra crédito e licença do SCOWL', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Licenças e créditos'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Licenças e créditos'), findsOneWidget);
    final documentFinder = find.byKey(
      const ValueKey<String>('legal_document_third_party_notices_pt_BR'),
      skipOffstage: false,
    );
    expect(documentFinder, findsOneWidget);
    final document = tester.widget<Text>(documentFinder).data!;
    expect(document, contains('SCOWL/ESDB rel-2026.02.25'));
    expect(document, contains('hunspell-reader 10.0.1'));
  });

  testWidgets('permanece utilizável em 320x568 com texto 2x', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.text('Versão 1.0.0'), findsOneWidget);
  });
}
