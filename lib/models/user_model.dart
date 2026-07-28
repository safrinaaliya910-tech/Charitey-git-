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
  
  // 👇 NEW: Fields for the 5-Star Rating System 👇
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
    this.averageRating = 0.0, // 👈 Default to 0.0
    this.totalReviews = 0,    // 👈 Default to 0
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
      'averageRating': averageRating, // 👈 Added to map
      'totalReviews': totalReviews,   // 👈 Added to map
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
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
      
      // 👇 Safely parse rating data from Firebase 👇
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
    );
  }
}