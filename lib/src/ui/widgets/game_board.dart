import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../app_theme.dart';

class GameBoard extends StatelessWidget {
  const GameBoard({
    required this.wordLength,
    required this.guesses,
    required this.draft,
    this.maxTileSize = 56,
    this.animatedRow,
    this.revealValue = 1,
    this.shakeValue = 0,
    super.key,
  });

  final int wordLength;
  final List<GuessResult> guesses;
  final String draft;
  final double maxTileSize;
  final int? animatedRow;
  final double revealValue;
  final double shakeValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 5.0;
        final available = math.min(constraints.maxWidth, 560.0);
        final tileSize = math.min(
          maxTileSize.clamp(26.0, 56.0),
          (available - (wordLength - 1) * gap) / wordLength,
        );
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var row = 0; row < 6; row++) ...<Widget>[
                Transform.translate(
                  offset: row == guesses.length
                      ? Offset(math.sin(shakeValue * math.pi * 6) * 8, 0)
                      : Offset.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var column = 0; column < wordLength; column++) ...[
                        _tileFor(row, column, tileSize),
                        if (column != wordLength - 1)
                          const SizedBox(width: gap),
                      ],
                    ],
                  ),
                ),
                if (row != 5) const SizedBox(height: gap),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _tileFor(int row, int column, double size) {
    String letter = '';
    LetterMark? mark;
    if (row < guesses.length) {
      letter = guesses[row].word[column];
      mark = guesses[row].marks[column];
    } else if (row == guesses.length && column < draft.length) {
      letter = draft[column];
    }

    var progress = 1.0;
    if (row == animatedRow) {
      final totalMs = 240 + (wordLength - 1) * 60;
      final elapsed = revealValue * totalMs;
      progress = ((elapsed - column * 60) / 240).clamp(0.0, 1.0).toDouble();
      if (progress < .5) mark = null;
    }
    final angle = progress <= .5
        ? progress * math.pi
        : (1 - progress) * math.pi;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .001)
        ..rotateX(angle),
      child: _LetterTile(
        letter: letter,
        mark: mark,
        size: size,
        row: row,
        column: column,
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.mark,
    required this.size,
    required this.row,
    required this.column,
  });

  final String letter;
  final LetterMark? mark;
  final double size;
  final int row;
  final int column;

  @override
  Widget build(BuildContext context) {
    final color = switch (mark) {
      LetterMark.correct => AppColors.correct,
      LetterMark.present => AppColors.present,
      LetterMark.absent => AppColors.absent,
      null => AppColors.surface,
    };
    final state = switch (mark) {
      LetterMark.correct => 'correta na posição correta',
      LetterMark.present => 'existe em outra posição',
      LetterMark.absent => 'não existe na palavra',
      null => letter.isEmpty ? 'vazia' : 'ainda não avaliada',
    };
    return Semantics(
      excludeSemantics: true,
      label: letter.isEmpty
          ? 'Linha ${row + 1}, coluna ${column + 1}, casa $state'
          : 'Linha ${row + 1}, coluna ${column + 1}, '
                'letra ${letter.toUpperCase()}, $state',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(math.max(7.0, size * .18)),
          border: Border.all(
            color: mark == null
                ? AppColors.outline
                : color.withValues(alpha: .95),
            width: mark == null && letter.isNotEmpty ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(math.max(3.0, size * .08)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  letter.toUpperCase(),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: math.max(17.0, size * .43),
                    fontWeight: FontWeight.w800,
                    color: mark == LetterMark.present
                        ? AppColors.background
                        : AppColors.text,
                  ),
                ),
              ),
            ),
            if (mark != null)
              Positioned(
                bottom: math.max(3.0, size * .08),
                child: _StateMarker(mark: mark!, size: size),
              ),
          ],
        ),
      ),
    );
  }
}

class _StateMarker extends StatelessWidget {
  const _StateMarker({required this.mark, required this.size});

  final LetterMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (mark) {
      LetterMark.correct => Container(
        width: size * .25,
        height: 2,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      LetterMark.present => Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
      LetterMark.absent => const SizedBox(width: 6, child: Divider(height: 2)),
    };
  }
}
