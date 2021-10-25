import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:message/permissions.dart';
import 'package:message/token_monitor.dart';

import 'message.dart';
import 'message_list.dart';

/// Define a top-level named handler which background/terminated messages will
/// call.
/// To verify things are working, check out the native platform logs.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
}

/// Create a [AndroidNotificationChannel] for heads up notifications
late AndroidNotificationChannel channel;

/// Initialize the [FlutterLocalNotificationsPlugin] package.
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  //
  if (!kIsWeb) {
    channel = const AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description: 'This channel is used for important notifications.', // description
        importance: Importance.high
    );
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    /// Create an Android Notification Channel.
    /// We use this channel in the `AndroidManifest.xml` file to override the
    /// default FCM channel to enable heads up notifications.
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
    ///Update the iOS foreground notification presentation options to allow
    ///heads up notification.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Message Example',
      theme: ThemeData.dark(),
      routes: {
        '/': (context) => Application(),
        '/message': (context) => MessageView(),
      },
    );
  }
}

int _messageCount = 0;
String constructFCMPayload(String? token) {
  _messageCount++;
  return jsonEncode({
    'message': {
      'token': token,
      'data': {
        'via': 'FlutterFire Cloud Messaging!!!',
        'count': _messageCount.toString(),
      },
      'notification': {
        'title': 'Hello FlutterFire!',
        'body': 'This notification (#$_messageCount) was created via FCM!',
      }
    }
  }
  );
}

class Application extends StatefulWidget {

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".


  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  String? _token;
  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
          if (message != null) {
            Navigator.pushNamed(context, '/message', arguments: null);
          }
    });
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      print('receive message');
      if (notification != null && android != null && !kIsWeb) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription:channel.description,
                icon:'launch_background'
              ),
            ));
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published');
      Navigator.pushNamed(context, '/message',
        arguments: MessageArguments(message, true));
    });
  }
  //
  Future<void> sendPushMessage() async {
    if (_token == null) {
      print('Unable to send FCM message, on token exists.');
      return;
    }
    try {
      final String jsonKeys = await rootBundle.loadString(
          'assets/server/cloudmessagedemo-11e05-firebase-adminsdk-m42rw-1952fc40dd.json'
      );
      var accountCredentials = ServiceAccountCredentials.fromJson(jsonKeys);
      var scopes = ["https://www.googleapis.com/auth/firebase.messaging"];
      var client = http.Client();
      //
      AccessCredentials credentials = await obtainAccessCredentialsViaServiceAccount(accountCredentials, scopes, client);
      final response = await client.post(Uri.parse('https://fcm.googleapis.com/v1/projects/cloudmessagedemo-11e05/messages:send'),
        headers: <String, String> {
          'Authorization': 'Bearer ${credentials.accessToken.data}',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body:constructFCMPayload(_token),
      );
     print("FCM request result status: ${response.statusCode}");
      print('FCM request for device sent with result: ${response.body}');
    } catch (e) {
      print('Send push message exception: $e');
    }
  }
  Future<void> onActionSelected (String value) async {
    switch(value){
      case 'subscribe':
        {
          print('FlutterFire Message Example: Subscribing to topic "fcm_test".');
          await FirebaseMessaging.instance.subscribeToTopic('fcm_test');
          print('FlutterFire Message Example: Subscribing to topic "fcm_test" successful');
        }
        break;
      case 'unsubscribe' :
        {
          print('FlutterFire Message Example: Unsubscribing from topic "fcm_test".');
          await FirebaseMessaging.instance.unsubscribeFromTopic('fcm_test');
          print('FlutterFire Message Example: Unsubscribing from topic "fcm_test" successful.');
        }
        break;
      case 'get_apns_token' :
        {
          if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) {
            print('FlutterFire Messaging Example: Getting APNs token...');
            String? token = await FirebaseMessaging.instance.getAPNSToken();
            print('Flutter Message Example: Got APNs token: $token');
          } else {
            print('FlutterFire Message Example: Getting an APNs token is only supported on iOS and macOS platform');
          }
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Clouding Message'),
        actions: [
          PopupMenuButton<String>(
            onSelected: onActionSelected,
            itemBuilder: (context) {
              return [
                const PopupMenuItem(
                  value: 'subscribe',
                  child: const Text('Subscribe to topic')
                ),
                const PopupMenuItem(
                    value: 'unsubscribe',
                    child: const Text('Unsubscribe to topic')
                ),
                const PopupMenuItem(
                    value: 'get_apns_token',
                    child: const Text('Get APNs token (Apple only)')
                ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child:Column(
          children: [
            const MetaCard('Permission', Permissions()),
            MetaCard('FCM Token', TokenMonitor( (token) {
              _token = token;
              return token == null
                  ? const CircularProgressIndicator()
                  : Text(token, style: const TextStyle(fontSize: 12),);
            })),
            MetaCard('Message Stream', const MessageList())
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: sendPushMessage,
        backgroundColor: Colors.white,
        child: const Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
class MetaCard extends StatelessWidget {
  final String _title;
  final Widget _children;
  const MetaCard(this._title, this._children);
  //
  @override
  Widget build(BuildContext context) {
    return Container (
      width: double.infinity,
      margin: const EdgeInsets.only(left: 8, right: 8, top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Text(_title, style: const TextStyle(fontSize: 16),),
              ),
              _children,
            ],
          ),
        ),
      ),
    );
  }
}
