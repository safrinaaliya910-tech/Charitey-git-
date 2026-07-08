//chat_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/chat_preview_model.dart';
import '../models/notification_model.dart'; 
import 'package:http/http.dart' as http;

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> sendMessage(
  String senderId,
  String senderName,
  String receiverId,
  String receiverName,
  String message, {
  String? senderPhone,
  String? senderLocation,
  String? senderRole,
  String type = 'text',        // NEW
  String? mediaUrl,            // NEW
  String? fileName,            // NEW
  int? fileSize,               // NEW
  String? replyToId,           // NEW
  String? replyToMessage,      // NEW
  String? replyToSenderName,   // NEW
  String? replyToType,         // NEW
}) async {
  try {
    String chatRoomId = getChatRoomId(senderId, receiverId);

    MessageModel newMessage = MessageModel(
      messageId: '',
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      timestamp: DateTime.now(),
      delivered: false,
      read: false,
      type: type,               // NEW
      mediaUrl: mediaUrl,       // NEW
      fileName: fileName,       // NEW
      fileSize: fileSize,       // NEW
      replyToId: replyToId,                 // NEW
      replyToMessage: replyToMessage,       // NEW
      replyToSenderName: replyToSenderName, // NEW
      replyToType: replyToType,             // NEW
    );

      // 1. Add the actual message to the chat room
      await _firestore.collection('chats').doc(chatRoomId).collection('messages').add(newMessage.toMap());

      // Compute the preview text ONCE, before either Firestore write
      String previewText = type == 'image'
          ? (message.isNotEmpty && message != '[Image]' ? '📷 $message' : '📷 Photo')
          : type == 'video'
              ? (message.isNotEmpty && message != '[Video]' ? '🎥 $message' : '🎥 Video')
              : type == 'document'
                  ? '📄 ${fileName ?? "Document"}'
                  : message;

      // 2. Update the Sender's Inbox
      await _firestore.collection('users').doc(senderId).collection('chat_previews').doc(chatRoomId).set({
        'participantId': receiverId,
        'participantName': receiverName,
        'lastMessage': previewText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hasUnread': false,
      }, SetOptions(merge: true));

      // 3. Update the Receiver's Inbox
      await _firestore.collection('users').doc(receiverId).collection('chat_previews').doc(chatRoomId).set({
        'participantId': senderId,
        'participantName': senderName,
        'lastMessage': previewText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hasUnread': true, 
      }, SetOptions(merge: true));

      // --- 4. THE CUSTOMIZED NOTIFICATION ALERT ---
      String notifTitle;
      String notifMessage;
      
      if (senderRole == 'ngo') {
        notifTitle = 'Message from NGO';
        notifMessage = 'The NGO you donated to ($senderName) wants to send you a message regarding your donation. Tap to view details.';
      } 
      // --- FIX: Added logic for Travel Agency ---
      else if (senderRole == 'travel_agency') {
        notifTitle = 'Message from Travel Agency';
        notifMessage = 'The Travel Agency ($senderName) assigned to your donation has sent a message. Tap to view details.';
      } 
      else {
        notifTitle = 'Message from $senderName (Donor)';
        notifMessage = 'Tap to view details and reply.';
      }

      NotificationModel alert = NotificationModel(
        id: _firestore.collection('notifications').doc().id,
        receiverId: receiverId, 
        senderId: senderId,               
        senderName: senderName,
        type: 'new_message', 
        title: notifTitle,
        message: notifMessage, 
        relatedItemId: chatRoomId, 
        createdAt: DateTime.now(),
      );

      Map<String, dynamic> alertData = alert.toMap();
      if (senderPhone != null) alertData['senderPhone'] = senderPhone;
      if (senderLocation != null) alertData['senderLocation'] = senderLocation;
      if (senderRole != null) alertData['senderRole'] = senderRole; 

      await _firestore.collection('notifications').doc(alert.id).set(alertData);

    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  Stream<List<MessageModel>> getMessages(String userId1, String userId2) {
    String chatRoomId = getChatRoomId(userId1, userId2);

    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      List<MessageModel> messages = snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .where((m) => !m.deletedFor.contains(userId1)) // NEW: hide "deleted for me"
          .toList();

      // --- NEW: Read receipts, step 1 (delivered) ---
      // userId1 is always the person currently viewing this stream (see how
      // getMessages is called from ChatScreen: getMessages(user.uid, otherUserId)).
      // The instant their device pulls this snapshot, any message addressed to
      // them that isn't flagged "delivered" yet gets flagged now. Fire-and-forget
      // so it never blocks rendering the message list.
      _markDeliveredForViewer(chatRoomId, userId1, messages);

      return messages;
    });
  }

  Future<void> _markDeliveredForViewer(String chatRoomId, String viewerId, List<MessageModel> messages) async {
    try {
      final undelivered = messages.where((m) => m.receiverId == viewerId && !m.delivered).toList();
      if (undelivered.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      for (var m in undelivered) {
        batch.update(
          _firestore.collection('chats').doc(chatRoomId).collection('messages').doc(m.messageId),
          {'delivered': true},
        );
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as delivered: $e');
    }
  }

  Stream<List<ChatPreviewModel>> getChatInbox(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_previews')
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatPreviewModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // --- NEW: Read receipts, step 2 (read) ---
  // Call this when the user actually opens/views a chat. It flips `read`
  // (and `delivered`, in case it was somehow missed) to true on every
  // message where they are the receiver, and clears the unread badge on
  // their own inbox preview for this chat.
  Future<void> markMessagesAsRead(String currentUserId, String otherUserId) async {
    try {
      String chatRoomId = getChatRoomId(currentUserId, otherUserId);

      QuerySnapshot unreadMessages = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true, 'delivered': true});
      }

      // Also clear the "unread" badge on the reader's own inbox entry
      batch.set(
        _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('chat_previews')
            .doc(chatRoomId),
        {'hasUnread': false},
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

// ============ DELETE MESSAGE ============

  Future<void> deleteMessageForMe(String chatRoomId, String messageId, String currentUserId) async {
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedFor': FieldValue.arrayUnion([currentUserId]),
    });
  }

  Future<void> deleteMessageForEveryone(String chatRoomId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeletedForEveryone': true,
      'message': 'This message was deleted',
      'mediaUrl': null,
      'fileName': null,
    });
  }

  // ============ CLEAR CHAT ============

  Future<void> clearChatForMe(String currentUserId, String otherUserId) async {
    final chatRoomId = getChatRoomId(currentUserId, otherUserId);
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        'deletedFor': FieldValue.arrayUnion([currentUserId]),
      });
    }
    await batch.commit();
  }

  // ============ BLOCK / UNBLOCK ============

  Future<void> blockUser(String currentUserId, String otherUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(otherUserId)
        .set({'blockedAt': FieldValue.serverTimestamp()});
  }

  Future<void> unblockUser(String currentUserId, String otherUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(otherUserId)
        .delete();
  }

  Stream<bool> isBlockedByMe(String currentUserId, String otherUserId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(otherUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<bool> amIBlockedByThem(String currentUserId, String otherUserId) {
    return _firestore
        .collection('users')
        .doc(otherUserId)
        .collection('blocked_users')
        .doc(currentUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

// --- NEW: upload bytes to Cloudinary and return the secure download URL ---
static const String _cloudinaryCloudName = 'dn3crlxzz'; 
static const String _cloudinaryUploadPreset = 'yzl8jb6z'; // e.g. 'chat_media_unsigned'

Future<String> uploadChatMedia(Uint8List bytes, String chatRoomId, String fileName) async {
  final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/auto/upload');

  final request = http.MultipartRequest('POST', uri)
    ..fields['upload_preset'] = _cloudinaryUploadPreset
    ..fields['folder'] = 'chat_media/$chatRoomId'
    ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

  // NEW: longer timeout, scaled by file size (videos need more time)
  final timeoutSeconds = bytes.length > 5 * 1024 * 1024 ? 120 : 30;

  final streamedResponse = await request.send().timeout(
    Duration(seconds: timeoutSeconds),
    onTimeout: () => throw Exception('Upload timed out — file may be too large or connection too slow'),
  );
  final response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode != 200) {
    throw Exception('Cloudinary upload failed: ${response.statusCode} ${response.body}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return data['secure_url'] as String;
}

// --- NEW: pick-and-send convenience wrapper used by ChatScreen ---
Future<void> sendMediaMessage({
  required Uint8List bytes,
  required String fileName,
  required String senderId,
  required String senderName,
  required String receiverId,
  required String receiverName,
  required String type, // 'image' | 'video' | 'document'
  String? caption,            // NEW: WhatsApp-style caption text
  String? senderPhone,
  String? senderLocation,
  String? senderRole,
  String? replyToId,
  String? replyToMessage,
  String? replyToSenderName,
  String? replyToType,
}) async {
  final chatRoomId = getChatRoomId(senderId, receiverId);
  final fileSize = bytes.length;

  final url = await uploadChatMedia(bytes, chatRoomId, fileName);

  final defaultText = type == 'image'
      ? '[Image]'
      : type == 'video'
          ? '[Video]'
          : '[Document] $fileName';

  await sendMessage(
    senderId,
    senderName,
    receiverId,
    receiverName,
    (caption != null && caption.trim().isNotEmpty) ? caption.trim() : defaultText, // NEW: caption overrides placeholder
    senderPhone: senderPhone,
    senderLocation: senderLocation,
    senderRole: senderRole,
    type: type,
    mediaUrl: url,
    fileName: fileName,
    fileSize: fileSize,
    replyToId: replyToId,
    replyToMessage: replyToMessage,
    replyToSenderName: replyToSenderName,
    replyToType: replyToType,
  );
}
//
}