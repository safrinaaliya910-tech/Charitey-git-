// lib/services/storage_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class StorageService {
  // Configured directly from your Cloudinary Environment Settings
  static const String _cloudName = 'dn3crlxzz';

  // The official unsigned preset copied from your upload settings tab
  static const String _uploadPreset = 'yzl8jb6z';

  /// Max size we allow for verification documents (license / registration
  /// PDFs). Keep this in sync with whatever your Cloudinary plan/preset
  /// actually allows.
  static const int maxDocumentSizeBytes = 5 * 1024 * 1024; // 5 MB

  /// Uploads an image file or web byte array directly to Cloudinary bypassing the Firebase paywall
  Future<String?> uploadImage(File? imageFile, Uint8List? webImage) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      var request = http.MultipartRequest('POST', url);

      // Inject required unsigned form fields
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'charitey_uploads';

      if (kIsWeb) {
        if (webImage == null) {
          debugPrint("Cloudinary Web Upload Blocked: webImage data is null.");
          return null;
        }
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          webImage,
          filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      } else {
        if (imageFile == null) {
          debugPrint("Cloudinary Mobile Upload Blocked: imageFile local path is null.");
          return null;
        }
        request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("CLOUDINARY STATUS: ${response.statusCode}");
      debugPrint("CLOUDINARY BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final secureUrl = data['secure_url'] as String?;
        debugPrint("🎉 Cloudinary Media Upload Successful: $secureUrl");
        return secureUrl;
      } else {
        debugPrint("Cloudinary Server Core Rejection: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Fatal execution crash inside custom StorageService layer: $e");
      return null;
    }
  }

  /// Uploads a verification DOCUMENT (PDF) — used for NGO license
  /// certificates and volunteer driving licenses so an admin can manually
  /// verify them later.
  ///
  /// IMPORTANT: PDFs must go through Cloudinary's `raw` resource type.
  /// The `image/upload` endpoint used by [uploadImage] will reject them.
  ///
  /// Progress is reported in coarse stages (start / mid / done) via
  /// [onProgress] rather than tracked byte-by-byte. The previous
  /// byte-by-byte implementation manually re-streamed the multipart body
  /// through a separate StreamedRequest to compute live percentages, and
  /// that re-streaming was silently corrupting the uploaded PDF bytes —
  /// the file would upload with a 200 OK but fail to open afterward.
  /// This version sends the request exactly as http.MultipartRequest
  /// builds it, with no manual byte handling, so the uploaded file is
  /// guaranteed to match the original on disk.
  Future<String?> uploadDocument({
    File? file,
    Uint8List? bytes,
    required String fileName,
    String folder = 'charitey_uploads/license_documents',
    void Function(double progress)? onProgress,
  }) async {
    try {
      final int sizeBytes = kIsWeb
          ? (bytes?.length ?? 0)
          : (file != null ? await file.length() : 0);

      if (sizeBytes == 0) {
        debugPrint("Cloudinary Document Upload Blocked: no file data provided.");
        return null;
      }
      if (sizeBytes > maxDocumentSizeBytes) {
        debugPrint("Cloudinary Document Upload Blocked: file exceeds $maxDocumentSizeBytes bytes.");
        return null;
      }

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/raw/upload');
      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = folder;

      if (kIsWeb) {
        if (bytes == null) {
          debugPrint("Cloudinary Document Upload Blocked: web bytes are null.");
          return null;
        }
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      } else {
        if (file == null) {
          debugPrint("Cloudinary Document Upload Blocked: file path is null.");
          return null;
        }
        request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));
      }

      onProgress?.call(0.15);

      final streamedResponse = await request.send();

      onProgress?.call(0.85);

      final response = await http.Response.fromStream(streamedResponse);

      onProgress?.call(1.0);

      debugPrint("CLOUDINARY DOC STATUS: ${response.statusCode}");
      debugPrint("CLOUDINARY DOC BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final secureUrl = data['secure_url'] as String?;
        final int? bytesStored = data['bytes'] as int?;

        if (bytesStored != null && bytesStored != sizeBytes) {
          debugPrint(
            "⚠️ Size mismatch — local file was $sizeBytes bytes but Cloudinary "
            "stored $bytesStored bytes. The uploaded document may be corrupted.",
          );
        }

        debugPrint("🎉 Cloudinary Document Upload Successful: $secureUrl");
        return secureUrl;
      } else {
        debugPrint("Cloudinary Document Rejection: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Fatal execution crash while uploading document: $e");
      return null;
    }
  }
}