import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/notification_model.dart';
import 'rating_dialog.dart';

class VolunteerPaymentScreen extends StatefulWidget {
  final String donationId;
  const VolunteerPaymentScreen({super.key, required this.donationId});

  @override
  State<VolunteerPaymentScreen> createState() => _VolunteerPaymentScreenState();
}

class _VolunteerPaymentScreenState extends State<VolunteerPaymentScreen> {
  final Color themeColor = const Color(0xFF7D444C);
  bool _isLoading = true;
  bool _hasAttemptedPayment = false;
  bool _isWaitingForVolunteer = false;

  double _feeAmount = 0.0;
  String _volunteerId = "";
  String _volunteerName = "";
  String _volunteerUpi = "";
  String _itemName = "Delivery Item";

  StreamSubscription<DocumentSnapshot>? _donationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchInitialDetails();
    _listenToDonationStatus();
  }

  Future<void> _fetchInitialDetails() async {
    try {
      var donSnap = await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).get();
      if (!donSnap.exists) return;
      
      var donData = donSnap.data() as Map<String, dynamic>;
      _feeAmount = (donData['deliveryFee'] as num?)?.toDouble() ?? 35.0;
      _volunteerId = donData['assignedVolunteerId'] ?? '';
      _itemName = donData['items'] ?? donData['itemName'] ?? 'Delivery Item';

      if (_volunteerId.isNotEmpty) {
        var volSnap = await FirebaseFirestore.instance.collection('users').doc(_volunteerId).get();
        if (volSnap.exists) {
          var volData = volSnap.data() as Map<String, dynamic>;
          _volunteerName = volData['name'] ?? 'Volunteer';
          _volunteerUpi = volData['upiId'] ?? '';
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 👇 REAL-TIME LISTENER: Automatically unlocks when Volunteer approves 👇
  void _listenToDonationStatus() {
    _donationSubscription = FirebaseFirestore.instance
        .collection('donations')
        .doc(widget.donationId)
        .snapshots()
        .listen((snap) {
      if (snap.exists && mounted) {
        var data = snap.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';

        if (status == 'fully_completed') {
          // Volunteer clicked YES! Unlock and show rating!
          _donationSubscription?.cancel();
          Navigator.pop(context); // Close the lock screen
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => RatingDialog(
              volunteerId: _volunteerId,
              volunteerName: _volunteerName,
              donationId: widget.donationId,
            ),
          );
        } else if (status == 'payment_verification_pending') {
          setState(() => _isWaitingForVolunteer = true);
        } else if (status == 'completed_awaiting_payment') {
          // Volunteer clicked NO. Reset back to payment buttons.
          setState(() {
            _isWaitingForVolunteer = false;
            _hasAttemptedPayment = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _donationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _launchUPI() async {
    if (_volunteerUpi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Volunteer has not set a UPI ID. You can skip payment.'), backgroundColor: Colors.orange),
      );
      setState(() => _hasAttemptedPayment = true);
      return;
    }

    String safeName = Uri.encodeComponent(_volunteerName);
    String safeNote = Uri.encodeComponent("Charitey Delivery Fee");
    String upiUrl = "upi://pay?pa=${_volunteerUpi.trim()}&pn=$safeName&am=$_feeAmount&cu=INR&tn=$safeNote";

    try {
      bool launched = await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
      if (!launched) throw Exception("Could not launch");
      setState(() => _hasAttemptedPayment = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI App found. Please check your apps.'), backgroundColor: Colors.red),
      );
      setState(() => _hasAttemptedPayment = true); 
    }
  }

  // 👇 NOTIFIES VOLUNTEER FOR VERIFICATION INSTEAD OF UNLOCKING 👇
  Future<void> _notifyVolunteerForVerification() async {
    setState(() => _isWaitingForVolunteer = true);
    
    try {
      await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
        'status': 'payment_verification_pending',
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUserModel!;

      String notifId = FirebaseFirestore.instance.collection('notifications').doc().id;
      NotificationModel notif = NotificationModel(
        id: notifId,
        receiverId: _volunteerId,
        senderId: currentUser.uid,
        senderName: currentUser.name,
        type: 'verify_payment',
        title: 'Payment Verification Required',
        message: 'Donor ${currentUser.name} says they have paid the ₹${_feeAmount.toStringAsFixed(0)} delivery fee for $_itemName. Please confirm if you received it.',
        relatedItemId: widget.donationId,
        createdAt: DateTime.now(),
        isRead: false,
      );
      await FirestoreService().sendNotification(notif);

    } catch (e) {
      setState(() => _isWaitingForVolunteer = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error contacting volunteer. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: themeColor)));
    }

    return PopScope(
      canPop: false, 
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.5),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _isWaitingForVolunteer ? Colors.blue.shade50 : Colors.red.shade50, 
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    _isWaitingForVolunteer ? Icons.hourglass_top_rounded : Icons.lock_rounded, 
                    color: _isWaitingForVolunteer ? Colors.blue : Colors.red, 
                    size: 36
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isWaitingForVolunteer ? "Awaiting Verification" : "Action Required",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  _isWaitingForVolunteer 
                      ? "We have notified $_volunteerName. \nYour screen will unlock automatically the moment they confirm receipt."
                      : "Your delivery has been safely completed by $_volunteerName!\n\nPlease clear the delivery fee to unlock full access.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 24),
                
                if (!_isWaitingForVolunteer) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Delivery Fee Due:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text("₹${_feeAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_hasAttemptedPayment) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _launchUPI,
                        icon: const Icon(Icons.payment_rounded, color: Colors.white),
                        label: Text("Pay ₹${_feeAmount.toStringAsFixed(0)} via UPI", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text("Did the payment succeed?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _notifyVolunteerForVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Yes, Payment Completed", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _hasAttemptedPayment = false),
                      child: const Text("No, let me try again", style: TextStyle(color: Colors.redAccent)),
                    )
                  ]
                ] else ...[
                  // Showing waiting spinner
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: CircularProgressIndicator(color: Colors.blue),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}