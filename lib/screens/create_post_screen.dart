import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';
import '../models/notification_model.dart';
import '../widgets/custom_button.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedDonorName = '';
  String _selectedDonorUid = '';
  String _selectedVolunteerName = '';
  String _selectedVolunteerUid = '';

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

      PostModel newPost = PostModel(
        postId: postId,
        ngoId: user.uid,
        // Save the NGO's profile image so PostCardWidget
        // can render it directly without a Firestore fetch
        ngoProfileImage: user.profileImage,
        donorId: _selectedDonorName,
        donorUid: _selectedDonorUid,
        volunteerName: _selectedVolunteerName,
        volunteerUid: _selectedVolunteerUid,
        image: imageUrl,
        description: _descriptionController.text.trim(),
        likes: 0,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .set(newPost.toMap());

      // Notify tagged users (donor and volunteer)
      final recipients = <Map<String, String>>[];
      if (_selectedDonorUid.isNotEmpty) {
        recipients.add({'uid': _selectedDonorUid, 'name': _selectedDonorName});
        print(
          'DEBUG: Added donor - uid: $_selectedDonorUid, name: $_selectedDonorName',
        );
      }
      if (_selectedVolunteerUid.isNotEmpty) {
        recipients.add({
          'uid': _selectedVolunteerUid,
          'name': _selectedVolunteerName,
        });
        print(
          'DEBUG: Added volunteer - uid: $_selectedVolunteerUid, name: $_selectedVolunteerName',
        );
      }

      print('DEBUG: Total recipients to notify: ${recipients.length}');
      for (int i = 0; i < recipients.length; i++) {
        final recipient = recipients[i];
        final uid = recipient['uid'] ?? '';
        print('DEBUG: Processing recipient $i - uid: $uid');
        if (uid.isEmpty) {
          print('DEBUG: Skipping recipient $i - empty uid');
          continue;
        }
        String notifId = FirebaseFirestore.instance
            .collection('notifications')
            .doc()
            .id;
        NotificationModel notification = NotificationModel(
          id: notifId,
          receiverId: uid,
          senderId: user.uid,
          senderName: user.name,
          title: "You were tagged in a post!",
          message: "${user.name} tagged you in their Impact Gallery.",
          type: 'tag',
          relatedItemId: postId,
          createdAt: DateTime.now(),
          isRead: false,
        );
        print('DEBUG: Sending notification to recipient $i (uid: $uid)');
        await FirestoreService().sendNotification(notification);
        print('DEBUG: Notification sent to recipient $i');
      }
      print('DEBUG: All notifications sent');

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

  /// Searches users by username (strips leading '@').
  Future<List<Map<String, String>>> _searchUsers(String query) async {
    if (query.isEmpty) return [];

    String safeQuery = query.replaceAll('@', '').toLowerCase();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: safeQuery)
          .where('username', isLessThanOrEqualTo: '$safeQuery\uf8ff')
          .limit(5)
          .get();

      return snapshot.docs
          .map((doc) {
            var data = doc.data();
            return {
              'uid': doc.id,
              'name': data['name'] as String? ?? 'Unknown',
              'username': data['username'] as String? ?? '',
            };
          })
          .where((u) => u['username']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint("Search error: $e");
      return [];
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

            // ── Tag donor (autocomplete) ─────────────────
            const Text(
              "Tag Donor (Optional)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Autocomplete<Map<String, String>>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text == '') {
                  return const Iterable<Map<String, String>>.empty();
                }
                return await _searchUsers(textEditingValue.text);
              },
              displayStringForOption: (Map<String, String> option) =>
                  "@${option['username']}",
              onSelected: (Map<String, String> selection) {
                setState(() {
                  _selectedDonorName = "@${selection['username']}";
                  _selectedDonorUid = selection['uid']!;
                });
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      decoration: InputDecoration(
                        hintText: "Search @username...",
                        prefixIcon: Icon(
                          Icons.alternate_email_rounded,
                          color: Colors.grey.shade500,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
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
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: MediaQuery.of(context).size.width - 40,
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: options.length,
                        shrinkWrap: true,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: themeColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(Icons.person, color: themeColor),
                            ),
                            title: Text(
                              "@${option['username']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Tag volunteer (autocomplete) ──────────────
            const Text(
              "Tag Volunteer (Optional)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Autocomplete<Map<String, String>>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text == '') {
                  return const Iterable<Map<String, String>>.empty();
                }
                return await _searchUsers(textEditingValue.text);
              },
              displayStringForOption: (Map<String, String> option) =>
                  "@${option['username']}",
              onSelected: (Map<String, String> selection) {
                setState(() {
                  _selectedVolunteerName = "@${selection['username']}";
                  _selectedVolunteerUid = selection['uid']!;
                });
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      decoration: InputDecoration(
                        hintText: "Search @username...",
                        prefixIcon: Icon(
                          Icons.volunteer_activism_rounded,
                          color: Colors.grey.shade500,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
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
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: MediaQuery.of(context).size.width - 40,
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: options.length,
                        shrinkWrap: true,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: themeColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(Icons.person, color: themeColor),
                            ),
                            title: Text(
                              "@${option['username']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

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