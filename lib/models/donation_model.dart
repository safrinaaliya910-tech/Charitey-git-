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

  // Delivery Math & Location Fields
  final double? deliveryFee;
  final double? distanceKm;
  final double? donorLat;
  final double? donorLng;

  // 👇 NEW: Payment verification fields
  final String? paymentReference;
  final DateTime? paymentSubmittedAt;
  final DateTime? paymentDisputedAt;
  final String? paymentStatus; // 'paid' | 'pending' | 'disputed' etc.

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
    this.deliveryFee,
    this.distanceKm,
    this.donorLat,
    this.donorLng,
    this.paymentReference,
    this.paymentSubmittedAt,
    this.paymentDisputedAt,
    this.paymentStatus,
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
      'deliveryFee': deliveryFee,
      'distanceKm': distanceKm,
      'donorLat': donorLat,
      'donorLng': donorLng,
      'paymentReference': paymentReference,
      'paymentSubmittedAt': paymentSubmittedAt != null ? Timestamp.fromDate(paymentSubmittedAt!) : null,
      'paymentDisputedAt': paymentDisputedAt != null ? Timestamp.fromDate(paymentDisputedAt!) : null,
      'paymentStatus': paymentStatus,
    };
  }

  factory DonationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return DonationModel(
      donationId: documentId,
      listingId: map['listingId'] ?? '',
      ngoId: map['ngoId'] ?? map['ngold'] ?? '',
      donorId: map['donorId'] ?? '',
      donorName: map['donorName'] ?? '',
      donorPhone: map['donorPhone'] ?? '',
      donorLocation: map['donorLocation'] ?? '',
      status: map['status'] ?? 'pending',
      donatedQuantity: map['donatedQuantity'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      cancelReason: map['cancelReason'],
      cancelledAt: (map['cancelledAt'] as Timestamp?)?.toDate(),
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      donorLat: (map['donorLat'] as num?)?.toDouble(),
      donorLng: (map['donorLng'] as num?)?.toDouble(),
      paymentReference: map['paymentReference'],
      paymentSubmittedAt: (map['paymentSubmittedAt'] as Timestamp?)?.toDate(),
      paymentDisputedAt: (map['paymentDisputedAt'] as Timestamp?)?.toDate(),
      paymentStatus: map['paymentStatus'],
    );
  }
}