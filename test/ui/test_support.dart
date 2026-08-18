import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/ads/game_ads.dart';
import 'package:lexinexo/src/audio/success_audio_service.dart';
import 'package:lexinexo/src/data/catalog_repository.dart';
import 'package:lexinexo/src/data/save_repository.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/state/game_store.dart';
import 'package:lexinexo/src/ui/app_theme.dart';
import 'package:lexinexo/src/ui/ads_scope.dart';
import 'package:lexinexo/src/ui/game_scope.dart';
import 'package:lexinexo/src/ui/screens/game_screen.dart';

class MemoryStorage implements SaveStorage {
  MemoryStorage({this.value});

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class FakeCatalog extends CatalogRepository {
  static const Map<int, String> answers = <int, String>{
    3: 'cat',
    4: 'book',
    5: 'crane',
    6: 'planet',
    7: 'journey',
    8: 'elephant',
  };

  static const Map<int, String> wrongAnswers = <int, String>{
    3: 'dog',
    4: 'lamp',
    5: 'stone',
    6: 'flower',
    7: 'blanket',
    8: 'mountain',
  };

  static final Set<String> accepted = <String>{
    ...answers.values,
    ...wrongAnswers.values,
  };

  @override
  Future<void> load() async {}

  @override
  WordLevel level(GameMode mode, int number) {
    final band = WordLengthBand.tryFromGlobalLevel(number)!;
    final answer = answers[band.wordLength]!;
    return WordLevel(
      number: number,
      answer: answer,
      translation: 'tradução de $answer',
      meaning: 'Significado comum de $answer para o teste.',
      hint: mode == GameMode.withHints
          ? 'Uma pista em português para esta palavra.'
          : null,
      hintEn: mode == GameMode.withHints
          ? 'An English hint for this word.'
          : null,
    );
  }

  @override
  List<WordLevel> levelsFor(GameMode mode) => <WordLevel>[
    for (var number = 1; number <= 500; number++) level(mode, number),
  ];

  @override
  Future<bool> isAccepted(String word) async => accepted.contains(word);
}

ModeProgress modeProgress({
  Map<int, int> completedByLength = const <int, int>{},
  Map<int, GameSession> sessionsByLength = const <int, GameSession>{},
  int lastSelectedLength = 3,
}) {
  return ModeProgress(
    lastSelectedLength: lastSelectedLength,
    lengths: <WordLengthBand, LengthProgress>{
      for (final band in WordLengthBand.values)
        band: LengthProgress(
          completedCount: (completedByLength[band.wordLength] ?? 0).clamp(
            0,
            band.levelCount,
          ),
          lastOpenedLevel:
              sessionsByLength[band.wordLength]?.levelNumber ??
              band.globalLevelForLocal(
                ((completedByLength[band.wordLength] ?? 0) + 1).clamp(
                  1,
                  band.levelCount,
                ),
              ),
          session: sessionsByLength[band.wordLength],
        ),
    },
  );
}

AppSave appSave({
  ModeProgress? withHints,
  ModeProgress? withoutHints,
  bool successSoundEnabled = true,
}) {
  return AppSave(
    modes: <GameMode, ModeProgress>{
      GameMode.withHints: withHints ?? modeProgress(),
      GameMode.withoutHints: withoutHints ?? modeProgress(),
    },
    successSoundEnabled: successSoundEnabled,
  );
}

Future<GameStore> createTestStore({
  MemoryStorage? storage,
  AppSave? initialSave,
}) async {
  final effectiveStorage = storage ?? MemoryStorage();
  if (initialSave != null) {
    effectiveStorage.value = jsonEncode(initialSave.toJson());
  }
  final store = GameStore(
    catalog: FakeCatalog(),
    saves: SaveRepository(effectiveStorage),
  );
  await store.initialize();
  return store;
}

Future<void> pumpGame(
  WidgetTester tester, {
  required GameStore store,
  required GameMode mode,
  required int levelNumber,
  SuccessAudioService? audio,
  GameAds? ads,
  bool disableAnimations = false,
}) async {
  final effectiveAds = ads ?? DisabledGameAds();
  await tester.pumpWidget(
    GameScope(
      store: store,
      child: AdsScope(
        ads: effectiveAds,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: GameScreen(
                mode: mode,
                levelNumber: levelNumber,
                successAudioService: audio,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enterWord(WidgetTester tester, String word) async {
  for (final letter in word.toUpperCase().split('')) {
    await tester.tap(find.text(letter).last);
  }
  await tester.tap(find.text('ENTER'));
}

class RecordingSuccessAudio implements SuccessAudioService {
  RecordingSuccessAudio({this.result = true, this.throwOnPlay = false});

  final bool result;
  final bool throwOnPlay;
  int calls = 0;

  @override
  Future<bool> playSuccess() async {
    calls++;
    if (throwOnPlay) throw StateError('audio indisponível');
    return result;
  }
}

class RecordingGameAds extends GameAds {
  RecordingGameAds({
    this.requirePrivacyOptions = false,
    this.throwOnShow = false,
  });

  final bool requirePrivacyOptions;
  final bool throwOnShow;
  int initializeCalls = 0;
  int naturalBreakCalls = 0;
  int privacyOptionsCalls = 0;

  @override
  bool get privacyOptionsRequired => requirePrivacyOptions;

  @override
  Future<void> initialize() async => initializeCalls += 1;

  @override
  Future<void> showInterstitialAtNaturalBreak() async {
    naturalBreakCalls += 1;
    if (throwOnShow) throw StateError('anúncio indisponível');
  }

  @override
  Future<void> showPrivacyOptions() async => privacyOptionsCalls += 1;
}
