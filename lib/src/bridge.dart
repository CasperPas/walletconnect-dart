import 'dart:convert';
import 'dart:io' show HttpServer, HttpRequest, WebSocket, WebSocketTransformer;

class BridgeServer {
  final int port;

  Map<String, Set<WebSocket>> _pubs = Map();

  Map<String, String?> _pubCache = Map();

  BridgeServer(this.port) {
    HttpServer.bind('localhost', port).then((HttpServer server) {
      print('[+]WebSocket listening at -- ws://localhost:$port/');
      server.listen((HttpRequest request) {
        WebSocketTransformer.upgrade(request).then((WebSocket ws) {
          print("[+]A client's connected");
          ws.listen(
            (message) {
              try {
                print('[*]Message: $message');
                final msg = jsonDecode(message) as Map<String, dynamic>;
                final type = msg['type'] as String;
                final topic = msg['topic'] as String;
                switch (type) {
                  case "pub":
                    var sendMessage = false;
                    _pubs[topic]?.forEach((r) {
                      r.add(message);
                      sendMessage = true;
                      print('[===>]Message sent: $message');
                    });
                    if (!sendMessage) {
                      print('[=]Message cached: $message');
                      _pubCache[topic] = message;
                    }
                    break;
                  case "sub":
                    if (!_pubs.containsKey(topic)) {
                      _pubs[topic] = Set();
                    }
                    _pubs[topic]?.add(ws);
                    if (_pubCache.containsKey(topic)) {
                      final cached = _pubCache[topic]!;
                      print('[*]Send cached: $cached');
                      ws.add(cached);
                    }
                    break;
                  case "ack":
                    if (_pubCache.containsKey(topic) &&
                        _pubs.containsKey(topic)) {
                      _pubCache.remove(topic);
                      print('[*]"Acked" cache for: $topic');
                    }
                    break;
                  default:
                    print('[!]Error -- Unknown type');
                    return;
                }
              } catch (err) {
                print('[!]Error -- ${err.toString()}');
              }
            },
            onDone: () {
              _cleanupSocket(ws);
              print('[-]Disconnected');
            },
            onError: (err) {
              _cleanupSocket(ws);
              print('[!]Error -- ${err.toString()}');
            },
            cancelOnError: true,
          );
        }, onError: (err) => print('[!]Error -- ${err.toString()}'));
      }, onError: (err) => print('[!]Error -- ${err.toString()}'));
    }, onError: (err) => print('[!]Error -- ${err.toString()}'));
  }

  void _cleanupSocket(WebSocket ws) {
    for (var pub in _pubs.values) {
      pub.remove(ws);
    }
  }
}
