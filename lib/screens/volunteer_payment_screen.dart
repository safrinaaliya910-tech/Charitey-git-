import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/notification_model.dart';
import 'rating_dialog.dart';
import 'package:gal/gal.dart';

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
  bool _isAdminReview = false;

  double _feeAmount = 0.0;
  String _volunteerId = "";
  String _volunteerName = "";
  String _volunteerUpi = "";
  String _itemName = "Delivery Item";

  late final String _txnRef;
  final TextEditingController _refController = TextEditingController();

  StreamSubscription<DocumentSnapshot>? _donationSubscription;

  @override
  void initState() {
    super.initState();
    // Keep tr short & alphanumeric (some UPI apps reject long / special refs)
    _txnRef = DateTime.now().millisecondsSinceEpoch.toString();
    _fetchInitialDetails();
    _listenToDonationStatus();
  }

  Future<void> _fetchInitialDetails() async {
    try {
      var donSnap = await FirebaseFirestore.instance
          .collection('donations')
          .doc(widget.donationId)
          .get();
      if (!donSnap.exists) return;

      var donData = donSnap.data() as Map<String, dynamic>;
      _feeAmount = (donData['deliveryFee'] as num?)?.toDouble() ?? 35.0;
      _volunteerId = donData['assignedVolunteerId'] ?? '';
      _itemName = donData['items'] ?? donData['itemName'] ?? 'Delivery Item';

      if (_volunteerId.isNotEmpty) {
        var volSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(_volunteerId)
            .get();
        if (volSnap.exists) {
          var volData = volSnap.data() as Map<String, dynamic>;
          _volunteerName = (volData['name'] ?? 'Volunteer').toString().trim();
          // Critical: clean UPI exactly like profile setup stores it
          _volunteerUpi = (volData['upiId'] ?? '')
              .toString()
              .trim()
              .toLowerCase()
              .replaceAll(' ', '');
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

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
          _donationSubscription?.cancel();
          Navigator.pop(context);
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
          setState(() {
            _isWaitingForVolunteer = true;
            _isAdminReview = false;
          });
        } else if (status == 'admin_verification_pending') {
          setState(() {
            _isWaitingForVolunteer = true;
            _isAdminReview = true;
          });
        } else if (status == 'completed_awaiting_payment') {
          setState(() {
            _isWaitingForVolunteer = false;
            _hasAttemptedPayment = false;
            _isAdminReview = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _donationSubscription?.cancel();
    _refController.dispose();
    super.dispose();
  }

  /// NPCI-compliant UPI deep-link (same style as profile-setup preview).
  /// Uses Uri.queryParameters so encoding is correct and consistent.
  String _buildUpiUri() {
    final pa = _volunteerUpi.trim().toLowerCase().replaceAll(' ', '');
    final pn = _volunteerName.trim().isEmpty ? 'Volunteer' : _volunteerName.trim();
    final am = _feeAmount.toStringAsFixed(2); // e.g. 1450.00
    final tn = 'Fourth Idly Delivery Fee';

    // Build with Uri so special chars in name/note are encoded once, correctly.
    // Omit 'tr' — some apps (esp. GPay) are picky; pa+pn+am+cu+tn is enough for P2P.
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': pa,
        'pn': pn,
        'am': am,
        'cu': 'INR',
        'tn': tn,
      },
    );
    return uri.toString();
  }

  bool get _isUpiValid {
    final upi = _volunteerUpi.trim().toLowerCase();
    final re = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    return re.hasMatch(upi);
  }

  Future<void> _launchUPI() async {
    if (!_isUpiValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Volunteer has not set a valid UPI ID. You can skip payment.'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _hasAttemptedPayment = true);
      return;
    }

    try {
      final launched = await launchUrl(
        Uri.parse(_buildUpiUri()),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('Could not launch');
      setState(() => _hasAttemptedPayment = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI App found. Please check your apps.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _hasAttemptedPayment = true);
    }
  }

  Future<Uint8List> _generateQrPngBytes() async {
    final painter = QrPainter(
      data: _buildUpiUri(),
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );

    final ui.Image image = await painter.toImage(1024);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to create QR image');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _downloadQrCode() async {
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gallery permission is required to save the QR code.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      final Uint8List pngBytes = await _generateQrPngBytes();

      await Gal.putImageBytes(
        pngBytes,
        name: 'FourthIdly_UPI_QR_$_txnRef',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code saved to your gallery ✓'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmQrPaymentAttempted() {
    setState(() => _hasAttemptedPayment = true);
  }

  Future<void> _notifyVolunteerForVerification() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the Transaction / UPI Reference ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isWaitingForVolunteer = true);

    try {
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(widget.donationId)
          .update({
        'status': 'payment_verification_pending',
        'paymentReference': ref,
        'paymentSubmittedAt': FieldValue.serverTimestamp(),
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUserModel!;

      String notifId =
          FirebaseFirestore.instance.collection('notifications').doc().id;
      NotificationModel notif = NotificationModel(
        id: notifId,
        receiverId: _volunteerId,
        senderId: currentUser.uid,
        senderName: currentUser.name,
        type: 'verify_payment',
        title: 'Payment Verification Required',
        message:
            'Donor ${currentUser.name} says they have paid ₹${_feeAmount.toStringAsFixed(0)} for $_itemName.\n\nReference ID: $ref\n\nPlease confirm if you received it.',
        relatedItemId: widget.donationId,
        createdAt: DateTime.now(),
        isRead: false,
      );
      await FirestoreService().sendNotification(notif);
    } catch (e) {
      setState(() => _isWaitingForVolunteer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error contacting volunteer. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: themeColor)),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.5),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            constraints: const BoxConstraints(maxHeight: 680),
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
                      color: _isAdminReview
                          ? Colors.orange.shade50
                          : (_isWaitingForVolunteer
                              ? Colors.blue.shade50
                              : Colors.red.shade50),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isAdminReview
                          ? Icons.support_agent_rounded
                          : (_isWaitingForVolunteer
                              ? Icons.hourglass_top_rounded
                              : Icons.lock_rounded),
                      color: _isAdminReview
                          ? Colors.orange
                          : (_isWaitingForVolunteer ? Colors.blue : Colors.red),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isAdminReview
                        ? "Admin is Reviewing"
                        : (_isWaitingForVolunteer
                            ? "Awaiting Verification"
                            : "Action Required"),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isAdminReview
                        ? "The volunteer reported they did not receive the payment.\n\nOur admin team is verifying the transaction using your Reference ID.\nYou will be notified once they unlock your screen."
                        : (_isWaitingForVolunteer
                            ? "We have notified $_volunteerName.\nYour screen will unlock automatically the moment they confirm receipt."
                            : "Your delivery has been safely completed by $_volunteerName!\n\nPlease clear the delivery fee to unlock full access."),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
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
                          const Text(
                            "Delivery Fee Due:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "₹${_feeAmount.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (!_hasAttemptedPayment) ...[
                      if (_isUpiValid) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              QrImageView(
                                data: _buildUpiUri(),
                                version: QrVersions.auto,
                                size: 190,
                                gapless: true,
                                backgroundColor: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Scan with any UPI app to pay ₹${_feeAmount.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Show UPI so donor can verify payee
                              Text(
                                _volunteerUpi,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Payee: $_volunteerName",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "You can also take a screenshot and pay",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _downloadQrCode,
                            icon: Icon(Icons.download_rounded,
                                size: 18, color: themeColor),
                            label: Text(
                              "Download QR Code",
                              style: TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: themeColor.withOpacity(0.5)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _confirmQrPaymentAttempted,
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: const Text(
                              "I've Paid via QR",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Invalid / missing UPI
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            _volunteerUpi.isEmpty
                                ? "Volunteer has not set a UPI ID yet."
                                : "Volunteer UPI ID looks invalid: $_volunteerUpi",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _launchUPI,
                            icon: const Icon(Icons.payment_rounded,
                                color: Colors.white),
                            label: Text(
                              "Pay ₹${_feeAmount.toStringAsFixed(0)} via UPI",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      const Text(
                        "Did the payment succeed?",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _refController,
                        decoration: InputDecoration(
                          labelText: "Transaction / UPI Reference ID *",
                          hintText: "Enter the 12-digit reference number",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.receipt_long_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _notifyVolunteerForVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Yes, Payment Completed",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            setState(() => _hasAttemptedPayment = false),
                        child: const Text(
                          "No, let me try again",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      )
                    ]
                  ] else ...[
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