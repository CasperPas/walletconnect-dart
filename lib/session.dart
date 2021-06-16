import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:walletconnect/config.dart';
import 'package:walletconnect/encryption.dart';
import 'package:walletconnect/store.dart';
import 'package:walletconnect/transport.dart';

import 'interfaces.dart';

typedef ResponseCallback = void Function(RpcResponse);

class WCSession {
  late String _currentKey;
  late Config _config;

  String get encryptionKey => _currentKey;
  String get decryptionKey => _currentKey;

  List<String>? _approvedAccounts;
  int? _chainId;

  int? _handshakeId;
  String? _peerId;
  PeerMeta? _peerMeta;

  late ClientInfo _clientData;

  late WCSessionStore _sessionStore;
  late Transport _transport;
  late PayloadAdapter _payloadAdapter;
  Set<Callback> _callbacks = Set();
  Map<int, ResponseCallback> _requests = Map();

  // int createCallId() =>
  //     DateTime.now().millisecondsSinceEpoch * 1000 + Random().nextInt(999);
  static int createCallId() => DateTime.now().microsecondsSinceEpoch;
  PeerMeta? get peerMeta => _peerMeta;
  List<String>? get approvedAccounts => _approvedAccounts;

  WCSession(
    Config config,
    PeerMeta clientMeta,
    String? clientId,
  ) {
    _config = config;
    _currentKey = _config.key;
    _transport = Transport(config.bridge, _handleStatus, _handleMessage);
    _payloadAdapter = PayloadAdapter();
    _sessionStore = WCSessionStore();
    _sessionStore.init().then((_) {
      final state = _sessionStore.load(config.handshakeTopic);
      if (state != null) {
        if (clientId != null && clientId != state.clientData.peerId) {
          throw ArgumentError(
              "Provided clientId is different from stored clientId");
        }
        _currentKey = state.currentKey;
        _approvedAccounts = state.approvedAccounts;
        _chainId = state.chainId;
        _handshakeId = state.handshakeId;
        _peerId = state.peerData?.peerId;
        _peerMeta = state.peerData?.peerMeta;
        _clientData = state.clientData;
      } else {
        _clientData = ClientInfo(
          clientId ?? Uuid().v4(),
          clientMeta,
        );
      }
      _storeSession();
    });
  }

  void addCallback(Callback cb) {
    _callbacks.add(cb);
  }

  void removeCallback(Callback cb) {
    _callbacks.remove(cb);
  }

  void clearCallbacks() {
    _callbacks.clear();
  }

  Future<void> offer() async {
    if (await _transport.connect()) {
      final requestId = createCallId();
      _send(
        RpcRequest.sessionRequest(requestId, _clientData),
        _config.handshakeTopic,
        (RpcResponse res) {
          final result = res.result as Map<String, dynamic>?;
          if (result != null) {
            final peerMeta = result['peerMeta'];
            _peerId = result['peerId'];
            _peerMeta = peerMeta != null
                ? PeerMeta(
                    peerMeta['url'],
                    peerMeta['name'],
                    peerMeta['icons'].cast<String>(),
                    scheme: peerMeta['scheme'],
                    description: peerMeta['description'],
                  )
                : null;
            _approvedAccounts = result['accounts']?.cast<String>();
            _chainId = result['chainId'];
            _clientData.chainId = _chainId;
            _storeSession();
            _triggerCallbacks(
                status: result['approved'] ? Status.Approved : Status.Closed);
          }
        },
      );
      _handshakeId = requestId;
      final url = _config.toWCUri();
      print(url);
      launch(url);
    }
  }

  void approve(List<String> accounts, int chainId) {
    if (_handshakeId == null) return;
    _chainId = chainId;
    _approvedAccounts = accounts;
    final params = {
      "approved": true,
      "chainId": chainId,
      "accounts": accounts,
      "peerData": _clientData,
    };
    _send(RpcResponse(_handshakeId!, params));
    _storeSession();
    _triggerCallbacks(status: Status.Approved);
  }

  void update(List<String> accounts, int chainId) {
    _send(RpcRequest.sessionUpdate(createCallId(), true, chainId, accounts));
  }

  void reject() {
    if (_handshakeId != null) {
      _send(RpcResponse(
        _handshakeId!,
        {
          "approved": true,
          "chainId": null,
          "accounts": null,
          "peerData": null,
        },
      ));
    }
    _endSession();
  }

