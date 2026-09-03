import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../screens/chat_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/home_screen.dart';
import '../screens/volunteer_dashboard.dart';
import '../screens/volunteer_payment_screen.dart';
import '../screens/profile_screen.dart'; // keep if you need it
import 'navigation_keys.dart'; // must contain: final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();



class NotificationService {
  static bool _listenersRegistered = false;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initNotifications() async {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    // Background handler MUST be top-level
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permission granted');
    } else {
      debugPrint('❌ Notification permission denied');
    }

    // iOS / Android presentation options
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get & save token
    final fcmToken = await _getTokenWithDetails();
    debugPrint("================================");
    debugPrint("FCM TOKEN = $fcmToken");
    debugPrint("CURRENT USER = ${_auth.currentUser?.uid}");
    debugPrint("================================");

    await _saveTokenForCurrentUser(fcmToken);

    // Keep token updated
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveTokenForCurrentUser(await _getTokenWithDetails());
      }
    });

    _firebaseMessaging.onTokenRefresh.listen((token) async {
      debugPrint('🔄 FCM Token refreshed');
      await _saveTokenForCurrentUser(token);
    });

    // ── Foreground ──────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground message: ${message.data}');
      _showForegroundBanner(message);
    });

    // ── App opened from background ──────────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      debugPrint('[FCM TAP] Background → opened: ${message.data}');
      await _handleNotificationOpened(message);
    });

    // ── Cold start ──────────────────────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM TAP] Cold start: ${initialMessage.data}');
        // Small delay so navigator is ready
        await Future.delayed(const Duration(milliseconds: 800));
        await _handleNotificationOpened(initialMessage);
      }
    });
  }

  // ── Instagram-style banner ────────────────────────────────────
  void _showForegroundBanner(RemoteMessage message) {
    final messenger = notificationScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'New Notification';
    final body = message.notification?.body ??
        message.data['message']?.toString() ??
        message.data['body']?.toString() ??
        '';

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  body,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFFB56F76),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: SnackBarAction(
          label: 'OPEN',
          textColor: Colors.white,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            _handleNotificationOpened(message);
          },
        ),
      ),
    );
  }

  Future<String?> _getTokenWithDetails() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint('FCM getToken error: $e');
      return null;
    }
  }

  Future<void> _saveTokenForCurrentUser(String? token) async {
    final user = _auth.currentUser;
    if (token == null || user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ FCM token saved for ${user.uid}');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }

  Future<void> _handleNotificationOpened(RemoteMessage message) async {
    final type = (message.data['notificationType'] ??
            message.data['type'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final relatedItemId = (message.data['relatedItemId'] ??
            message.data['itemId'] ??
            message.data['id'] ??
            '')
        .toString()
        .trim();

    debugPrint('[FCM TAP] type=$type  relatedItemId=$relatedItemId');
    await _routeNotification(type, relatedItemId);
  }

  Future<void> _routeNotification(String type, String relatedItemId) async {
    // Wait until navigator is ready (important for cold start)
    int attempts = 0;
    while (appNavigatorKey.currentState == null && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 150));
      attempts++;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[FCM TAP] Navigator still null after waiting');
      return;
    }

    Future<void> push(Widget screen) async {
      navigator.push(MaterialPageRoute(builder: (_) => screen));
    }

    // These types must open the EXACT same popup / dialog as in-app
    const dialogTypes = {
      'donation_offer',
      'volunteer_accepted',
      'volunteer_expired',
      'donation_cancelled',
      'expired_request',
      'verify_payment',
      'payment_verified',
      'payment_rejected',
    };

    if (dialogTypes.contains(type)) {
      await push(NotificationsScreen(
        autoOpenType: type,
        autoOpenRelatedItemId: relatedItemId,
      ));
      return;
    }

    switch (type) {
      case 'new_message':
        if (relatedItemId.isEmpty) {
          await push(const NotificationsScreen());
          return;
        }
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) {
          await push(const NotificationsScreen());
          return;
        }
        final otherUserId = _extractOtherUserId(relatedItemId, currentUserId);
        if (otherUserId == null) {
          await push(const NotificationsScreen());
          return;
        }
        final snap =
            await _firestore.collection('users').doc(otherUserId).get();
        final data = snap.data() ?? {};
        final name =
            (data['username'] ?? data['name'] ?? 'Chat').toString();
        final image = (data['profileImage'] ?? '').toString();
        await push(ChatScreen(
          otherUserId: otherUserId,
          otherUserName: name,
          otherUserProfileImage: image.isEmpty ? null : image,
        ));
        break;

      case 'delivery_arrived':
        final uid = _auth.currentUser?.uid;
        if (uid == null) {
          await push(const NotificationsScreen());
          return;
        }
        await push(PendingReceiptsScreen(ngoId: uid));
        break;

      // 🔥 CRITICAL: Payment Required → open locked payment screen
      case 'payment_pending':
        if (relatedItemId.isEmpty) {
          await push(const NotificationsScreen());
          return;
        }
        await push(VolunteerPaymentScreen(donationId: relatedItemId));
        break;

      case 'new_task_available':
      case 'urgent_task':
        await push(VolunteerDashboard(
          highlightDonationId:
              relatedItemId.isNotEmpty ? relatedItemId : null,
        ));
        break;

      case 'tag':
        if (relatedItemId.isEmpty) {
          await push(const NotificationsScreen());
          return;
        }
        await push(HomeScreen(
          initialIndex: 1,
          targetPostId: relatedItemId,
        ));
        break;

      default:
        await push(const NotificationsScreen());
    }
  }

  String? _extractOtherUserId(String chatRoomId, String currentUserId) {
    final members = chatRoomId
        .split('_')
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    members.remove(currentUserId);
    return members.isNotEmpty ? members.first : null;
  }
}

// ── Background handler (MUST stay top-level) ────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // You can do light processing here if needed
  debugPrint("🌙 Background message received: ${message.messageId}");
  debugPrint("Data: ${message.data}");
}