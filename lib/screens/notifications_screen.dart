import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/notification_model.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'volunteer_payment_screen.dart';
import 'volunteer_dashboard.dart';
import 'rating_dialog.dart';
// Make sure this path is correct
import 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String? autoOpenType;
  final String? autoOpenRelatedItemId;

  const NotificationsScreen({
    super.key,
    this.autoOpenType,
    this.autoOpenRelatedItemId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _autoOpened = false;
  final Color themeColor = const Color(0xFFB56F76);

  // ───────────────────────────────────────────────────────────────
  // AUTO-OPEN from push notification
  // ───────────────────────────────────────────────────────────────
  void _tryAutoOpen(List<NotificationModel> notifications) {
    if (widget.autoOpenType == null) return;

    final type = widget.autoOpenType!.toLowerCase();
    final relatedId = widget.autoOpenRelatedItemId ?? '';

    NotificationModel? target;

    if (relatedId.isNotEmpty) {
      try {
        target = notifications.firstWhere(
          (n) =>
              n.type.toLowerCase() == type && n.relatedItemId == relatedId,
        );
      } catch (_) {}
    }

    target ??= (() {
      try {
        return notifications.firstWhere(
          (n) => n.type.toLowerCase() == type,
        );
      } catch (_) {
        return null;
      }
    })();

    if (target == null) return;

    if (!target.isRead) {
      FirestoreService().markNotificationAsRead(target.id);
    }

    final notif = target;
    final isDonationOffer = notif.type == 'donation_offer';
    final isVolunteerAccepted = notif.type == 'volunteer_accepted';
    final isCancellation = notif.type == 'donation_cancelled';
    final isExpiration = notif.type == 'expired_request';
    final isVolunteerExpired = notif.type == 'volunteer_expired';
    final isVerifyPayment = notif.type == 'verify_payment';
    final isPaymentVerified = notif.type == 'payment_verified';

    if (isVerifyPayment) {
      _showVerifyPaymentDialog(context, notif, themeColor);
    } else if (isPaymentVerified) {
      _openRatingFromPaymentVerified(context, notif);
    } else if (isCancellation) {
      _showDonorCancellationDetails(context, notif, themeColor);
    } else if (isExpiration) {
      _showExpirationDetails(context, notif);
    } else if (isVolunteerExpired) {
      _showNoVolunteerFoundDetails(context, notif);
    } else {
      // donation_offer + volunteer_accepted → rich popup
      _showRichDetailsPopup(
        context,
        notif,
        themeColor,
        isDonationOffer,
        isVolunteerAccepted,
      );
    }
  }

  // ───────────────────────────────────────────────────────────────
  // ORIGINAL METHODS (kept 100% intact)
  // ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchDetailsData(
    NotificationModel notif,
    bool isDonationOffer,
    bool amINGO,
    bool isVolunteerAccepted,
  ) async {
    Map<String, dynamic> result = {};
    try {
      if (isDonationOffer) {
        DocumentSnapshot donationSnap = await FirebaseFirestore.instance
            .collection('donations')
            .doc(notif.relatedItemId)
            .get();
        if (donationSnap.exists && donationSnap.data() != null) {
          var donationData = donationSnap.data() as Map<String, dynamic>;
          result['donationData'] = donationData;
          if (!amINGO) {
            String? ngoId = donationData['ngoId'] ?? notif.receiverId;
            if (ngoId != null && ngoId.isNotEmpty) {
              DocumentSnapshot ngoSnap = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(ngoId)
                  .get();
              if (ngoSnap.exists && ngoSnap.data() != null) {
                result['ngoProfileData'] =
                    ngoSnap.data() as Map<String, dynamic>;
              }
            }
          } else {
            DocumentSnapshot senderSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(notif.senderId)
                .get();
            if (senderSnap.exists && senderSnap.data() != null) {
              result['senderProfileData'] =
                  senderSnap.data() as Map<String, dynamic>;
            }
          }
        }
      } else {
        DocumentSnapshot senderSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(notif.senderId)
            .get();
        if (senderSnap.exists && senderSnap.data() != null) {
          result['senderProfileData'] =
              senderSnap.data() as Map<String, dynamic>;
        }
        DocumentSnapshot notifSnap = await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notif.id)
            .get();
        if (notifSnap.exists && notifSnap.data() != null) {
          result['notifData'] = notifSnap.data() as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint("Error fetching dynamic notification details: $e");
    }
    return result;
  }

  void _showRichDetailsPopup(
    BuildContext context,
    NotificationModel notif,
    Color themeColor,
    bool isDonationOffer,
    bool isVolunteerAccepted,
  ) {
    final currentUser = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUserModel;
    bool amINGO = currentUser?.role == 'ngo';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isDonationOffer
                    ? Icons.volunteer_activism
                    : (isVolunteerAccepted
                        ? Icons.directions_car_rounded
                        : Icons.message_rounded),
                color: themeColor,
              ),
              const SizedBox(width: 10),
              Text(
                isDonationOffer
                    ? "Donation Details"
                    : (isVolunteerAccepted
                        ? "Volunteer Details"
                        : "Contact Details"),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: FutureBuilder<Map<String, dynamic>>(
            future: _fetchDetailsData(
              notif,
              isDonationOffer,
              amINGO,
              isVolunteerAccepted,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: themeColor),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("Details no longer available.");
              }

              var fetchedData = snapshot.data!;
              String displayTitle = "";
              String nameLabel = "";
              String locationLabel = "";
              String contactName = "";
              String contactUsername = "";
              String contactPhone = "";
              String contactLocation = "";
              String contactUserId = "";
              String targetChatId = "";

              if (isDonationOffer) {
                var donationData = fetchedData['donationData'] ?? {};
                if (amINGO) {
                  displayTitle = "Offered By:";
                  nameLabel = "Donor Name";
                  locationLabel = "Pickup Location";
                  var senderProfile = fetchedData['senderProfileData'] ?? {};
                  contactName = senderProfile['name'] ??
                      donationData['donorName'] ??
                      'Unknown Donor';
                  contactUsername = senderProfile['username'] ??
                      senderProfile['userName'] ??
                      donationData['donorUsername'] ??
                      "";
                  contactPhone = senderProfile['phone'] ??
                      donationData['donorPhone'] ??
                      'Unknown Phone';
                  contactLocation = senderProfile['location'] ??
                      donationData['donorLocation'] ??
                      'Unknown Location';
                  contactUserId = senderProfile['uid'] ??
                      donationData['donorId'] ??
                      notif.senderId;
                  targetChatId = contactUserId;
                } else {
                  displayTitle = "Donating To:";
                  nameLabel = "Organization Name";
                  locationLabel = "Drop-off/NGO Location";
                  var ngoProfile = fetchedData['ngoProfileData'] ?? {};
                  contactName = ngoProfile['ngoName'] ??
                      ngoProfile['name'] ??
                      donationData['ngoName'] ??
                      'Unknown NGO';
                  contactUsername = ngoProfile['username'] ??
                      ngoProfile['userName'] ??
                      donationData['ngoUsername'] ??
                      "";
                  contactPhone = ngoProfile['phone'] ??
                      ngoProfile['ngoPhone'] ??
                      donationData['ngoPhone'] ??
                      'Not Provided';
                  contactLocation = ngoProfile['address'] ??
                      ngoProfile['location'] ??
                      donationData['ngoLocation'] ??
                      'Not Provided';
                  contactUserId = ngoProfile['uid'] ??
                      donationData['ngoId'] ??
                      notif.receiverId;
                  targetChatId = contactUserId;
                }
              } else if (isVolunteerAccepted) {
                var senderProfile = fetchedData['senderProfileData'] ?? {};
                displayTitle = "Assigned Logistics:";
                nameLabel = "Volunteer Name";
                locationLabel = "Volunteer Location";
                contactName = senderProfile['name'] ?? notif.senderName;
                contactUsername = senderProfile['username'] ??
                    senderProfile['userName'] ??
                    "";
                contactPhone = senderProfile['phone'] ?? 'Not Provided';
                contactLocation =
                    senderProfile['location'] ?? 'Not Provided';
                contactUserId = senderProfile['uid'] ?? notif.senderId;
                targetChatId = notif.senderId;
              } else {
                var senderProfile = fetchedData['senderProfileData'] ?? {};
                var notifData = fetchedData['notifData'] ?? {};
                nameLabel = "Sender Name";
                locationLabel = "Location";
                contactName = senderProfile['name'] ??
                    senderProfile['ngoName'] ??
                    notif.senderName;
                contactUsername = senderProfile['username'] ??
                    senderProfile['userName'] ??
                    "";
                contactPhone = senderProfile['phone'] ??
                    notifData['senderPhone'] ??
                    'Not Provided';
                contactLocation = senderProfile['address'] ??
                    senderProfile['location'] ??
                    notifData['senderLocation'] ??
                    'Not Provided';
                contactUserId = senderProfile['uid'] ?? notif.senderId;
                targetChatId = notif.senderId;
              }

              String buttonText = "Open Chat";
              if (isDonationOffer) {
                buttonText =
                    amINGO ? "Accept & Chat with Donor" : "Chat with NGO";
              } else if (isVolunteerAccepted) {
                buttonText = "Open Chat with Volunteer";
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayTitle.isNotEmpty) ...[
                    Text(
                      displayTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      notif.message,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _detailRowWithId(
                    Icons.person_outline,
                    nameLabel,
                    contactName,
                    contactUsername,
                    themeColor,
                  ),
                  const SizedBox(height: 16),
                  _detailRow(
                    Icons.phone_outlined,
                    "Contact Number",
                    contactPhone,
                    themeColor,
                  ),
                  const SizedBox(height: 16),
                  _detailRow(
                    Icons.location_on_outlined,
                    locationLabel,
                    contactLocation,
                    themeColor,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUserId: targetChatId,
                              otherUserName: contactName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: Text(
                        buttonText,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _detailRowWithId(
    IconData icon,
    String label,
    String name,
    String detailValue,
    Color themeColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: themeColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detailValue.isNotEmpty
                    ? '@$detailValue'
                    : "Username not available",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
    Color themeColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: themeColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showExpirationDetails(BuildContext context, NotificationModel notif) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.timer_off_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text(
                "Request Expired",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  notif.message,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Because the deadline has passed, this request is no longer visible to donors. If you still need these items, please create a new request.",
                style: TextStyle(color: Colors.black87, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Understood",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNoVolunteerFoundDetails(
    BuildContext context,
    NotificationModel notif,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_off_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  "No Volunteer Found",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  notif.message,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Understood",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDonorCancellationDetails(
    BuildContext context,
    NotificationModel notification,
    Color themeColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(notification.senderId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: themeColor),
                ),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text("Donor details no longer available."),
                ),
              );
            }

            var donorData = snapshot.data!.data() as Map<String, dynamic>;
            String contactName = donorData['name'] ?? notification.senderName;

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Cancellation Details",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Donor Information",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: donorData['profileImage'] != null &&
                              donorData['profileImage'].toString().isNotEmpty
                          ? NetworkImage(donorData['profileImage'])
                          : null,
                      child: donorData['profileImage'] == null ||
                              donorData['profileImage'].toString().isEmpty
                          ? Icon(
                              Icons.person,
                              color: Colors.grey.shade400,
                              size: 30,
                            )
                          : null,
                    ),
                    title: Text(
                      contactName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          "${donorData['phone'] ?? 'No phone provided'}",
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${donorData['location'] ?? 'No Location provided'}",
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUserId: notification.senderId,
                              otherUserName: contactName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Open Chat with Donor",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openRatingFromPaymentVerified(
    BuildContext context,
    NotificationModel notif,
  ) async {
    try {
      final donationId = notif.relatedItemId.trim();
      if (donationId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Donation not found for this notification.'),
            ),
          );
        }
        return;
      }

      final donSnap = await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .get();

      if (!donSnap.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Donation no longer exists.')),
          );
        }
        return;
      }

      final data = donSnap.data() as Map<String, dynamic>;

      if (data['isRated'] == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already rated this delivery.')),
          );
        }
        return;
      }

      String volunteerId =
          (data['assignedVolunteerId'] ?? '').toString().trim();
      if (volunteerId.isEmpty) {
        volunteerId = notif.senderId.trim();
      }

      String volunteerName = notif.senderName;
      if (volunteerId.isNotEmpty) {
        final volSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(volunteerId)
            .get();
        if (volSnap.exists) {
          volunteerName =
              (volSnap.data()?['name'] ?? volunteerName).toString().trim();
        }
      }
      if (volunteerName.isEmpty) volunteerName = 'Volunteer';

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => RatingDialog(
          volunteerId: volunteerId,
          volunteerName: volunteerName,
          donationId: donationId,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open rating: $e')),
        );
      }
    }
  }

  Future<void> _showVerifyPaymentDialog(
    BuildContext context,
    NotificationModel notif,
    Color themeColor,
  ) async {
    try {
      final donSnap = await FirebaseFirestore.instance
          .collection('donations')
          .doc(notif.relatedItemId)
          .get();

      if (donSnap.exists) {
        final data = donSnap.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString();
        final paymentStatus = (data['paymentStatus'] ?? '').toString();

        final alreadyHandled = status == 'fully_completed' ||
            status == 'admin_verification_pending' ||
            paymentStatus == 'paid' ||
            paymentStatus == 'disputed';

        if (alreadyHandled) {
          if (!context.mounted) return;

          final wasPaid =
              status == 'fully_completed' || paymentStatus == 'paid';

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    wasPaid
                        ? Icons.check_circle_rounded
                        : Icons.support_agent_rounded,
                    color: wasPaid ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wasPaid ? 'Already Confirmed' : 'Already Reported',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: wasPaid ? Colors.green : Colors.orange,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                wasPaid
                    ? 'You already confirmed that you received this payment.\n\nThe donor has been notified and their screen is unlocked.'
                    : 'You already reported that you did not receive this payment.\n\nAdmin is reviewing the transaction. No further action is needed from you.',
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: wasPaid ? Colors.green : Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking donation before verify dialog: $e');
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.currency_rupee_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Verify Payment',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          "${notif.message}\n\nIf you select 'Yes, Received', the donor's screen will unlock immediately.",
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showNotReceivedConfirmation(context, notif, themeColor);
            },
            child: Text(
              'Not Received',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('donations')
                  .doc(notif.relatedItemId)
                  .update({
                'status': 'fully_completed',
                'paymentStatus': 'paid',
              });

              final notifId =
                  FirebaseFirestore.instance.collection('notifications').doc().id;
              final returnNotif = NotificationModel(
                id: notifId,
                receiverId: notif.senderId,
                senderId: notif.receiverId,
                senderName: 'Volunteer',
                type: 'payment_verified',
                title: 'Payment Verified! 🎉',
                message:
                    'Thank you! The volunteer confirmed receipt of your delivery fee.',
                relatedItemId: notif.relatedItemId,
                createdAt: DateTime.now(),
                isRead: false,
              );
              await FirestoreService().sendNotification(returnNotif);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Yes, Received',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotReceivedConfirmation(
    BuildContext context,
    NotificationModel notif,
    Color themeColor,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Confirm – Payment Not Received?",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: const Text(
          "Are you sure you have not received this payment?\n\n"
          "If you confirm, our admin team will verify the transaction using the Reference ID provided by the donor and will contact both parties if needed.",
          style: TextStyle(height: 1.45, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              await FirebaseFirestore.instance
                  .collection('donations')
                  .doc(notif.relatedItemId)
                  .update({
                'status': 'admin_verification_pending',
                'paymentStatus': 'disputed',
                'paymentDisputedAt': FieldValue.serverTimestamp(),
              });

              final donorNotifId =
                  FirebaseFirestore.instance.collection('notifications').doc().id;
              final donorNotif = NotificationModel(
                id: donorNotifId,
                receiverId: notif.senderId,
                senderId: notif.receiverId,
                senderName: 'Volunteer',
                type: 'payment_rejected',
                title: 'Payment Under Admin Review',
                message:
                    'The volunteer reported they did not receive your payment. Our admin team is verifying the transaction using your Reference ID. You will be notified once the check is complete.',
                relatedItemId: notif.relatedItemId,
                createdAt: DateTime.now(),
                isRead: false,
              );
              await FirestoreService().sendNotification(donorNotif);

              await _notifyAdminsOfDispute(notif);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Yes, Still Not Received",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _notifyAdminsOfDispute(NotificationModel originalNotif) async {
    try {
      final donationSnap = await FirebaseFirestore.instance
          .collection('donations')
          .doc(originalNotif.relatedItemId)
          .get();

      final donationData = donationSnap.data() ?? {};
      final ref = donationData['paymentReference'] ?? 'Not provided';
      final fee = (donationData['deliveryFee'] as num?)?.toDouble() ?? 0;

      String volunteerName = 'Volunteer';
      final volSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(originalNotif.receiverId)
          .get();
      if (volSnap.exists) {
        volunteerName = volSnap.data()?['name'] ?? 'Volunteer';
      }

      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var adminDoc in adminQuery.docs) {
        final notifId =
            FirebaseFirestore.instance.collection('notifications').doc().id;
        final adminNotif = NotificationModel(
          id: notifId,
          receiverId: adminDoc.id,
          senderId: originalNotif.receiverId,
          senderName: volunteerName,
          type: 'payment_dispute',
          title: 'Payment Dispute – Action Required',
          message:
              'Volunteer "$volunteerName" reported NON-RECEIPT of ₹${fee.toStringAsFixed(0)}.\n\n'
              'Donor: ${originalNotif.senderName}\n'
              'Reference ID: $ref\n'
              'Donation ID: ${originalNotif.relatedItemId}\n\n'
              'Please verify and unlock the donor phone if the payment is genuine.',
          relatedItemId: originalNotif.relatedItemId,
          createdAt: DateTime.now(),
          isRead: false,
        );
        await FirestoreService().sendNotification(adminNotif);
      }
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final firestoreService = FirestoreService();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(
          child: Text("Please log in to view notifications."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: firestoreService.getUserNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: themeColor),
            );
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notifications."));
          }

          final notifications = snapshot.data ?? [];

          // Auto-open from push
          if (!_autoOpened &&
              widget.autoOpenType != null &&
              notifications.isNotEmpty) {
            _autoOpened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _tryAutoOpen(notifications);
            });
          }

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No new notifications",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              bool isMessage = notif.type == 'new_message';
              bool isTag = notif.type == 'tag';
              bool isDonationOffer = notif.type == 'donation_offer';
              bool isCancellation = notif.type == 'donation_cancelled';
              bool isExpiration = notif.type == 'expired_request';
              bool isVolunteerAccepted = notif.type == 'volunteer_accepted';
              bool isVolunteerExpired = notif.type == 'volunteer_expired';
              bool isDeliveryArrived = notif.type == 'delivery_arrived';
              bool isPaymentPending = notif.type == 'payment_pending';
              bool isVerifyPayment = notif.type == 'verify_payment';
              bool isPaymentVerified = notif.type == 'payment_verified';

              bool isTaskNotification = notif.type == 'new_task_available' ||
                  notif.type == 'urgent_task';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: notif.isRead
                      ? Colors.white
                      : themeColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: notif.isRead
                        ? Colors.grey.shade200
                        : themeColor.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isCancellation
                        ? Colors.red.shade50
                        : (isExpiration || isVolunteerExpired
                            ? Colors.orange.shade50
                            : (isPaymentPending ||
                                    isVerifyPayment ||
                                    isPaymentVerified
                                ? Colors.blue.shade50
                                : (isTaskNotification
                                    ? Colors.deepPurple.shade50
                                    : themeColor.withOpacity(0.1)))),
                    child: Icon(
                      isCancellation
                          ? Icons.cancel_presentation_rounded
                          : isExpiration
                              ? Icons.timer_off_rounded
                              : isVolunteerExpired
                                  ? Icons.person_off_rounded
                                  : isDeliveryArrived
                                      ? Icons.inventory_2_rounded
                                      : isPaymentPending
                                          ? Icons.payment_rounded
                                          : isVerifyPayment
                                              ? Icons.currency_rupee_rounded
                                              : isPaymentVerified
                                                  ? Icons.verified_rounded
                                                  : isTaskNotification
                                                      ? Icons.two_wheeler_rounded
                                                      : (isTag
                                                          ? Icons.photo_library_rounded
                                                          : (isMessage
                                                              ? Icons.message_rounded
                                                              : (isVolunteerAccepted
                                                                  ? Icons
                                                                      .directions_car_rounded
                                                                  : Icons
                                                                      .volunteer_activism))),
                      color: isCancellation
                          ? Colors.red
                          : (isExpiration || isVolunteerExpired
                              ? Colors.orange
                              : (isPaymentPending ||
                                      isVerifyPayment ||
                                      isPaymentVerified
                                  ? Colors.blue
                                  : (isTaskNotification
                                      ? Colors.deepPurple
                                      : themeColor))),
                    ),
                  ),
                  title: Text(
                    notif.title,
                    style: TextStyle(
                      fontWeight:
                          notif.isRead ? FontWeight.w600 : FontWeight.bold,
                      color: isCancellation
                          ? Colors.red.shade900
                          : (isExpiration || isVolunteerExpired
                              ? Colors.orange.shade900
                              : Colors.black87),
                      height: 1.3,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      notif.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  trailing: notif.isRead
                      ? null
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () {
                    if (!notif.isRead) {
                      firestoreService.markNotificationAsRead(notif.id);
                    }

                    if (isDeliveryArrived) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PendingReceiptsScreen(ngoId: user.uid),
                        ),
                      );
                    } else if (isPaymentPending) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VolunteerPaymentScreen(
                            donationId: notif.relatedItemId,
                          ),
                        ),
                      );
                    } else if (isVerifyPayment) {
                      _showVerifyPaymentDialog(context, notif, themeColor);
                    } else if (isPaymentVerified) {
                      _openRatingFromPaymentVerified(context, notif);
                    } else if (isTaskNotification) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VolunteerDashboard(
                            highlightDonationId:
                                notif.relatedItemId.isNotEmpty
                                    ? notif.relatedItemId
                                    : null,
                          ),
                        ),
                      );
                    } else if (isTag) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeScreen(
                            initialIndex: 1,
                            targetPostId: notif.relatedItemId,
                          ),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    } else if (isCancellation) {
                      _showDonorCancellationDetails(
                        context,
                        notif,
                        themeColor,
                      );
                    } else if (isExpiration) {
                      _showExpirationDetails(context, notif);
                    } else if (isVolunteerExpired) {
                      _showNoVolunteerFoundDetails(context, notif);
                    } else {
                      _showRichDetailsPopup(
                        context,
                        notif,
                        themeColor,
                        isDonationOffer,
                        isVolunteerAccepted,
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}