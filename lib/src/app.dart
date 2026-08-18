import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ads/game_ads.dart';
import 'state/game_store.dart';
import 'ui/ads_scope.dart';
import 'ui/app_theme.dart';
import 'ui/game_scope.dart';
import 'ui/screens/home_screen.dart';

class LexiNexoApp extends StatefulWidget {
  LexiNexoApp({required this.store, GameAds? ads, super.key})
    : ads = ads ?? DisabledGameAds();

  final GameStore store;
  final GameAds ads;

  @override
  State<LexiNexoApp> createState() => _LexiNexoAppState();
}

class _LexiNexoAppState extends State<LexiNexoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.ads.initialize().catchError((Object _) {}));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.ads.initialize().catchError((Object _) {}));
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.store.flush().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.ads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScope(
      store: widget.store,
      child: AdsScope(
        ads: widget.ads,
        child: MaterialApp(
          title: 'Worde',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const <Locale>[Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

class InitializationErrorApp extends StatelessWidget {
  const InitializationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.error_outline_rounded, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Não foi possível carregar os níveis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Feche o aplicativo e tente novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
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
