import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

// Import plumber pages
import 'plumber/task_page.dart';
import 'plumber/map_page.dart';
import 'plumber/chats_page.dart';
import 'plumber/profile_page.dart';

// Import customer pages
import 'customer/splash_screen.dart';
import 'customer/my_job_orders_page.dart';
import 'customer/jo_request_form.dart';
import 'customer/home_page.dart';
import 'customer/plumber_page.dart';
import 'customer/chats_page.dart' as customer;
import 'customer/profile_page.dart' as customer;
import 'customer/chat_detail_page.dart';

// Initialize local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔔 Background message received: ${message.notification?.title}");
}

// Create Android notification channel
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important notifications',
  importance: Importance.max,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Firebase.initializeApp();

  // Request permissions (iOS)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Create Android notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Initialize local notifications
  const InitializationSettings initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      // Handle click on notification
      print("🔔 Notification clicked: ${details.payload}");
      // You can navigate based on payload here
    },
  );

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📱 Foreground message received: ${message.notification?.title}");
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title ?? "AquaFix",
        notification.body ?? "You have a new message",
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        payload: message.data['route'] ?? '', // Optional payload for navigation
      );
    }
  });

  // Handle notification click when app is in background / terminated
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("🔔 Notification opened: ${message.notification?.title}");
    final route = message.data['route'];
    if (route != null && route.isNotEmpty) {
      navigatorKey.currentState?.pushNamed(route);
    }
  });

  // Handle notification opened from terminated state
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print("🔔 App opened from terminated state via notification");
    final route = initialMessage.data['route'];
    if (route != null && route.isNotEmpty) {
      navigatorKey.currentState?.pushNamed(route);
    }
  }

  // Token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print("🔄 New FCM Token: $newToken");
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    final plumberId = prefs.getString('plumber_id');

    if (customerId != null || plumberId != null) {
      await http.post(
        Uri.parse('https://aquafixsansimon.com/api/save_fcm_token.php'),
        body: {
          'user_type': customerId != null ? 'customer' : 'plumber',
          'user_id': customerId ?? plumberId!,
          'fcm_token': newToken,
        },
      );
      print("✅ FCM token updated in backend");
    }
  });

  // Status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ScreenUtilInit(
      designSize: const Size(393, 851),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => child!,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AquaFix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 130, 200),
        ),
        fontFamily: 'PlusJakartaSans',
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/jobRequestForm': (context) => JORequestForm(),
        '/all_job_requests': (context) => MyJobOrdersPage(),
        '/task': (context) => const TaskPage(currentIndex: 0),
        '/map': (context) => const MapPage(currentIndex: 1),
        '/chats': (context) => const ChatsPage(currentIndex: 2),
        '/profile': (context) => const ProfilePage(currentIndex: 3),
        '/customer_home': (context) => HomePage(currentIndex: 0),
        '/customer_plumber': (context) => PlumberPage(currentIndex: 1),
        '/customer_chats': (context) => customer.ChatsPage(currentIndex: 2),
        '/customer_profile': (context) => customer.ProfilePage(currentIndex: 3),
      },
      navigatorObservers: [routeObserver],
      onGenerateRoute: (settings) {
        if (settings.name == '/customer_chat_detail') {
          final args = settings.arguments as Map?;
          return MaterialPageRoute(
            builder:
                (context) => ChatDetailPage(
                  userName: args?['userName'] ?? '',
                  chatId: args?['chatId'],
                  customerId: args?['customerId'],
                  plumberId: args?['plumberId'],
                ),
          );
        }
        return null; // fallback to default
      },
    );
  }
}
