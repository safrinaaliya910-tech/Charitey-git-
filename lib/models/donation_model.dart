//lib/models/donation_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String donationId;
  final String listingId;
  final String ngoId; 
  final String donorId;
  final String donorName;
  final String donorPhone;
  final String donorLocation;
  final String status;
  final DateTime createdAt;
  final int donatedQuantity;
  
  final String? cancelReason;
  final DateTime? cancelledAt;

  // 👇 NEW: Delivery Math & Location Fields for Volunteers 👇
  final double? deliveryFee;
  final double? distanceKm;
  final double? donorLat;
  final double? donorLng;

  DonationModel({
    required this.donationId,
    required this.listingId,
    required this.ngoId,
    required this.donorId,
    required this.donorName,
    required this.donorPhone,
    required this.donorLocation,
    required this.status,
    required this.createdAt,
    required this.donatedQuantity,
    this.cancelReason,
    this.cancelledAt,
    this.deliveryFee, // <-- NEW
    this.distanceKm,  // <-- NEW
    this.donorLat,    // <-- NEW
    this.donorLng,    // <-- NEW
  });

  Map<String, dynamic> toMap() {
    return {
      'donationId': donationId,
      'listingId': listingId,
      'ngoId': ngoId,
      'donorId': donorId,
      'donorName': donorName,
      'donorPhone': donorPhone,
      'donorLocation': donorLocation,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'donatedQuantity': donatedQuantity,
      'cancelReason': cancelReason,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'deliveryFee': deliveryFee, // <-- NEW
      'distanceKm': distanceKm,   // <-- NEW
      'donorLat': donorLat,       // <-- NEW
      'donorLng': donorLng,       // <-- NEW
    };
  }

  factory DonationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return DonationModel(
      donationId: documentId,
      listingId: map['listingId'] ?? '',
      ngoId: map['ngoId'] ?? map['ngold'] ?? '', // Handles old typo data safely
      donorId: map['donorId'] ?? '',
      donorName: map['donorName'] ?? '',
      donorPhone: map['donorPhone'] ?? '',
      donorLocation: map['donorLocation'] ?? '',
      status: map['status'] ?? 'pending',
      donatedQuantity: map['donatedQuantity'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      cancelReason: map['cancelReason'],
      cancelledAt: (map['cancelledAt'] as Timestamp?)?.toDate(),
      
      // 👇 NEW: Safe parsing for doubles from Firestore 👇
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      donorLat: (map['donorLat'] as num?)?.toDouble(),
      donorLng: (map['donorLng'] as num?)?.toDouble(),
    );
  }
}