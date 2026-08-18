import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/ui/ads_scope.dart';
import 'package:lexinexo/src/ui/screens/about_screen.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mostra versão e política de anúncios empacotada', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sobre o Worde'), findsOneWidget);
    expect(find.text('Versão 1.0.0'), findsOneWidget);
    expect(find.text('Privacidade, anúncios e dados locais'), findsOneWidget);
    expect(find.textContaining('Google Mobile Ads'), findsOneWidget);
    expect(find.textContaining('pode coletar e compartilhar'), findsOneWidget);
  });

  testWidgets('abre preferências UMP quando a região exige', (tester) async {
    final ads = RecordingGameAds(requirePrivacyOptions: true);
    await tester.pumpWidget(
      AdsScope(
        ads: ads,
        child: const MaterialApp(home: AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('ad_privacy_options'));
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable),
    );
    final outlinedButton = tester.widget<OutlinedButton>(button);
    outlinedButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(ads.privacyOptionsCalls, 1);
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
