//screens/ngo_listing_details_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NgoListingDetailsScreen extends StatelessWidget {
  final String listingId;

  const NgoListingDetailsScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('ngo_listings')
            .doc(listingId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(
                child: Text('This request is no longer available.'));
          }

          final itemName = data['type'] == 'food'
              ? data['foodType'] ?? 'Food'
              : data['productName'] ?? 'Product';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _DetailRow(label: 'Item', value: itemName.toString()),
              _DetailRow(
                  label: 'Quantity',
                  value: (data['quantity'] ?? 'Not specified').toString()),
              _DetailRow(
                  label: 'Fulfilled',
                  value: (data['fulfilledQuantity'] ?? 0).toString()),
              _DetailRow(
                  label: 'Status',
                  value: (data['status'] ?? 'unknown').toString()),
              _DetailRow(
                  label: 'Location',
                  value: (data['ngoLocation'] ??
                          data['pickupAddress'] ??
                          'Not specified')
                      .toString()),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child:
                  Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}