import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
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

  Future<void> _acceptTask(String donationId, String volunteerId, String donorId, String ngoId, String itemName) async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
      
      // 1. Update the original donations collection
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'delivery_accepted',
        'assignedVolunteerId': volunteerId, 
      });

      // 👇 NEW: 2. Update the volunteer_requests collection for the Admin Panel 👇
      // This searches for the pending request involving this specific Donor and NGO and marks it accepted.
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
              'status': 'accepted', // Changes status for Admin Panel!
              'assignedVolunteer': user!.name, // Records the volunteer's name
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

// 👇 NEW: Confirmation Dialog before accepting 👇
  Future<void> _confirmAndAcceptTask(BuildContext context, String donationId, String volunteerId, String donorId, String ngoId, String itemName) async {
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
        content: const Text(
          "Are you ready to deliver?\n\nYou must deliver on time. If there is any delay, please inform the NGO and Donor properly through the chat.",
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
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Yes, I'm Ready", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    // If they clicked "Yes", trigger your existing accept task logic!
    if (confirm) {
      await _acceptTask(donationId, volunteerId, donorId, ngoId, itemName);
    }
  }
  // =========================================================================
  // 👇 NEW: LAZY EXPIRATION AND URGENT ALERT LOGIC 👇
  // =========================================================================

  // Handles tasks that nobody accepted in time
  Future<void> _handleExpiredTask(String donationId, String donorId, String ngoId, String itemName) async {
    try {
      // 1. Mark the donation as expired so it disappears from all lists
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'volunteer_not_found',
      });
      
      // 2. Notify the NGO
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

      // 3. Notify the Donor
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
      
      // 4. Update the Admin Panel Database
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

  // Sends a broadcast alert 24 hours before expiry
  Future<void> _triggerUrgentVolunteerNotification(String donationId, String itemName, String location) async {
    try {
      // 1. Immediately flag it so other volunteers don't trigger duplicate alerts
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'urgentNotified': true,
      });

      // 2. Fetch all registered volunteers
      var volunteersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'volunteer')
          .get();
      
      // 3. Send them all an urgent notification via a Firebase Batch Write
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
      String? assignedVolunteerId = donationData['assignedVolunteerId'];
      
      bool isAcceptedByMe = (status == 'delivery_accepted' && assignedVolunteerId == myUserId);
      
      // 👇 Tab filter - FIXED: Now strictly hides 'volunteer_not_found' tasks 👇
      if (showAvailable) {
        if (status != 'pending') continue; 
      } else {
        if (!isAcceptedByMe) continue; 
      }

      // Fetch the NGO listing to see if they actually need a volunteer
      var listingSnap = await FirebaseFirestore.instance.collection('ngo_listings').doc(listingId).get();
      if (!listingSnap.exists) continue;
      
      var listingData = listingSnap.data() as Map<String, dynamic>;
      bool? isVolunteerAvailable = listingData['isVolunteerAvailable'] as bool?;
      
      if (isVolunteerAvailable == true) {
        continue; // The NGO has their own volunteer, so skip this card!
      }
      
      String type = listingData['type'] ?? 'food';
      String itemName = type == 'food' ? (listingData['foodType'] ?? "Food") : (listingData['productName'] ?? "Product");

      // ==========================================================
      // 👇 NEW: EXPIRY & URGENT NOTIFICATION LOGIC 👇
      // ==========================================================
      Timestamp? liveUntilTs = listingData['liveUntil'] as Timestamp?;
      DateTime liveUntil = liveUntilTs != null ? liveUntilTs.toDate() : DateTime.now().add(const Duration(days: 365));
      DateTime now = DateTime.now();

      if (status == 'pending') {
        if (now.isAfter(liveUntil)) {
          // ❌ TASK HAS EXPIRED: Run cleanup and skip building the card
          _handleExpiredTask(donationId, donorId, listingData['ngold'] ?? listingData['ngoId'] ?? '', itemName);
          continue; 
        } else {
          // 🚨 URGENT NOTIFICATION: Less than 24 hours remaining
          bool urgentNotified = donationData['urgentNotified'] == true;
          if (!urgentNotified && liveUntil.difference(now).inHours <= 24) {
            _triggerUrgentVolunteerNotification(donationId, itemName, listingData['ngoLocation'] ?? 'your area');
          }
        }
      }
      // ==========================================================
      
      // Pulling the exact donated amount directly from the Donation Document
      String rawDonatedQty = donationData['donatedQuantity']?.toString() ?? 
                             donationData['quantity']?.toString() ?? 
                             donationData['donatedAmount']?.toString() ?? '';
                             
      String unitVal = listingData['unit']?.toString() ?? '';
      String quantity = rawDonatedQty.isEmpty ? '1 Item' : '$rawDonatedQty $unitVal'.trim();

      String availability = listingData['availability'] ?? 'Time not specified';
      String ngoName = listingData['ngoName'] ?? 'Unknown NGO';
      String ngoLocation = listingData['ngoLocation'] ?? 'Location unavailable';
      String ngoId = listingData['ngoId'] ?? listingData['ngold'] ?? '';
      
      // Fetch NGO Phone
      String ngoPhone = 'Phone unavailable';
      var ngoUserSnap = await FirebaseFirestore.instance.collection('users').doc(ngoId).get();
      if (ngoUserSnap.exists) {
        var ngoUserData = ngoUserSnap.data() as Map<String, dynamic>;
        ngoPhone = ngoUserData['phone'] ?? 'Phone unavailable';
      }

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
          isAcceptedByMe: isAcceptedByMe,
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
                  .where('status', whereIn: ['pending', 'delivery_accepted'])
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
                
                // 👇 This is where the magic happens! We wait for the cards to be fully built and checked
                return FutureBuilder<List<Widget>>(
                  future: _generateFilteredCards(donations, user.uid),
                  builder: (context, cardSnapshot) {
                    if (cardSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: themeColor));
                    }
                    
                    // If the list comes back completely empty, show the message!
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
    required bool isAcceptedByMe,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18), // Slightly more breathing room
      decoration: BoxDecoration(
        // 👇 Premium gradient background fading into a faint dusky rose 👇
        gradient: LinearGradient(
          colors: [
            Colors.white,
            themeColor.withValues(alpha: 0.04), // Faint dusky rose tint
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20), // Rounder edges look more modern
        // 👇 Crisp, neat border to frame the card 👇
        border: Border.all(
          color: themeColor.withValues(alpha: 0.2), 
          width: 1.5,
        ),
        boxShadow: [
          // 👇 Soft glowing shadow using the theme color instead of harsh black 👇
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
                    color: isAcceptedByMe ? Colors.green.shade50 : themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isAcceptedByMe ? Colors.green.shade200 : Colors.transparent),
                  ),
                  child: Text(
                    isAcceptedByMe ? "Task Accepted" : "Pickup Needed",
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: isAcceptedByMe ? Colors.green.shade700 : themeColor,
                    ),
                  ),
                ),
                Text(
                  quantity, 
                  style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              itemName, 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
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
                          "PICKUP FROM", 
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
                  // 👇 Hooks into the new Confirmation Dialog 👇
                  onPressed: () => _confirmAndAcceptTask(context, donationId, myId, donorId, ngoId, itemName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Accept Task", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              )
            else
              Column(
                children: [
                 // 👇 NEW: Mark as Completed Button with Popup (Dashboard) 👇
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                         // 👇 1. Show Confirmation Dialog 👇
                         bool confirm = await showDialog(
                           context: context,
                           builder: (ctx) => AlertDialog(
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                             title: Row(
                               children: [
                                 Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 24),
                                 const SizedBox(width: 8),
                                 Text("Confirm Delivery", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 20)),
                               ],
                             ),
                             content: const Text(
                               "Have you successfully delivered the item(s) from the donor to the NGO?\n\nPlease only confirm if the handover is fully complete. If there is a delay, use the chat to inform them.",
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
                                 child: const Text("Yes, Completed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                               ),
                             ],
                           ),
                         ) ?? false;

                         // If they clicked cancel, stop here!
                         if (!confirm) return; 

                         // 👇 2. Proceed with existing completion logic 👇
                         await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
                            'status': 'delivery_completed'
                         });
                         
                         final authProvider = Provider.of<AuthProvider>(context, listen: false);
                         final currentUserId = authProvider.currentFirebaseUser?.uid;
                         final currentUserName = authProvider.currentUserModel?.name ?? 'Volunteer';

                         if (currentUserId != null) {
                           await FirebaseFirestore.instance.collection('users').doc(currentUserId).set({
                             'deliveriesCompleted': FieldValue.increment(1)
                           }, SetOptions(merge: true));
                         }

                         if (donorId.isNotEmpty && listingId.isNotEmpty) {
                           var requestQuery = await FirebaseFirestore.instance
                               .collection('volunteer_requests')
                               .where('donorId', isEqualTo: donorId)
                               .where('listingId', isEqualTo: listingId)
                               .limit(1)
                               .get();

                           if (requestQuery.docs.isNotEmpty) {
                             await FirebaseFirestore.instance
                                 .collection('volunteer_requests')
                                 .doc(requestQuery.docs.first.id)
                                 .update({
                                   'status': 'completed', 
                                   'assignedVolunteer': currentUserName, 
                                 });
                           }
                         }

                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                             content: Text('Delivery marked as completed!'),
                             backgroundColor: Colors.green,
                           ));
                         }
                      },
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      label: const Text(
                        "Mark Delivery as Completed",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600, 
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // 👇 NEW: Chat Buttons Side-By-Side (Bottom) 👇
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