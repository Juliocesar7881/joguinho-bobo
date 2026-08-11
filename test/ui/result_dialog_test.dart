import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/ui/app_theme.dart';
import 'package:lexinexo/src/ui/widgets/result_dialog.dart';

void main() {
  const regularLevel = WordLevel(
    number: 12,
    answer: 'crane',
    translation: 'grou',
    meaning: 'Ave alta de pernas longas encontrada perto da agua.',
    hint: 'Uma ave alta que costuma viver perto de areas alagadas.',
  );
  const finalLevel = WordLevel(
    number: 500,
    answer: 'elephant',
    translation: 'elefante',
    meaning: 'Grande mamifero terrestre conhecido por sua tromba.',
    hint: 'Mamifero terrestre muito grande que possui uma tromba.',
  );

  testWidgets('vitoria comum mostra conteudo e as tres acoes', (tester) async {
    ResultAction? selected;
    await _pumpLauncher(
      tester,
      level: regularLevel,
      won: true,
      onResult: (value) => selected = value,
    );

    expect(find.text('Você acertou!'), findsOneWidget);
    expect(find.text('CRANE'), findsOneWidget);
    expect(find.text('Tradução: grou'), findsOneWidget);
    expect(find.textContaining('Significado:'), findsOneWidget);
    expect(find.text('Próximo nível'), findsOneWidget);
    expect(find.text('Jogar novamente'), findsOneWidget);
    expect(find.text('Voltar aos níveis'), findsOneWidget);

    await tester.tap(find.text('Jogar novamente'));
    await tester.pumpAndSettle();
    expect(selected, ResultAction.replay);
  });

  testWidgets('derrota revela resposta e oferece somente repetir ou voltar', (
    tester,
  ) async {
    ResultAction? selected;
    await _pumpLauncher(
      tester,
      level: regularLevel,
      won: false,
      onResult: (value) => selected = value,
    );

    expect(find.text('Não foi dessa vez'), findsOneWidget);
    expect(find.text('CRANE'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Jogar novamente'), findsNothing);
    expect(find.text('Próximo nível'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(selected, ResultAction.advance);
  });

  testWidgets('vitoria no nivel 500 troca avancar por ver conclusao', (
    tester,
  ) async {
    ResultAction? selected;
    await _pumpLauncher(
      tester,
      level: finalLevel,
      won: true,
      isLastInCategory: true,
      onResult: (value) => selected = value,
    );

    expect(find.text('Ver conclusão'), findsOneWidget);
    expect(find.text('Próximo nível'), findsNothing);

    await tester.tap(find.text('Ver conclusão'));
    await tester.pumpAndSettle();
    expect(selected, ResultAction.advance);
  });

  testWidgets('dialogo terminal ignora toque externo e botao voltar', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      level: regularLevel,
      won: true,
      onResult: (_) {},
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Você acertou!'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Você acertou!'), findsOneWidget);
  });

  testWidgets('acao voltar aos niveis devolve o resultado correto', (
    tester,
  ) async {
    ResultAction? selected;
    await _pumpLauncher(
      tester,
      level: regularLevel,
      won: false,
      onResult: (value) => selected = value,
    );

    await tester.tap(find.text('Voltar aos níveis'));
    await tester.pumpAndSettle();

    expect(selected, ResultAction.levels);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required WordLevel level,
  required bool won,
  bool isLastInCategory = false,
  required ValueChanged<ResultAction?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              onResult(
                await showGameResultDialog(
                  context: context,
                  level: level,
                  won: won,
                  isLastInCategory: isLastInCategory,
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
