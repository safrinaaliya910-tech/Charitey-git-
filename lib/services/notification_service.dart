// notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/donation_offer_details_screen.dart';
import '../screens/ngo_listing_details_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/home_screen.dart';
import '../screens/payment_verification_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/volunteer_dashboard.dart';
import '../screens/volunteer_payment_screen.dart';
// Add the correct import for PendingReceiptsScreen if it lives elsewhere
// import '../screens/pending_receipts_screen.dart'; (or wherever it is)
import 'navigation_keys.dart';

final GlobalKey<ScaffoldMessengerState> notificationScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class NotificationService {
  static bool _listenersRegistered = false;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initNotifications() async {
    // Prevent duplicate listener registration (teammate)
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final fcmToken = await _getTokenWithDetails();

    print("================================");
    print("FCM TOKEN = $fcmToken");
    print("CURRENT USER = ${_auth.currentUser?.uid}");
    print("================================");

    await _saveTokenForCurrentUser(fcmToken);

    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveTokenForCurrentUser(await _getTokenWithDetails());
      }
    });

    _firebaseMessaging.onTokenRefresh.listen((token) async {
      await _saveTokenForCurrentUser(token);
    });

    // Foreground message logging (both)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    // When app is opened from background via notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      print('[FCM TAP] LISTENER FIRED - raw message: ${message.data}');
      await _handleNotificationOpened(message);
    });

    // Safer cold-start handling (teammate) â€“ waits until first frame so navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print(
            '[FCM TAP] COLD START HANDLER - raw message: ${initialMessage.data}');
        await _handleNotificationOpened(initialMessage);
      } else {
        print(
            '[FCM TAP] getInitialMessage returned null (no cold-start notification)');
      }
    });
  }

  Future<String?> _getTokenWithDetails() async {
    try {
      return await _firebaseMessaging.getToken();
    } on FirebaseException catch (error, stackTrace) {
      print('FCM getToken FirebaseException: $error');
      print('FCM getToken code: ${error.code}');
      print('FCM getToken message: ${error.message}');
      print('FCM getToken plugin: ${error.plugin}');
      print('FCM getToken stack trace: $stackTrace');
      _showTokenError(
        'FCM token error [${error.code}]: ${error.message ?? error}',
      );
    } catch (error, stackTrace) {
      print('FCM getToken exception: $error');
      print('FCM getToken stack trace: $stackTrace');
      _showTokenError('FCM token error: $error');
    }

    return null;
  }

  void _showTokenError(String message) {
    void showError() {
      final messenger = notificationScaffoldMessengerKey.currentState;
      if (messenger == null) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 10),
        ),
      );
    }

    if (notificationScaffoldMessengerKey.currentState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showError());
    } else {
      showError();
    }
  }

  Future<void> _saveTokenForCurrentUser(String? token) async {
    final user = _auth.currentUser;
    if (token == null || user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
  }

  Future<void> _handleNotificationOpened(RemoteMessage message) async {
    print('[FCM TAP] ============ NOTIFICATION TAP DETECTED ============');
    print('[FCM TAP] messageId=${message.messageId}');
    print('[FCM TAP] rawNotificationData=${message.data}');
    print('[FCM TAP] payloadDebug=' +
        message.data.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join(', '));

    final type =
        (message.data['notificationType'] ?? message.data['type'] ?? '')
            .toString();
    final relatedItemId = (message.data['relatedItemId'] ??
            message.data['itemId'] ??
            message.data['id'] ??
            '')
        .toString()
        .trim();

    print('[FCM TAP] resolvedType=$type');
    print('[FCM TAP] resolvedRelatedItemId=$relatedItemId');
    print('[FCM TAP] ===== STARTING ROUTE NAVIGATION =====');

    await _routeNotification(type, relatedItemId);
  }

  Future<bool> _routeNotification(String type, String relatedItemId) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      print('[FCM TAP] âŒ NAVIGATOR NULL - Cannot navigate!');
      print(
          '[FCM TAP] routeFallback reason=navigatorKey.currentState was null');
      _showNavigationFailure('navigatorKey.currentState was null');
      return false;
    }

    print('[FCM TAP] âœ“ Navigator is ready');

    Future<bool> pushWidget(Widget screen) async {
      if (appNavigatorKey.currentState == null) {
        print(
            '[FCM TAP] âŒ routeFallback reason=navigatorKey.currentState was null before push');
        _showNavigationFailure(
            'navigatorKey.currentState was null before push');
        return false;
      }
      print('[FCM TAP] âœ“ Pushing widget: ${screen.runtimeType}');
      appNavigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return true;
    }

    try {
      switch (type) {
        case 'new_message':
          print('[FCM TAP] â†’ Routing to: new_message');
          if (relatedItemId.isEmpty) {
            print('[FCM TAP] âŒ relatedItemId was empty for type=new_message');
            _showNavigationFailure(
                'relatedItemId was empty for type=new_message');
            await pushWidget(const NotificationsScreen());
            return false;
          }

          final currentUserId = _auth.currentUser?.uid;
          if (currentUserId == null || currentUserId.isEmpty) {
            _showNavigationFailure(
                'currentUserId was null while routing new_message');
            await pushWidget(const NotificationsScreen());
            return false;
          }

          final otherUserId = _extractOtherUserId(relatedItemId, currentUserId);
          if (otherUserId == null || otherUserId.isEmpty) {
            _showNavigationFailure(
                'chat room id could not be resolved to a valid otherUserId for new_message');
            await pushWidget(const NotificationsScreen());
            return false;
          }

          final otherUserSnap =
              await _firestore.collection('users').doc(otherUserId).get();

          if (!otherUserSnap.exists) {
            _showNavigationFailure(
                'target user for chat no longer exists: $otherUserId');
            await pushWidget(const NotificationsScreen());
            return false;
          }

          final otherUserData = otherUserSnap.data() ?? {};
          final otherUserName =
              (otherUserData['username'] ?? otherUserData['name'] ?? 'Chat')
                  .toString();
          final profileImage = (otherUserData['profileImage'] ?? '').toString();

          return await pushWidget(
            ChatScreen(
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              otherUserProfileImage: profileImage.isEmpty ? null : profileImage,
            ),
          );

        case 'donation_offer':
          print('[FCM TAP] â†’ Routing to: donation_offer');
          if (relatedItemId.isEmpty) {
            print(
                '[FCM TAP] âŒ relatedItemId was empty for type=donation_offer');
            _showNavigationFailure(
                'relatedItemId was empty for type=donation_offer');
            await pushWidget(const NotificationsScreen());
            return false;
          }
          print(
              '[FCM TAP] â†’ Opening DonationOfferDetailsScreen with id=$relatedItemId');
          return await pushWidget(
            DonationOfferDetailsScreen(donationId: relatedItemId),
          );

        case 'volunteer_accepted':
          return await pushWidget(
            DonationOfferDetailsScreen(donationId: relatedItemId),
          );

        case 'volunteer_expired':
        case 'donation_cancelled':
        case 'payment_verified':
          if (relatedItemId.isEmpty) {
            await pushWidget(const NotificationsScreen());
            return false;
          }
          return await pushWidget(
            DonationOfferDetailsScreen(donationId: relatedItemId),
          );

        case 'delivery_arrived':
          final currentUserId = _auth.currentUser?.uid;
          if (currentUserId == null || currentUserId.isEmpty) {
            print(
                '[FCM TAP] routeFallback reason=currentUserId was null for delivery_arrived');
            _showNavigationFailure(
                'currentUserId was null for delivery_arrived');
            await pushWidget(const NotificationsScreen());
            return false;
          }
          return await pushWidget(PendingReceiptsScreen(ngoId: currentUserId));

        case 'payment_pending':
        case 'payment_rejected':
          if (relatedItemId.isEmpty) {
            print(
                '[FCM TAP] routeFallback reason=relatedItemId was empty for type=$type');
            _showNavigationFailure('relatedItemId was empty for type=$type');
            await pushWidget(const NotificationsScreen());
            return false;
          }
          return await pushWidget(
              VolunteerPaymentScreen(donationId: relatedItemId));

        case 'verify_payment':
          if (relatedItemId.isEmpty) {
            await pushWidget(const NotificationsScreen());
            return false;
          }
          return await pushWidget(
            PaymentVerificationScreen(donationId: relatedItemId),
          );

        case 'tag':
          if (relatedItemId.isEmpty) {
            await pushWidget(const NotificationsScreen());
            return false;
          }
          return await pushWidget(
            HomeScreen(initialIndex: 1, targetPostId: relatedItemId),
          );

        case 'expired_request':
          if (relatedItemId.isEmpty) {
            await pushWidget(const NotificationsScreen());
            return false;
          }
          return await pushWidget(
            NgoListingDetailsScreen(listingId: relatedItemId),
          );

        case 'new_task_available':
        case 'urgent_task':
          return await pushWidget(
            VolunteerDashboard(
              highlightDonationId:
                  relatedItemId.isNotEmpty ? relatedItemId : null,
            ),
          );

        default:
          print(
              '[FCM TAP] routeFallback reason=notificationType did not match any case; type=$type, relatedItemId=$relatedItemId');
          _showNavigationFailure(
              'notificationType did not match any supported case; type=$type, relatedItemId=$relatedItemId');
          await pushWidget(const NotificationsScreen());
          return false;
      }
    } catch (error, stackTrace) {
      print('[FCM TAP] routeFallback reason=exception during route: $error');
      print('[FCM TAP] routeFallback stackTrace=$stackTrace');
      _showNavigationFailure('exception during route: $error');
      await pushWidget(const NotificationsScreen());
      return false;
    }
  }

  Future<bool> _pushSafeScreen(Widget screen) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return false;
    }

    navigator.push(
      MaterialPageRoute(builder: (_) => screen),
    );
    return true;
  }

  void _showNavigationFailure(String reason) {
    print('Notification navigation failed: $reason');
  }

  String? _extractOtherUserId(String chatRoomId, String currentUserId) {
    if (chatRoomId.isEmpty) {
      return null;
    }

    final members = chatRoomId.split('_');
    if (members.length < 2) {
      return null;
    }

    final uniqueMembers =
        members.where((id) => id.trim().isNotEmpty).toSet().toList();
    uniqueMembers.remove(currentUserId);

    return uniqueMembers.isNotEmpty ? uniqueMembers.first : null;
  }
}

// Top-level function for background messages (required by Firebase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}