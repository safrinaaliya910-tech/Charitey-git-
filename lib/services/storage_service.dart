// lib/services/storage_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Max size for verification documents (license / registration PDFs).
  static const int maxDocumentSizeBytes = 5 * 1024 * 1024; // 5 MB

  /// Uploads an image — used for BOTH activity/post photos (Activity page)
  /// AND profile photos (Profile Setup + Edit Profile screens).
  /// All images are public, so they share the same 'activity_images/' path.
  Future<String?> uploadImage(File? imageFile, Uint8List? webImage) async {
    try {
      final String fileName =
          'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('activity_images/$fileName');

      UploadTask task;
      if (kIsWeb) {
        if (webImage == null) {
          debugPrint("Firebase Web Upload Blocked: webImage data is null.");
          return null;
        }
        task = ref.putData(
          webImage,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        if (imageFile == null) {
          debugPrint("Firebase Mobile Upload Blocked: imageFile is null.");
          return null;
        }
        task = ref.putFile(imageFile);
      }

      final TaskSnapshot snapshot = await task;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint("🎉 Firebase Image Upload Successful: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("Fatal error uploading image: $e");
      return null;
    }
  }

  /// Uploads a verification DOCUMENT (PDF) — NGO license certificates and
  /// volunteer driving licenses, used on the Profile Setup page.
  /// Stored under a per-UID subfolder so Storage Rules can restrict access
  /// to the owner + admins only.
  Future<String?> uploadDocument({
    File? file,
    Uint8List? bytes,
    required String fileName,
    String folder = 'license_documents',
    void Function(double progress)? onProgress,
  }) async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint("Firebase Document Upload Blocked: no signed-in user.");
        return null;
      }

      final int sizeBytes = kIsWeb
          ? (bytes?.length ?? 0)
          : (file != null ? await file.length() : 0);

      if (sizeBytes == 0) {
        debugPrint("Firebase Document Upload Blocked: no file data provided.");
        return null;
      }
      if (sizeBytes > maxDocumentSizeBytes) {
        debugPrint("Firebase Document Upload Blocked: file exceeds $maxDocumentSizeBytes bytes.");
        return null;
      }

      // Per-user subfolder — required for the Storage Rules to work.
      final Reference ref = _storage.ref().child('$folder/$uid/$fileName');

      UploadTask task;
      if (kIsWeb) {
        if (bytes == null) {
          debugPrint("Firebase Document Upload Blocked: web bytes are null.");
          return null;
        }
        task = ref.putData(
          bytes,
          SettableMetadata(contentType: 'application/pdf'),
        );
      } else {
        if (file == null) {
          debugPrint("Firebase Document Upload Blocked: file path is null.");
          return null;
        }
        task = ref.putFile(file);
      }

      task.snapshotEvents.listen((TaskSnapshot snap) {
        if (snap.totalBytes > 0) {
          onProgress?.call(snap.bytesTransferred / snap.totalBytes);
        }
      });

      final TaskSnapshot snapshot = await task;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint("🎉 Firebase Document Upload Successful: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("Fatal error uploading document: $e");
      return null;
    }
  }
}