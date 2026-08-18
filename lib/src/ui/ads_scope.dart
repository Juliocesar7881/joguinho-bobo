import 'package:flutter/widgets.dart';

import '../ads/game_ads.dart';

class AdsScope extends InheritedNotifier<GameAds> {
  const AdsScope({required GameAds ads, required super.child, super.key})
    : super(notifier: ads);

  static GameAds of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdsScope>();
    assert(scope != null, 'AdsScope não encontrado na árvore de widgets.');
    return scope!.notifier!;
  }

  static GameAds? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdsScope>()?.notifier;
}
