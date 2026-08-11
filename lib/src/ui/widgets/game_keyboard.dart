import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../app_theme.dart';

class GameKeyboard extends StatelessWidget {
  const GameKeyboard({
    required this.marks,
    required this.onLetter,
    required this.onEnter,
    required this.onBackspace,
    required this.enabled,
    super.key,
  });

  final Map<String, LetterMark> marks;
  final ValueChanged<String> onLetter;
  final VoidCallback onEnter;
  final VoidCallback onBackspace;
  final bool enabled;

  static const rows = <String>['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 500.0);
        final gap = (width / 150).clamp(2.0, 4.0).toDouble();
        final keyWidth = (width - gap * 9) / 10;
        final specialKeyWidth = keyWidth * 1.5 + gap / 2;
        final keyHeight = (width * .12).clamp(44.0, 48.0).toDouble();
        return Semantics(
          label: 'Teclado do jogo',
          child: Center(
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _letterRow(
                    rows[0],
                    keyWidth: keyWidth,
                    keyHeight: keyHeight,
                    gap: gap,
                  ),
                  const SizedBox(height: 5),
                  _letterRow(
                    rows[1],
                    keyWidth: keyWidth,
                    keyHeight: keyHeight,
                    gap: gap,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _enterKey(width: specialKeyWidth, height: keyHeight),
                      SizedBox(width: gap),
                      for (final (index, letter)
                          in rows[2].split('').indexed) ...<Widget>[
                        _letterKey(letter, width: keyWidth, height: keyHeight),
                        if (index != rows[2].length - 1) SizedBox(width: gap),
                      ],
                      SizedBox(width: gap),
                      _backspaceKey(width: specialKeyWidth, height: keyHeight),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _letterRow(
    String letters, {
    required double keyWidth,
    required double keyHeight,
    required double gap,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      for (final (index, letter) in letters.split('').indexed) ...<Widget>[
        _letterKey(letter, width: keyWidth, height: keyHeight),
        if (index != letters.length - 1) SizedBox(width: gap),
      ],
    ],
  );

  Widget _letterKey(
    String letter, {
    required double width,
    required double height,
  }) => _LetterKey(
    letter: letter,
    mark: marks[letter],
    enabled: enabled,
    onTap: () => onLetter(letter),
    width: width,
    height: height,
  );

  Widget _enterKey({required double width, required double height}) =>
      _SpecialKey(
        label: 'Enter',
        onTap: enabled ? onEnter : null,
        width: width,
        height: height,
        child: const Text(
          'ENTER',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      );

  Widget _backspaceKey({required double width, required double height}) =>
      _SpecialKey(
        label: 'Apagar',
        onTap: enabled ? onBackspace : null,
        width: width,
        height: height,
        child: const Icon(Icons.backspace_outlined, size: 20),
      );
}

class _LetterKey extends StatelessWidget {
  const _LetterKey({
    required this.letter,
    required this.mark,
    required this.enabled,
    required this.onTap,
    required this.width,
    required this.height,
  });

  final String letter;
  final LetterMark? mark;
  final bool enabled;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = switch (mark) {
      LetterMark.correct => AppColors.correct,
      LetterMark.present => AppColors.present,
      LetterMark.absent => AppColors.absent,
      null => AppColors.surfaceHigh,
    };
    final state = switch (mark) {
      LetterMark.correct => 'correta',
      LetterMark.present => 'presente',
      LetterMark.absent => 'ausente',
      null => 'não usada',
    };
    return SizedBox(
      key: ValueKey<String>('letter_key_$letter'),
      width: width,
      height: height,
      child: Semantics(
        button: true,
        enabled: enabled,
        excludeSemantics: true,
        label: 'Letra ${letter.toUpperCase()}, $state',
        child: Material(
          color: enabled ? color : color.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        letter.toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          color: mark == LetterMark.present
                              ? AppColors.background
                              : AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                if (mark != null)
                  Positioned(
                    bottom: 5,
                    left: 0,
                    right: 0,
                    child: Center(child: _KeyStateMarker(mark: mark!)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialKey extends StatelessWidget {
  const _SpecialKey({
    required this.label,
    required this.onTap,
    required this.child,
    required this.width,
    required this.height,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey<String>('special_key_${label.toLowerCase()}'),
      width: width,
      height: height,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        excludeSemantics: true,
        label: label,
        child: Material(
          color: AppColors.surfaceHigh.withValues(
            alpha: onTap == null ? .5 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: AppColors.primary.withValues(
                alpha: onTap == null ? .35 : .9,
              ),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyStateMarker extends StatelessWidget {
  const _KeyStateMarker({required this.mark});

  final LetterMark mark;

  @override
  Widget build(BuildContext context) {
    final color = mark == LetterMark.present
        ? AppColors.background
        : AppColors.text;
    return switch (mark) {
      LetterMark.correct => Container(width: 11, height: 2, color: color),
      LetterMark.present => Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      LetterMark.absent => Icon(Icons.remove, size: 9, color: color),
    };
  }
}
