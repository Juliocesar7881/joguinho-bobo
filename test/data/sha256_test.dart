import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/data/sha256.dart';

void main() {
  test('sha256 interno confere com vetores conhecidos', () {
    expect(
      sha256Hex(const <int>[]),
      'e3b0c44298fc1c149afbf4c8996fb924'
      '27ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223'
      'b00361a396177a9cb410ff61f20015ad',
    );
  });
}