  void approveRequest(int id, dynamic response) {
    _send(RpcResponse(id, response));
  }

  void rejectRequest(int id, int errorCode, String errorMsg) {
    _send(RpcResponse(id, null, {
      "code": errorCode,
      "message": errorMsg,
    }));
  }

  void performMethodCall(JsonRpc call, ResponseCallback? callback) {
    _send(call, _peerId, callback);
    const methodList = [
      RpcMethods.SEND_TRANSACTION,
      RpcMethods.ETH_SEND_RAW_TRANSACTION,
      RpcMethods.SIGN_MESSAGE,
      "wallet_addEthereumChain",
    ];
    if (call is RpcRequest && methodList.contains(call.method)) {
      launch("wc:");
    }
  }

  void kill() {
    _send(RpcRequest.sessionUpdate(createCallId(), false, null, null));
    _endSession();
  }

  void _endSession() {
    _sessionStore.remove(_config.handshakeTopic);
    _approvedAccounts = null;
    _chainId = null;
    _transport.close();
    _triggerCallbacks(status: Status.Closed);
  }

  void _storeSession() {
    _sessionStore.store(
      _config.handshakeTopic,
      State(
        _config,
        _clientData,
        _peerId != null ? ClientInfo(_peerId!, _peerMeta!) : null,
        _handshakeId,
        _currentKey,
        _approvedAccounts,
        _chainId,
      ),
    );
  }

  void _triggerCallbacks({Status? status, JsonRpc? methodCall}) {
    for (var cb in _callbacks) {
      try {
        if (status != null) {
          cb.onStatus(status);
        }
        if (methodCall != null) {
          cb.onResponse(methodCall);
        }
      } catch (e) {
        cb.onStatus(Status.Error);
      }
    }
  }

  void _handleStatus(Status status) {
    if (status == Status.Connected) {
      _transport.send(SocketMessage(_clientData.peerId, "sub", ""));
    }

    _triggerCallbacks(status: status);
  }

  void _handleMessage(SocketMessage message) {
    if (message.type != "pub") return;
    JsonRpc data;
    try {
      data = _payloadAdapter.parse(message.payload, decryptionKey);
    } on Exception catch (e) {
      _handlePayloadError(e);
      return;
    }

    String accountToCheck = "";
    if (data is RpcRequest) {
      final params = data.params.first as Map<String, dynamic>;
      switch (data.method) {
        case RpcMethods.SESSION_REQUEST:
          _handshakeId = data.id;
          _peerId = params['peer']['id'];
          _peerMeta = params['peer']['meta'];
          _storeSession();
          break;
        case RpcMethods.SESSION_UPDATE:
          if (!params['approved']) {
            _endSession();
          }

          _chainId = params['chainId'];
          _clientData.chainId = _chainId;
          _approvedAccounts =
              params['accounts']?.cast<String>() ?? _approvedAccounts;

          _triggerCallbacks(methodCall: data);
          break;
        case RpcMethods.SEND_TRANSACTION:
          accountToCheck = params['from'];
          break;
        case RpcMethods.SIGN_MESSAGE:
          accountToCheck = params['address'];
          break;
      }
    } else if (data is RpcResponse) {
      if (_requests.containsKey(data.id)) {
        _requests[data.id]!(data);
      }
    }

    if (accountToCheck.isNotEmpty && _accountCheck(data.id, accountToCheck)) {
      _triggerCallbacks(methodCall: data);
    }
  }

  bool _accountCheck(int id, String address) {
    final lowAddress = address.toLowerCase();
    final acc = _approvedAccounts?.firstWhere(
            (account) => account.toLowerCase() == lowAddress,
            orElse: () => "") ??
        "";
    if (acc.isEmpty) {
      _handlePayloadError(null, id);
      return false;
    }

    return true;
  }

  void _handlePayloadError(Exception? e, [int requestId = 0]) {
    _triggerCallbacks(status: Status.Error);
    if (requestId > 0) rejectRequest(requestId, e.hashCode, e.toString());
  }

  bool _send(
    JsonRpc msg, [
    String? topic,
    ResponseCallback? callback,
  ]) {
    if (topic == null && _peerId == null) {
      return false;
    }

    final payload = _payloadAdapter.prepare(msg, encryptionKey);
    if (callback != null) {
      _requests[msg.id] = callback;
    }

    _transport.send(SocketMessage(topic ?? _peerId!, "pub", payload));
    return true;
  }
}
