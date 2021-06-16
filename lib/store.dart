import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'interfaces.dart';

class WCSessionStore {
  static const _STORE_KEY = "WALLET_CONNECT_SESSION_STORE";

  SharedPreferences? _prefs;
  Map<String, State> _currentStates = Map();

  Iterable<State> get list => _currentStates.values;

  Future<void> init() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    final String json = _prefs?.getString(_STORE_KEY) ?? "{}";
    _currentStates =
        (jsonDecode(json) as Map<String, dynamic>).map((key, value) {
      final item = State(
        Config.fromMap(value['config']),
        ClientInfo.fromMap(value['clientData']),
        value['peerData'] != null
            ? ClientInfo.fromMap(value['peerData'])
            : null,
        value['handshakeId'],
        value['currentKey'],
        value['approvedAccounts']?.cast<String>(),
        value['chainId'],
      );
      return MapEntry(key, item);
    });
  }

  void _saveStore() {
    final json = jsonEncode(_currentStates.map((key, value) => MapEntry(key, {
          "config": value.config.asMap,
          "clientData": value.clientData.asMap,
          "peerData": value.peerData?.asMap,
          "handshakeId": value.handshakeId,
          "currentKey": value.currentKey,
          "approvedAccounts": value.approvedAccounts,
          "chainId": value.chainId,
        })));
    _prefs?.setString(_STORE_KEY, json);
  }

  State? load(String id) => _currentStates[id] ?? null;

  void store(String id, State state) {
    if (_prefs == null) return;
    _currentStates[id] = state;
    _saveStore();
  }

  void remove(String id) {
    if (_prefs == null) return;
    _currentStates.remove(id);
    _saveStore();
  }
}

class State {
  Config config;
  ClientInfo clientData;
  ClientInfo? peerData;
  int? handshakeId;
  String currentKey;
  List<String>? approvedAccounts;
  int? chainId;

  State(
    this.config,
    this.clientData,
    this.peerData,
    this.handshakeId,
    this.currentKey,
    this.approvedAccounts,
    this.chainId,
  );
}
