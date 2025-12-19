import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  static DatabaseReference chatRef(String chatId) {
    return FirebaseDatabase.instance.ref('chats/$chatId/messages');
  }

  static Future<void> sendMessage(
    String chatId,
    Map<String, dynamic> message,
  ) async {
    await chatRef(chatId).push().set(message);
  }

  static Stream<DatabaseEvent> messageStream(String chatId) {
    return chatRef(chatId).onValue;
  }

  static Future<void> markNotificationAsViewed(
    String userId,
    String notificationId,
  ) async {
    final ref = FirebaseDatabase.instance
        .ref()
        .child('notifications')
        .child(userId)
        .child(notificationId);
    await ref.update({'viewed': true});
  }
}
