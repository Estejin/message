import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:message/message.dart';

class MessageList extends StatefulWidget {
  const MessageList({Key? key}) : super(key: key);
  @override
  State<StatefulWidget> createState() => _MessageList();
}
class _MessageList extends State<MessageList> {
  List<RemoteMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        _messages = [..._messages, message];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty) {
      return const Text('No message received');
    }
    return ListView.builder(
        shrinkWrap: true,
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          RemoteMessage message = _messages[index];
          return ListTile(
            title: Text(message.messageId?? 'no RemoteMessage.messageId available'),
            subtitle: Text(message.sentTime?.toString() ?? DateTime.now().toString()),
            onTap: ()=>Navigator.pushNamed(context, '/message', arguments: MessageArguments(message, false)),
          );
        }
    );
  }
}