import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../app_theme.dart';

enum ResultAction { advance, replay, levels }

Future<ResultAction?> showGameResultDialog({
  required BuildContext context,
  required WordLevel level,
  required bool won,
  bool isLastInCategory = false,
}) {
  return showDialog<ResultAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  won ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: won ? AppColors.correct : AppColors.present,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  won ? 'Você acertou!' : 'Não foi dessa vez',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  level.answer.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 14),
                Text('Tradução: ${level.translation}'),
                const SizedBox(height: 6),
                Text(
                  'Significado: ${level.meaning}',
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context, ResultAction.advance),
                  child: Text(
                    won
                        ? isLastInCategory
                              ? 'Ver conclusão'
                              : 'Próximo nível'
                        : 'Tentar novamente',
                  ),
                ),
                if (won) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, ResultAction.replay),
                    child: const Text('Jogar novamente'),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, ResultAction.levels),
                  child: const Text('Voltar aos níveis'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
