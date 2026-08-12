import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/game_store.dart';
import '../app_theme.dart';
import '../game_scope.dart';
import '../navigation.dart';
import 'completion_screen.dart';
import 'level_grid_screen.dart';

class WordLengthScreen extends StatefulWidget {
  const WordLengthScreen({required this.mode, super.key});

  final GameMode mode;

  @override
  State<WordLengthScreen> createState() => _WordLengthScreenState();
}

class _WordLengthScreenState extends State<WordLengthScreen> {
  bool _opening = false;

  Future<void> _openLength(int wordLength) async {
    if (_opening) return;
    _opening = true;
    final store = GameScope.of(context);
    try {
      await store.selectWordLength(widget.mode, wordLength);
      if (!mounted) return;
      await Navigator.of(context).push(
        fastRoute<void>(
          LevelGridScreen(mode: widget.mode, wordLength: wordLength),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GameScope.of(context);
    final progress = store.progressFor(widget.mode);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode.title),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      textScale >= 1.65 || constraints.maxWidth < 280 ? 2 : 3;
                  const gap = 10.0;
                  final cardWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final cardHeight = textScale <= 1.3 ? 118.0 : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Quantas letras?',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Escolha uma categoria. O progresso fica salvo em cada tamanho.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      _OverallProgress(completed: progress.totalCompleted),
                      if (progress.isComplete) ...<Widget>[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('mode_completion_button'),
                          onPressed: () => Navigator.of(context).push(
                            fastRoute<void>(
                              CompletionScreen(mode: widget.mode),
                            ),
                          ),
                          icon: const Icon(Icons.emoji_events_outlined),
                          label: const Text('Ver conclusão do modo'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: gap,
                        runSpacing: gap,
                        children: <Widget>[
                          for (final band in WordLengthBand.values)
                            SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: _LengthCard(
                                mode: widget.mode,
                                band: band,
                                store: store,
                                onTap: () => _openLength(band.wordLength),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '$completed/500 desafios concluídos',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: completed / 500,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LengthCard extends StatelessWidget {
  const _LengthCard({
    required this.mode,
    required this.band,
    required this.store,
    required this.onTap,
  });

  final GameMode mode;
  final WordLengthBand band;
  final GameStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = store.lengthProgressFor(mode, band.wordLength);
    final session = progress.session;
    final terminal =
        session != null &&
        session.isTerminal(store.level(mode, session.levelNumber).answer);
    final active = session != null;
    final status = terminal
        ? 'Resultado pendente'
        : active
        ? 'Partida em andamento'
        : progress.isComplete(band)
        ? 'Categoria concluída'
        : 'Próximo: nível ${progress.completedCount + 1}';
    final semanticState = terminal || active
        ? '$status, ${progress.completedCount} de ${band.levelCount} concluídos'
        : progress.isComplete(band)
        ? 'concluída'
        : '$status, ${progress.completedCount} de ${band.levelCount} concluídos';
    final visualStatus = terminal
        ? 'Resultado'
        : active
        ? 'Em jogo'
        : progress.isComplete(band)
        ? 'Concluída'
        : 'Nível ${progress.completedCount + 1}';
    final selected =
        store.progressFor(mode).lastSelectedLength == band.wordLength;
    final accent = terminal || active
        ? AppColors.secondary
        : progress.isComplete(band)
        ? AppColors.correct
        : selected
        ? AppColors.primary
        : AppColors.muted;
    final statusIcon = terminal
        ? Icons.visibility_outlined
        : active
        ? Icons.play_arrow_rounded
        : progress.isComplete(band)
        ? Icons.check_rounded
        : Icons.arrow_forward_rounded;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${band.wordLength} letras, $semanticState',
      child: Material(
        key: ValueKey<String>('length_card_${band.wordLength}'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[accent.withValues(alpha: .14), AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: terminal || active || progress.isComplete(band) || selected
                  ? accent
                  : AppColors.outline,
              width: terminal || active || progress.isComplete(band) ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${band.wordLength}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      height: .95,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LETRAS',
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.15,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: progress.completedCount / band.levelCount,
                      backgroundColor: AppColors.surfaceHigh,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${progress.completedCount}/${band.levelCount} concluídos',
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(statusIcon, size: 13, color: accent),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          visualStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
