// volunteer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/fare_calculator.dart';
import '../services/location_service.dart';
import '../models/notification_model.dart';
import 'chat_screen.dart';

class VolunteerDashboard extends StatefulWidget {
  // 👇 NEW: Optional donationId to scroll to and highlight the moment the
  // dashboard opens — passed in from NotificationsScreen when the user taps
  // a 'new_task_available' or 'urgent_task' notification, so they land
  // directly on the relevant card instead of having to hunt for it.
  final String? highlightDonationId;

  const VolunteerDashboard({Key? key, this.highlightDonationId}) : super(key: key);

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final Color themeColor = const Color(0xFFB56F76);
  final ScrollController _scrollController = ScrollController();

  bool showAvailable = true;

  // 👇 NEW: GlobalKey attached to the highlighted card so we can locate its
  // BuildContext and call Scrollable.ensureVisible on it. _hasScrolledToHighlight
  // guards against re-scrolling on every Firestore stream rebuild.
  GlobalKey? _highlightKey;
  bool _hasScrolledToHighlight = false;

  @override
  void initState() {
    super.initState();
    if (widget.highlightDonationId != null) {
      _highlightKey = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 👇 NEW: Parses the volunteer's stored 'vehicleType' string (from their
  // profile, set once at registration) back into the VehicleType enum.
  // Defaults to bike if missing/invalid — covers volunteers who registered
  // before this feature existed.
  VehicleType _parseVehicleType(String? value) {
    if (value == null || value.trim().isEmpty) return VehicleType.bike;
    return VehicleType.values.firstWhere(
      (v) => v.name.toLowerCase() == value.trim().toLowerCase(),
      orElse: () => VehicleType.bike,
    );
  }

  // 👇 NEW: Scrolls the highlighted card into view once it's actually been
  // laid out. Called from the FutureBuilder below after each card build;
  // retries harmlessly on every rebuild until the card's context resolves
  // (e.g. first stream event might not have it yet), then locks via
  // _hasScrolledToHighlight so it doesn't keep re-scrolling on later updates.
  void _scrollToHighlightIfNeeded() {
    if (widget.highlightDonationId == null || _hasScrolledToHighlight) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _highlightKey?.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
        _hasScrolledToHighlight = true;
      }
    });
  }

  Future<void> _acceptTask({
    required String donationId,
    required String volunteerId,
    required String donorId,
    required String ngoId,
    required String itemName,
    required VehicleType vehicleType,
    required double deliveryFee,
  }) async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;

      // 1. Update the original donations collection
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'delivery_accepted',
        'assignedVolunteerId': volunteerId,
        'vehicleType': vehicleType.name,
        'deliveryFee': deliveryFee,
      });

      // 2. Update the volunteer_requests collection for the Admin Panel
      var requestQuery = await FirebaseFirestore.instance
          .collection('volunteer_requests')
          .where('donorId', isEqualTo: donorId)
          .where('ngoId', isEqualTo: ngoId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (requestQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('volunteer_requests')
            .doc(requestQuery.docs.first.id)
            .update({
              'status': 'accepted',
              'assignedVolunteer': user!.name,
            });
      }

      String notifIdNgo = FirebaseFirestore.instance.collection('notifications').doc().id;
      NotificationModel ngoNotif = NotificationModel(
        id: notifIdNgo,
        receiverId: ngoId,
        senderId: volunteerId,
        senderName: user!.name,
        type: 'volunteer_accepted',
        title: 'Volunteer Assigned',
        message: '${user.name} has accepted the task to pick up and deliver $itemName.',
        relatedItemId: donationId,
        createdAt: DateTime.now(),
        isRead: false,
      );
      await FirestoreService().sendNotification(ngoNotif);

      String notifIdDonor = FirebaseFirestore.instance.collection('notifications').doc().id;
      NotificationModel donorNotif = NotificationModel(
        id: notifIdDonor,
        receiverId: donorId,
        senderId: volunteerId,
        senderName: user.name,
        type: 'volunteer_accepted',
        title: 'Pickup Volunteer Assigned',
        message: '${user.name} will be picking up your donation ($itemName) soon.',
        relatedItemId: donationId,
        createdAt: DateTime.now(),
        isRead: false,
      );
      await FirestoreService().sendNotification(donorNotif);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Pickup Task Accepted!', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        showAvailable = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept task: $e')),
      );
    }
  }

  // 👇 UPDATED: No more "Choose Your Vehicle" dialog here. Vehicle type comes
  // from the volunteer's registered profile (already resolved by the caller
  // in _buildDeliveryCard / _generateFilteredCards) and is passed straight
  // in, along with the fee already computed for that vehicle. This goes
  // directly to the existing "Confirm Pickup" dialog.
  Future<void> _confirmAndAcceptTask(
    BuildContext context,
    String donationId,
    String volunteerId,
    String donorId,
    String ngoId,
    String itemName,
    VehicleType vehicleType,
    double deliveryFee,
  ) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: themeColor, size: 24),
            const SizedBox(width: 8),
            Text("Confirm Pickup", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you ready to deliver?\n\nYou must deliver on time. If there is any delay, please inform the NGO and Donor properly through the chat.",
              style: TextStyle(height: 1.5, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(_vehicleIcon(vehicleType), color: themeColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Vehicle: ${vehicleType.name} • Fee: ₹${deliveryFee.toStringAsFixed(0)}",
                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Yes, I'm Ready", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _acceptTask(
        donationId: donationId,
        volunteerId: volunteerId,
        donorId: donorId,
        ngoId: ngoId,
        itemName: itemName,
        vehicleType: vehicleType,
        deliveryFee: deliveryFee,
      );
    }
  }

  IconData _vehicleIcon(VehicleType vehicleType) {
    switch (vehicleType) {
      case VehicleType.scooty:
        return Icons.two_wheeler_rounded;
      case VehicleType.bike:
        return Icons.pedal_bike_rounded;
      case VehicleType.auto:
        return Icons.electric_rickshaw_rounded;
      case VehicleType.car:
        return Icons.directions_car_rounded;
      case VehicleType.tempo:
      case VehicleType.van:
        return Icons.local_shipping_outlined;
      case VehicleType.lorry:
        return Icons.local_shipping_rounded;
    }
  }

  Future<void> _handleExpiredTask(String donationId, String donorId, String ngoId, String itemName) async {
    try {
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'volunteer_not_found',
      });

      if (ngoId.isNotEmpty) {
        String notifIdNgo = FirebaseFirestore.instance.collection('notifications').doc().id;
        await FirebaseFirestore.instance.collection('notifications').doc(notifIdNgo).set({
          'id': notifIdNgo,
          'receiverId': ngoId,
          'senderId': 'system',
          'senderName': 'System Alert',
          'type': 'volunteer_expired',
          'title': 'No Volunteer Found',
          'message': 'Unfortunately, no volunteer accepted the pickup for $itemName in time. Please re-request or arrange private transport.',
          'relatedItemId': donationId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (donorId.isNotEmpty) {
        String notifIdDonor = FirebaseFirestore.instance.collection('notifications').doc().id;
        await FirebaseFirestore.instance.collection('notifications').doc(notifIdDonor).set({
          'id': notifIdDonor,
          'receiverId': donorId,
          'senderId': 'system',
          'senderName': 'System Alert',
          'type': 'volunteer_expired',
          'title': 'Pickup Expired',
          'message': 'No volunteer was available to pick up $itemName before the required time. Please consider redonating or dropping it off.',
          'relatedItemId': donationId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      var requestQuery = await FirebaseFirestore.instance
          .collection('volunteer_requests')
          .where('donorId', isEqualTo: donorId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (requestQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('volunteer_requests')
            .doc(requestQuery.docs.first.id)
            .update({
              'status': 'expired',
            });
      }
    } catch (e) {
      debugPrint("Error handling expired task: $e");
    }
  }

  // 👇 Fires ONCE per donation, the moment it first appears as a
  // pending pickup task (i.e. as soon as _generateFilteredCards sees it
  // without the 'newTaskNotified' flag set). Notifies every registered
  // volunteer with type 'new_task_available' so NotificationsScreen can
  // route a tap straight into VolunteerDashboard, highlighting this card.
  // The 'newTaskNotified' flag on the donation doc guarantees this only
  // sends once, even though multiple volunteers' dashboards may be
  // listening to the same query at once.
  Future<void> _triggerNewTaskNotification(String donationId, String itemName, String location) async {
    try {
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'newTaskNotified': true,
      });

      var volunteersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'volunteer')
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var volDoc in volunteersSnap.docs) {
        String volId = volDoc.id;
        String notifId = FirebaseFirestore.instance.collection('notifications').doc().id;

        batch.set(FirebaseFirestore.instance.collection('notifications').doc(notifId), {
          'id': notifId,
          'receiverId': volId,
          'senderId': 'system',
          'senderName': 'New Task',
          'type': 'new_task_available',
          'title': 'New Pickup Task Available 🚴',
          'message': 'A new donation of $itemName in $location is ready for pickup. Tap to view and accept.',
          'relatedItemId': donationId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error triggering new task notification: $e");
    }
  }

  Future<void> _triggerUrgentVolunteerNotification(String donationId, String itemName, String location) async {
    try {
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'urgentNotified': true,
      });

      var volunteersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'volunteer')
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var volDoc in volunteersSnap.docs) {
        String volId = volDoc.id;
        String notifId = FirebaseFirestore.instance.collection('notifications').doc().id;

        batch.set(FirebaseFirestore.instance.collection('notifications').doc(notifId), {
          'id': notifId,
          'receiverId': volId,
          'senderId': 'system',
          'senderName': 'Urgent Alert',
          'type': 'urgent_task',
          'title': 'Urgent: Volunteer Needed! 🚨',
          'message': 'A donation of $itemName in $location needs pickup within 24 hours! Accept the task now and make an impact.',
          'relatedItemId': donationId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error triggering urgent notification: $e");
    }
  }

  Future<List<Widget>> _generateFilteredCards(List<QueryDocumentSnapshot> donations, String myUserId) async {
    List<Widget> cardList = [];

    // 👇 Resolve the CURRENT VOLUNTEER's own registered vehicle once,
    // from their profile (set during registration/profile-setup). This is
    // used for every card's fee preview and for the fee actually charged
    // when they accept a task — no more per-task vehicle picker.
    final myUserModel = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    final VehicleType myVehicleType = _parseVehicleType(myUserModel?.vehicleType);

    for (var donationDoc in donations) {
      var donationData = donationDoc.data() as Map<String, dynamic>;
      var donationId = donationDoc.id;

      String listingId = donationData['listingId'] ?? '';
      String donorId = donationData['donorId'] ?? '';

      if (listingId.isEmpty || donorId.isEmpty) continue;

      String donorName = donationData['donorName'] ?? 'Unknown Donor';
      String donorLocation = donationData['donorLocation'] ?? 'Location unavailable';
      String donorPhone = donationData['donorPhone'] ?? 'Phone unavailable';
      String status = donationData['status'] ?? 'pending';
      String? vehicleTypeValue = donationData['vehicleType']?.toString();
      String? assignedVolunteerId = donationData['assignedVolunteerId'];

      bool isAcceptedByMe = (status == 'delivery_accepted' && assignedVolunteerId == myUserId) ||
                            (status == 'pending_ngo_confirmation' && assignedVolunteerId == myUserId) ||
                            (status == 'completed_awaiting_payment' && assignedVolunteerId == myUserId) ||
                            (status == 'fully_completed' && assignedVolunteerId == myUserId);

      if (showAvailable) {
        if (status != 'pending') continue;
      } else {
        if (!isAcceptedByMe) continue;
      }

      var listingSnap = await FirebaseFirestore.instance.collection('ngo_listings').doc(listingId).get();
      if (!listingSnap.exists) continue;

      var listingData = listingSnap.data() as Map<String, dynamic>;
      bool? isVolunteerAvailable = listingData['isVolunteerAvailable'] as bool?;

      if (isVolunteerAvailable == true) {
        continue; // NGO has their own volunteer, skip
      }

      String type = listingData['type'] ?? 'food';
      String itemName = type == 'food' ? (listingData['foodType'] ?? "Food") : (listingData['productName'] ?? "Product");

      Timestamp? liveUntilTs = listingData['liveUntil'] as Timestamp?;
      DateTime liveUntil = liveUntilTs != null ? liveUntilTs.toDate() : DateTime.now().add(const Duration(days: 365));
      DateTime now = DateTime.now();

      if (status == 'pending') {
        if (now.isAfter(liveUntil)) {
          _handleExpiredTask(donationId, donorId, listingData['ngold'] ?? listingData['ngoId'] ?? '', itemName);
          continue;
        } else {
          // 👇 Notify every volunteer the moment this task first
          // appears as pending — separate, one-time flag from the
          // urgent (<=24h) notification below.
          bool newTaskNotified = donationData['newTaskNotified'] == true;
          if (!newTaskNotified) {
            _triggerNewTaskNotification(donationId, itemName, listingData['ngoLocation'] ?? 'your area');
          }

          bool urgentNotified = donationData['urgentNotified'] == true;
          if (!urgentNotified && liveUntil.difference(now).inHours <= 24) {
            _triggerUrgentVolunteerNotification(donationId, itemName, listingData['ngoLocation'] ?? 'your area');
          }
        }
      }

      String rawDonatedQty = donationData['donatedQuantity']?.toString() ??
                             donationData['quantity']?.toString() ??
                             donationData['donatedAmount']?.toString() ?? '';

      String unitVal = listingData['unit']?.toString() ?? '';
      String quantity = rawDonatedQty.isEmpty ? '1 Item' : '$rawDonatedQty $unitVal'.trim();

      String availability = listingData['availability'] ?? 'Time not specified';
      String ngoName = listingData['ngoName'] ?? 'Unknown NGO';

      // FETCH NGO PICKUP/DROP ADDRESS PREFERRING PINNED ADDRESS
      String ngoLocation = listingData['pickupAddress'] ?? listingData['ngoLocation'] ?? 'Location unavailable';
      String ngoId = listingData['ngoId'] ?? listingData['ngold'] ?? '';

      String ngoPhone = 'Phone unavailable';
      var ngoUserSnap = await FirebaseFirestore.instance.collection('users').doc(ngoId).get();
      if (ngoUserSnap.exists) {
        var ngoUserData = ngoUserSnap.data() as Map<String, dynamic>;
        ngoPhone = ngoUserData['phone'] ?? 'Phone unavailable';
      }

      // 👇 FARE & DISTANCE — prefer stored distance/fee from the donation
      // (saved by donation_page.dart using road-distance + FareCalculator),
      // otherwise recompute using straight-line distance as a fallback.
      double deliveryFee = (donationData['deliveryFee'] as num?)?.toDouble() ?? 0.0;
      double? storedDistanceKm = (donationData['distanceKm'] as num?)?.toDouble();
      double? donorLat = (donationData['donorLat'] as num?)?.toDouble();
      double? donorLng = (donationData['donorLng'] as num?)?.toDouble();
      double? ngoLat = (listingData['pickupLat'] as num?)?.toDouble();
      double? ngoLng = (listingData['pickupLng'] as num?)?.toDouble();

      double distanceKm = storedDistanceKm ?? 0.0;
      double durationMinutes = (distanceKm / 30.0) * 60.0;
      if (distanceKm <= 0 && donorLat != null && donorLng != null && ngoLat != null && ngoLng != null) {
        final routeInfo = await LocationHelperService.getRouteInfo(
          originLat: donorLat,
          originLng: donorLng,
          destLat: ngoLat,
          destLng: ngoLng,
        );
        if (routeInfo != null && routeInfo.distanceKm > 0) {
          distanceKm = routeInfo.distanceKm;
          durationMinutes = routeInfo.durationMinutes;
        } else {
          double distMeters = Geolocator.distanceBetween(donorLat, donorLng, ngoLat, ngoLng);
          distanceKm = (distMeters / 1000.0);
          durationMinutes = (distanceKm / 30.0) * 60.0;
        }
      }

      // 👇 For tasks that are not yet accepted, always preview the
      // fee using the CURRENT VOLUNTEER's registered vehicle. This prevents
      // showing a generic per-km estimate (e.g. ₹10/km) saved earlier and
      // ensures the badge vehicle and displayed fee match. When a task is
      // accepted the donation's stored deliveryFee is authoritative and
      // remains unchanged.
      if (!isAcceptedByMe) {
        deliveryFee = FareCalculator.calculate(
          vehicle: myVehicleType,
          distanceKm: distanceKm,
          durationMinutes: durationMinutes,
        );
      }

      // For "Available" (not-yet-accepted) tasks, show the badge using MY
      // vehicle since that's what will be used if I accept it.
      String badgeVehicleType = (isAcceptedByMe && vehicleTypeValue != null && vehicleTypeValue.isNotEmpty)
          ? vehicleTypeValue
          : myVehicleType.name;

      // 👇 NEW: Is this the card we were told to scroll to & highlight?
      bool isHighlighted = widget.highlightDonationId != null && widget.highlightDonationId == donationId;

      cardList.add(
        _buildDeliveryCard(
          donationId: donationId,
          listingId: listingId,
          itemName: itemName,
          quantity: quantity,
          availability: availability,
          ngoName: ngoName,
          ngoLocation: ngoLocation,
          ngoPhone: ngoPhone,
          ngoId: ngoId,
          donorName: donorName,
          donorLocation: donorLocation,
          donorPhone: donorPhone,
          donorId: donorId,
          myId: myUserId,
          status: status, // Passed down for rendering logic
          isAcceptedByMe: isAcceptedByMe,
          deliveryFee: deliveryFee,
          distanceKm: distanceKm,
          vehicleType: badgeVehicleType,
          myVehicleType: myVehicleType,
          isHighlighted: isHighlighted,
          cardKey: isHighlighted ? _highlightKey : null,
        )
      );
    }

    // 👇 NEW: Try scrolling to the highlighted card now that the list is built.
    _scrollToHighlightIfNeeded();

    return cardList;
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUserModel;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => showAvailable = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: showAvailable ? themeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            "Available",
                            style: TextStyle(
                              color: showAvailable ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => showAvailable = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !showAvailable ? themeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            "Accepted",
                            style: TextStyle(
                              color: !showAvailable ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('status', whereIn: ['pending', 'delivery_accepted', 'pending_ngo_confirmation', 'completed_awaiting_payment', 'fully_completed'])
                  .snapshots(),
              builder: (context, donationSnapshot) {
                if (donationSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: themeColor));
                }

                if (!donationSnapshot.hasData || donationSnapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var donations = donationSnapshot.data!.docs.toList();
                donations.sort((a, b) {
                  var aData = a.data() as Map<String, dynamic>;
                  var bData = b.data() as Map<String, dynamic>;
                  DateTime aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  DateTime bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  return bTime.compareTo(aTime);
                });

                return FutureBuilder<List<Widget>>(
                  future: _generateFilteredCards(donations, user.uid),
                  builder: (context, cardSnapshot) {
                    if (cardSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: themeColor));
                    }

                    if (!cardSnapshot.hasData || cardSnapshot.data!.isEmpty) {
                      return _buildEmptyState();
                    }

                    return Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 6.0,
                      radius: const Radius.circular(10),
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 100),
                        children: cardSnapshot.data!,
                      ),
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard({
    required String donationId,
    required String listingId,
    required String itemName,
    required String quantity,
    required String availability,
    required String ngoName,
    required String ngoLocation,
    required String ngoPhone,
    required String ngoId,
    required String donorName,
    required String donorLocation,
    required String donorPhone,
    required String donorId,
    required String myId,
    required String status,
    required bool isAcceptedByMe,
    required double deliveryFee,
    required double distanceKm,
    String? vehicleType,
    required VehicleType myVehicleType,
    bool isHighlighted = false, // 👈 NEW
    Key? cardKey, // 👈 NEW
  }) {
    bool isCompleted = status == 'delivery_completed' || status == 'fully_completed' || status == 'completed_awaiting_payment';
    bool isPendingNGO = status == 'pending_ngo_confirmation';

    Widget cardContent = Container(
      key: cardKey, // 👈 NEW: lets Scrollable.ensureVisible find this exact card
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHighlighted
              ? [Colors.white, Colors.red.withValues(alpha: 0.06)]
              : [Colors.white, themeColor.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? Colors.red.shade400 : themeColor.withValues(alpha: 0.2),
          width: isHighlighted ? 2.2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted ? Colors.red.withValues(alpha: 0.18) : themeColor.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // slightly tighter padding helps on small screens
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👇 NEW: "URGENT" ribbon banner shown only on the highlighted card
            if (isHighlighted)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "URGENT — THIS IS THE TASK FROM YOUR ALERT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // ── STATUS + PAY BADGE (fixed overflow) ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge – flexible so it can shrink if needed
                Flexible(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade50
                          : (isPendingNGO ? Colors.orange.shade50 : themeColor.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCompleted
                            ? Colors.green.shade200
                            : (isPendingNGO ? Colors.orange.shade200 : Colors.transparent),
                      ),
                    ),
                    child: Text(
                      isCompleted
                          ? "Completed"
                          : (isPendingNGO
                              ? "Waiting for NGO"
                              : (isAcceptedByMe ? "In Transit" : "Pickup Needed")),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? Colors.green.shade700
                            : (isPendingNGO ? Colors.orange.shade700 : themeColor),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Pay + vehicle + distance – flexible + FittedBox prevents overflow
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded,
                                color: Color(0xFF2E7D32), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "₹${deliveryFee.toStringAsFixed(0)} Pay",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2E7D32),
                                fontSize: 13,
                              ),
                            ),
                            if (vehicleType != null && vehicleType.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              _buildVehicleBadge(vehicleType),
                            ],
                            if (distanceKm > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                "(${distanceKm.toStringAsFixed(1)} km)",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── ITEM NAME + QUANTITY ─────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  quantity,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                    fontSize: 15,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── REQUIRED BY ──────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Required by: $availability",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),

            // ── PICKUP + DELIVER BOXES ───────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PICKUP FROM (DONOR)",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildDetailRow(Icons.person_outline, donorName),
                        if (isAcceptedByMe) ...[
                          const SizedBox(height: 3),
                          _buildDetailRow(Icons.phone_outlined, donorPhone),
                        ],
                        const SizedBox(height: 3),
                        _buildDetailRow(Icons.location_on_outlined, donorLocation),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DELIVER TO (NGO)",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildDetailRow(Icons.account_balance_outlined, ngoName),
                        if (isAcceptedByMe) ...[
                          const SizedBox(height: 3),
                          _buildDetailRow(Icons.phone_outlined, ngoPhone),
                        ],
                        const SizedBox(height: 3),
                        _buildDetailRow(Icons.location_on_outlined, ngoLocation),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── ACTION BUTTONS / STATUS MESSAGES ─────────────────────────────
            if (!isAcceptedByMe)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmAndAcceptTask(
                    context,
                    donationId,
                    myId,
                    donorId,
                    ngoId,
                    itemName,
                    myVehicleType,
                    deliveryFee,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHighlighted ? Colors.red.shade600 : themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Accept Task (Earn ₹${deliveryFee.toStringAsFixed(0)})",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  if (status == 'delivery_accepted')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          bool confirm = await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 24),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Confirm Drop-off",
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: const Text(
                                    "Have you physically handed over the items to the NGO?\n\nPlease only confirm if the handover is fully complete.",
                                    style: TextStyle(height: 1.5, fontSize: 15, color: Colors.black87),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(
                                        "Cancel",
                                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text(
                                        "Yes, Dropped Off",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (!confirm) return;

                          await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
                            'status': 'pending_ngo_confirmation'
                          });

                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final currentUserId = authProvider.currentFirebaseUser?.uid;
                          final currentUserName = authProvider.currentUserModel?.name ?? 'Volunteer';

                          String notifIdNgo = FirebaseFirestore.instance.collection('notifications').doc().id;
                          NotificationModel ngoNotif = NotificationModel(
                            id: notifIdNgo,
                            receiverId: ngoId,
                            senderId: currentUserId!,
                            senderName: currentUserName,
                            type: 'delivery_arrived',
                            title: 'Delivery Arrived! 📦',
                            message:
                                '$currentUserName has dropped off $itemName. Please open your profile and confirm receipt to release their payment.',
                            relatedItemId: donationId,
                            createdAt: DateTime.now(),
                            isRead: false,
                          );
                          await FirestoreService().sendNotification(ngoNotif);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('NGO Notified! Awaiting their confirmation.'),
                              backgroundColor: Colors.orange,
                            ));
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                        label: const Text(
                          "Mark Delivery as Completed",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else if (isPendingNGO)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Center(
                        child: Text(
                          "Waiting for NGO to confirm receipt...",
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else if (status == 'completed_awaiting_payment')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Center(
                        child: Text(
                          "Delivery Verified! Awaiting Payment from Donor.",
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.share, size: 18, color: themeColor),
                        label: Text("Share Impact", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: themeColor.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Donor / NGO chat buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(otherUserId: donorId, otherUserName: donorName),
                              ),
                            );
                          },
                          icon: Icon(Icons.chat_bubble_outline_rounded, color: themeColor, size: 16),
                          label: Text(
                            "Donor",
                            style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            side: BorderSide(color: themeColor.withValues(alpha: 0.5), width: 1.5),
                            backgroundColor: themeColor.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(otherUserId: ngoId, otherUserName: ngoName),
                              ),
                            );
                          },
                          icon: Icon(Icons.chat_bubble_outline_rounded, color: Colors.blueGrey.shade700, size: 16),
                          label: Text(
                            "NGO",
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            side: BorderSide(color: Colors.blueGrey.shade300, width: 1.5),
                            backgroundColor: Colors.blueGrey.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
          ],
        ),
      ),
    );

    // 👇 NEW: Wrap the highlighted card in a pulsing red glow for a few
    // seconds so it visually jumps out the moment the page loads. After the
    // pulse settles it keeps its static red border (set above), so the user
    // can still identify it if they look away and back.
    if (isHighlighted) {
      return _PulseHighlight(child: cardContent);
    }
    return cardContent;
  }

  Widget _buildVehicleBadge(String vehicleType) {
    final normalizedVehicle = vehicleType.toLowerCase();

    final icon = switch (normalizedVehicle) {
      'scooty' => Icons.two_wheeler_rounded,
      'bike' => Icons.pedal_bike_rounded,
      'auto' => Icons.electric_rickshaw_rounded,
      'car' => Icons.directions_car_rounded,
      'tempo' || 'van' => Icons.local_shipping_outlined,
      'lorry' => Icons.local_shipping_rounded,
      _ => Icons.local_shipping_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: themeColor, size: 12),
          const SizedBox(width: 3),
          Text(
            vehicleType,
            style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.25),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_car_filled_outlined, size: 60, color: themeColor),
          ),
          const SizedBox(height: 24),
          Text(
            showAvailable ? "No tasks available" : "No accepted tasks",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            showAvailable ? "Check back later for new pickup requests." : "Accept a task to see it here.",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// 👇 NEW: Small self-contained widget that pulses a red glow around its
// child a few times (via a repeating AnimationController) and then stops,
// leaving the child's own static styling in place. Used to draw the eye to
// the highlighted card immediately after VolunteerDashboard opens.
class _PulseHighlight extends StatefulWidget {
  final Widget child;
  const _PulseHighlight({required this.child});

  @override
  State<_PulseHighlight> createState() => _PulseHighlightState();
}

class _PulseHighlightState extends State<_PulseHighlight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _glow = Tween<double>(begin: 0.12, end: 0.45).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
    // Pulse for ~3 seconds (a handful of cycles), then settle down.
    Future.delayed(const Duration(milliseconds: 2900), () {
      if (mounted) _controller.stop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: _glow.value),
                blurRadius: 22,
                spreadRadius: 3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}