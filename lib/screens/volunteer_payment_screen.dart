import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  // 👇 NEW: unique transaction reference generated once per screen load,
  // so the QR and the "Open UPI App" fallback both point to the same
  // payment attempt instead of generating a new tr= each rebuild.
  late final String _txnRef;

  // 👇 NEW: key used to capture the QR code widget as an image for download.
  final GlobalKey _qrKey = GlobalKey();

  StreamSubscription<DocumentSnapshot>? _donationSubscription;

  @override
  void initState() {
    super.initState();
    _txnRef = DateTime.now().millisecondsSinceEpoch.toString();
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

  // 👇 NEW: single source of truth for the UPI URI, used by both the QR
  // code and the "Open UPI App" fallback button. am is fixed to 2 decimals
  // and a stable tr= reference is included, both of which reduce false
  // "risky payment" rejections in GPay/PhonePe/Paytm fraud checks.
  String _buildUpiUri() {
    String safeName = Uri.encodeComponent(_volunteerName);
    String safeNote = Uri.encodeComponent("Fourth Idly Delivery Fee");
    return "upi://pay?pa=${_volunteerUpi.trim()}&pn=$safeName&am=${_feeAmount.toStringAsFixed(2)}&cu=INR&tn=$safeNote&tr=$_txnRef";
  }

  Future<void> _launchUPI() async {
    if (_volunteerUpi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Volunteer has not set a UPI ID. You can skip payment.'), backgroundColor: Colors.orange),
      );
      setState(() => _hasAttemptedPayment = true);
      return;
    }

    try {
      bool launched = await launchUrl(Uri.parse(_buildUpiUri()), mode: LaunchMode.externalApplication);
      if (!launched) throw Exception("Could not launch");
      setState(() => _hasAttemptedPayment = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI App found. Please check your apps.'), backgroundColor: Colors.red),
      );
      setState(() => _hasAttemptedPayment = true);
    }
  }

  // 👇 NEW: captures the QR code widget as a PNG image and hands it to the
  // OS share sheet so the donor can save it to their gallery/files or open
  // it directly in any UPI/scanner app.
  Future<void> _downloadQrCode() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/upi_qr_$_txnRef.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR to pay ₹${_feeAmount.toStringAsFixed(0)} via UPI',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save QR code. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  // 👇 NEW: donor confirms manually after scanning the QR with their own
  // phone. There's no app-launch callback for a scan, so this is how the
  // QR path feeds into the same "Did the payment succeed?" step below.
  void _confirmQrPaymentAttempted() {
    setState(() => _hasAttemptedPayment = true);
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
            constraints: const BoxConstraints(maxHeight: 640),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _isWaitingForVolunteer ? Colors.blue.shade50 : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isWaitingForVolunteer ? Icons.hourglass_top_rounded : Icons.lock_rounded,
                      color: _isWaitingForVolunteer ? Colors.blue : Colors.red,
                      size: 36,
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
                      // 👇 QR is the primary payment path.
                      if (_volunteerUpi.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              RepaintBoundary(
                                key: _qrKey,
                                child: QrImageView(
                                  data: _buildUpiUri(),
                                  version: QrVersions.auto,
                                  size: 190,
                                  gapless: false,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Scan with any UPI app to pay ₹${_feeAmount.toStringAsFixed(0)}",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              // 👇 NEW: lets donors know a screenshot works just as well
                              // as downloading the QR, especially for same-device payments.
                              Text(
                                "You can also take a screenshot and pay",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 👇 NEW: replaces the old Copy ID / Open UPI App row.
                        // Captures the QR as an image and hands it to the OS share
                        // sheet so the donor can save it or open it in any app.
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _downloadQrCode,
                            icon: Icon(Icons.download_rounded, size: 18, color: themeColor),
                            label: Text("Download QR Code", style: TextStyle(color: themeColor, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: themeColor.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _confirmQrPaymentAttempted,
                            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                            label: const Text("I've Paid via QR", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ] else ...[
                        // No UPI ID on file at all — same behavior as before.
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
                      ],
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
      ),
    );
  }
}