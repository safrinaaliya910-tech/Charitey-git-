//post_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String ngoId; // FIXED TYPO
  final String donorId;
  final String donorUid;
  final String volunteerName;
  final String volunteerUid;
  final String? ngoProfileImage;
  final String image;
  final String description;
  final int likes;
  final List<String> likedBy;   // ADD THIS
  final DateTime createdAt;

  PostModel({
    required this.postId,
    required this.ngoId,
    required this.donorId,
    this.donorUid = '',
    this.volunteerName = '',
    this.volunteerUid = '',
    this.ngoProfileImage,
    required this.image,
    required this.description,
    this.likes = 0,
    this.likedBy = const [],   // ADD THIS
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'ngoId': ngoId,
      'donorId': donorId,
      'donorUid': donorUid,
      'volunteerName': volunteerName,
      'volunteerUid': volunteerUid,
      'ngoProfileImage': ngoProfileImage,
      'image': image,
      'description': description,
      'likes': likes,
      'likedBy': likedBy,   // ADD THIS
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PostModel(
      postId: documentId,
      ngoId: map['ngoId'] ?? map['ngold'] ?? '', // Handles old typo data safely
      donorId: map['donorId'] ?? '',
      donorUid: map['donorUid'] ?? '',
      volunteerName: map['volunteerName'] ?? '',
      volunteerUid: map['volunteerUid'] ?? '',
      ngoProfileImage: map['ngoProfileImage'] as String?,
      image: map['image'] ?? '',
      description: map['description'] ?? '',
      likes: map['likes'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),   // ADD THIS
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}