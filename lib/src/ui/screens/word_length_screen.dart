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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = textScale >= 1.5
                      ? 1
                      : constraints.maxWidth < 360
                      ? 1
                      : constraints.maxWidth < 680
                      ? 2
                      : 3;
                  const gap = 12.0;
                  final cardWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Escolha o tamanho',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Todas as categorias estão disponíveis. Avance no seu ritmo em cada uma.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${progress.totalCompleted}/500 desafios concluídos',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (progress.isComplete) ...<Widget>[
                        const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: <Widget>[
                          for (final band in WordLengthBand.values)
                            SizedBox(
                              width: cardWidth,
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

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${band.wordLength} letras, $semanticState',
      child: Material(
        key: ValueKey<String>('length_card_${band.wordLength}'),
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 154),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active
                    ? AppColors.secondary
                    : progress.isComplete(band)
                    ? AppColors.correct
                    : AppColors.outline,
                width: active || progress.isComplete(band) ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '${band.wordLength}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'letras',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${progress.completedCount}/${band.levelCount} concluídos',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      terminal
                          ? Icons.visibility_outlined
                          : active
                          ? Icons.play_circle_outline_rounded
                          : progress.isComplete(band)
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                      size: 17,
                      color: terminal || active
                          ? AppColors.secondary
                          : progress.isComplete(band)
                          ? AppColors.correct
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: terminal || active
                              ? AppColors.secondary
                              : progress.isComplete(band)
                              ? AppColors.correct
                              : AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
