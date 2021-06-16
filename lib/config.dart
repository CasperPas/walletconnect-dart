import 'dart:convert';

import 'package:flutter/foundation.dart';

class Config {
  String handshakeTopic;
  String bridge;
  String key;
  String protocol;
  int version;

  Config(
    this.handshakeTopic,
    this.bridge,
    this.key, [
    this.protocol = "wc",
    this.version = 1,
  ]);

  Config.fromMap(Map<String, dynamic> jsonObj)
      : this(
          jsonObj["handshakeTopic"],
          jsonObj["bridge"],
          jsonObj["key"],
          jsonObj["protocol"],
          jsonObj["version"],
        );

  Config.fromJson(String json) : this.fromMap(jsonDecode(json));

  Map<String, dynamic> get asMap => {
        "handshakeTopic": handshakeTopic,
        "bridge": bridge,
        "key": key,
        "protocol": protocol,
        "version": version,
      };

  String toWCUri() =>
      "wc:$handshakeTopic@$version?bridge=${Uri.encodeFull(bridge)}&key=$key";

  static Config fromWCUri(String uri) {
    final protocolSeparator = uri.indexOf(':');
    final handshakeTopicSeparator = uri.indexOf('@', protocolSeparator);
    final versionSeparator = uri.indexOf('?');
    final protocol = uri.substring(0, protocolSeparator);
    final handshakeTopic =
        uri.substring(protocolSeparator + 1, handshakeTopicSeparator);

    if (versionSeparator > 0) {
      final version = int.tryParse(
              uri.substring(handshakeTopicSeparator + 1, versionSeparator)) ??
          1;
      final params = {};
      uri.substring(versionSeparator + 1).split("&").forEach((it) {
        final param = it.split("=");
        params[param[0]] = Uri.encodeComponent(param[1]);
      });
      final bridge = params["bridge"] ?? null;
      final key = params["key"] ?? null;

      if (bridge == null) throw ErrorDescription("Bridge is missing");
      if (key == null) throw ErrorDescription("Key is missing");

      return Config(handshakeTopic, bridge, key, protocol, version);
    }

    final version =
        int.tryParse(uri.substring(handshakeTopicSeparator + 1)) ?? 1;
    return Config(handshakeTopic, "", "key", protocol, version);
  }
}
