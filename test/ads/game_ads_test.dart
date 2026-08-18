import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/ads/game_ads.dart';

void main() {
  test('intersticial fica elegível somente a cada três resultados', () {
    final gate = InterstitialFrequencyGate();

    expect(gate.registerResult(), isFalse);
    expect(gate.registerResult(), isFalse);
    expect(gate.registerResult(), isTrue);
    gate.markShown();
    expect(gate.registerResult(), isFalse);
    expect(gate.registerResult(), isFalse);
    expect(gate.registerResult(), isFalse);
  });

  test('intervalo mínimo libera nova exibição após três minutos', () {
    var now = DateTime(2026, 8, 17, 12);
    final gate = InterstitialFrequencyGate(now: () => now);

    gate.registerResult();
    gate.registerResult();
    expect(gate.registerResult(), isTrue);
    gate.markShown();

    now = now.add(const Duration(minutes: 2, seconds: 59));
    gate.registerResult();
    gate.registerResult();
    expect(gate.registerResult(), isFalse);

    now = now.add(const Duration(seconds: 1));
    gate.registerResult();
    gate.registerResult();
    expect(gate.registerResult(), isTrue);
  });
}
