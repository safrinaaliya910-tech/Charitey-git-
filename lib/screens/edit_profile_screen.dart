//edit_profile_screen.dart
//edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/fare_calculator.dart';
import '../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  String? _selectedVehicleType;

  File? _newImageFile;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  final Color themeColor = const Color(0xFFB56F76);

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel!;
    _nameController = TextEditingController(text: user.name);
    _phoneController = TextEditingController(text: user.phone);
    _locationController = TextEditingController(text: user.location);
    _selectedVehicleType = user.vehicleType;
  }

  String? get currentImageUrl =>
      Provider.of<AuthProvider>(context, listen: false)
          .currentUserModel
          ?.profileImage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final file = File(picked.path);
      final url = await StorageService().uploadImage(file, null);

      if (url != null && mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final uid = authProvider.currentFirebaseUser?.uid;

        // 1. Update via provider (updates in-memory model + notifies listeners)
        await authProvider.updateProfile(profileImage: url);

        // 2. Safety-net direct Firestore write
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'profileImage': url});
        }

        setState(() => _newImageFile = file);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        vehicleType: _selectedVehicleType,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeProfileImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text(
            'Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isUploadingImage = true);
    try {
      final authProvider =
          Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.currentFirebaseUser?.uid;

      // Clear via provider
      await authProvider.updateProfile(profileImage: '');

      // Safety-net direct Firestore write
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'profileImage': ''});
      }

      setState(() => _newImageFile = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile photo removed.'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to remove photo: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUserModel;
    final currentImageUrl = user?.profileImage;
    final role = user?.role.toLowerCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Profile",
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text("SAVE",
                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- PROFILE IMAGE PICKER ---
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Avatar ──
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: themeColor.withOpacity(0.1),
                      backgroundImage: _newImageFile != null
                          ? FileImage(_newImageFile!) as ImageProvider
                          : (currentImageUrl != null && currentImageUrl!.isNotEmpty
                              ? NetworkImage(currentImageUrl!)
                              : null),
                      child: (_newImageFile == null &&
                              (currentImageUrl == null || currentImageUrl!.isEmpty))
                          ? Text(
                              (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor),
                            )
                          : null,
                    ),

                    // ── Camera button bottom-right ──
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingImage ? null : _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: _isUploadingImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 16),
                        ),
                      ),
                    ),

                    // ── Remove button bottom-left (only when image exists) ──
                    if (_newImageFile != null ||
                        (currentImageUrl != null && currentImageUrl!.isNotEmpty))
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: GestureDetector(
                          onTap: _isUploadingImage ? null : _removeProfileImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _newImageFile != null ||
                        (currentImageUrl != null && currentImageUrl!.isNotEmpty)
                    ? ""
                    : "Tap 📷 to add a photo",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 32),

              _buildEditField("Name", _nameController, Icons.person_outline),
              const SizedBox(height: 20),
              _buildEditField("Phone Number", _phoneController, Icons.phone_android_outlined),
              const SizedBox(height: 20),
              _buildEditField("Location", _locationController, Icons.location_on_outlined),
              const SizedBox(height: 20),
              if (role == 'travel_agency' || role == 'volunteer')
                _buildVehicleDropdown(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: themeColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: themeColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
    );
  }

  Widget _buildVehicleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedVehicleType,
      decoration: InputDecoration(
        labelText: 'Vehicle Type',
        prefixIcon: Icon(Icons.directions_car_outlined, color: themeColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: themeColor, width: 2),
        ),
      ),
      items: VehicleType.values.map((vehicle) {
        return DropdownMenuItem(
          value: vehicle.name,
          child: Text(vehicle.name[0].toUpperCase() + vehicle.name.substring(1)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedVehicleType = value;
        });
      },
    );
  }
}