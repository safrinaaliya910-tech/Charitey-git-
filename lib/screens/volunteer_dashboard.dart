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
  const VolunteerDashboard({Key? key}) : super(key: key);

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final Color themeColor = const Color(0xFFB56F76);
  final ScrollController _scrollController = ScrollController();
  
  bool showAvailable = true;

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

    // 👇 NEW: Resolve the CURRENT VOLUNTEER's own registered vehicle once,
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
      if (distanceKm <= 0 && donorLat != null && donorLng != null && ngoLat != null && ngoLng != null) {
        final double? routeKm = await LocationHelperService.getRouteDistanceKm(
          originLat: donorLat,
          originLng: donorLng,
          destLat: ngoLat,
          destLng: ngoLng,
        );
        if (routeKm != null && routeKm > 0) {
          distanceKm = routeKm;
        } else {
          double distMeters = Geolocator.distanceBetween(donorLat, donorLng, ngoLat, ngoLng);
          distanceKm = (distMeters / 1000.0);
        }
      }

      // 👇 UPDATED: For tasks that are not yet accepted, always preview the
      // fee using the CURRENT VOLUNTEER's registered vehicle. This prevents
      // showing a generic per-km estimate (e.g. ₹10/km) saved earlier and
      // ensures the badge vehicle and displayed fee match. When a task is
      // accepted the donation's stored deliveryFee is authoritative and
      // remains unchanged.
      if (!isAcceptedByMe) {
        deliveryFee = FareCalculator.calculate(vehicle: myVehicleType, distanceKm: distanceKm);
      }

      // For "Available" (not-yet-accepted) tasks, show the badge using MY
      // vehicle since that's what will be used if I accept it.
      String badgeVehicleType = (isAcceptedByMe && vehicleTypeValue != null && vehicleTypeValue.isNotEmpty)
          ? vehicleTypeValue
          : myVehicleType.name;

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
        )
      );
    }
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
  }) {
    bool isCompleted = status == 'delivery_completed' || status == 'fully_completed' || status == 'completed_awaiting_payment';
    bool isPendingNGO = status == 'pending_ngo_confirmation';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            themeColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.2), 
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.shade50 : (isPendingNGO ? Colors.orange.shade50 : themeColor.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isCompleted ? Colors.green.shade200 : (isPendingNGO ? Colors.orange.shade200 : Colors.transparent)),
                  ),
                  child: Text(
                    isCompleted ? "Completed" : (isPendingNGO ? "Waiting for NGO" : (isAcceptedByMe ? "In Transit" : "Pickup Needed")),
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: isCompleted ? Colors.green.shade700 : (isPendingNGO ? Colors.orange.shade700 : themeColor),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2E7D32), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "₹${deliveryFee.toStringAsFixed(0)} Pay",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7D32),
                          fontSize: 15,
                        ),
                      ),
                      if (vehicleType != null && vehicleType.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildVehicleBadge(vehicleType),
                      ],
                      if (distanceKm > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          "(${distanceKm.toStringAsFixed(1)} km)",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    itemName, 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                Text(
                  quantity, 
                  style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Required by: $availability",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.person_outline, donorName),
                        
                        if (isAcceptedByMe) ...[
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.phone_outlined, donorPhone),
                        ],
                        
                        const SizedBox(height: 4),
                        _buildDetailRow(Icons.location_on_outlined, donorLocation),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.account_balance_outlined, ngoName),
                        
                        if (isAcceptedByMe) ...[
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.phone_outlined, ngoPhone),
                        ],
                        
                        const SizedBox(height: 4),
                        _buildDetailRow(Icons.location_on_outlined, ngoLocation),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
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
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Accept Task (Earn ₹${deliveryFee.toStringAsFixed(0)})", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                                   Text("Confirm Drop-off", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 20)),
                                 ],
                               ),
                               content: const Text(
                                 "Have you physically handed over the items to the NGO?\n\nPlease only confirm if the handover is fully complete.",
                                 style: TextStyle(height: 1.5, fontSize: 15, color: Colors.black87),
                               ),
                               actions: [
                                 TextButton(
                                   onPressed: () => Navigator.pop(ctx, false),
                                   child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                 ),
                                 ElevatedButton(
                                   onPressed: () => Navigator.pop(ctx, true),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.green.shade600,
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                   ),
                                   child: const Text("Yes, Dropped Off", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 ),
                               ],
                             ),
                           ) ?? false;

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
                             message: '$currentUserName has dropped off $itemName. Please open your profile and confirm receipt to release their payment.',
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                      child: Center(child: Text("Waiting for NGO to confirm receipt...", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold))),
                    )
                  else if (status == 'completed_awaiting_payment')
                     Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)),
                      child: Center(child: Text("Delivery Verified! Awaiting Payment from Donor.", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold))),
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
                            style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                            style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: themeColor, size: 14),
          const SizedBox(width: 4),
          Text(
            vehicleType,
            style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.2),
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