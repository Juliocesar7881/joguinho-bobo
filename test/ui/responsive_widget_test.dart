import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/domain/models.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('teclado ocupa três linhas e cabe em 320x568', (tester) async {
    const size = Size(320, 568);
    _configureView(tester, size);
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
    );

    _expectThreeKeyboardRows(tester, size);
    _expectAdaptiveKeyHeights(tester);
    final q = tester.getRect(
      find.byKey(const ValueKey<String>('letter_key_q')),
    );
    final p = tester.getRect(
      find.byKey(const ValueKey<String>('letter_key_p')),
    );
    expect(q.left, lessThanOrEqualTo(10));
    expect(p.right, greaterThanOrEqualTo(310));
    expect(q.width, inInclusiveRange(26, 32));
    final boardBottom = tester.getRect(
      find.byKey(const ValueKey<String>('board_tile_5_0')),
    );
    final bottomKey = tester.getRect(
      find.byKey(const ValueKey<String>('letter_key_m')),
    );
    expect(q.top - boardBottom.bottom, greaterThanOrEqualTo(17.9));
    expect(bottomKey.bottom, lessThanOrEqualTo(size.height - 18));
    expect(tester.takeException(), isNull);
  });

  testWidgets('teclado mantém a mesma estrutura em telefone 412x915', (
    tester,
  ) async {
    const size = Size(412, 915);
    _configureView(tester, size);
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 51,
    );

    expect(find.text('Dica (PT)'), findsOneWidget);
    expect(find.text('Hint (EN)'), findsOneWidget);
    _expectThreeKeyboardRows(tester, size);
    _expectAdaptiveKeyHeights(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet limita a largura sem alterar as três linhas', (
    tester,
  ) async {
    const size = Size(1024, 1366);
    _configureView(tester, size);
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withoutHints,
      levelNumber: 461,
    );

    expect(find.text('Palavra com 8 letras'), findsOneWidget);
    _expectThreeKeyboardRows(tester, size);
    _expectAdaptiveKeyHeights(tester);
    final q = tester.getRect(
      find.byKey(const ValueKey<String>('letter_key_q')),
    );
    final p = tester.getRect(
      find.byKey(const ValueKey<String>('letter_key_p')),
    );
    expect(p.right - q.left, closeTo(500, 0.5));
    expect(q.width, lessThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('palavra de oito letras e dicas cabem no telefone baixo', (
    tester,
  ) async {
    const size = Size(320, 568);
    _configureView(tester, size);
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 461,
    );

    expect(find.text('Nível 1 de 40'), findsOneWidget);
    expect(find.text('Dica (PT)'), findsOneWidget);
    expect(find.text('Hint (EN)'), findsOneWidget);
    _expectThreeKeyboardRows(tester, size);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('texto 2x preserva teclado fixo e área superior rolável', (
    tester,
  ) async {
    const size = Size(412, 915);
    _configureView(tester, size, textScaleFactor: 2);
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 151,
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Dica (PT)'), findsOneWidget);
    expect(find.text('Hint (EN)'), findsOneWidget);
    _expectThreeKeyboardRows(tester, size);
    _expectAdaptiveKeyHeights(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('texto 2x também cabe no telefone 320x568', (tester) async {
    const size = Size(320, 568);
    _configureView(tester, size, textScaleFactor: 2);
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 461,
    );

    _expectThreeKeyboardRows(tester, size);
    _expectAdaptiveKeyHeights(tester);
    final boardBottom = tester.getRect(
      find.byKey(const ValueKey<String>('board_tile_5_0')),
    );
    final keyboardTop = tester.getRect(
      find.byKey(const ValueKey<String>('letter_key_q')),
    );
    expect(keyboardTop.top - boardBottom.bottom, greaterThanOrEqualTo(17.9));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _configureView(
  WidgetTester tester,
  Size logicalSize, {
  double textScaleFactor = 1,
}) {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void _expectThreeKeyboardRows(WidgetTester tester, Size viewport) {
  final keys = <String>[
    for (final letter in 'qwertyuiopasdfghjklzxcvbnm'.split(''))
      'letter_key_$letter',
    'special_key_enter',
    'special_key_apagar',
  ];
  final rects = <String, Rect>{
    for (final key in keys)
      key: tester.getRect(find.byKey(ValueKey<String>(key))),
  };
  final rowTops = rects.values.map((rect) => rect.top.round()).toSet();
  expect(rowTops, hasLength(3));
  expect(rects['letter_key_q']!.top, rects['letter_key_p']!.top);
  expect(rects['letter_key_a']!.top, rects['letter_key_l']!.top);
  expect(rects['special_key_enter']!.top, rects['letter_key_z']!.top);
  expect(rects['letter_key_z']!.top, rects['letter_key_m']!.top);
  expect(rects['letter_key_m']!.top, rects['special_key_apagar']!.top);
  for (final entry in rects.entries) {
    expect(entry.value.left, greaterThanOrEqualTo(0), reason: entry.key);
    expect(entry.value.top, greaterThanOrEqualTo(0), reason: entry.key);
    expect(
      entry.value.right,
      lessThanOrEqualTo(viewport.width),
      reason: entry.key,
    );
    expect(
      entry.value.bottom,
      lessThanOrEqualTo(viewport.height),
      reason: entry.key,
    );
  }
}

void _expectAdaptiveKeyHeights(WidgetTester tester) {
  for (final key in <String>[
    'letter_key_q',
    'letter_key_p',
    'letter_key_a',
    'letter_key_l',
    'letter_key_z',
    'letter_key_m',
    'special_key_enter',
    'special_key_apagar',
  ]) {
    final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
    expect(rect.height, inInclusiveRange(44, 48), reason: key);
  }
}
