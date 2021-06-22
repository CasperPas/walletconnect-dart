import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:test/test.dart';
import 'package:walletconnect/src/hex.dart';

void main() {
  final key =
      Uint8List.fromList([12, 0, 50, 23, 53, 129, 99, 217, 233, 88, 255]);
  const hexKey = "0x0c003217358163d9e958ff";
  // Javascript equivalent:
  // "0x" + [12, 0, 50, 23, 53, 129, 99, 217, 233, 88, 255].map(e => e.toString(16).padStart(2, "0")).join("")
  final encoded = encode(key);

  test('encode', () {
    expect(encoded, equals(hexKey));
  });

  test('decode', () {
    final decoded = decode(encoded);
    expect(listEquals(decoded, key), equals(true));
  });
}
