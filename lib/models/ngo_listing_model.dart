import 'package:cloud_firestore/cloud_firestore.dart';

class NgoListingModel {
  final String listingId;
  final String ngoId;
  final String ngoName;
  final String ngoLocation;
  final String type;

  final String? imageUrl;

  final String? foodType;
  final int? quantity;
  final int? fulfilledQuantity; // Tracks balance progression
  final String? unit;

  final String? category;
  final String? productName;

  final String availability;
  final DateTime liveUntil;
  final DateTime createdAt;
  final String status;
  
  // --- Volunteer Availability Field ---
  final bool? isVolunteerAvailable; 
  final String? ngoProfileImage; 
  final String? description;

  // 👇 NEW: Location fields for platform volunteers 👇
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupAddress;

  NgoListingModel({
    required this.listingId,
    required this.ngoId,
    required this.ngoName,
    required this.ngoLocation,
    required this.type,
    this.imageUrl,
    this.foodType,
    this.quantity,
    this.fulfilledQuantity,
    this.unit,
    this.category,
    this.productName,
    required this.availability,
    required this.liveUntil,
    required this.createdAt,
    required this.status,
    this.isVolunteerAvailable, 
    this.ngoProfileImage, 
    this.description,
    this.pickupLat,     // <-- NEW
    this.pickupLng,     // <-- NEW
    this.pickupAddress, // <-- NEW
  });

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'ngoId': ngoId,
      'ngoName': ngoName,
      'ngoLocation': ngoLocation,
      'type': type,
      'imageUrl': imageUrl,
      'foodType': foodType,
      'quantity': quantity,
      'fulfilledQuantity': fulfilledQuantity ?? 0, 
      'unit': unit,
      'category': category,
      'productName': productName,
      'availability': availability,
      'liveUntil': Timestamp.fromDate(liveUntil),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'isVolunteerAvailable': isVolunteerAvailable, 
      'ngoProfileImage': ngoProfileImage, 
      'description': description, 
      'pickupLat': pickupLat,         // <-- NEW
      'pickupLng': pickupLng,         // <-- NEW
      'pickupAddress': pickupAddress, // <-- NEW
    };
  }

  factory NgoListingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return NgoListingModel(
      listingId: documentId,
      ngoId: map['ngoId'] ?? '',
      ngoName: map['ngoName'] ?? '',
      ngoLocation: map['ngoLocation'] ?? '',
      type: map['type'] ?? 'food',

      imageUrl: map['imageUrl'],

      foodType: map['foodType'],
      quantity: map['quantity'],
      fulfilledQuantity: map['fulfilledQuantity'] ?? 0, 
      unit: map['unit'],
      category: map['category'],
      productName: map['productName'],

      availability: map['availability'] ?? '',

      liveUntil: (map['liveUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

      status: map['status'] ?? 'open',
      isVolunteerAvailable: map['isVolunteerAvailable'] as bool?, 
      ngoProfileImage: map['ngoProfileImage'] as String?, 
      description: map['description'] as String?, 
      
      // 👇 NEW: Safe parsing for doubles from Firestore 👇
      pickupLat: (map['pickupLat'] as num?)?.toDouble(),
      pickupLng: (map['pickupLng'] as num?)?.toDouble(),
      pickupAddress: map['pickupAddress'] as String?,
    );
  }
}