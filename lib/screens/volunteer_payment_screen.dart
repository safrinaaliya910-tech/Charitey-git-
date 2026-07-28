import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // 👇 NEW: tracks whether this donation was already paid before this screen opened.
  // This is what prevents the "payment already done but screen opens again" bug,
  // no matter which entry point (home screen listener OR notification tap) opened it.
  bool _alreadyPaid = false;

  double _feeAmount = 0.0;
  String _volunteerId = "";
  String _volunteerName = "";
  String _volunteerUpi = "";

  @override
  void initState() {
    super.initState();
    _fetchPaymentDetails();
  }

  Future<void> _fetchPaymentDetails() async {
    try {
      // 1. Fetch Donation Doc
      var donSnap = await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).get();
      if (!donSnap.exists) {
        setState(() => _isLoading = false);
        return;
      }

      var donData = donSnap.data() as Map<String, dynamic>;

      // 👇 NEW: Check current status BEFORE showing the "pay now" UI.
      // If it's already fully_completed / paid, we don't need fee or volunteer
      // details at all — we just flag it and bail out early.
      final String status = donData['status'] ?? '';
      final String paymentStatus = donData['paymentStatus'] ?? '';
      if (status == 'fully_completed' || paymentStatus == 'paid') {
        _alreadyPaid = true;
        setState(() => _isLoading = false);
        return;
      }

      _feeAmount = (donData['deliveryFee'] as num?)?.toDouble() ?? 35.0;
      _volunteerId = donData['assignedVolunteerId'] ?? '';

      // 2. Fetch Volunteer Doc for UPI ID
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

  Future<void> _launchUPI() async {
    if (_volunteerUpi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Volunteer has not set a UPI ID. You can skip payment.'), backgroundColor: Colors.orange),
      );
      setState(() => _hasAttemptedPayment = true);
      return;
    }

    // Safely encode spaces so the URL doesn't break
    String safeName = Uri.encodeComponent(_volunteerName);
    String safeNote = Uri.encodeComponent("Charitey Delivery Fee");

    String upiUrl = "upi://pay?pa=${_volunteerUpi.trim()}&pn=$safeName&am=$_feeAmount&cu=INR&tn=$safeNote";

    try {
      bool launched = await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
      if (!launched) throw Exception("Could not launch");

      // Update UI to show confirmation buttons after they return from UPI app
      setState(() => _hasAttemptedPayment = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI App found (GPay, PhonePe, etc.)'), backgroundColor: Colors.red),
      );
      setState(() => _hasAttemptedPayment = true); // Let them manually bypass if it breaks
    }
  }

  Future<void> _confirmPaymentComplete() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: themeColor)),
    );

    try {
      await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
        'status': 'fully_completed',
        'paymentStatus': 'paid',
      });

      // 👇 NEW: Mark any existing "payment_pending" notifications for this donation
      // as read, so they don't keep sitting in the notification list as an
      // actionable item after payment is already done.
      try {
        final notifSnap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('relatedItemId', isEqualTo: widget.donationId)
            .where('type', isEqualTo: 'payment_pending')
            .get();
        for (var doc in notifSnap.docs) {
          await doc.reference.update({'isRead': true});
        }
      } catch (_) {
        // Non-critical cleanup — ignore failures here so it never blocks payment flow.
      }

      if (!mounted) return;
      Navigator.pop(context); // close loader
      Navigator.pop(context); // close payment screen

      // Open Rating Dialog instantly after payment screen closes
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => RatingDialog(
          volunteerId: _volunteerId,
          volunteerName: _volunteerName,
          donationId: widget.donationId,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error updating payment.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: themeColor)));
    }

    // 👇 NEW: If this donation was already paid before this screen even opened,
    // don't show the lock/payment UI at all. Just notify and pop back out.
    // This is the fix for: home screen already showed payment -> user paid ->
    // user then taps the old notification -> screen would reopen asking to pay again.
    if (_alreadyPaid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This delivery fee is already paid ✅'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      });
      return const Scaffold(backgroundColor: Colors.white, body: SizedBox.shrink());
    }

    return PopScope(
      canPop: false, // Prevent swiping back
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF7F8),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text("Pending Payment", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_rounded, color: Colors.red, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Action Required",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your delivery has been safely completed by $_volunteerName!\n\nPlease clear the delivery fee to unlock full access.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 24),
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
                  // Shows AFTER they click the UPI button and return to the app
                  const Text("Did the payment succeed?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _confirmPaymentComplete,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}