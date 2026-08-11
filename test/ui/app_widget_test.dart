import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/app.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/ui/screens/completion_screen.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('início mostra os dois modos e progressos independentes', (
    tester,
  ) async {
    final store = await createTestStore(
      initialSave: appSave(
        withHints: modeProgress(completedByLength: const <int, int>{3: 12}),
        withoutHints: modeProgress(completedByLength: const <int, int>{4: 7}),
      ),
    );
    await tester.pumpWidget(LexiNexoApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('LexiNexo'), findsOneWidget);
    expect(find.text('Com dicas'), findsOneWidget);
    expect(find.text('Sem dicas'), findsOneWidget);
    expect(find.text('12/500'), findsOneWidget);
    expect(find.text('7/500'), findsOneWidget);
    expect(find.byKey(const Key('home_about_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_about_button')));
    await tester.pumpAndSettle();
    expect(find.text('Sobre o LexiNexo'), findsOneWidget);
    expect(find.text('Versão 1.0.0'), findsOneWidget);
  });

  testWidgets('fluxo com dicas mostra as pistas em português e inglês', (
    tester,
  ) async {
    final store = await createTestStore();
    await tester.pumpWidget(LexiNexoApp(store: store));
    await _openCategory(tester, mode: GameMode.withHints, wordLength: 3);

    expect(find.text('Nível 1 de 50'), findsOneWidget);
    expect(find.text('Com dicas • 3 letras'), findsOneWidget);
    expect(find.text('Dica (PT)'), findsOneWidget);
    expect(
      find.text('Uma pista em português para esta palavra.'),
      findsOneWidget,
    );
    expect(find.text('Hint (EN)'), findsOneWidget);
    expect(find.text('An English hint for this word.'), findsOneWidget);
  });

  testWidgets('modo sem dicas não vaza nenhuma pista', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(LexiNexoApp(store: store));
    await _openCategory(tester, mode: GameMode.withoutHints, wordLength: 3);

    expect(find.text('Palavra com 3 letras'), findsOneWidget);
    expect(find.text('Dica (PT)'), findsNothing);
    expect(find.text('Hint (EN)'), findsNothing);
    expect(find.textContaining('pista em português'), findsNothing);
    expect(find.textContaining('English hint'), findsNothing);
  });

  testWidgets('acerto abre resultado com as três ações', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(LexiNexoApp(store: store));
    await _openCategory(tester, mode: GameMode.withHints, wordLength: 3);

    await enterWord(tester, 'cat');
    await tester.pumpAndSettle();

    expect(find.text('Você acertou!'), findsOneWidget);
    expect(find.text('Próximo nível'), findsOneWidget);
    expect(find.text('Jogar novamente'), findsOneWidget);
    expect(find.text('Voltar aos níveis'), findsOneWidget);
  });

  testWidgets('teclado atualiza estados somente depois do flip', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = await createTestStore();
    await tester.pumpWidget(LexiNexoApp(store: store));
    await _openCategory(tester, mode: GameMode.withHints, wordLength: 3);
    await enterWord(tester, 'dog');

    await tester.pump();
    expect(find.bySemanticsLabel('Letra D, não usada'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Letra D, ausente'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tela final descreve as seis categorias concluídas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CompletionScreen(mode: GameMode.withoutHints)),
    );

    expect(find.text('Modo zerado!'), findsOneWidget);
    expect(find.textContaining('500 desafios de 3 a 8 letras'), findsOneWidget);
    expect(find.text('Rever categorias'), findsOneWidget);
  });
}

Future<void> _openCategory(
  WidgetTester tester, {
  required GameMode mode,
  required int wordLength,
}) async {
  await tester.tap(find.text(mode.title));
  await tester.pumpAndSettle();
  final card = find.byKey(ValueKey<String>('length_card_$wordLength'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}
