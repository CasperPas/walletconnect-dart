import 'dart:convert';
import 'package:walletconnect/src/hex.dart';

import 'interfaces.dart';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class EncryptionPayload {
  late String data;
  late String hmac;
  late String iv;

  EncryptionPayload(
    this.data,
    this.hmac,
    this.iv,
  );

  EncryptionPayload.fromJson(String json) {
    final obj = jsonDecode(json).cast<String, String>();
    data = obj['data'] ?? "";
    hmac = obj['hmac'] ?? "";
    iv = obj['iv'] ?? "";
  }

  @override
  String toString() => jsonEncode({"data": data, "hmac": hmac, "iv": iv});
}

class PayloadAdapter {
  JsonRpc parse(String payload, String key) {
    final encryptedPayload = EncryptionPayload.fromJson(payload);
    final eKey = Key.fromBase16(key);
    final iv = IV.fromBase16(encryptedPayload.iv);
    final hmac = Hmac(sha256, eKey.bytes);
    final digest =
        hmac.convert([...decode(encryptedPayload.data), ...iv.bytes]);
    if (encryptedPayload.hmac != digest.toString()) {
      throw ArgumentError("Authentication failed");
    }
    final encrypter = Encrypter(AES(eKey, mode: AESMode.cbc));
    final decrypted = encrypter.decrypt16(
      encryptedPayload.data,
      iv: iv,
    );

    final decryptedObj = jsonDecode(decrypted);

    if (decryptedObj['method'] != null) {
      return RpcRequest.fromMap(decryptedObj);
    }

    return RpcResponse.fromMap(decryptedObj);
  }

  String prepare(JsonRpc payload, String key, [String? ivStr]) {
    final data = payload.toString();
    return prepareJson(data, key, ivStr);
  }

  String prepareJson(String data, String key, [String? ivStr]) {
    final eKey = Key.fromBase16(key);
    final iv = ivStr != null ? IV.fromBase16(ivStr) : IV.fromSecureRandom(16);

    final encrypter = Encrypter(AES(eKey, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(data, iv: iv);

    final hmac = Hmac(sha256, eKey.bytes);
    final digest = hmac.convert([...encrypted.bytes, ...iv.bytes]);

    return EncryptionPayload(
      encrypted.base16,
      digest.toString(),
      iv.base16,
    ).toString();
  }
}
