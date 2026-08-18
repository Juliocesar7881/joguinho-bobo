import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/success_audio_service.dart';
import '../../domain/models.dart';
import '../../domain/word_evaluator.dart';
import '../../state/game_store.dart';
import '../app_theme.dart';
import '../ads_scope.dart';
import '../game_scope.dart';
import '../navigation.dart';
import '../widgets/game_board.dart';
import '../widgets/game_keyboard.dart';
import '../widgets/result_dialog.dart';
import 'category_completion_screen.dart';
import 'completion_screen.dart';

class GameScreen extends StatefulWidget {
  GameScreen({
    required this.mode,
    required this.levelNumber,
    SuccessAudioService? successAudioService,
    super.key,
  }) : successAudioService = successAudioService ?? NativeSuccessAudioService();

  final GameMode mode;
  final int levelNumber;
  final SuccessAudioService successAudioService;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final AnimationController _shakeController;
  late final AnimationController _successController;
  bool _started = false;
  bool _ready = false;
  bool _inputLocked = false;
  bool _dialogVisible = false;
  bool _successVisible = false;
  int? _animatedRow;

  WordLengthBand get _band =>
      WordLengthBand.tryFromGlobalLevel(widget.levelNumber)!;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(vsync: this, value: 1);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final store = GameScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare(store));
    });
  }

  Future<void> _prepare(GameStore store) async {
    final session =
        store.sessionFor(widget.mode, widget.levelNumber) ??
        await store.openLevel(widget.mode, widget.levelNumber);
    if (!mounted) return;
    final level = store.level(widget.mode, widget.levelNumber);
    setState(() {
      _ready = true;
      _inputLocked = session.isTerminal(level.answer);
    });
    if (session.isTerminal(level.answer)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showResult(session.isWon(level.answer)));
      });
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ready || _inputLocked) return;
    final store = GameScope.of(context);
    final level = store.level(widget.mode, widget.levelNumber);
    final session = store.sessionFor(widget.mode, widget.levelNumber);
    if (session == null) return;
    _revealController.duration = Duration(
      milliseconds: 240 + (level.wordLength - 1) * 60,
    );
    setState(() {
      _inputLocked = true;
      _animatedRow = session.submittedGuesses.length;
      _revealController.value = 0;
    });

    late final SubmitOutcome outcome;
    try {
      outcome = await store.submit(widget.mode, widget.levelNumber);
    } on Object {
      if (!mounted) return;
      setState(() {
        _animatedRow = null;
        _revealController.value = 1;
        _inputLocked = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a partida.')),
        );
      return;
    }
    if (!mounted) return;
    if (outcome.status != SubmitStatus.accepted) {
      setState(() {
        _animatedRow = null;
        _revealController.value = 1;
      });
      unawaited(HapticFeedback.lightImpact());
      await _shakeController.forward(from: 0);
      if (!mounted) return;
      final message = outcome.status == SubmitStatus.incomplete
          ? 'Complete a palavra.'
          : 'Essa palavra não foi encontrada.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text(message),
          ),
        );
      setState(() => _inputLocked = false);
      return;
    }

    if (!outcome.won && !outcome.lost) {
      unawaited(HapticFeedback.lightImpact());
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _revealController.value = 1;
    } else {
      await _revealController.forward();
    }
    if (!mounted) return;
    setState(() {
      _animatedRow = null;
      _inputLocked = outcome.won || outcome.lost;
    });
    if (outcome.won) {
      unawaited(HapticFeedback.mediumImpact());
      await _playSuccessFeedback(store);
      await _showAdAtNaturalBreak();
      if (mounted) await _showResult(true);
    } else if (outcome.lost) {
      unawaited(HapticFeedback.mediumImpact());
      await _showAdAtNaturalBreak();
      if (mounted) await _showResult(false);
    }
  }

  Future<void> _showAdAtNaturalBreak() async {
    if (!mounted) return;
    try {
      await AdsScope.of(context).showInterstitialAtNaturalBreak();
    } on Object {
      // Ads are optional. A network or SDK failure never blocks the result.
    }
  }

  Future<void> _playSuccessFeedback(GameStore store) async {
    if (store.save.successSoundEnabled) {
      unawaited(
        widget.successAudioService.playSuccess().catchError(
          (Object _) => false,
        ),
      );
    }
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _successVisible = true);
    await _successController.forward(from: 0);
    if (!mounted) return;
    setState(() => _successVisible = false);
  }

  Future<void> _showResult(bool won) async {
    if (_dialogVisible || !mounted) return;
    _dialogVisible = true;
    final store = GameScope.of(context);
    final level = store.level(widget.mode, widget.levelNumber);
    final action = await showGameResultDialog(
      context: context,
      level: level,
      won: won,
      isLastInCategory: widget.levelNumber == _band.lastGlobalLevel,
    );
    _dialogVisible = false;
    if (!mounted || action == null) return;

    switch (action) {
      case ResultAction.levels:
        if (!await _runResultMutation(
          () => store.clearSession(widget.mode, _band.wordLength),
          won: won,
        )) {
          return;
        }
        if (mounted) Navigator.of(context).pop();
        return;
      case ResultAction.replay:
        if (!await _runResultMutation(
          () => store.restartLevel(widget.mode, widget.levelNumber),
          won: won,
        )) {
          return;
        }
        if (!mounted) return;
        setState(() {
          _inputLocked = false;
          _animatedRow = null;
          _revealController.value = 1;
        });
        return;
      case ResultAction.advance:
        if (!won) {
          if (!await _runResultMutation(
            () => store.restartLevel(widget.mode, widget.levelNumber),
            won: won,
          )) {
            return;
          }
          if (!mounted) return;
          setState(() {
            _inputLocked = false;
            _animatedRow = null;
            _revealController.value = 1;
          });
          return;
        }
        if (widget.levelNumber == _band.lastGlobalLevel) {
          if (!await _runResultMutation(
            () => store.clearSession(widget.mode, _band.wordLength),
            won: won,
          )) {
            return;
          }
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            fastRoute<void>(
              store.progressFor(widget.mode).isComplete
                  ? CompletionScreen(mode: widget.mode)
                  : CategoryCompletionScreen(mode: widget.mode, band: _band),
            ),
          );
          return;
        }
        final next = widget.levelNumber + 1;
        if (!await _runResultMutation(
          () => store.restartLevel(widget.mode, next),
          won: won,
        )) {
          return;
        }
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          fastRoute<void>(GameScreen(mode: widget.mode, levelNumber: next)),
        );
    }
  }

  Future<bool> _runResultMutation(
    Future<void> Function() mutation, {
    required bool won,
  }) async {
    try {
      await mutation();
      return true;
    } on Object {
      if (!mounted) return false;
      setState(() => _inputLocked = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Não foi possível concluir a ação. Tente novamente.'),
          ),
        );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showResult(won));
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GameScope.of(context);
    final level = store.level(widget.mode, widget.levelNumber);
    final session =
        store.sessionFor(widget.mode, widget.levelNumber) ??
        GameSession(levelNumber: widget.levelNumber);
    final guesses = store.evaluatedGuesses(widget.mode, widget.levelNumber);
    final terminal = session.isTerminal(level.answer);
    final localLevel = _band.localLevelForGlobal(widget.levelNumber);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: <Widget>[
              Text('Nível $localLevel de ${_band.levelCount}'),
              Text(
                '${widget.mode.title} • ${_band.wordLength} letras',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            key: const Key('success_sound_toggle'),
            tooltip: store.save.successSoundEnabled
                ? 'Desativar som de acerto'
                : 'Ativar som de acerto',
            onPressed: () async {
              try {
                await store.setSuccessSoundEnabled(
                  !store.save.successSoundEnabled,
                );
              } on Object {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Não foi possível alterar o som.'),
                    ),
                  );
              }
            },
            icon: Icon(
              store.save.successSoundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, upperConstraints) {
                          final textScale = MediaQuery.textScalerOf(
                            context,
                          ).scale(1);
                          final hintBudget = widget.mode == GameMode.withHints
                              ? 116.0 + (textScale - 1).clamp(0, 1) * 70
                              : 36.0;
                          final maxTileSize =
                              ((upperConstraints.maxHeight - hintBudget - 34) /
                                      6)
                                  .clamp(26.0, 56.0)
                                  .toDouble();
                          return SingleChildScrollView(
                            // On very short phones the bilingual hint can make
                            // the upper section scroll. Anchor that section to
                            // the board so the playing surface always remains
                            // visibly separated from the fixed keyboard.
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: 600,
                                  minHeight: upperConstraints.maxHeight - 8,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    if (widget.mode == GameMode.withHints)
                                      _BilingualHint(level: level)
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Text(
                                          'Palavra com ${level.wordLength} letras',
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ),
                                    AnimatedBuilder(
                                      animation: _revealController,
                                      builder: (context, _) => AnimatedBuilder(
                                        animation: _shakeController,
                                        builder: (context, _) => GameBoard(
                                          wordLength: level.wordLength,
                                          guesses: guesses,
                                          draft: session.draft,
                                          maxTileSize: maxTileSize,
                                          animatedRow: _animatedRow,
                                          revealValue: _revealController.value,
                                          shakeValue: _shakeController.value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      // The keyboard stays comfortably above the system edge,
                      // while this top inset clearly separates it from the
                      // board without consuming another scrollable region.
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 44),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: GameKeyboard(
                          marks: WordEvaluator.keyboardMarks(
                            _animatedRow == null
                                ? guesses
                                : guesses.take(_animatedRow!).toList(),
                          ),
                          enabled: _ready && !_inputLocked && !terminal,
                          onLetter: (letter) => store.addLetter(
                            widget.mode,
                            widget.levelNumber,
                            letter,
                          ),
                          onBackspace: () => store.deleteLetter(
                            widget.mode,
                            widget.levelNumber,
                          ),
                          onEnter: _submit,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_successVisible)
                  Positioned.fill(
                    child: _SuccessCheck(animation: _successController),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BilingualHint extends StatelessWidget {
  const _BilingualHint({required this.level});

  final WordLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Dica (PT)',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            level.hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.3),
          ),
          const SizedBox(height: 7),
          Container(width: 42, height: 1, color: AppColors.outline),
          const SizedBox(height: 7),
          const Text(
            'Hint (EN)',
            style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            level.hintEn!,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _SuccessCheck extends StatelessWidget {
  const _SuccessCheck({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final value = animation.value;
          final scale = TweenSequence<double>(<TweenSequenceItem<double>>[
            TweenSequenceItem<double>(
              tween: Tween<double>(
                begin: .72,
                end: 1.08,
              ).chain(CurveTween(curve: Curves.easeOutBack)),
              weight: 72,
            ),
            TweenSequenceItem<double>(
              tween: Tween<double>(begin: 1.08, end: 1),
              weight: 28,
            ),
          ]).transform(value);
          final opacity = value < .16
              ? value / .16
              : value > .78
              ? (1 - value) / .22
              : 1.0;
          return Center(
            child: Semantics(
              liveRegion: true,
              label: 'Palavra correta',
              child: Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          );
        },
        child: Container(
          key: const Key('success_check_animation'),
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            color: AppColors.correct,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.correct.withValues(alpha: .4),
                blurRadius: 30,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, size: 68, color: Colors.white),
        ),
      ),
    );
  }
}
