//screens/donation_offer_details_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DonationOfferDetailsScreen extends StatelessWidget {
  final String donationId;

  const DonationOfferDetailsScreen({super.key, required this.donationId});

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFB56F76);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Donation Offer Details',
          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('donations')
            .doc(donationId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: themeColor),
            );
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Donation offer details are no longer available.'),
            );
          }

          final donation = snapshot.data!.data() as Map<String, dynamic>;
          final listingId = (donation['listingId'] ?? '').toString();

          return FutureBuilder<DocumentSnapshot>(
            future: listingId.isEmpty
                ? null
                : FirebaseFirestore.instance
                    .collection('ngo_listings')
                    .doc(listingId)
                    .get(),
            builder: (context, listingSnapshot) {
              final listing =
                  listingSnapshot.data?.data() as Map<String, dynamic>? ?? {};
              final itemName = listing['foodType'] ??
                  listing['productName'] ??
                  donation['itemName'] ??
                  'Donation';
              final quantity = donation['donatedQuantity'] ??
                  donation['quantity'] ??
                  donation['donatedAmount'] ??
                  'Not specified';

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _DetailCard(
                    title: 'Donation',
                    rows: [
                      _DetailRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Item',
                        value: itemName.toString(),
                      ),
                      _DetailRow(
                        icon: Icons.numbers,
                        label: 'Quantity',
                        value: quantity.toString(),
                      ),
                      _DetailRow(
                        icon: Icons.info_outline,
                        label: 'Status',
                        value: (donation['status'] ?? 'pending').toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailCard(
                    title: 'Donor Information',
                    rows: [
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: (donation['donorName'] ?? 'Unknown Donor').toString(),
                      ),
                      _DetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: (donation['donorPhone'] ?? 'Not provided').toString(),
                      ),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Pickup Location',
                        value: (donation['donorLocation'] ?? 'Not provided').toString(),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;

  const _DetailCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFFB56F76)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}