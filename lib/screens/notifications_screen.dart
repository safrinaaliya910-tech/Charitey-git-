import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/notification_model.dart';
import 'chat_screen.dart';
import 'home_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
      }

      DocumentSnapshot notifSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notif.id)
          .get();
      if (notifSnap.exists && notifSnap.data() != null) {
        result['notifData'] = notifSnap.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching dynamic notification details: $e");
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
                      '';
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
                      '';
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
                    '';
                contactPhone = senderProfile['phone'] ?? 'Not Provided';
                contactLocation = senderProfile['location'] ?? 'Not Provided';
                contactUserId =
                    senderProfile['uid'] ?? notif.senderId; // Real User ID
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
                    '';
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

                  // ==================== UPDATED: Name + Username Below ====================
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

  // NEW HELPER - Shows Name + Username below (like in the image)
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
          title: Row(
            children: [
              const Icon(Icons.timer_off_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              const Text(
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final firestoreService = FirestoreService();
    final Color themeColor = const Color(0xFFB56F76);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Please log in to view notifications.")),
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
            return Center(child: CircularProgressIndicator(color: themeColor));
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notifications."));
          }

          final notifications = snapshot.data ?? [];

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

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: notif.isRead
                      ? Colors.white
                      : themeColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: notif.isRead
                        ? Colors.grey.shade200
                        : themeColor.withValues(alpha: 0.3),
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
                        : (isExpiration
                            ? Colors.orange.shade50
                            : themeColor.withValues(alpha: 0.1)),
                    child: Icon(
                      isCancellation
                          ? Icons.cancel_presentation_rounded
                          : isExpiration
                              ? Icons.timer_off_rounded
                              : (isTag
                                  ? Icons.photo_library_rounded
                                  : (isMessage
                                      ? Icons.message_rounded
                                      : (isVolunteerAccepted
                                          ? Icons.directions_car_rounded
                                          : Icons.volunteer_activism))),
                      color: isCancellation
                          ? Colors.red
                          : (isExpiration ? Colors.orange : themeColor),
                    ),
                  ),
                  title: Text(
                    notif.title,
                    style: TextStyle(
                      fontWeight:
                          notif.isRead ? FontWeight.w600 : FontWeight.bold,
                      color: isCancellation
                          ? Colors.red.shade900
                          : (isExpiration
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
                    if (isTag) {
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
                      _showDonorCancellationDetails(context, notif, themeColor);
                    } else if (isExpiration) {
                      _showExpirationDetails(context, notif);
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