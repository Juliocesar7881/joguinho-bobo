import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/data/catalog_repository.dart';
import 'src/data/save_repository.dart';
import 'src/state/game_store.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  final startedAt = DateTime.now();

  try {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    final store = GameStore(
      catalog: CatalogRepository(),
      saves: SaveRepository(PreferencesSaveStorage()),
    );
    await store.initialize();
    final remainingMilliseconds =
        600 - DateTime.now().difference(startedAt).inMilliseconds;
    if (remainingMilliseconds > 0) {
      await Future<void>.delayed(Duration(milliseconds: remainingMilliseconds));
    }
    runApp(LexiNexoApp(store: store));
    binding.allowFirstFrame();
  } on Object {
    runApp(const InitializationErrorApp());
    binding.allowFirstFrame();
  }
}
