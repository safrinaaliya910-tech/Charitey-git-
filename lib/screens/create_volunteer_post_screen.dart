import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import '../models/post_model.dart';
import '../widgets/custom_button.dart';

// Same posting flow as CreatePostScreen (NGO), but without the
// "Tag Donor" / "Tag Volunteer" autocomplete fields — no need to
// mention any user id here. Just an image + a caption.
class CreateVolunteerPostScreen extends StatefulWidget {
  const CreateVolunteerPostScreen({Key? key}) : super(key: key);

  @override
  State<CreateVolunteerPostScreen> createState() =>
      _CreateVolunteerPostScreenState();
}

class _CreateVolunteerPostScreenState
    extends State<CreateVolunteerPostScreen> {
  final TextEditingController _descriptionController = TextEditingController();

  File? _selectedImage;
  Uint8List? _webImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  final Color themeColor = const Color(0xFFB56F76);

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        _webImage = await picked.readAsBytes();
      } else {
        _selectedImage = File(picked.path);
      }
      setState(() {});
    }
  }

  Future<void> _uploadPost() async {
    if ((_selectedImage == null && _webImage == null) ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image and write a description.'),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final storageService = StorageService();
      String? imageUrl;

      imageUrl = await storageService.uploadImage(_selectedImage, _webImage);

      if (imageUrl == null || imageUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Image upload failed. Please check your connection and try again.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      String postId = FirebaseFirestore.instance.collection('posts').doc().id;

      // Same collection + same PostModel shape as the NGO flow.
      // Tag fields are left empty since no user id mention is needed here.
      PostModel newPost = PostModel(
        postId: postId,
        ngoId: user.uid,
        ngoProfileImage: user.profileImage,
        donorId: '',
        donorUid: '',
        volunteerName: '',
        volunteerUid: '',
        image: imageUrl,
        description: _descriptionController.text.trim(),
        likes: 0,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .set(newPost.toMap());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Post published to Impact Gallery!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 22,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "New Post",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image picker ────────────────────────────
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: _selectedImage != null || _webImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: kIsWeb
                            ? Image.memory(_webImage!, fit: BoxFit.cover)
                            : Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 50,
                            color: themeColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Tap to upload a photo",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Description ──────────────────────────────
            const Text(
              "Description",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Write a caption about this impact...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeColor),
                ),
              ),
            ),
            const SizedBox(height: 40),

            CustomButton(
              text: "Share to Gallery",
              isLoading: _isLoading,
              onPressed: _uploadPost,
            ),
          ],
        ),
      ),
    );
  }
}