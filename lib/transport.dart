import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'interfaces.dart';

typedef StatusHandler = void Function(Status);
typedef MessageHandler = void Function(SocketMessage);

class Transport {
  Transport(
    String serverUrl,
    StatusHandler statusHandler,
    MessageHandler messageHandler,
  )   : _serverUrl = serverUrl,
        _messageHandler = messageHandler,
        _statusHandler = statusHandler;

  String _serverUrl;
  StatusHandler _statusHandler;
  MessageHandler _messageHandler;
  ListQueue<SocketMessage> _queue = ListQueue();
  WebSocket? _socket;
  StreamSubscription? _subs;

  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    if (_socket != null) return true;
    try {
      _socket = await WebSocket.connect(_serverUrl.replaceFirst("http", "ws"));

      final onDisconnect = () {
        _isConnected = false;
        _socket = null;
        _statusHandler(Status.Disconected);
      };

      if (_socket?.readyState == WebSocket.open) {
        _subs = _socket?.listen(
          (data) {
            try {
              final Map<String, dynamic>? msg = jsonDecode(data);

              _messageHandler(SocketMessage(
                msg?['topic'] ?? '',
                msg?['type'] ?? '',
                msg?['payload'] ?? '',
              ));
            } catch (e) {
              print(e.toString());
            }
          },
          onDone: () {
            onDisconnect();
          },
          onError: (e) {
            print(e.toString());
            _statusHandler(Status.Error);
            onDisconnect();
          },
        );
        _isConnected = true;
        _statusHandler(Status.Connected);
        _drainQueue();
      } else {
        print('[!]Connection Denied');
      }
    } catch (e) {
      print(e.toString());
      return false;
    }
    return true;
  }

  void send(SocketMessage message) {
    _queue.add(message);
    _drainQueue();
  }

  void _drainQueue() {
    if (_isConnected && _socket != null) {
      while (_queue.isNotEmpty) {
        final message = _queue.removeFirst();
        final Map<String, dynamic> msgData = {
          "topic": message.topic,
          "type": message.type,
          "payload": message.payload,
        };

        _socket?.add(jsonEncode(msgData));
      }
    } else {
      connect();
    }
  }

  void close() async {
    await _subs?.cancel();
    // await _socket?.close();
    _socket = null;
    _isConnected = false;
  }
}
