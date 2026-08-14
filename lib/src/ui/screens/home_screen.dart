import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../app_theme.dart';
import '../game_scope.dart';
import '../navigation.dart';
import 'about_screen.dart';
import 'word_length_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = GameScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _BrandHeader(),
                  const SizedBox(height: 42),
                  for (final mode in GameMode.values) ...<Widget>[
                    _ModeCard(
                      mode: mode,
                      completed: store.progressFor(mode).totalCompleted,
                      onTap: () => Navigator.of(context).push(
                        fastRoute<void>(
                          WordLengthScreen(mode: mode),
                          name: wordLengthRouteName(mode),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    key: const Key('home_about_button'),
                    onPressed: () => Navigator.of(
                      context,
                    ).push(fastRoute<void>(const AboutScreen())),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Sobre, privacidade e licenças'),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/branding/worde-icon.png',
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 76,
                height: 76,
                color: AppColors.surface,
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Worde',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Descubra palavras. Aprenda inglês.',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.completed,
    required this.onTap,
  });

  final GameMode mode;
  final int completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = mode == GameMode.withHints
        ? Icons.lightbulb_outline_rounded
        : Icons.grid_3x3_rounded;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${mode.title}, $completed de 500 níveis concluídos',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        mode.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completed/500',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
