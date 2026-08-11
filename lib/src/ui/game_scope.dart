import 'package:flutter/widgets.dart';

import '../state/game_store.dart';

class GameScope extends InheritedNotifier<GameStore> {
  const GameScope({required GameStore store, required super.child, super.key})
    : super(notifier: store);

  static GameStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GameScope>();
    assert(scope != null, 'GameScope não encontrado.');
    return scope!.notifier!;
  }
}
