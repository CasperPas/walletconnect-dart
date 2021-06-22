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

    await _prefs?.reload();

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

  Future<bool> _saveStore() async {
    final json = jsonEncode(_currentStates.map((key, value) => MapEntry(key, {
          "config": value.config.asMap,
          "clientData": value.clientData.asMap,
          "peerData": value.peerData?.asMap,
          "handshakeId": value.handshakeId,
          "currentKey": value.currentKey,
          "approvedAccounts": value.approvedAccounts,
          "chainId": value.chainId,
        })));
    final saved = await _prefs?.setString(_STORE_KEY, json) ?? false;
    return saved;
  }

  State? load(String id) => _currentStates[id] ?? null;

  Future<void> store(String id, State state) async {
    if (_prefs == null) return;
    _currentStates[id] = state;
    await _saveStore();
  }

  Future<void> remove(String id) async {
    if (_prefs == null) return;
    _currentStates.remove(id);
    await _saveStore();
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
