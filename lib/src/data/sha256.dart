import 'dart:typed_data';

const _mask32 = 0xffffffff;
const _roundConstants = <int>[
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
];

String sha256Hex(List<int> bytes) {
  final bitLength = bytes.length * 8;
  final paddedLength = ((bytes.length + 9 + 63) ~/ 64) * 64;
  final padded = Uint8List(paddedLength)..setRange(0, bytes.length, bytes);
  padded[bytes.length] = 0x80;
  for (var index = 0; index < 8; index++) {
    padded[paddedLength - 1 - index] = (bitLength >>> (index * 8)) & 0xff;
  }

  final hash = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  final words = Uint32List(64);
  for (var offset = 0; offset < padded.length; offset += 64) {
    for (var index = 0; index < 16; index++) {
      final start = offset + index * 4;
      words[index] =
          (padded[start] << 24) |
          (padded[start + 1] << 16) |
          (padded[start + 2] << 8) |
          padded[start + 3];
    }
    for (var index = 16; index < 64; index++) {
      final smallSigma0 =
          _rotateRight(words[index - 15], 7) ^
          _rotateRight(words[index - 15], 18) ^
          (words[index - 15] >>> 3);
      final smallSigma1 =
          _rotateRight(words[index - 2], 17) ^
          _rotateRight(words[index - 2], 19) ^
          (words[index - 2] >>> 10);
      words[index] =
          (words[index - 16] + smallSigma0 + words[index - 7] + smallSigma1) &
          _mask32;
    }

    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];
    for (var index = 0; index < 64; index++) {
      final bigSigma1 =
          _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
      final choose = (e & f) ^ ((~e & _mask32) & g);
      final temporary1 =
          (h + bigSigma1 + choose + _roundConstants[index] + words[index]) &
          _mask32;
      final bigSigma0 =
          _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temporary2 = (bigSigma0 + majority) & _mask32;
      h = g;
      g = f;
      f = e;
      e = (d + temporary1) & _mask32;
      d = c;
      c = b;
      b = a;
      a = (temporary1 + temporary2) & _mask32;
    }
    hash[0] = (hash[0] + a) & _mask32;
    hash[1] = (hash[1] + b) & _mask32;
    hash[2] = (hash[2] + c) & _mask32;
    hash[3] = (hash[3] + d) & _mask32;
    hash[4] = (hash[4] + e) & _mask32;
    hash[5] = (hash[5] + f) & _mask32;
    hash[6] = (hash[6] + g) & _mask32;
    hash[7] = (hash[7] + h) & _mask32;
  }
  return hash.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
}

int _rotateRight(int value, int amount) =>
    ((value >>> amount) | (value << (32 - amount))) & _mask32;
