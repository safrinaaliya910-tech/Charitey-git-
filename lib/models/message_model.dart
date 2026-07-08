//message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool delivered;
  final bool read;
  final String type;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;

  // --- NEW: delete tracking ---
  final List<String> deletedFor;       // uids who "deleted for me"
  final bool isDeletedForEveryone;

  // --- NEW: reply tracking ---
  final String? replyToId;
  final String? replyToMessage;        // denormalized preview text
  final String? replyToSenderName;
  final String? replyToType;           // 'text' | 'image' | 'document'

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.delivered = false,
    this.read = false,
    this.type = 'text',
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.deletedFor = const [],
    this.isDeletedForEveryone = false,
    this.replyToId,
    this.replyToMessage,
    this.replyToSenderName,
    this.replyToType,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'delivered': delivered,
      'read': read,
      'type': type,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'deletedFor': deletedFor,
      'isDeletedForEveryone': isDeletedForEveryone,
      'replyToId': replyToId,
      'replyToMessage': replyToMessage,
      'replyToSenderName': replyToSenderName,
      'replyToType': replyToType,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MessageModel(
      messageId: documentId,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      delivered: map['delivered'] ?? false,
      read: map['read'] ?? false,
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      deletedFor: List<String>.from(map['deletedFor'] ?? []),
      isDeletedForEveryone: map['isDeletedForEveryone'] ?? false,
      replyToId: map['replyToId'],
      replyToMessage: map['replyToMessage'],
      replyToSenderName: map['replyToSenderName'],
      replyToType: map['replyToType'],
    );
  }
}