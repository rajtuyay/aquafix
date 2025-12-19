import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/main_scaffold.dart';
import 'chat_detail_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ChatsPage extends StatefulWidget {
  final int currentIndex;

  const ChatsPage({super.key, required this.currentIndex});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with RouteAware {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  StreamSubscription<DatabaseEvent>? _firebaseSub;
  String? _plumberId;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  Set<String> _notifiedChatIds = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _fetchChats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ModalRoute.of(context)?.addScopedWillPopCallback(_onWillPop);
    });
  }

  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(initializationSettings);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(
        message.notification?.title,
        message.notification?.body,
      );
    });
  }

  void _showNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'chat_channel',
          'Chat Messages',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _localNotifications.show(
      0,
      title ?? 'New Message',
      body ?? '',
      platformChannelSpecifics,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    RouteObserver<PageRoute>().subscribe(
      this,
      ModalRoute.of(context)! as PageRoute,
    );
  }

  @override
  void dispose() {
    RouteObserver<PageRoute>().unsubscribe(this);
    _firebaseSub?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    _fetchChats(); // Ensure chat list is refreshed
    return true;
  }

  @override
  void didPopNext() {
    _fetchChats(); // Ensure chat list is refreshed after returning
  }

  Future<void> _fetchChats() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id');
    _plumberId = plumberId;
    if (plumberId == null) {
      setState(() {
        _chats = [];
        _loading = false;
      });
      return;
    }
    final url = Uri.parse(
      'https://aquafixsansimon.com/api/plumber_chats.php?plumber_id=$plumberId',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      // Sort chats by last_time descending (latest at top)
      data.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['last_time']?.toString() ?? '') ??
            DateTime(2000);
        final bTime =
            DateTime.tryParse(b['last_time']?.toString() ?? '') ??
            DateTime(2000);
        return bTime.compareTo(aTime);
      });
      setState(() {
        _chats = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
      _subscribeToFirebaseUpdates();
    } else {
      setState(() {
        _chats = [];
        _loading = false;
      });
    }
  }

  void _subscribeToFirebaseUpdates() {
    _firebaseSub?.cancel();
    final db = FirebaseDatabase.instance.ref('chats');
    _firebaseSub = db.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() {
          _chats =
              _chats.map((chat) {
                final chatId = chat['chat_id'].toString();
                final chatData = data[chatId];
                if (chatData is Map && chatData['messages'] != null) {
                  List msgList = [];
                  final messages = chatData['messages'];
                  if (messages is Map) {
                    msgList = messages.values.where((m) => m != null).toList();
                  } else if (messages is List) {
                    msgList = messages.where((m) => m != null).toList();
                  }
                  final hasPlumber = msgList.any(
                    (m) => m['plumber_id']?.toString() == _plumberId,
                  );
                  if (hasPlumber && msgList.isNotEmpty) {
                    msgList.sort((a, b) {
                      final aid =
                          int.tryParse(a['message_id']?.toString() ?? '') ?? 0;
                      final bid =
                          int.tryParse(b['message_id']?.toString() ?? '') ?? 0;
                      return aid.compareTo(bid);
                    });
                    final lastMsg = msgList.last;
                    return {
                      ...chat,
                      'last_message': lastMsg['message'] ?? '',
                      'last_media_path': lastMsg['media_path'] ?? '',
                      'last_time': lastMsg['sent_at'] ?? '',
                      'last_sender_type': lastMsg['sender'] ?? '',
                    };
                  }
                }
                return chat;
              }).toList();
          // Sort chats by last_time descending (latest at top)
          _chats.sort((a, b) {
            final aTime =
                DateTime.tryParse(a['last_time']?.toString() ?? '') ??
                DateTime(2000);
            final bTime =
                DateTime.tryParse(b['last_time']?.toString() ?? '') ??
                DateTime(2000);
            return bTime.compareTo(aTime);
          });
        });
      }
    });
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM dd HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _markLastMessageAsRead(Map<String, dynamic> chat) async {
    final chatId = chat['chat_id'].toString();
    final customerId = chat['customer_id'].toString();
    final plumberId = _plumberId;
    // Only mark as read if last message is from customer and is unread
    if (chat['is_unread'] == '0' || chat['is_unread'] == 0) {
      final url = Uri.parse(
        'https://aquafixsansimon.com/api/mark_message_read.php',
      );
      await http.post(
        url,
        body: {
          'chat_id': chatId,
          'user_type': 'plumber',
          'user_id': plumberId ?? '',
        },
      );
      // Optionally, update Firebase as well (if you store is_read there)
    }
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top;
    final double headerHeight = 64.h;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: MainScaffold(
        currentIndex: widget.currentIndex,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              height: headerHeight + safeTop,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/homepage-header.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22.w, safeTop, 22.w, 0),
                  child: Text(
                    'Chats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Content Section
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: Expanded(
                child:
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _chats.isEmpty
                        ? Center(
                          child: Text(
                            "No chats yet.",
                            style: TextStyle(fontSize: 15.sp),
                          ),
                        )
                        : ListView.separated(
                          itemCount: _chats.length,
                          separatorBuilder:
                              (_, __) =>
                                  Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final chat = _chats[index];
                            String subtitle = '';
                            final lastMessage =
                                chat['last_message']?.toString() ?? '';
                            final lastMediaPath =
                                chat['last_media_path']?.toString() ?? '';
                            final senderType =
                                chat['last_sender_type']?.toString() ?? '';
                            final isPlumber = senderType == 'plumber';
                            // FIX: Use '0' for unread, not '1'
                            final isUnread =
                                chat['is_unread'] == '0' ||
                                chat['is_unread'] == 0;
                            final isOpposite = senderType == 'customer';

                            if ((lastMessage.isEmpty ||
                                    lastMessage.trim().isEmpty) &&
                                lastMediaPath.isNotEmpty) {
                              final ext = lastMediaPath.toLowerCase();
                              final isImage =
                                  ext.endsWith('.jpg') ||
                                  ext.endsWith('.jpeg') ||
                                  ext.endsWith('.png') ||
                                  ext.endsWith('.gif');
                              final isVideo =
                                  ext.endsWith('.mp4') ||
                                  ext.endsWith('.mov') ||
                                  ext.endsWith('.avi') ||
                                  ext.endsWith('.webm') ||
                                  ext.endsWith('.mkv');
                              if (isPlumber) {
                                subtitle = "You sent a photo.";
                                if (isVideo) subtitle = "You sent a video.";
                              } else {
                                subtitle =
                                    "${chat['customer_name']} sent a photo.";
                                if (isVideo)
                                  subtitle =
                                      "${chat['customer_name']} sent a video.";
                              }
                            } else if (lastMessage.isNotEmpty) {
                              subtitle =
                                  isPlumber ? "You: $lastMessage" : lastMessage;
                            }

                            return ListTile(
                              dense: true,
                              leading:
                                  chat['profile_image'] != null &&
                                          chat['profile_image']
                                              .toString()
                                              .isNotEmpty
                                      ? CircleAvatar(
                                        backgroundColor: Colors.grey[200],
                                        backgroundImage: NetworkImage(
                                          // Adjust this path to match your actual storage location
                                          'https://aquafixsansimon.com/uploads/profiles/customers/${chat['profile_image']}',
                                        ),
                                        radius: 22.sp,
                                      )
                                      : CircleAvatar(
                                        backgroundColor: const Color.fromRGBO(
                                          45,
                                          159,
                                          208,
                                          1,
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 24.w,
                                        ),
                                      ),
                              title: Text(
                                chat['customer_name'] ?? 'Customer',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight:
                                      isUnread && isOpposite
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight:
                                      isUnread && isOpposite
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                _formatDate(chat['last_time']?.toString()),
                                style: TextStyle(fontSize: 12.sp),
                              ),
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final plumberId = prefs.getString('plumber_id');
                                await _markLastMessageAsRead(
                                  chat,
                                ); // Mark as read
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ChatDetailPage(
                                          userName:
                                              chat['customer_name'] ??
                                              'Customer',
                                          chatId:
                                              chat['chat_id'] is int
                                                  ? chat['chat_id']
                                                  : int.tryParse(
                                                    chat['chat_id'].toString(),
                                                  ),
                                          customerId:
                                              chat['customer_id'] is int
                                                  ? chat['customer_id']
                                                  : int.tryParse(
                                                    chat['customer_id']
                                                        .toString(),
                                                  ),
                                          plumberId:
                                              plumberId != null
                                                  ? int.tryParse(plumberId)
                                                  : null,
                                        ),
                                  ),
                                );
                                _fetchChats(); // Always refresh from backend after returning
                              },
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
