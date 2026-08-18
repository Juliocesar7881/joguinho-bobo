import 'package:flutter/material.dart';

import '../../legal/legal_documents.dart';
import '../ads_scope.dart';
import '../app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final ads = AdsScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o Worde')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: <Widget>[
                const _AboutHeader(),
                const SizedBox(height: 20),
                const _LegalSection(
                  icon: Icons.shield_outlined,
                  title: 'Privacidade, anúncios e dados locais',
                  documentKey: 'privacy_policy_pt_BR',
                  content: privacyPolicyPtBr,
                ),
                if (ads?.privacyOptionsRequired ?? false) ...<Widget>[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('ad_privacy_options'),
                    onPressed: () async {
                      try {
                        await ads!.showPrivacyOptions();
                      } on Object {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não foi possível abrir as opções de privacidade.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text(
                      'Preferências de privacidade de anúncios',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const _LegalSection(
                  icon: Icons.description_outlined,
                  title: 'Licenças e créditos',
                  documentKey: 'third_party_notices_pt_BR',
                  content: thirdPartyNoticesPtBr,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/branding/worde-icon.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Worde',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Versão ${AboutScreen.version}',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Jogo de palavras em inglês; a partida funciona offline.',
                    style: TextStyle(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.icon,
    required this.title,
    required this.documentKey,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String documentKey;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content.trim(),
            key: ValueKey<String>('legal_document_$documentKey'),
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
