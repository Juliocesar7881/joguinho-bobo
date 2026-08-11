import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lexinexo/src/app.dart';
import 'package:lexinexo/src/data/catalog_repository.dart';
import 'package:lexinexo/src/data/save_repository.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/state/game_store.dart';

const _formFactor = String.fromEnvironment(
  'SCREENSHOT_FORM_FACTOR',
  defaultValue: 'phone',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captura estados reais da ficha da loja', (tester) async {
    assert(
      _formFactor == 'phone' || _formFactor == 'tablet',
      'SCREENSHOT_FORM_FACTOR deve ser phone ou tablet.',
    );
    final store = GameStore(
      catalog: CatalogRepository(),
      saves: SaveRepository(_MemoryStorage()),
    );
    await store.initialize();
    await tester.pumpWidget(LexiNexoApp(store: store));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    if (_formFactor == 'phone') {
      await _capture(binding, tester, '01-inicio');
    }

    await tester.tap(find.text('Com dicas'));
    await tester.pumpAndSettle();
    await _capture(
      binding,
      tester,
      _formFactor == 'phone' ? '02-tamanhos' : '01-tamanhos',
    );

    final wordLength = _formFactor == 'phone' ? 4 : 5;
    final lengthCard = find.byKey(ValueKey<String>('length_card_$wordLength'));
    await tester.ensureVisible(lengthCard);
    await tester.tap(lengthCard);
    await tester.pumpAndSettle();
    await _capture(
      binding,
      tester,
      _formFactor == 'phone' ? '03-niveis-4-letras' : '02-niveis-5-letras',
    );

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Dica (PT)'), findsOneWidget);
    expect(find.text('Hint (EN)'), findsOneWidget);
    await _capture(
      binding,
      tester,
      _formFactor == 'phone'
          ? '04-jogo-dicas-bilingues'
          : '03-jogo-dicas-bilingues',
    );

    final globalLevel = store.globalLevelForLocal(wordLength, 1);
    final answer = store.level(GameMode.withHints, globalLevel).answer;
    for (final letter in answer.toUpperCase().split('')) {
      await tester.tap(find.text(letter).last);
    }
    await tester.tap(find.text('ENTER'));
    await tester.pumpAndSettle();
    expect(find.text('Você acertou!'), findsOneWidget);
    await _capture(
      binding,
      tester,
      _formFactor == 'phone' ? '05-vitoria' : '04-vitoria',
    );

    if (_formFactor == 'phone') {
      await tester.tap(find.text('Voltar aos níveis'));
      await tester.pumpAndSettle();
      await _tapBack(tester);
      await _tapBack(tester);
      await tester.tap(find.byKey(const Key('home_about_button')));
      await tester.pumpAndSettle();
      await _capture(binding, tester, '06-privacidade');
    }
  });
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Voltar').last);
  await tester.pumpAndSettle();
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name, {
  Duration delay = const Duration(milliseconds: 600),
}) async {
  if (delay > Duration.zero) await tester.pump(delay);
  await binding.takeScreenshot('$_formFactor/$name');
}

class _MemoryStorage implements SaveStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
