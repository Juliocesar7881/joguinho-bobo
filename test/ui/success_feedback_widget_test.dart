import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/domain/models.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('vitória fresca toca uma vez e anima antes do diálogo', (
    tester,
  ) async {
    final audio = RecordingSuccessAudio();
    final ads = RecordingGameAds();
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
      audio: audio,
      ads: ads,
    );

    await enterWord(tester, 'cat');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 370));
    await tester.pump();

    expect(audio.calls, 1);
    expect(find.byKey(const Key('success_check_animation')), findsOneWidget);
    expect(find.text('Você acertou!'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('success_check_animation')), findsNothing);
    expect(find.text('Você acertou!'), findsOneWidget);
    expect(audio.calls, 1);
    expect(ads.naturalBreakCalls, 1);
  });

  testWidgets('falha de anúncio nunca bloqueia o resultado', (tester) async {
    final ads = RecordingGameAds(throwOnShow: true);
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
      ads: ads,
      disableAnimations: true,
    );

    await enterWord(tester, 'cat');
    await tester.pumpAndSettle();

    expect(ads.naturalBreakCalls, 1);
    expect(find.text('Você acertou!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opção de som desativada é persistida e impede reprodução', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final firstStore = await createTestStore(storage: storage);
    await pumpGame(
      tester,
      store: firstStore,
      mode: GameMode.withHints,
      levelNumber: 1,
    );

    expect(find.byTooltip('Desativar som de acerto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('success_sound_toggle')));
    await tester.pumpAndSettle();
    expect(firstStore.successSoundEnabled, isFalse);
    expect(find.byTooltip('Ativar som de acerto'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final restored = await createTestStore(storage: storage);
    final audio = RecordingSuccessAudio();
    await pumpGame(
      tester,
      store: restored,
      mode: GameMode.withHints,
      levelNumber: 1,
      audio: audio,
    );
    expect(restored.successSoundEnabled, isFalse);
    expect(find.byTooltip('Ativar som de acerto'), findsOneWidget);

    await enterWord(tester, 'cat');
    await tester.pumpAndSettle();
    expect(find.text('Você acertou!'), findsOneWidget);
    expect(audio.calls, 0);
  });

  testWidgets('animações reduzidas pulam check mas mantêm o som', (
    tester,
  ) async {
    final audio = RecordingSuccessAudio();
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
      audio: audio,
      disableAnimations: true,
    );

    await enterWord(tester, 'cat');
    await tester.pumpAndSettle();

    expect(audio.calls, 1);
    expect(find.byKey(const Key('success_check_animation')), findsNothing);
    expect(find.text('Você acertou!'), findsOneWidget);
  });

  testWidgets('falha de áudio não impede vitória ou diálogo', (tester) async {
    final audio = RecordingSuccessAudio(throwOnPlay: true);
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
      audio: audio,
    );

    await enterWord(tester, 'cat');
    await tester.pumpAndSettle();

    expect(audio.calls, 1);
    expect(find.text('Você acertou!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('derrota não toca o som de acerto', (tester) async {
    final audio = RecordingSuccessAudio();
    final ads = RecordingGameAds();
    final store = await createTestStore();
    await pumpGame(
      tester,
      store: store,
      mode: GameMode.withHints,
      levelNumber: 1,
      audio: audio,
      ads: ads,
    );

    for (var attempt = 0; attempt < 6; attempt++) {
      await enterWord(tester, 'dog');
      await tester.pumpAndSettle();
    }

    expect(find.text('Não foi dessa vez'), findsOneWidget);
    expect(audio.calls, 0);
    expect(ads.naturalBreakCalls, 1);
  });
}
