import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../app_theme.dart';
import '../navigation.dart';

class CategoryCompletionScreen extends StatelessWidget {
  const CategoryCompletionScreen({
    required this.mode,
    required this.band,
    super.key,
  });

  final GameMode mode;
  final WordLengthBand band;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: AppColors.correct.withValues(alpha: .15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: AppColors.correct,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${band.wordLength} letras concluídas!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Você venceu os ${band.levelCount} desafios de ${band.wordLength} letras no modo ${mode.title.toLowerCase()}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('back_to_word_lengths'),
                      onPressed: () => Navigator.of(context).popUntil(
                        (route) =>
                            route.isFirst ||
                            route.settings.name == wordLengthRouteName(mode),
                      ),
                      icon: const Icon(Icons.apps_rounded),
                      label: const Text('Voltar aos tamanhos'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      child: const Text('Voltar ao início'),
                    ),
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
