import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/app.dart';
import 'package:lexinexo/src/data/save_repository.dart';
import 'package:lexinexo/src/state/game_store.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pausar o aplicativo aguarda a fila de persistencia', (
    tester,
  ) async {
    final saves = _TrackingSaveRepository();
    final store = GameStore(catalog: FakeCatalog(), saves: saves);
    final ads = RecordingGameAds();
    await store.initialize();
    await tester.pumpWidget(LexiNexoApp(store: store, ads: ads));
    await tester.pumpAndSettle();
    expect(ads.initializeCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(saves.flushCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(ads.initializeCalls, 2);
  });
}

class _TrackingSaveRepository extends SaveRepository {
  _TrackingSaveRepository() : super(MemoryStorage());

  int flushCalls = 0;

  @override
  Future<void> flush() async {
    flushCalls++;
  }
}
