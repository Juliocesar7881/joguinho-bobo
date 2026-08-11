import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/audio/success_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NativeSuccessAudioService.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = NativeSuccessAudioService(channel: channel);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('invoca exatamente o metodo nativo de sucesso', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return true;
    });

    expect(await service.playSuccess(), isTrue);
    expect(receivedCall?.method, NativeSuccessAudioService.playSuccessMethod);
    expect(receivedCall?.arguments, isNull);
  });

  test('retorno nulo da plataforma e tratado como falha inofensiva', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);

    expect(await service.playSuccess(), isFalse);
  });

  test('erro da plataforma nao escapa para a partida', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'AUDIO_UNAVAILABLE');
    });

    expect(await service.playSuccess(), isFalse);
  });

  test('canal nativo ausente nao escapa para a partida', () async {
    expect(await service.playSuccess(), isFalse);
  });
}
