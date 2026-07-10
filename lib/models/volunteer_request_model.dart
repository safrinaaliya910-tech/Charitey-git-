import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerRequestModel {
  final String requestId;
  final String ngoId;
  final String ngoName;       // <-- NEW: Deliver To Name
  final String donorId;
  final String donorName;     // <-- NEW: Pickup From Name
  final String listingId;
  final String itemName;      // <-- NEW: Delivery Item Name
  final String quantity;      // <-- NEW: Quantity
  final String status;
  final String? assignedVolunteer;
  final DateTime createdAt;

  VolunteerRequestModel({
    required this.requestId,
    required this.ngoId,
    required this.ngoName,
    required this.donorId,
    required this.donorName,
    required this.listingId,
    required this.itemName,
    required this.quantity,
    required this.status,
    this.assignedVolunteer,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'ngoId': ngoId,
      'ngoName': ngoName,
      'donorId': donorId,
      'donorName': donorName,
      'listingId': listingId,
      'itemName': itemName,
      'quantity': quantity,
      'status': status,
      'assignedVolunteer': assignedVolunteer,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory VolunteerRequestModel.fromMap(Map<String, dynamic> map, String documentId) {
    return VolunteerRequestModel(
      requestId: documentId,
      ngoId: map['ngoId'] ?? '',
      ngoName: map['ngoName'] ?? 'Unknown NGO',
      donorId: map['donorId'] ?? '',
      donorName: map['donorName'] ?? 'Unknown Donor',
      listingId: map['listingId'] ?? '',
      itemName: map['itemName'] ?? 'Unknown Item',
      quantity: map['quantity']?.toString() ?? '',
      status: map['status'] ?? 'pending',
      assignedVolunteer: map['assignedVolunteer'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}