//screens/payment_verification_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaymentVerificationScreen extends StatefulWidget {
  final String donationId;

  const PaymentVerificationScreen({super.key, required this.donationId});

  @override
  State<PaymentVerificationScreen> createState() =>
      _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  bool _busy = false;

  Future<Map<String, dynamic>?> _loadDonation() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('donations')
        .doc(widget.donationId)
        .get();
    return snapshot.data();
  }

  Future<void> _updatePayment(
      Map<String, dynamic> donation, bool received) async {
    if (_busy) return;
    setState(() => _busy = true);
    final donorId = (donation['donorId'] ?? '').toString();
    try {
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(widget.donationId)
          .update({
        'status': received ? 'fully_completed' : 'admin_verification_pending',
        'paymentStatus': received ? 'paid' : 'disputed',
        if (!received) 'paymentDisputedAt': FieldValue.serverTimestamp(),
      });

      if (donorId.isNotEmpty) {
        final notificationRef =
            FirebaseFirestore.instance.collection('notifications').doc();
        await notificationRef.set({
          'id': notificationRef.id,
          'receiverId': donorId,
          'senderId': FirebaseAuth.instance.currentUser?.uid ?? 'system',
          'senderName': 'Volunteer',
          'type': received ? 'payment_verified' : 'payment_rejected',
          'title':
              received ? 'Payment Verified!' : 'Payment Under Admin Review',
          'message': received
              ? 'Thank you! The volunteer confirmed receipt of your delivery fee.'
              : 'The volunteer reported they did not receive your payment. Our admin team is reviewing the transaction.',
          'relatedItemId': widget.donationId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(received
                  ? 'Payment verified.'
                  : 'Payment sent for admin review.')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Payment')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadDonation(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final donation = snapshot.data;
          if (donation == null) {
            return const Center(
                child: Text('Donation details are no longer available.'));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Confirm the delivery fee payment for this donation.',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(
                  'Payment reference: ${(donation['paymentReference'] ?? 'Not provided').toString()}'),
              Text('Amount: ₹${(donation['deliveryFee'] ?? 0).toString()}'),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _busy ? null : () => _updatePayment(donation, true),
                child: const Text('Yes, Payment Received'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _updatePayment(donation, false),
                child: const Text('Payment Not Received'),
              ),
            ],
          );
        },
      ),
    );
  }
}