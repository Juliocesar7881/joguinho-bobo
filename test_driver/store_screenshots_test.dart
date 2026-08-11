import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputRoot = Platform.environment['LEXINEXO_SCREENSHOT_OUTPUT'];
  if (outputRoot == null || outputRoot.trim().isEmpty) {
    throw StateError('LEXINEXO_SCREENSHOT_OUTPUT não foi definido.');
  }
  await integrationDriver(
    onScreenshot: (name, image, [args]) async {
      final relativeParts = name.split('/');
      final output = File(
        '${<String>[outputRoot, ...relativeParts].join(Platform.pathSeparator)}.png',
      );
      await output.parent.create(recursive: true);
      await output.writeAsBytes(image, flush: true);
      return true;
    },
  );
}
