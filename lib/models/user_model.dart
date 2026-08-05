//user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String username;
  final String phone;
  final String email;
  final String role; 
  final String location;
  final String profileImage;
  final String license;
  final DateTime createdAt;
  final int donationsCount;
  final int postsCount;
  final String? fcmToken;
  final List<String> favorites;
  
  final String? profession;
  final String? upiId;
  final String? vehicleType;
  final String? licenseDocumentUrl;

  // 👇 NEW: Verification status. Admin-controlled via the web panel.
  // 'pending' -> waiting for admin review (default for ngo/volunteer)
  // 'approved' / 'active' -> can access the home screen
  // 'rejected' / 'blocked' -> access denied, shown a message
  final String status;

  // 👇 Fields for the 5-Star Rating System 👇
  final double averageRating;
  final int totalReviews;

  UserModel({
    required this.uid,
    required this.name,
    this.username = '',
    required this.phone,
    required this.email,
    required this.role,
    required this.location,
    required this.profileImage,
    this.license = '',
    required this.createdAt,
    this.donationsCount = 0,
    this.postsCount = 0,
    this.fcmToken,
    this.favorites = const [],
    this.profession,
    this.upiId,
    this.vehicleType,
    this.licenseDocumentUrl,
    this.status = 'active', // 👈 NEW: real default is computed in fromMap based on role
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'phone': phone,
      'email': email,
      'role': role,
      'location': location,
      'profileImage': profileImage,
      'license': license,
      'createdAt': createdAt.toIso8601String(),
      'donationsCount': donationsCount,
      'postsCount': postsCount,
      'fcmToken': fcmToken,
      'favorites': favorites,
      'profession': profession,
      'upiId': upiId,
      'vehicleType': vehicleType,
      'licenseDocumentUrl': licenseDocumentUrl,
      'status': status, // 👈 NEW: added to map
      'averageRating': averageRating,
      'totalReviews': totalReviews,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    final String roleValue = (map['role'] ?? 'user').toString().toLowerCase();

    // 👇 NEW: Matches the admin panel's default logic exactly — ngo and
    // volunteer accounts are 'pending' until an admin reviews their
    // uploaded document, unless Firestore already has an explicit status.
    final bool requiresVerification = roleValue == 'ngo' || roleValue == 'volunteer';
    final String resolvedStatus = (map['status'] as String?)?.toLowerCase() ??
        (requiresVerification ? 'pending' : 'active');

    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      location: map['location'] ?? '',
      profileImage: map['profileImage'] ?? '',
      license: map['license'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      donationsCount: map['donationsCount'] ?? 0,
      postsCount: map['postsCount'] ?? 0,
      fcmToken: map['fcmToken'],
      favorites: List<String>.from(map['favorites'] ?? []),
      profession: map['profession'], 
      upiId: map['upiId'],
      vehicleType: map['vehicleType'],
      licenseDocumentUrl: map['licenseDocumentUrl'],
      status: resolvedStatus, // 👈 NEW
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
    );
  }
}