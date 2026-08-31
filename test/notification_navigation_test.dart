//test/notification_navigation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:charity_app/services/notification_navigation.dart';

void main() {
  group('NotificationNavigation', () {
    test('uses the in-app notification mapping for payment verification and rating flow', () {
      expect(NotificationNavigation.resolveRouteKind('verify_payment'),
          NotificationRouteKind.verifyPaymentDialog);
      expect(NotificationNavigation.resolveRouteKind('payment_verified'),
          NotificationRouteKind.paymentVerifiedRating);
    });

    test('keeps the task and delivery flows consistent across notification sources', () {
      expect(NotificationNavigation.resolveRouteKind('delivery_arrived'),
          NotificationRouteKind.pendingReceipts);
      expect(NotificationNavigation.resolveRouteKind('new_task_available'),
          NotificationRouteKind.volunteerDashboard);
      expect(NotificationNavigation.resolveRouteKind('urgent_task'),
          NotificationRouteKind.volunteerDashboard);
    });

    test('routes the tag notification through the post target flow', () {
      expect(NotificationNavigation.resolveRouteKind('tag'),
          NotificationRouteKind.homePost);
    });
  });
}