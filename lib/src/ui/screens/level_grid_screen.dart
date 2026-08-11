import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/game_store.dart';
import '../app_theme.dart';
import '../game_scope.dart';
import '../navigation.dart';
import 'category_completion_screen.dart';
import 'game_screen.dart';

class LevelGridScreen extends StatefulWidget {
  const LevelGridScreen({
    required this.mode,
    required this.wordLength,
    super.key,
  });

  final GameMode mode;
  final int wordLength;

  @override
  State<LevelGridScreen> createState() => _LevelGridScreenState();
}

class _LevelGridScreenState extends State<LevelGridScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _positioned = false;
  bool _opening = false;

  WordLengthBand get _band =>
      WordLengthBand.tryFromWordLength(widget.wordLength)!;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openLevel(int globalLevelNumber) async {
    if (_opening) return;
    _opening = true;
    final store = GameScope.of(context);
    final progress = store.lengthProgressFor(widget.mode, widget.wordLength);
    final pendingResultLevel = _pendingResultLevel(store, progress);
    final levelNumber = pendingResultLevel ?? globalLevelNumber;
    try {
      await store.openLevel(widget.mode, levelNumber);
      if (!mounted) return;
      await Navigator.of(context).push(
        fastRoute<void>(
          GameScreen(mode: widget.mode, levelNumber: levelNumber),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GameScope.of(context);
    final progress = store.lengthProgressFor(widget.mode, widget.wordLength);
    final pendingResultLevel = _pendingResultLevel(store, progress);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('${widget.wordLength} letras'),
            Text(
              widget.mode.title,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        titleSpacing: 8,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 360
                ? 4
                : constraints.maxWidth < 650
                ? 5
                : 8;
            if (!_positioned) {
              _positioned = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_scrollController.hasClients) return;
                final targetGlobal =
                    pendingResultLevel ??
                    (progress.isComplete(_band)
                        ? _band.lastGlobalLevel
                        : progress.nextGlobalLevel(_band));
                final target = _band.localLevelForGlobal(targetGlobal);
                final row = (target - 1) ~/ columns;
                final gridWidth = math.min(constraints.maxWidth, 720.0) - 40;
                final cellSize = (gridWidth - (columns - 1) * 10) / columns;
                final offset = math.max(0.0, row * (cellSize + 10) - 80.0);
                _scrollController.jumpTo(
                  math.min(offset, _scrollController.position.maxScrollExtent),
                );
              });
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            '${progress.completedCount}/${_band.levelCount} concluídos',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              if (pendingResultLevel != null) {
                                _openLevel(pendingResultLevel);
                              } else if (progress.isComplete(_band)) {
                                Navigator.of(context).push(
                                  fastRoute<void>(
                                    CategoryCompletionScreen(
                                      mode: widget.mode,
                                      band: _band,
                                    ),
                                  ),
                                );
                              } else {
                                _openLevel(progress.nextGlobalLevel(_band));
                              }
                            },
                            icon: Icon(
                              pendingResultLevel != null
                                  ? Icons.visibility_outlined
                                  : progress.isComplete(_band)
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(
                              pendingResultLevel != null
                                  ? 'Ver resultado'
                                  : progress.isComplete(_band)
                                  ? 'Categoria concluída'
                                  : 'Continuar',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _band.levelCount,
                        itemBuilder: (context, index) {
                          final localNumber = index + 1;
                          final globalNumber = _band.globalLevelForLocal(
                            localNumber,
                          );
                          final completed =
                              localNumber <= progress.completedCount;
                          final available =
                              !progress.isComplete(_band) &&
                              localNumber == progress.completedCount + 1;
                          final active =
                              progress.session?.levelNumber == globalNumber;
                          return _LevelTile(
                            number: localNumber,
                            completed: completed,
                            available: available,
                            active: active,
                            onTap: completed || available
                                ? () => _openLevel(globalNumber)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  int? _pendingResultLevel(GameStore store, LengthProgress progress) {
    final session = progress.session;
    if (session == null) return null;
    final answer = store.level(widget.mode, session.levelNumber).answer;
    return session.isTerminal(answer) ? session.levelNumber : null;
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.number,
    required this.completed,
    required this.available,
    required this.active,
    required this.onTap,
  });

  final int number;
  final bool completed;
  final bool available;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = onTap == null;
    final background = completed
        ? AppColors.surfaceHigh
        : AppColors.surface.withValues(alpha: available ? 1 : .55);
    final state = completed
        ? 'concluído'
        : available
        ? 'disponível'
        : 'bloqueado';
    return Semantics(
      button: !locked,
      enabled: !locked,
      excludeSemantics: true,
      label: 'Nível $number, $state${active ? ', partida em andamento' : ''}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? AppColors.secondary
                    : available
                    ? AppColors.primary
                    : AppColors.outline.withValues(alpha: .55),
                width: active || available ? 2.5 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Text(
                  '$number',
                  style: TextStyle(
                    color: locked
                        ? AppColors.muted.withValues(alpha: .48)
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (completed)
                  const Positioned(
                    right: 5,
                    top: 5,
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: AppColors.correct,
                    ),
                  ),
                if (locked)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: AppColors.muted.withValues(alpha: .42),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
