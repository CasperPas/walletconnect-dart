import 'dart:convert';
import 'dart:typed_data';

import 'package:walletconnect/src/hex.dart';

class PeerMeta {
  String url;
  String name;
  List<String> icons;
  String? description;
  String? scheme;

  PeerMeta(
    this.url,
    this.name,
    this.icons, {
    this.scheme,
    this.description,
  });

  Map<String, dynamic> get asMap => {
        "url": url,
        "name": name,
        "icons": icons,
        "scheme": scheme,
        "description": description,
      };

  PeerMeta.fromMap(Map<String, dynamic> jsonObj)
      : this(
          jsonObj['url'],
          jsonObj['name'],
          jsonObj['icons']?.cast<String>(),
          scheme: jsonObj['scheme'],
          description: jsonObj['description'],
        );

  PeerMeta.fromJson(String json) : this.fromMap(jsonDecode(json));
}

class ClientInfo {
  String peerId;
  PeerMeta peerMeta;
  int? chainId;
  bool? approved;

  ClientInfo(
    this.peerId,
    this.peerMeta, {
    this.approved = false,
    this.chainId = 0,
  });

  Map<String, dynamic> get asMap => {
        "peerId": peerId,
        "peerMeta": peerMeta.asMap,
        "approved": approved,
        "chainId": chainId,
      };

  ClientInfo.fromMap(Map<String, dynamic> jsonObj)
      : this(
          jsonObj['peerId'],
          PeerMeta.fromMap(jsonObj['peerMeta']),
          approved: jsonObj['approved'],
          chainId: jsonObj['chainId'],
        );

  ClientInfo.fromJson(String json) : this.fromMap(jsonDecode(json));
}

class WalletInfo {
  String peerId;
  int chainId;
  bool approved;
  List<String> accounts;
  PeerMeta peerMeta;

  WalletInfo(
    this.peerId,
    this.chainId,
    this.approved,
    this.accounts,
    this.peerMeta,
  );
}

class JsonRpc {
  final int id;
  final String jsonrpc = "2.0";

  JsonRpc(this.id);

  Map<String, dynamic> get asMap => {};

  @override
  String toString() => jsonEncode(asMap);
}

class RpcMethods {
  static const SEND_TRANSACTION = "eth_sendTransaction";
  static const SESSION_REQUEST = "wc_sessionRequest";
  static const SESSION_UPDATE = "wc_sessionUpdate";
  static const SIGN_MESSAGE = "personal_sign";
  static const ETH_SIGN_TRANSACTION = "eth_signTransaction";
  static const ETH_SEND_RAW_TRANSACTION = "eth_sendRawTransaction";
}

class RpcRequest extends JsonRpc {
  String method;
  List<dynamic> params;

  RpcRequest(int id, this.method, this.params) : super(id);

  RpcRequest.sendTransaction(
    int id,
    String from,
    String value,
    String data, {
    String? to,
    String? nonce,
    String? gasPrice,
    String? gasLimit,
  }) : this(id, RpcMethods.SEND_TRANSACTION, [
          {
            "from": from,
            "to": to,
            "nonce": nonce,
            "gasPrice": gasPrice,
            "gas": gasLimit,
            "value": value,
            "data": data,
          }
        ]);

  RpcRequest.sessionRequest(int id, ClientInfo peerData)
      : this(id, RpcMethods.SESSION_REQUEST, [peerData.intoMap()]);

  RpcRequest.sessionUpdate(
      int id, bool approved, int? chainId, List<String>? accounts)
      : this(id, RpcMethods.SESSION_UPDATE, [
          {
            "approved": approved,
            "chainId": chainId,
            "accounts": accounts,
          }
        ]);

  RpcRequest.personalSign(int id, String address, String message)
      : this(id, RpcMethods.SIGN_MESSAGE,
            [encode(Uint8List.fromList(utf8.encode(message))), address]);

  RpcRequest.fromMap(Map<String, dynamic> jsonObj)
      : this(jsonObj['id'], jsonObj['method'], jsonObj['params']);

  RpcRequest.fromJson(String json) : this.fromMap(jsonDecode(json));

  @override
  Map<String, dynamic> get asMap => _jsonRpc(id, method, params);
}

class RpcResponse extends JsonRpc {
  dynamic result;
  dynamic error;

  RpcResponse(int id, this.result, [this.error]) : super(id);

  RpcResponse.fromMap(Map<String, dynamic> jsonObj)
      : this(jsonObj['id'], jsonObj['result'], jsonObj['error']);

  RpcResponse.fromJson(String json) : this.fromMap(jsonDecode(json));

  @override
  Map<String, dynamic> get asMap {
    final res = {
      "id": id,
      "jsonrpc": jsonrpc,
    };
    if (result != null) {
      res["result"] = result;
    }
    if (error != null) {
      res["error"] = error;
    }
    return res;
  }
}

enum Status {
  Connected,
  Disconected,
  Approved,
  Closed,
  Error,
}

class Callback {
  Callback(
    this.onStatus,
    this.onResponse,
  );
  final void Function(Status) onStatus;
  final void Function(JsonRpc) onResponse;
}

class SocketMessage {
  String topic;
  String type;
  String payload;

  SocketMessage(this.topic, this.type, this.payload);
}

/// === Extensions ===
extension PeerMetaEx on PeerMeta? {
  void intoMap(Map<String, dynamic> params) {
    params["peerMeta"] = {
      "description": this?.description ?? "",
      "url": this?.description ?? "",
      "name": this?.description ?? "",
      "icons": this?.icons ?? [],
    };
  }
}

extension PeerDataEx on ClientInfo {
  Map<String, dynamic> intoMap([Map<String, dynamic>? params]) {
    if (params == null) params = Map();
    params['peerId'] = this.peerId;
    this.peerMeta.intoMap(params);
    return params;
  }
}

/// === Private supporting functions ===
Map<String, dynamic> _jsonRpc(
  int id,
  String method,
  List<dynamic> params,
) =>
    {
      "id": id,
      "jsonrpc": "2.0",
      "method": method,
      "params": params,
    };
