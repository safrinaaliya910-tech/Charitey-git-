//services/notification_navigation.dart
enum NotificationRouteKind {
  chat,
  donationOffer,
  volunteerDetails,
  donorCancellation,
  requestExpired,
  volunteerDashboard,
  homePost,
  pendingReceipts,
  volunteerPayment,
  verifyPaymentDialog,
  paymentVerifiedRating,
  paymentVerification,
  ngoListing,
  fallback,
}

class NotificationNavigation {
  static NotificationRouteKind resolveRouteKind(String type) {
    final normalizedType = type.trim().toLowerCase();

    switch (normalizedType) {
      case 'new_message':
        return NotificationRouteKind.chat;
      case 'donation_offer':
        return NotificationRouteKind.donationOffer;
      case 'volunteer_accepted':
      case 'volunteer_expired':
        return NotificationRouteKind.volunteerDetails;
      case 'new_task_available':
      case 'urgent_task':
        return NotificationRouteKind.volunteerDashboard;
      case 'delivery_arrived':
        return NotificationRouteKind.pendingReceipts;
      case 'payment_pending':
      case 'payment_rejected':
        return NotificationRouteKind.volunteerPayment;
      case 'verify_payment':
        return NotificationRouteKind.verifyPaymentDialog;
      case 'payment_verified':
        return NotificationRouteKind.paymentVerifiedRating;
      case 'donation_cancelled':
        return NotificationRouteKind.donorCancellation;
      case 'expired_request':
        return NotificationRouteKind.requestExpired;
      case 'tag':
        return NotificationRouteKind.homePost;
      default:
        return NotificationRouteKind.fallback;
    }
  }

  static bool requiresRelatedItemId(NotificationRouteKind routeKind) {
    switch (routeKind) {
      case NotificationRouteKind.chat:
      case NotificationRouteKind.donationOffer:
      case NotificationRouteKind.volunteerDetails:
      case NotificationRouteKind.donorCancellation:
      case NotificationRouteKind.requestExpired:
      case NotificationRouteKind.volunteerDashboard:
      case NotificationRouteKind.homePost:
      case NotificationRouteKind.pendingReceipts:
      case NotificationRouteKind.volunteerPayment:
      case NotificationRouteKind.verifyPaymentDialog:
      case NotificationRouteKind.paymentVerifiedRating:
      case NotificationRouteKind.paymentVerification:
      case NotificationRouteKind.ngoListing:
        return true;
      case NotificationRouteKind.fallback:
        return false;
    }
  }

  static String descriptionForType(String type) {
    switch (resolveRouteKind(type)) {
      case NotificationRouteKind.chat:
        return 'open chat';
      case NotificationRouteKind.donationOffer:
        return 'open donation offer details';
      case NotificationRouteKind.volunteerDetails:
        return 'open volunteer details';
      case NotificationRouteKind.donorCancellation:
        return 'open donor cancellation details';
      case NotificationRouteKind.requestExpired:
        return 'open expired request details';
      case NotificationRouteKind.volunteerDashboard:
        return 'open volunteer dashboard';
      case NotificationRouteKind.homePost:
        return 'open tagged post';
      case NotificationRouteKind.pendingReceipts:
        return 'open pending receipts';
      case NotificationRouteKind.volunteerPayment:
        return 'open volunteer payment';
      case NotificationRouteKind.verifyPaymentDialog:
        return 'open verify payment dialog';
      case NotificationRouteKind.paymentVerifiedRating:
        return 'open payment verified rating dialog';
      case NotificationRouteKind.paymentVerification:
        return 'open payment verification screen';
      case NotificationRouteKind.ngoListing:
        return 'open NGO listing';
      case NotificationRouteKind.fallback:
        return 'fallback to notifications';
    }
  }
}