import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TokenMonitor extends StatefulWidget {
  final Widget Function(String? token) _builder;
  TokenMonitor(this._builder);
  @override
  _TokenMonitor createState() => _TokenMonitor();
}
class _TokenMonitor extends State<TokenMonitor> {
  String? _token;
  late Stream<String> _tokenStream;
  //
  void setToken(String? token) {
    print('Set FCM Token: $token');
    setState(() {
      _token = token;
    });
  }

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.getToken(vapidKey: '').then(setToken);
    _tokenStream = FirebaseMessaging.instance.onTokenRefresh;
    _tokenStream.listen(setToken);
  }

  @override
  Widget build(BuildContext context) {
    return widget._builder(_token);
  }
}