import 'package:test/test.dart';
import 'package:walletconnect/encryption.dart';

void main() {
  final key =
      "a9930f5d16577367f5a94ad1895a57699af2fcbf5488de9bd8ce9416c7c171f4";
  const payload =
      '{"id":1623917486542444,"jsonrpc":"2.0","error":{"code":-32000,"message":"Session Rejected"}}';
  const payloadEncrypted =
      '{"data":"88756345b12d0ff165317fa19e8a1ccd2f855bf4673ef8085bae5f9ba07ad806e32a65416350cce8be7d84ce7e00d1473b186a54ef415480ee1c1535a0f38e716603ffe43abe278847077cf50406c246223b1268fcc8e2719a022ce3c155955e","hmac":"a199f4eae1697c4e90c34df15d9ba4f3e9d3c134926e7c5325907aa054402795","iv":"c3d87fd6ee61d27609b521377e6e5e04"}';
  final adapter = PayloadAdapter();

  final payloadEncryptedObj = EncryptionPayload.fromJson(payloadEncrypted);

  test('encode', () {
    final res = adapter.prepareJson(payload, key, payloadEncryptedObj.iv);
    final resObj = EncryptionPayload.fromJson(res);
    expect(resObj.iv, equals(payloadEncryptedObj.iv));
    expect(resObj.data, equals(payloadEncryptedObj.data));
    expect(resObj.hmac, equals(payloadEncryptedObj.hmac));
  });

  test('decode', () {
    final res = adapter.parse(payloadEncrypted, key);
    expect(payload, equals(res.toString()));
  });
}
