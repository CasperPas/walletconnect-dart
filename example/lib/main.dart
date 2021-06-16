import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:walletconnect/interfaces.dart';

import 'package:walletconnect/walletconnect.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Config _config;
  late WCSession _session;
  late Callback _callbacks;
  late BridgeServer _bridgeServer;

  Status _status = Status.Disconected;
  String _account = "";
  String _qrContent = "";

  @override
  void initState() {
    _bridgeServer = BridgeServer(8080);
    _callbacks = Callback(
      (status) {
        switch (status) {
          case Status.Approved:
            _account = _session.approvedAccounts?.first ?? "";
            _qrContent = "";
            break;
          case Status.Closed:
            break;
          default:
            break;
        }
        setState(() {
          _status = status;
        });
      },
      (method) {
        print("Method called");
      },
    );

    final key = encode(
        Uint8List.fromList(
            [for (var i = 0; i < 32; i++) Random().nextInt(256)]),
        "");
    // _config = Config(Uuid().v4(), "https://bridge.walletconnect.org", key);
    _config =
        Config(Uuid().v4(), "http://localhost:${_bridgeServer.port}", key);
    _session = WCSession(
        _config,
        PeerMeta(
          "http://localhost",
          "Localhost",
          [],
          description: "Example App",
        ),
        null);
    _session.addCallback(_callbacks);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status.toString()),
            Text(_account),
            if (_status == Status.Approved) ...[
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    _session.performMethodCall(
                      RpcRequest.sendTransaction(
                        WCSession.createCallId(),
                        _account,
                        '0x5AF3107A4000',
                        "",
                        to: '0xB934902e429DFc228368B1e214fc7F355c9B85A3',
                      ),
                      (res) {
                        print(res);
                      },
                    );
                  },
                  child: Text("Send Transaction"),
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    _session.performMethodCall(
                      RpcRequest.personalSign(
                        WCSession.createCallId(),
                        _account,
                        "A message from Dart SDK!",
                      ),
                      (res) {
                        print(res);
                      },
                    );
                  },
                  child: Text("Sign Message"),
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    _session.kill();
                  },
                  child: Text("Disconnect"),
                ),
              ),
            ] else ...[
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await _session.offer();
                    setState(() {
                      _qrContent = _config.toWCUri();
                    });
                  },
                  child: Text("Connect"),
                ),
              ),
              if (_qrContent.isNotEmpty) QrImage(data: _qrContent),
            ],
          ],
        ),
      ),
    );
  }
}
