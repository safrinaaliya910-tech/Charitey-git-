import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ngo_listing_model.dart';
import '../models/donation_model.dart';
import '../models/volunteer_request_model.dart';
import '../models/notification_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // --- NGO LISTINGS LOGIC ---
  // ==========================================

  // Create NGO Listing
  Future<void> createNgoListing(NgoListingModel listing) async {
    try {
      await _firestore
          .collection('ngo_listings')
          .doc(listing.listingId)
          .set(listing.toMap());
    } catch (e) {
      print('Error creating listing: $e');
      rethrow;
    }
  }

  // Get Open NGO Listings Stream
  Stream<List<NgoListingModel>> getOpenListingsStream() {
    return _firestore
        .collection('ngo_listings')
        .where('status', isEqualTo: 'open') // Optimized to only stream available listings
        .snapshots()
        .map((snapshot) {
          print("Documents Found: ${snapshot.docs.length}");
          return snapshot.docs
              .map((doc) => NgoListingModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Get NGO Listings Stream (for specific NGO)
  Stream<List<NgoListingModel>> getNgoListingsStream(String ngoId) {
    return _firestore
        .collection('ngo_listings')
        .where('ngoId', isEqualTo: ngoId)
        // Order handled via client runtime below to fully protect against composite index crash rules
        .snapshots()
        .map((snapshot) {
          print("NGO LISTINGS COUNT: ${snapshot.docs.length}");
          var docs = snapshot.docs
              .map((doc) => NgoListingModel.fromMap(doc.data(), doc.id))
              .toList();
          
          // Client side descending date ordering
          docs.sort((a, b) {
            final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
          
          return docs;
        });
  }

  // Update NGO Listing status
  Future<void> updateListingStatus(String listingId, String newStatus) async {
    try {
      await _firestore.collection('ngo_listings').doc(listingId).update({
        'status': newStatus,
      });
    } catch (e) {
      print('Error updating listing status: $e');
      rethrow;
    }
  }

  // ==========================================
  // --- DONATIONS LOGIC ---
  // ==========================================

  // Process Donation (Transactional: Create donation, update listing quantities/status, create volunteer request, and notify NGO)
  Future<void> processDonation({
    required DonationModel donation,
    required NotificationModel notification,
  }) async { 
    try {
      // One single comprehensive transaction handles all data interactions securely
      await _firestore.runTransaction((transaction) async { 
        // Document References
        DocumentReference listingRef = _firestore.collection('ngo_listings').doc(donation.listingId); 
        DocumentReference donationRef = _firestore.collection('donations').doc(donation.donationId); 
        DocumentReference notificationRef = _firestore.collection('notifications').doc(notification.id); 

        // a. Read listing state within the safe window
        DocumentSnapshot listingSnapshot = await transaction.get(listingRef); 
        if (!listingSnapshot.exists) { 
          throw Exception("Listing does not exist!"); 
        }

        final data = listingSnapshot.data() as Map<String, dynamic>;
        
        // Safe extraction of status to prevent missing property errors
        String currentStatus = data['status'] ?? 'open'; 
        if (currentStatus == 'closed') { 
          throw Exception("This request has already been fulfilled."); 
        }

        // b. Calculate fulfillment quantities handling safe num -> int evaluations
        final int currentFulfilled = (data['fulfilledQuantity'] as num? ?? 0).toInt();
        final int targetQuantity = (data['quantity'] as num? ?? 0).toInt();
        final int remainingNow = targetQuantity - currentFulfilled;

        // Verify that another concurrent user hasn't fulfilled this listing mid-process
        if (donation.donatedQuantity > remainingNow) {
          throw Exception("Only $remainingNow item(s) are still needed.");
        }

        final int newFulfilled = currentFulfilled + donation.donatedQuantity;
        String newStatus = 'open';
        if (newFulfilled >= targetQuantity) {
          newStatus = 'closed';
        }

        // c. Write: Apply balance modification updates safely to the listing document
        transaction.update(listingRef, {
          'fulfilledQuantity': newFulfilled,
          'status': newStatus,
        });

        // d. Write: Create donation record
        transaction.set(donationRef, donation.toMap()); 

        // e. Write: Auto-create a volunteer request for this donation
       DocumentReference volunteerRequestRef = FirebaseFirestore.instance.collection('volunteer_requests').doc();
        
        // Safely extract item name and unit from the listing data
        String itemName = data['type'] == 'food' || data['type'] == 'FOOD'
            ? (data['foodType'] ?? 'Food') 
            : (data['productName'] ?? 'Product');
        String unit = data['unit'] ?? '';
        
        VolunteerRequestModel vRequest = VolunteerRequestModel(
          requestId: volunteerRequestRef.id,
          ngoId: donation.ngoId,           // FIXED: Changed from ngold to ngoId
          ngoName: data['ngoName'] ?? 'Unknown NGO', 
          donorId: donation.donorId,   
          donorName: donation.donorName, 
          listingId: donation.listingId,
          itemName: itemName,
          quantity: "${donation.donatedQuantity} $unit".trim(), // FIXED: Changed from quantity/donatedAmount to donatedQuantity
          status: 'pending',
          createdAt: DateTime.now(),
        );

        transaction.set(volunteerRequestRef, vRequest.toMap()); // Make sure this matches your variable name (vRequest)

        // f. Write: Create notification record inside the transaction execution block
        transaction.set(notificationRef, notification.toMap()); 
      });
    } catch (e) { 
      print('Error processing transactional donation: $e'); 
      rethrow; 
    }
  }

  // Get user donations
  Stream<List<DonationModel>> getUserDonationsStream(String donorId) {
    return _firestore
        .collection('donations')
        .where('donorId', isEqualTo: donorId)
        // Query composite index safety optimization fallback applied below
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs
              .map((doc) => DonationModel.fromMap(doc.data(), doc.id))
              .toList();

          // Client side sorting fallback avoids configuration crash blocks completely
          docs.sort((a, b) {
            final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });

          return docs;
        });
  }

  // ==========================================
  // --- IN-APP NOTIFICATION LOGIC ---
  // ==========================================

  // Send a standalone notification to the database (fallback/external usage)
  Future<void> sendNotification(NotificationModel notification) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  // Listen for new notifications for a specific user (NGO)
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          // Convert raw map data to models
          var docs = snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();

          // Sort manually in client-side runtime to avoid Firestore index generation errors
          docs.sort((a, b) {
            final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });

          return docs;
        });
  }

  // Mark a notification as read when clicked
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  // ==========================================
  // --- ⚙️ NEW: LAZY EXPIRATION CLEANUP ENGINE ---
  // ==========================================

  // This automatically runs in the background when the NGO opens the app
  Future<void> cleanUpExpiredRequests(String currentNgoId) async {
    try {
      // 1. Get all 'open' requests for this specific NGO
      QuerySnapshot openRequests = await _firestore
          .collection('ngo_listings')
          .where('ngoId', isEqualTo: currentNgoId)
          .where('status', isEqualTo: 'open')
          .get();

      for (var doc in openRequests.docs) {
        var data = doc.data() as Map<String, dynamic>;
        
        // Safely extract the expiration date
        Timestamp? liveUntilTimestamp = data['liveUntil'] as Timestamp?;
        if (liveUntilTimestamp == null) continue;
        
        DateTime liveUntil = liveUntilTimestamp.toDate();
        
        // 2. Check if the deadline has passed compared to RIGHT NOW
        if (liveUntil.isBefore(DateTime.now())) {
          int totalQty = (data['quantity'] as num?)?.toInt() ?? 0;
          int fulfilledQty = (data['fulfilledQuantity'] as num?)?.toInt() ?? 0;
          
          // Math Check: Calculate Pending Quantity
          int pendingQty = totalQty - fulfilledQty;

          // 3. Close the listing by updating its status to 'expired'
          await _firestore
              .collection('ngo_listings')
              .doc(doc.id)
              .update({'status': 'expired'});

          // 4. Send Notification ONLY if there are pending items left to donate
          if (pendingQty > 0) {
            String itemName = data['type'] == 'food' 
                ? (data['foodType'] ?? 'Food items') 
                : (data['productName'] ?? 'Products');
                
            String message = "Your requested time is out. Out of $totalQty $itemName, $pendingQty are still pending. Please create a new request.";

            String notifId = _firestore.collection('notifications').doc().id;
            
            NotificationModel expiredNotif = NotificationModel(
              id: notifId,
              receiverId: currentNgoId,
              senderId: 'system',
              senderName: 'System Alert',
              type: 'expired_request',
              title: 'Request Expired',
              message: message,
              relatedItemId: doc.id,
              createdAt: DateTime.now(),
            );

            // Push notification to the database safely
            await _firestore
                .collection('notifications')
                .doc(notifId)
                .set(expiredNotif.toMap());
          }
        }
      }
    } catch (e) {
      print("Error running lazy cleanup: $e");
    }
  }
  
  // ==========================================
  // --- FEEDBACK LOGIC ---
  // ==========================================
  
  // Save user feedback to the database for the Admin Panel
  Future<void> submitFeedback(Map<String, dynamic> feedbackData) async {
    try {
      // Creates a new collection called 'feedbacks'
      await _firestore.collection('feedbacks').add(feedbackData);
    } catch (e) {
      print("Error submitting feedback: $e");
      rethrow;
    }
  }
}