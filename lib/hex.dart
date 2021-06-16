import 'dart:typed_data';

const _CHARS = "0123456789abcdef";

String encode(Uint8List value, [String prefix = "0x"]) {
  return prefix +
      value.map((b) => _CHARS[(b >> 4) & 0x0f] + _CHARS[b & 0x0f]).join();
}

int _hexToBin(String ch) {
  if (ch.length != 1) throw ArgumentError("Input string must be 1 in length.");
  final c = ch[0].toLowerCase();
  final res = _CHARS.indexOf(c);
  if (res == -1) throw ArgumentError("$ch is not a valid hex character");
  return res;
}

Uint8List decode(String value) {
  if (value.length % 2 != 0)
    throw ArgumentError("Hex-string must have an even number of digits");
  final normalized = value.startsWith("0x") ? value.substring(2) : value;
  return Uint8List.fromList([
    for (var i = 0; i < normalized.length; i += 2)
      (_hexToBin(normalized[i]) << 4) + _hexToBin(normalized[i + 1])
  ]);
}
