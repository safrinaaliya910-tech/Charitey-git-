import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';

import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/fare_calculator.dart';
import '../models/post_model.dart';
import '../models/notification_model.dart';
import 'edit_profile_screen.dart';
import 'role_selection_screen.dart';
import 'ngo_dashboard.dart';
import 'create_post_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? visitedUserId;
  const ProfileScreen({super.key, this.visitedUserId});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final Color themeColor = const Color(0xFFB56F76);
  bool isUploading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUserModel;

    if (currentUser == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: themeColor)),
      );
    }

    final String currentUserId = authProvider.currentFirebaseUser?.uid ?? '';
    final bool isVisiting =
        widget.visitedUserId != null && widget.visitedUserId != currentUserId;
    final String targetUid = isVisiting ? widget.visitedUserId! : currentUserId;

    return FutureBuilder<DocumentSnapshot?>(
      future: isVisiting
          ? FirebaseFirestore.instance.collection('users').doc(targetUid).get()
          : Future.value(null),
      builder: (context, userSnapshot) {
        if (isVisiting &&
            userSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFFDF7F8),
            body: Center(child: CircularProgressIndicator(color: themeColor)),
          );
        }

        String name = currentUser.name;
        String username = currentUser.username;
        String email = currentUser.email;
        String phone = currentUser.phone;
        String location = currentUser.location;
        String profileImage = currentUser.profileImage;
        String license = currentUser.license;
        String role = currentUser.role.toString().trim().toLowerCase();

        // Universal rating data
        double averageRating = currentUser.averageRating;
        int totalReviews = currentUser.totalReviews;

        if (isVisiting &&
            userSnapshot.hasData &&
            userSnapshot.data != null &&
            userSnapshot.data!.exists) {
          var data = userSnapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? 'Unknown';
          username = data['username'] ?? '';
          email = data['email'] ?? '';
          phone = data['phone'] ?? '';
          location = data['location'] ?? '';
          profileImage = data['profileImage'] ?? '';
          role = (data['role'] ?? 'user').toString().trim().toLowerCase();

          // Pull the visited user's rating
          averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
          totalReviews = (data['totalReviews'] as num?)?.toInt() ?? 0;
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFDF7F8), Color(0xFFEEDAE0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.1, 1.0],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor, themeColor.withOpacity(0.7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Transform.translate(
                                offset: const Offset(0, -40),
                                child: GestureDetector(
                                  onTap: profileImage.isEmpty
                                      ? null
                                      : () => _openImageViewer(
                                          context,
                                          profileImage,
                                          name,
                                        ),
                                  child: CircleAvatar(
                                    radius: 54,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: themeColor.withOpacity(0.1),
                                      backgroundImage: profileImage.isNotEmpty
                                          ? NetworkImage(profileImage)
                                          : null,
                                      child: isUploading
                                          ? const CircularProgressIndicator()
                                          : (profileImage.isEmpty
                                              ? Icon(
                                                  Icons.person_rounded,
                                                  size: 50,
                                                  color: themeColor,
                                                )
                                              : null),
                                    ),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(0, -20),
                                child: Column(
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (username.isNotEmpty)
                                      Text(
                                        "@$username",
                                        style: TextStyle(
                                          color: themeColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    // UNIVERSAL STAR RATING BADGE 
                                    if (totalReviews > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.amber.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              averageRating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "($totalReviews Reviews)",
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (!isVisiting)
                                      Text(
                                        email,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (!isVisiting && phone.isNotEmpty)
                                _buildInfoTile(Icons.phone_android_rounded, phone),
                              if (location.isNotEmpty)
                                _buildInfoTile(Icons.location_on_rounded, location),
                              if (!isVisiting &&
                                  license.isNotEmpty &&
                                  (role == 'ngo' ||
                                      role == 'volunteer' ||
                                      role == 'travel_agency'))
                                _buildInfoTile(
                                  role == 'volunteer'
                                      ? Icons.credit_card_rounded
                                      : Icons.verified_user_rounded,
                                  license,
                                ),
                              if (!isVisiting && role == 'travel_agency')
                                _buildVehicleInfoTile(
                                  currentUser.vehicleType,
                                  () => _showChangeVehicleDialog(currentUser.vehicleType),
                                ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!isVisiting)
                                    SizedBox(
                                      width: 140,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const EditProfileScreen(),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: themeColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: const Text(
                                          "Edit Profile",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  if (isVisiting && role == 'ngo') ...[
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(currentUserId)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        List<dynamic> favorites = [];
                                        if (snapshot.hasData &&
                                            snapshot.data!.exists) {
                                          final data = snapshot.data!.data()
                                              as Map<String, dynamic>?;
                                          favorites = data?['favorites'] ?? [];
                                        }
                                        bool isFav = favorites.contains(targetUid);
                                        return IconButton(
                                          icon: Icon(
                                            isFav
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                          ),
                                          color: isFav ? Colors.red : themeColor,
                                          iconSize: 32,
                                          onPressed: () => _toggleFavoriteNgo(
                                            currentUserId,
                                            targetUid,
                                            isFav,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isVisiting) ...[
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Navigates to PendingReceiptsScreen
                              if (role == 'ngo') ...[
                                _buildActionButton(
                                    "Requests",
                                    Icons.history,
                                    () => _showRecentRequestsSheet(
                                        context, targetUid)),
                                _buildActionButton(
                                    "Pending\nReceipts",
                                    Icons.inventory_2_outlined,
                                    () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => PendingReceiptsScreen(
                                                ngoId: targetUid)))),
                                _buildActionButton("Share", Icons.share,
                                    () => _shareApp(context)),
                              ] else ...[
                                _buildActionButton(
                                  role == 'volunteer'
                                      ? "My Deliveries"
                                      : "My Donations",
                                  role == 'volunteer'
                                      ? Icons.local_shipping_rounded
                                      : Icons.history,
                                  () {
                                    if (role == 'volunteer') {
                                      _showMyTasksSheet(context);
                                    } else {
                                      _showMyDonationsSheet(context);
                                    }
                                  },
                                ),
                                _buildActionButton("Share", Icons.share,
                                    () => _shareApp(context)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (role == 'ngo')
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('ngo_listings')
                                      .where('ngoId', isEqualTo: targetUid)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    String count = "0";
                                    if (snapshot.hasData) {
                                      count = snapshot.data!.docs.length
                                          .toString();
                                    }
                                    return _buildStatCard(
                                      "Total Requests",
                                      count,
                                      () => _showRecentRequestsSheet(
                                        context,
                                        targetUid,
                                      ),
                                    );
                                  },
                                )
                              else if (role == 'volunteer')
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('donations')
                                      .where(
                                        'assignedVolunteerId',
                                        isEqualTo: targetUid,
                                      )
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    String count = "0";
                                    if (snapshot.hasData) {
                                      count = snapshot.data!.docs.where((d) {
                                        String status = (d.data()
                                                as Map<String, dynamic>)['status'] ??
                                            '';
                                        return status.contains('completed');
                                      }).length.toString();
                                    }
                                    return _buildStatCard(
                                      "Completed Tasks",
                                      count,
                                      () => _showMyTasksSheet(context),
                                    );
                                  },
                                )
                              else
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('donations')
                                      .where('donorId', isEqualTo: targetUid)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    String count = "0";
                                    if (snapshot.hasData) {
                                      count = snapshot.data!.docs.length
                                          .toString();
                                    }
                                    return _buildStatCard(
                                      "Total Donations",
                                      count,
                                      () => _showMyDonationsSheet(context),
                                    );
                                  },
                                ),
                            ],
                          ),
                          if (role == 'volunteer') ...[
                            const SizedBox(height: 25),
                            VolunteerImpactStoryWidget(
                              userId: targetUid,
                              themeColor: themeColor,
                            ),
                          ],
                          if (role != 'ngo' && role != 'volunteer') ...[
                            const SizedBox(height: 25),
                            DonorImpactStoryWidget(
                              userId: targetUid,
                              themeColor: themeColor,
                            ),
                          ],
                        ],
                        if (role == 'ngo') ...[
                          const SizedBox(height: 40),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              isVisiting ? "Posts" : "Your Posts",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('posts')
                                .where('ngoId', isEqualTo: targetUid)
                                .snapshots(),
                            builder: (context, postSnapshot) {
                              if (postSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: themeColor,
                                  ),
                                );
                              }
                              if (postSnapshot.hasError) {
                                return Center(
                                  child: Text(
                                    "Error loading posts.",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                );
                              }
                              var posts =
                                  postSnapshot.data?.docs.toList() ?? [];
                              posts.sort((a, b) {
                                var aData = a.data() as Map<String, dynamic>;
                                var bData = b.data() as Map<String, dynamic>;
                                var aTime = aData['createdAt'];
                                var bTime = bData['createdAt'];
                                DateTime aDate = aTime is Timestamp
                                    ? aTime.toDate()
                                    : DateTime.fromMillisecondsSinceEpoch(0);
                                DateTime bDate = bTime is Timestamp
                                    ? bTime.toDate()
                                    : DateTime.fromMillisecondsSinceEpoch(0);
                                return bDate.compareTo(aDate);
                              });

                              if (posts.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 30,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.photo_library_outlined,
                                          size: 50,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          "No posts yet.",
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: posts.length,
                                itemBuilder: (context, index) {
                                  var postData = posts[index].data()
                                      as Map<String, dynamic>;
                                  var post = PostModel.fromMap(
                                    postData,
                                    posts[index].id,
                                  );
                                  return PostCardWidget(
                                    post: post,
                                    ngoName: name,
                                    currentUserId: currentUserId,
                                    themeColor: themeColor,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                        if (!isVisiting) ...[
                          const SizedBox(height: 25),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black12, blurRadius: 5),
                              ],
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.logout_rounded,
                                color: Colors.red,
                              ),
                              title: const Text(
                                "Logout",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                await authProvider.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RoleSelectionScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isVisiting)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Padding(
                                padding: EdgeInsets.only(left: 6.0),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          )
                       else
                          const SizedBox(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: themeColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoTile(String? vehicleType, VoidCallback onEdit) {
    final String label = (vehicleType != null && vehicleType.trim().isNotEmpty)
        ? _capitalize(vehicleType.trim())
        : 'Not set';
    final IconData icon = _vehicleIconFromString(vehicleType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Icon(
              Icons.edit_rounded,
              size: 18,
              color: themeColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _vehicleIconFromString(String? vehicleType) {
    final type = _vehicleTypeFromString(vehicleType);
    if (type == null) {
      return Icons.local_shipping_outlined;
    }
    switch (type) {
      case VehicleType.scooty:
        return Icons.moped_outlined;
      case VehicleType.bike:
        return Icons.pedal_bike_rounded;
      case VehicleType.auto:
        return Icons.electric_rickshaw_rounded;
      case VehicleType.car:
        return Icons.directions_car_rounded;
      case VehicleType.tempo:
      case VehicleType.van:
        return Icons.local_shipping_outlined;
      case VehicleType.lorry:
        return Icons.local_shipping_rounded;
    }
  }

  VehicleType? _vehicleTypeFromString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return VehicleType.values.firstWhere(
        (vehicle) => vehicle.name.toLowerCase() == value.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> _showChangeVehicleDialog(String? currentVehicleType) async {
    VehicleType? selectedVehicle =
        _vehicleTypeFromString(currentVehicleType) ?? VehicleType.bike;

    final bool? didSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: icon + title (matches screenshot)
                    Row(
                      children: [
                        Icon(Icons.directions_car_filled_rounded,
                            color: themeColor, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Choose Your Vehicle',
                          style: TextStyle(
                            color: themeColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select the vehicle your travel agency uses.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Horizontal scrollable chip row (matches screenshot)
                    SizedBox(
                      height: 68,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: VehicleType.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final vehicle = VehicleType.values[index];
                          final bool isSelected = selectedVehicle == vehicle;
                          return GestureDetector(
                            onTap: () => setState(() {
                              selectedVehicle = vehicle;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? themeColor.withOpacity(0.12)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? themeColor
                                      : Colors.grey.shade300,
                                  width: isSelected ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _vehicleIconFromString(vehicle.name),
                                    size: 20,
                                    color: isSelected
                                        ? themeColor
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    vehicle.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? themeColor
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cancel / Continue buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: themeColor.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: themeColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (didSave == true && selectedVehicle != null) {
      await Provider.of<AuthProvider>(context, listen: false)
          .updateProfile(vehicleType: selectedVehicle!.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vehicle updated to ${_capitalize(selectedVehicle!.name)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavoriteNgo(String donorId, String ngoId, bool isFav) async {
    if (donorId.isEmpty || ngoId.isEmpty) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(donorId);
    if (isFav) {
      await docRef.update({
        'favorites': FieldValue.arrayRemove([ngoId]),
      });
    } else {
      await docRef.update({
        'favorites': FieldValue.arrayUnion([ngoId]),
      });
    }
  }

  void _openImageViewer(BuildContext context, String imageUrl, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          name: name,
          themeColor: themeColor,
        ),
      ),
    );
  }

  Future<bool> _showCancelStepDialog(BuildContext context, String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes', style: TextStyle(color: themeColor)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _showCancelReasonDialog(BuildContext context) async {
    final TextEditingController reasonController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Step 3 of 3'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for cancellation'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text),
            child: Text('Submit', style: TextStyle(color: themeColor)),
          ),
        ],
      ),
    );
    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  Future<void> _showMyDonationsSheet(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    final String currentUserId = authProvider.currentFirebaseUser?.uid ?? '';
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDF7F8),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Recent Donation History",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: currentUserId.isEmpty
                  ? const Center(
                      child: Text("Unable to load donation history."),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('donations')
                          .where('donorId', isEqualTo: currentUserId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return Center(
                            child: Text("Error: ${snapshot.error}"),
                          );
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return Center(
                            child: CircularProgressIndicator(color: themeColor),
                          );

                        var allDocs = snapshot.data!.docs;
                        Map<String, Map<String, dynamic>> groupedDonations = {};

                        for (var doc in allDocs) {
                          var data = doc.data() as Map<String, dynamic>;
                          String listingId = data['listingId'] ?? doc.id;
                          String rawQty = data['quantity']?.toString() ??
                              data['qty']?.toString() ??
                              data['donatedAmount']?.toString() ??
                              '0';
                          String cleanQty = rawQty.replaceAll(RegExp(r'[^0-9]'), '');
                          int mathQty = int.tryParse(cleanQty.isEmpty ? '0' : cleanQty) ?? 0;

                          if (groupedDonations.containsKey(listingId)) {
                            groupedDonations[listingId]!['aggregatedQty'] =
                                (groupedDonations[listingId]!['aggregatedQty'] as int) + mathQty;
                            var existingTime = groupedDonations[listingId]!['createdAt'];
                            var thisTime = data['createdAt'];
                            DateTime existingDate = existingTime is Timestamp
                                ? existingTime.toDate()
                                : DateTime.fromMillisecondsSinceEpoch(0);
                            DateTime thisDate = thisTime is Timestamp
                                ? thisTime.toDate()
                                : DateTime.fromMillisecondsSinceEpoch(0);
                            if (thisDate.isAfter(existingDate)) {
                              groupedDonations[listingId]!['createdAt'] = data['createdAt'];
                              groupedDonations[listingId]!['status'] = data['status'];
                              groupedDonations[listingId]!['docId'] = doc.id;
                            }
                          } else {
                            data['aggregatedQty'] = mathQty;
                            data['docId'] = doc.id;
                            groupedDonations[listingId] = Map<String, dynamic>.from(data);
                          }
                        }
                        var donations = groupedDonations.values.toList();
                        donations.sort((a, b) {
                          var aTime = a['createdAt'];
                          var bTime = b['createdAt'];
                          DateTime aDate = aTime is Timestamp
                              ? aTime.toDate()
                              : DateTime.fromMillisecondsSinceEpoch(0);
                          DateTime bDate = bTime is Timestamp
                              ? bTime.toDate()
                              : DateTime.fromMillisecondsSinceEpoch(0);
                          return bDate.compareTo(aDate);
                        });

                        if (donations.isEmpty)
                          return const Center(
                            child: Text("No donation history found."),
                          );

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: donations.length,
                          itemBuilder: (context, index) {
                            var donation = donations[index];
                            final createdAt = donation['createdAt'];
                            String dateText = 'Unknown date';
                            DateTime? createdDate;
                            if (createdAt is Timestamp) {
                              createdDate = createdAt.toDate();
                              dateText = '${createdDate.day}/${createdDate.month}/${createdDate.year}';
                            }
                            String ngoName = donation['ngoName'] ?? 'NGO Partner';
                            String itemName = donation['items'] ?? donation['itemName'] ?? 'Item';
                            int donatedQty = donation['aggregatedQty'] as int;
                            String rawDisplayQty = donatedQty.toString();
                            String status = donation['status']?.toString().trim().toLowerCase() ?? 'pending';
                            String ngoId = donation['ngoId'] ?? '';
                            String listingId = donation['listingId'] ?? '';
                            String targetDocId = donation['docId'] ?? '';
                            
                            final bool isCancelled = status == 'cancelled';
                            final bool isPending = status == 'pending';
                            final bool canCancel = isPending &&
                                createdDate != null &&
                                DateTime.now().difference(createdDate).inHours < 24;

                            return FutureBuilder<List<DocumentSnapshot?>>(
                              future: () async {
                                final ngoDoc = ngoId.isNotEmpty
                                    ? await FirebaseFirestore.instance.collection('users').doc(ngoId).get()
                                    : null;
                                DocumentSnapshot? listingDoc;
                                if (listingId.isNotEmpty)
                                  listingDoc = await FirebaseFirestore.instance.collection('ngo_listings').doc(listingId).get();
                                return [ngoDoc, listingDoc];
                              }(),
                              builder: (context, combinedSnapshot) {
                                if (combinedSnapshot.connectionState == ConnectionState.waiting)
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(child: CircularProgressIndicator()),
                                  );

                                int totalQty = donatedQty;
                                int fulfilledQty = donatedQty;
                                String unit = '';
                                String type = 'PRODUCT';

                                if (combinedSnapshot.hasData && combinedSnapshot.data != null) {
                                  final ngoSnapshot = combinedSnapshot.data![0];
                                  if (ngoSnapshot != null && ngoSnapshot.exists) {
                                    var userData = ngoSnapshot.data() as Map<String, dynamic>?;
                                    ngoName = userData?['name'] ?? ngoName;
                                  }
                                  if (combinedSnapshot.data!.length > 1 && combinedSnapshot.data![1] != null) {
                                    final listingSnapshot = combinedSnapshot.data![1]!;
                                    if (listingSnapshot.exists) {
                                      var listingData = listingSnapshot.data() as Map<String, dynamic>?;
                                      if (listingData != null) {
                                        if (listingData['type'] == 'food' || listingData['type'] == 'FOOD') {
                                          itemName = listingData['foodType'] ?? itemName;
                                          type = 'FOOD';
                                        } else {
                                          itemName = listingData['productName'] ?? itemName;
                                          type = (listingData['type'] ?? 'PRODUCT').toString().toUpperCase();
                                        }
                                        unit = listingData['unit'] ?? '';
                                        totalQty = int.tryParse(listingData['quantity']?.toString() ?? '0') ?? donatedQty;
                                        fulfilledQty = int.tryParse(listingData['fulfilledQuantity']?.toString() ?? '0') ?? donatedQty;
                                      }
                                    }
                                  }
                                }
                                int remainingQty = totalQty - fulfilledQty;
                                if (remainingQty < 0) remainingQty = 0;

                                return EnhancedDonationHistoryCard(
                                  ngoName: ngoName,
                                  itemName: itemName,
                                  displayDonatedQty: rawDisplayQty,
                                  mathDonatedQty: donatedQty,
                                  totalQty: totalQty,
                                  fulfilledQty: fulfilledQty,
                                  remainingQty: remainingQty,
                                  unit: unit,
                                  type: type,
                                  dateText: dateText,
                                  status: status, 
                                  isCancelled: isCancelled,
                                  canCancel: canCancel,
                                  themeColor: themeColor,
                                  onCancel: () async {
                                    bool stepOne = await _showCancelStepDialog(context, 'Step 1 of 3', 'Do you really want to cancel this donation?');
                                    if (!stepOne || !context.mounted) return;
                                    bool stepTwo = await _showCancelStepDialog(context, 'Step 2 of 3', 'This action cannot be undone. Are you sure?');
                                    if (!stepTwo || !context.mounted) return;
                                    String? reason = await _showCancelReasonDialog(context);
                                    if (reason == null || reason.trim().isEmpty) return;

                                    try {
                                      await FirebaseFirestore.instance.collection('donations').doc(targetDocId).update({
                                        'status': 'cancelled',
                                        'cancelReason': reason.trim(),
                                        'cancelledAt': Timestamp.now(),
                                      });

                                      if (ngoId.isNotEmpty) {
                                        String notificationId = FirebaseFirestore.instance.collection('notifications').doc().id;
                                        NotificationModel notification = NotificationModel(
                                          id: notificationId,
                                          receiverId: ngoId,
                                          senderId: currentUserId,
                                          senderName: user.name,
                                          title: 'Donation Cancelled',
                                          message: '${user.name} cancelled the donation for $itemName. Reason: "${reason.trim()}". Phone: ${user.phone}',
                                          type: 'donation_cancelled',
                                          relatedItemId: targetDocId,
                                          createdAt: DateTime.now(),
                                          isRead: false,
                                        );
                                        await FirestoreService().sendNotification(notification);
                                      }

                                      if (listingId.isNotEmpty) {
                                        DocumentReference listingRef = FirebaseFirestore.instance.collection('ngo_listings').doc(listingId);
                                        await FirebaseFirestore.instance.runTransaction((transaction) async {
                                          DocumentSnapshot listingSnap = await transaction.get(listingRef);
                                          if (listingSnap.exists) {
                                            var lData = listingSnap.data() as Map<String, dynamic>;
                                            int currentFulfilled = (lData['fulfilledQuantity'] as num?)?.toInt() ?? 0;
                                            int totalNeeded = (lData['quantity'] as num?)?.toInt() ?? 0;
                                            int newFulfilled = currentFulfilled - donatedQty;
                                            if (newFulfilled < 0) newFulfilled = 0;
                                            String newStatus = lData['status'] ?? 'open';
                                            if (newFulfilled < totalNeeded && newStatus == 'closed') newStatus = 'open';
                                            transaction.update(listingRef, {
                                              'fulfilledQuantity': newFulfilled,
                                              'status': newStatus,
                                            });
                                          }
                                        });
                                      }
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donation cancelled. NGO notified and quantity restored!')));
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to cancel donation.')));
                                    }
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecentRequestsSheet(BuildContext context, String ngoId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDF7F8),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Your Donation Requests",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ngo_listings')
                    .where('ngoId', isEqualTo: ngoId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return Center(child: CircularProgressIndicator(color: themeColor));

                  var requests = snapshot.data!.docs.toList();
                  requests.sort((a, b) {
                    var aData = a.data() as Map<String, dynamic>;
                    var bData = b.data() as Map<String, dynamic>;
                    var aTime = aData['createdAt'];
                    var bTime = bData['createdAt'];
                    DateTime aDate = aTime is Timestamp ? aTime.toDate() : (aTime is DateTime ? aTime : DateTime.fromMillisecondsSinceEpoch(0));
                    DateTime bDate = bTime is Timestamp ? bTime.toDate() : (bTime is DateTime ? bTime : DateTime.fromMillisecondsSinceEpoch(0));
                    return bDate.compareTo(aDate);
                  });

                  if (requests.isEmpty)
                    return const Center(child: Text("You haven't made any requests yet."));

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      var data = requests[index].data() as Map<String, dynamic>;
                      String type = (data['type'] ?? 'PRODUCT').toString().toUpperCase();
                      bool isFood = type == 'FOOD';
                      String itemName = isFood ? (data['foodType'] ?? 'Food') : (data['productName'] ?? 'Product');
                      int totalQty = int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
                      int fulfilledQty = int.tryParse(data['fulfilledQuantity']?.toString() ?? '0') ?? 0;
                      int remainingQty = totalQty - fulfilledQty;
                      if (remainingQty < 0) remainingQty = 0;
                      String unit = data['unit'] ?? '';
                      double progress = totalQty > 0 ? (fulfilledQty / totalQty) : 0.0;
                      Timestamp? ts = data['createdAt'] as Timestamp?;
                      String dateText = ts != null ? "${ts.toDate().day}-${ts.toDate().month}-${ts.toDate().year}" : "Unknown Date";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  itemName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (!isFood) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "$fulfilledQty donated out of $totalQty",
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    "$remainingQty needed",
                                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                                ),
                              ),
                            ] else ...[
                              Text(
                                "Quantity Requested: $totalQty $unit",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(dateText, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                const SizedBox(width: 16),
                                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    data['ngoLocation'] ?? '',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareApp(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Share App Via",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    sheetContext,
                    "WhatsApp",
                    Icons.chat_bubble_outline,
                    "whatsapp://send?text=Check out Fourth Idly App: https://fourth idly.app",
                  ),
                  _buildShareOption(
                    sheetContext,
                    "Facebook",
                    Icons.facebook,
                    "https://www.facebook.com/sharer/sharer.php?u=https://fourth idly.app",
                  ),
                  _buildShareOption(
                    sheetContext,
                    "Instagram",
                    Icons.camera_alt_outlined,
                    "https://www.instagram.com",
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption(BuildContext context, String label, IconData icon, String urlScheme) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final Uri url = Uri.parse(urlScheme);
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (e) {
          await launchUrl(Uri.parse("https://fourth idly.app"), mode: LaunchMode.platformDefault);
        }
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: themeColor.withOpacity(0.1),
            child: Icon(icon, color: themeColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _showMyTasksSheet(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    final String currentUserId = authProvider.currentFirebaseUser?.uid ?? '';
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDF7F8),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "My Delivery Tasks",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: currentUserId.isEmpty
                  ? const Center(child: Text("Unable to load task history."))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('donations')
                          .where('assignedVolunteerId', isEqualTo: currentUserId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: themeColor));

                        var tasks = snapshot.data!.docs.toList();
                        tasks.sort((a, b) {
                          var aData = a.data() as Map<String, dynamic>;
                          var bData = b.data() as Map<String, dynamic>;
                          DateTime aDate = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                          DateTime bDate = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                          return bDate.compareTo(aDate);
                        });

                        if (tasks.isEmpty) {
                          return const Center(child: Text("You haven't accepted any tasks yet."));
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            var taskData = tasks[index].data() as Map<String, dynamic>;
                            var donationId = tasks[index].id;
                            String status = taskData['status'] ?? 'pending';

                            return VolunteerTaskHistoryCard(
                              donationId: donationId,
                              taskData: taskData,
                              themeColor: themeColor,
                              status: status,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
} // 👈 THIS IS THE CRUCIAL BRACKET CLOSING THE PROFILE SCREEN STATE


// =========================================================================
// PENDING RECEIPTS SCREEN
// =========================================================================
class PendingReceiptsScreen extends StatefulWidget {
  final String ngoId;
  const PendingReceiptsScreen({super.key, required this.ngoId});

  @override
  State<PendingReceiptsScreen> createState() => _PendingReceiptsScreenState();
}

class _PendingReceiptsScreenState extends State<PendingReceiptsScreen> {
  final Color themeColor = const Color(0xFFB56F76);

  @override
  Widget build(BuildContext context) {
    // 👇 `context` here belongs to the State itself — it stays alive as long as
    // this screen is on top. Every async callback below uses THIS context,
    // never the shadowed one from inner builders.
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Pending Receipts",
          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Confirm physical receipt to release the volunteer's payment.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('ngoId', isEqualTo: widget.ngoId)
                  .where('status', isEqualTo: 'pending_ngo_confirmation')
                  .snapshots(),
              builder: (streamContext, snapshot) {   // 👈 renamed, no shadowing
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: themeColor));
                }

                var receipts = snapshot.data!.docs.toList();
                if (receipts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("No pending receipts", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: receipts.length,
                  itemBuilder: (listContext, index) {   // 👈 renamed, no shadowing
                    var data = receipts[index].data() as Map<String, dynamic>;
                    String docId = receipts[index].id;
                    String donorName = data['donorName'] ?? 'Unknown Donor';
                    String volunteerName = data['volunteerName'] ?? 'Volunteer';
                    int quantity = data['donatedQuantity'] ?? data['quantity'] ?? 1;
                    String volunteerId = data['assignedVolunteerId'] ?? '';
                    String donorId = data['donorId'] ?? '';
                    String listingId = data['listingId'] ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('ngo_listings').doc(listingId).get(),
                      builder: (futureContext, listingSnap) {   // 👈 renamed, no shadowing
                        if (listingSnap.connectionState == ConnectionState.waiting) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200, width: 1.5),
                            ),
                            child: const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                          );
                        }

                        String itemName = data['items'] ?? data['itemName'] ?? 'Donation Item';
                        String unit = '';

                        if (listingSnap.hasData && listingSnap.data!.exists) {
                          var lData = listingSnap.data!.data() as Map<String, dynamic>;
                          unit = lData['unit'] ?? '';
                          if (lData['type'] == 'food') {
                            itemName = lData['foodType'] ?? itemName;
                          } else {
                            itemName = lData['productName'] ?? itemName;
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.local_shipping_rounded, color: themeColor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Waiting for your confirmation",
                                      style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Text("Item: $quantity $unit $itemName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 8),
                              Text("From Donor: $donorName", style: TextStyle(color: Colors.grey.shade700)),
                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    // 👇 Use `context` (the State's own, stable context) for the
                                    // confirmation dialog too — keeps everything on one safe context.
                                    bool confirm = await showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Row(
                                          children: [
                                            Icon(Icons.inventory_rounded, color: Colors.green.shade700),
                                            const SizedBox(width: 8),
                                            const Text("Confirm Receipt"),
                                          ],
                                        ),
                                        content: const Text("Have you physically received these items? Confirming this will prompt the donor to pay the volunteer."),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                            child: const Text("Yes, Received", style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ) ?? false;

                                    if (!confirm) return;

                                    if (volunteerId.isNotEmpty) {
                                      var vSnap = await FirebaseFirestore.instance.collection('users').doc(volunteerId).get();
                                      if (vSnap.exists) {
                                        volunteerName = (vSnap.data() as Map<String, dynamic>)['name'] ?? 'Volunteer';
                                      }
                                    }

                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    final currentUser = authProvider.currentUserModel;

                                    try {
                                      await FirebaseFirestore.instance.collection('donations').doc(docId).update({
                                        'status': 'completed_awaiting_payment'
                                      });

                                      if (volunteerId.isNotEmpty) {
                                        await FirebaseFirestore.instance.collection('users').doc(volunteerId).set({
                                          'deliveriesCompleted': FieldValue.increment(1)
                                        }, SetOptions(merge: true));
                                      }

                                      if (donorId.isNotEmpty && listingId.isNotEmpty) {
                                        var requestQuery = await FirebaseFirestore.instance
                                            .collection('volunteer_requests')
                                            .where('donorId', isEqualTo: donorId)
                                            .where('listingId', isEqualTo: listingId)
                                            .limit(1).get();

                                        if (requestQuery.docs.isNotEmpty) {
                                          await FirebaseFirestore.instance.collection('volunteer_requests')
                                              .doc(requestQuery.docs.first.id).update({'status': 'completed'});
                                        }
                                      }

                                     // Inside the onPressed of "Confirm Received" button
String notifIdDonor = FirebaseFirestore.instance.collection('notifications').doc().id;

NotificationModel donorNotif = NotificationModel(
  id: notifIdDonor,
  receiverId: donorId,
  senderId: widget.ngoId,
  senderName: currentUser?.name ?? 'NGO',
  type: 'payment_pending',                          // ← must be exactly this
  title: 'Payment Required',                        // ← better title for push
  message: 'Your donation of $itemName has safely reached us! Please tap here to pay your volunteer their delivery fee.',
  relatedItemId: docId,                             // donation ID
  createdAt: DateTime.now(),
  isRead: false,
);

await FirestoreService().sendNotification(donorNotif);
                                    } catch (e) {
                                      debugPrint("Update error: $e");
                                    }

                                    // 👇 THE FIX: `context` here is the State's own context,
                                    // captured from the outer build() method — it is NOT tied to
                                    // this specific list item, so it survives the item being
                                    // filtered out of the list the instant the status changed above.
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text('Receipt Confirmed! Donor notified to pay.'),
                                        backgroundColor: Colors.green,
                                      ));

                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (dialogCtx) => NgoRatingDialog(
                                          donorId: donorId,
                                          donorName: donorName,
                                          volunteerId: volunteerId,
                                          volunteerName: volunteerName,
                                          donationId: docId,
                                          themeColor: themeColor,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                                  label: const Text("Confirm Received", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// =========================================================================
// VOLUNTEER IMPACT STORY WIDGET
// =========================================================================
class VolunteerImpactStoryWidget extends StatefulWidget {
  final String userId;
  final Color themeColor;

  const VolunteerImpactStoryWidget({
    Key? key,
    required this.userId,
    required this.themeColor,
  }) : super(key: key);

  @override
  State<VolunteerImpactStoryWidget> createState() =>
      _VolunteerImpactStoryWidgetState();
}

class _VolunteerImpactStoryWidgetState extends State<VolunteerImpactStoryWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;
  int? _selectedDayIndex;

  static const Color _duskyRose = Color(0xFFB76E79);
  static const Color _duskyRoseLight = Color(0xFFE8B4BC);
  static const Color _duskyRoseDarkText = Color(0xFF5A1E29);
  static const Color _duskyRoseLabelText = Color(0xFF6B2737);

  // Statuses that count as a finished delivery for stats/badges/chart.
  static const Set<String> _completedStatuses = {
    'delivery_completed',
    'completed_awaiting_payment',
    'fully_completed',
    'completed',
  };

  int _visitStreak = 0;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOut,
    );
    _chartController.forward();
    _updateVisitStreak();
  }

  Future<void> _updateVisitStreak() async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
      final snap = await docRef.get();
      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int newStreak = 1;

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>?;
        final String? lastVisit = data?['lastProfileVisitDate'];
        final int prevStreak = (data?['profileVisitStreak'] as num?)?.toInt() ?? 0;

        if (lastVisit == todayKey) {
          if (mounted) setState(() => _visitStreak = prevStreak > 0 ? prevStreak : 1);
          return;
        } else if (lastVisit != null) {
          final lastDate = DateTime.parse(lastVisit);
          final yesterday =
              DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
          final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
          newStreak = (lastDateOnly == yesterday) ? prevStreak + 1 : 1;
        }
      }

      await docRef.set({
        'lastProfileVisitDate': todayKey,
        'profileVisitStreak': newStreak,
      }, SetOptions(merge: true));

      if (mounted) setState(() => _visitStreak = newStreak);
    } catch (_) {}
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _computeStats(List<QueryDocumentSnapshot> docs) {
    int totalCompleted = 0;
    int totalPending = 0;

    DateTime now = DateTime.now();
    List<String> dayLabels = [];
    List<double> acceptedCounts = List.filled(7, 0);
    List<double> completedCounts = List.filled(7, 0);
    Map<String, int> dayIndexMap = {};

    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      String label = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
      dayLabels.add(label);
      String key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      dayIndexMap[key] = 6 - i;
    }

    Set<String> streakDays = {};

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = (data['status'] ?? '').toString().trim().toLowerCase();
      var ts = data['createdAt'];
      bool isCompleted = _completedStatuses.contains(status);

      if (isCompleted) {
        totalCompleted++;
      } else if (status != 'cancelled') {
        totalPending++;
      }

      if (ts is Timestamp) {
        DateTime date = ts.toDate();
        String key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        int? idx = dayIndexMap[key];
        if (idx != null) {
          acceptedCounts[idx]++;
          if (isCompleted) completedCounts[idx]++;
        }
        if (isCompleted) streakDays.add(key);
      }
    }

    int streak = 0;
    DateTime cursor = DateTime.now();
    for (int i = 0; i < 60; i++) {
      String key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (streakDays.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    int personalBestIndex = -1;
    double maxCompleted = 0;
    for (int i = 0; i < completedCounts.length; i++) {
      if (completedCounts[i] > maxCompleted) {
        maxCompleted = completedCounts[i];
        personalBestIndex = i;
      }
    }

    return {
      'totalCompleted': totalCompleted,
      'totalPending': totalPending,
      'streak': streak,
      'livesTouched': totalCompleted * 3,
      'dayLabels': dayLabels,
      'acceptedCounts': acceptedCounts,
      'completedCounts': completedCounts,
      'personalBestIndex': personalBestIndex,
    };
  }

  Map<String, dynamic> _getBadgeInfo(int totalCompleted) {
    if (totalCompleted >= 31) {
      return {
        'rank': 'Legend', 'emoji': '💎', 'min': 31, 'max': null,
        'next': null, 'nextEmoji': '', 'quote': 'You are the backbone of this community. Thank you.',
      };
    } else if (totalCompleted >= 16) {
      return {
        'rank': 'Champion', 'emoji': '🥇', 'min': 16, 'max': 30,
        'next': 'Legend', 'nextEmoji': '💎', 'quote': 'You\'ve touched over ${totalCompleted * 3} lives. You\'re making real change.',
      };
    } else if (totalCompleted >= 6) {
      return {
        'rank': 'Supporter', 'emoji': '🥈', 'min': 6, 'max': 15,
        'next': 'Champion', 'nextEmoji': '🥇', 'quote': 'Your support is building a better tomorrow!',
      };
    } else {
      return {
        'rank': 'Helper', 'emoji': '🥉', 'min': 0, 'max': 5,
        'next': 'Supporter', 'nextEmoji': '🥈', 'quote': 'Every journey starts with one step. Keep going!',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('assignedVolunteerId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildLoadingCard();
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final stats = _computeStats(snapshot.data!.docs);
        final int totalCompleted = stats['totalCompleted'];
        final int totalPending = stats['totalPending'];
        final int streak = _visitStreak;
        final int livesTouched = stats['livesTouched'];
        final List<String> dayLabels = List<String>.from(stats['dayLabels']);
        final List<double> acceptedCounts = List<double>.from(stats['acceptedCounts']);
        final List<double> completedCounts = List<double>.from(stats['completedCounts']);
        final int personalBestIndex = stats['personalBestIndex'];
        final badge = _getBadgeInfo(totalCompleted);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.themeColor.withOpacity(0.14),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: widget.themeColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'YOUR IMPACT STORY',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.themeColor, letterSpacing: 1.2),
                    ),
                    const Spacer(),
                    _buildLiveBadge(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 16),
                child: Text('Last 7 days  •  All Time', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              ),
              SizedBox(
                height: 108,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildStatChip(Icons.local_shipping_rounded, 'Total Delivered', totalCompleted.toString()),
                    _buildStatChip(Icons.hourglass_top_rounded, 'Pending', totalPending.toString()),
                    _buildStatChip(Icons.local_fire_department_rounded, 'Streak', '$streak days'),
                    _buildStatChip(Icons.favorite_rounded, 'Lives Touched', '~$livesTouched people'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.shade200, thickness: 1, height: 1),
              _buildChartSection(dayLabels, acceptedCounts, completedCounts, personalBestIndex),
              Divider(color: Colors.grey.shade200, thickness: 1, height: 1),
              _buildBadgeSection(totalCompleted, badge),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Center(child: CircularProgressIndicator(color: widget.themeColor)),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value) {
    return Container(
      width: 126,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_duskyRoseLight.withOpacity(0.9), _duskyRoseLight.withOpacity(0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(color: _duskyRose.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 2, offset: const Offset(-1, -1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              top: -20, right: -20,
              child: Transform.rotate(
                angle: 0.6,
                child: Container(
                  width: 60, height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.45), Colors.white.withOpacity(0.0)],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 16, color: _duskyRoseDarkText),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _duskyRoseDarkText),
                  ),
                ),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10, color: _duskyRoseLabelText, height: 1.3, fontWeight: FontWeight.w700), maxLines: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(List<String> labels, List<double> accepted, List<double> completed, int personalBestIndex) {
    double maxVal = 0;
    for (var v in [...accepted, ...completed]) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 15, color: widget.themeColor),
              const SizedBox(width: 6),
              Text('Activity (Last 7 Days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              const Spacer(),
              Container(width: 12, height: 3, decoration: BoxDecoration(color: widget.themeColor.withOpacity(0.35), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Accepted', style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              Container(width: 12, height: 3, decoration: BoxDecoration(color: widget.themeColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Delivered', style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedDayIndex != null
                ? Container(
                    key: ValueKey(_selectedDayIndex),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.themeColor.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: widget.themeColor),
                        const SizedBox(width: 6),
                        Text(
                          '${labels[_selectedDayIndex!]}: ${completed[_selectedDayIndex!].toInt()} delivered, ${accepted[_selectedDayIndex!].toInt()} accepted',
                          style: TextStyle(fontSize: 12, color: widget.themeColor, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 0),
          ),
          GestureDetector(
            onTapDown: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              double chartWidth = box.size.width - 32;
              double sectionWidth = chartWidth / 7;
              int idx = (details.localPosition.dx / sectionWidth).floor().clamp(0, 6);
              setState(() {
                _selectedDayIndex = _selectedDayIndex == idx ? null : idx;
              });
            },
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(double.infinity, 150),
                  painter: _ImpactChartPainter(
                    accepted: accepted,
                    completed: completed,
                    labels: labels,
                    themeColor: widget.themeColor,
                    animationValue: _chartAnimation.value,
                    maxVal: maxVal,
                    personalBestIndex: personalBestIndex,
                    selectedIndex: _selectedDayIndex,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeSection(int totalCompleted, Map<String, dynamic> badge) {
    final bool isLegend = badge['next'] == null;
    final int min = badge['min'] as int;
    final int? max = badge['max'] as int?;
    final double progress = isLegend ? 1.0 : ((totalCompleted - min) / ((max! - min))).clamp(0.0, 1.0);
    final int toNext = isLegend ? 0 : ((max ?? 0) - totalCompleted + 1).clamp(0, 999);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.themeColor.withOpacity(0.10),
                  boxShadow: [BoxShadow(color: widget.themeColor.withOpacity(0.25), blurRadius: 16, spreadRadius: 2)],
                ),
                child: Center(child: Text(badge['emoji'], style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(badge['rank'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.themeColor)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: widget.themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text('$totalCompleted deliveries', style: TextStyle(fontSize: 11, color: widget.themeColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (!isLegend)
                      Text('$toNext more to become ${badge['next']} ${badge['nextEmoji']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500))
                    else
                      Text('Highest rank achieved! 🎉', style: TextStyle(fontSize: 12, color: widget.themeColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [widget.themeColor.withOpacity(0.10), widget.themeColor.withOpacity(0.03)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.themeColor.withOpacity(0.18)),
            ),
            child: Text('"${badge['quote']}"', style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontStyle: FontStyle.italic, height: 1.6, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// DONOR IMPACT STORY WIDGET
// =========================================================================
class DonorImpactStoryWidget extends StatefulWidget {
  final String userId;
  final Color themeColor;

  const DonorImpactStoryWidget({
    Key? key,
    required this.userId,
    required this.themeColor,
  }) : super(key: key);

  @override
  State<DonorImpactStoryWidget> createState() => _DonorImpactStoryWidgetState();
}

class _DonorImpactStoryWidgetState extends State<DonorImpactStoryWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;
  int? _selectedDayIndex;

  static const Color _duskyRose = Color(0xFFB76E79);
  static const Color _duskyRoseLight = Color(0xFFE8B4BC);
  static const Color _duskyRoseDarkText = Color(0xFF5A1E29);
  static const Color _duskyRoseLabelText = Color(0xFF6B2737);

  // Statuses that count as a fulfilled / completed donation.
  static const Set<String> _completedStatuses = {
    'delivery_completed',
    'completed_awaiting_payment',
    'fully_completed',
    'completed',
  };

  int _visitStreak = 0;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOut,
    );
    _chartController.forward();
    _updateVisitStreak();
  }

  Future<void> _updateVisitStreak() async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
      final snap = await docRef.get();
      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int newStreak = 1;

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>?;
        final String? lastVisit = data?['lastProfileVisitDate'];
        final int prevStreak =
            (data?['profileVisitStreak'] as num?)?.toInt() ?? 0;

        if (lastVisit == todayKey) {
          if (mounted) {
            setState(() => _visitStreak = prevStreak > 0 ? prevStreak : 1);
          }
          return;
        } else if (lastVisit != null) {
          final lastDate = DateTime.parse(lastVisit);
          final yesterday = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 1));
          final lastDateOnly =
              DateTime(lastDate.year, lastDate.month, lastDate.day);
          newStreak = (lastDateOnly == yesterday) ? prevStreak + 1 : 1;
        }
      }

      await docRef.set({
        'lastProfileVisitDate': todayKey,
        'profileVisitStreak': newStreak,
      }, SetOptions(merge: true));

      if (mounted) setState(() => _visitStreak = newStreak);
    } catch (_) {}
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _computeStats(List<QueryDocumentSnapshot> docs) {
    int totalDonations = 0;
    int totalFulfilled = 0;
    int totalPending = 0;

    DateTime now = DateTime.now();
    List<String> dayLabels = [];
    List<double> donatedCounts = List.filled(7, 0);
    List<double> fulfilledCounts = List.filled(7, 0);
    Map<String, int> dayIndexMap = {};

    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      String label = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
      dayLabels.add(label);
      String key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      dayIndexMap[key] = 6 - i;
    }

    Set<String> streakDays = {};

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = (data['status'] ?? '').toString().trim().toLowerCase();
      var ts = data['createdAt'];
      bool isFulfilled = _completedStatuses.contains(status);
      bool isCancelled = status == 'cancelled';

      totalDonations++;
      if (isFulfilled) {
        totalFulfilled++;
      } else if (!isCancelled) {
        totalPending++;
      }

      if (ts is Timestamp) {
        DateTime date = ts.toDate();
        String key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        int? idx = dayIndexMap[key];
        if (idx != null) {
          donatedCounts[idx]++;
          if (isFulfilled) fulfilledCounts[idx]++;
        }
        if (isFulfilled) streakDays.add(key);
      }
    }

    int streak = 0;
    DateTime cursor = DateTime.now();
    for (int i = 0; i < 60; i++) {
      String key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (streakDays.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    int personalBestIndex = -1;
    double maxFulfilled = 0;
    for (int i = 0; i < fulfilledCounts.length; i++) {
      if (fulfilledCounts[i] > maxFulfilled) {
        maxFulfilled = fulfilledCounts[i];
        personalBestIndex = i;
      }
    }

    return {
      'totalDonations': totalDonations,
      'totalFulfilled': totalFulfilled,
      'totalPending': totalPending,
      'streak': streak,
      'livesTouched': totalFulfilled * 3,
      'dayLabels': dayLabels,
      'donatedCounts': donatedCounts,
      'fulfilledCounts': fulfilledCounts,
      'personalBestIndex': personalBestIndex,
    };
  }

  Map<String, dynamic> _getBadgeInfo(int totalDonations) {
    if (totalDonations >= 31) {
      return {
        'rank': 'Legend', 'emoji': '💎', 'min': 31, 'max': null,
        'next': null, 'nextEmoji': '', 'quote': 'You are the backbone of this community. Thank you.',
      };
    } else if (totalDonations >= 16) {
      return {
        'rank': 'Champion', 'emoji': '🥇', 'min': 16, 'max': 30,
        'next': 'Legend', 'nextEmoji': '💎', 'quote': 'You\'ve touched over ${totalDonations * 3} lives. You\'re making real change.',
      };
    } else if (totalDonations >= 6) {
      return {
        'rank': 'Supporter', 'emoji': '🥈', 'min': 6, 'max': 15,
        'next': 'Champion', 'nextEmoji': '🥇', 'quote': 'Your generosity is building a better tomorrow!',
      };
    } else {
      return {
        'rank': 'Helper', 'emoji': '🥉', 'min': 0, 'max': 5,
        'next': 'Supporter', 'nextEmoji': '🥈', 'quote': 'Every journey starts with one step. Keep going!',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildLoadingCard();
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final stats = _computeStats(snapshot.data!.docs);
        final int totalDonations = stats['totalDonations'];
        final int totalPending = stats['totalPending'];
        final int streak = _visitStreak;
        final int livesTouched = stats['livesTouched'];
        final List<String> dayLabels = List<String>.from(stats['dayLabels']);
        final List<double> donatedCounts = List<double>.from(stats['donatedCounts']);
        final List<double> fulfilledCounts = List<double>.from(stats['fulfilledCounts']);
        final int personalBestIndex = stats['personalBestIndex'];
        final badge = _getBadgeInfo(totalDonations);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.themeColor.withOpacity(0.14),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: widget.themeColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'YOUR DONOR IMPACT',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.themeColor, letterSpacing: 1.2),
                    ),
                    const Spacer(),
                    _buildLiveBadge(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 16),
                child: Text('Last 7 days  •  All Time', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              ),
              SizedBox(
                height: 108,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildStatChip(Icons.volunteer_activism_rounded, 'Total Donations', totalDonations.toString()),
                    _buildStatChip(Icons.hourglass_top_rounded, 'Pending', totalPending.toString()),
                    _buildStatChip(Icons.local_fire_department_rounded, 'Streak', '$streak days'),
                    _buildStatChip(Icons.favorite_rounded, 'Lives Touched', '~$livesTouched people'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.shade200, thickness: 1, height: 1),
              _buildChartSection(dayLabels, donatedCounts, fulfilledCounts, personalBestIndex),
              Divider(color: Colors.grey.shade200, thickness: 1, height: 1),
              _buildBadgeSection(totalDonations, badge),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Center(child: CircularProgressIndicator(color: widget.themeColor)),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value) {
    return Container(
      width: 126,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_duskyRoseLight.withOpacity(0.9), _duskyRoseLight.withOpacity(0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(color: _duskyRose.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 2, offset: const Offset(-1, -1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              top: -20, right: -20,
              child: Transform.rotate(
                angle: 0.6,
                child: Container(
                  width: 60, height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.45), Colors.white.withOpacity(0.0)],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 16, color: _duskyRoseDarkText),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _duskyRoseDarkText),
                  ),
                ),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10, color: _duskyRoseLabelText, height: 1.3, fontWeight: FontWeight.w700), maxLines: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(List<String> labels, List<double> donated, List<double> fulfilled, int personalBestIndex) {
    double maxVal = 0;
    for (var v in [...donated, ...fulfilled]) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 15, color: widget.themeColor),
              const SizedBox(width: 6),
              Text('Activity (Last 7 Days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              const Spacer(),
              Container(width: 12, height: 3, decoration: BoxDecoration(color: widget.themeColor.withOpacity(0.35), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Donated', style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              Container(width: 12, height: 3, decoration: BoxDecoration(color: widget.themeColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Fulfilled', style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedDayIndex != null
                ? Container(
                    key: ValueKey(_selectedDayIndex),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.themeColor.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: widget.themeColor),
                        const SizedBox(width: 6),
                        Text(
                          '${labels[_selectedDayIndex!]}: ${fulfilled[_selectedDayIndex!].toInt()} fulfilled, ${donated[_selectedDayIndex!].toInt()} donated',
                          style: TextStyle(fontSize: 12, color: widget.themeColor, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 0),
          ),
          GestureDetector(
            onTapDown: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              double chartWidth = box.size.width - 32;
              double sectionWidth = chartWidth / 7;
              int idx = (details.localPosition.dx / sectionWidth).floor().clamp(0, 6);
              setState(() {
                _selectedDayIndex = _selectedDayIndex == idx ? null : idx;
              });
            },
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(double.infinity, 150),
                  painter: _ImpactChartPainter(
                    accepted: donated,
                    completed: fulfilled,
                    labels: labels,
                    themeColor: widget.themeColor,
                    animationValue: _chartAnimation.value,
                    maxVal: maxVal,
                    personalBestIndex: personalBestIndex,
                    selectedIndex: _selectedDayIndex,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeSection(int totalDonations, Map<String, dynamic> badge) {
    final bool isLegend = badge['next'] == null;
    final int min = badge['min'] as int;
    final int? max = badge['max'] as int?;
    final double progress = isLegend ? 1.0 : ((totalDonations - min) / ((max! - min))).clamp(0.0, 1.0);
    final int toNext = isLegend ? 0 : ((max ?? 0) - totalDonations + 1).clamp(0, 999);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.themeColor.withOpacity(0.10),
                  boxShadow: [BoxShadow(color: widget.themeColor.withOpacity(0.25), blurRadius: 16, spreadRadius: 2)],
                ),
                child: Center(child: Text(badge['emoji'], style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(badge['rank'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.themeColor)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: widget.themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text('$totalDonations donations', style: TextStyle(fontSize: 11, color: widget.themeColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (!isLegend)
                      Text('$toNext more to become ${badge['next']} ${badge['nextEmoji']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500))
                    else
                      Text('Highest rank achieved! 🎉', style: TextStyle(fontSize: 12, color: widget.themeColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [widget.themeColor.withOpacity(0.10), widget.themeColor.withOpacity(0.03)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.themeColor.withOpacity(0.18)),
            ),
            child: Text('"${badge['quote']}"', style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontStyle: FontStyle.italic, height: 1.6, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// IMPACT CHART PAINTER
// =========================================================================
class _ImpactChartPainter extends CustomPainter {
  final List<double> accepted;
  final List<double> completed;
  final List<String> labels;
  final Color themeColor;
  final double animationValue;
  final double maxVal;
  final int personalBestIndex;
  final int? selectedIndex;

  _ImpactChartPainter({
    required this.accepted,
    required this.completed,
    required this.labels,
    required this.themeColor,
    required this.animationValue,
    required this.maxVal,
    required this.personalBestIndex,
    this.selectedIndex,
  });

  static const double _padLeft = 16;
  static const double _padRight = 16;
  static const double _padTop = 24;
  static const double _padBottom = 28;

  Offset _pt(int i, List<double> data, Size size) {
    final int n = data.length;
    final double w = size.width - _padLeft - _padRight;
    final double h = size.height - _padTop - _padBottom;
    double x = _padLeft + (n <= 1 ? w / 2 : (i / (n - 1)) * w);
    double y = _padTop + h - (data[i] / maxVal) * h;
    return Offset(x, y);
  }

  Offset _pathEndpoint(Path path, Size size) {
    Offset last = Offset(
      _padLeft,
      _padTop + (size.height - _padTop - _padBottom),
    );
    for (final metric in path.computeMetrics()) {
      final tangent = metric.getTangentForOffset(metric.length);
      if (tangent != null) last = tangent.position;
    }
    return last;
  }

  Path _buildSmoothPath(List<double> data, Size size) {
    final path = Path();
    final int n = data.length;
    if (n < 2) return path;
    final pts = List.generate(n, (i) => _pt(i, data, size));
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = (i + 2 < pts.length) ? pts[i + 2] : p2;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  Path _revealPath(Path full, double t) {
    if (t >= 1) return full;
    if (t <= 0) return Path();
    final path = Path();
    for (final metric in full.computeMetrics()) {
      path.addPath(metric.extractPath(0, metric.length * t), Offset.zero);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final int n = accepted.length;
    if (n == 0) return;

    final double chartH = size.height - _padTop - _padBottom;

    final Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.14)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      double y = _padTop + (i / 4) * chartH;
      canvas.drawLine(
        Offset(_padLeft, y),
        Offset(size.width - _padRight, y),
        gridPaint,
      );
    }

    if (selectedIndex != null && selectedIndex! < n) {
      Offset selPt = _pt(selectedIndex!, completed, size);
      final Paint selPaint = Paint()
        ..color = themeColor.withOpacity(0.18)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(selPt.dx, _padTop),
        Offset(selPt.dx, _padTop + chartH),
        selPaint,
      );
    }

    final Path fullAcceptedPath = _buildSmoothPath(accepted, size);
    final Path fullCompletedPath = _buildSmoothPath(completed, size);
    final Path animAcceptedPath = _revealPath(fullAcceptedPath, animationValue);
    final Path animCompletedPath = _revealPath(
      fullCompletedPath,
      animationValue,
    );

    if (animationValue > 0 && n >= 2) {
      final Path fillPath = Path.from(animCompletedPath);
      final Offset endPt = _pathEndpoint(animCompletedPath, size);
      fillPath.lineTo(endPt.dx, _padTop + chartH);
      fillPath.lineTo(_pt(0, completed, size).dx, _padTop + chartH);
      fillPath.close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeColor.withOpacity(0.22),
              themeColor.withOpacity(0.02),
            ],
          ).createShader(Rect.fromLTWH(0, _padTop, size.width, chartH))
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      animAcceptedPath,
      Paint()
        ..color = themeColor.withOpacity(0.35)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    canvas.drawPath(
      animCompletedPath,
      Paint()
        ..color = themeColor.withOpacity(0.4)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      animCompletedPath,
      Paint()
        ..color = themeColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    double progress = animationValue * (n - 1);
    int visible = progress.ceil().clamp(0, n - 1);

    for (int i = 0; i <= visible; i++) {
      Offset pt = _pt(i, completed, size);
      bool isSel = selectedIndex == i;
      bool isPB = personalBestIndex == i && completed[i] > 0;

      if (isSel) {
        canvas.drawCircle(
          pt,
          9,
          Paint()..color = themeColor.withOpacity(0.18),
        );
      }
      canvas.drawCircle(pt, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        pt,
        5,
        Paint()
          ..color = themeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (completed[i] > 0) {
        canvas.drawCircle(pt, 3, Paint()..color = themeColor);
      }

      if (isPB) {
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(Icons.star_rounded.codePoint),
            style: TextStyle(
              fontSize: 16,
              fontFamily: Icons.star_rounded.fontFamily,
              package: Icons.star_rounded.fontPackage,
              color: themeColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - 28));
      }
      final lp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 10,
            color: isSel ? themeColor : Colors.grey.shade700,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lp.paint(
        canvas,
        Offset(pt.dx - lp.width / 2, size.height - _padBottom + 6),
      );
    }
  }

  @override
  bool shouldRepaint(_ImpactChartPainter old) =>
      old.animationValue != animationValue ||
      old.selectedIndex != selectedIndex ||
      old.accepted != accepted ||
      old.completed != completed;
}

// =========================================================================
// VOLUNTEER TASK HISTORY CARD
// =========================================================================
class VolunteerTaskHistoryCard extends StatefulWidget {
  final String donationId;
  final Map<String, dynamic> taskData;
  final Color themeColor;
  final String status;

  const VolunteerTaskHistoryCard({
    Key? key,
    required this.donationId,
    required this.taskData,
    required this.themeColor,
    required this.status,
  }) : super(key: key);

  @override
  State<VolunteerTaskHistoryCard> createState() =>
      _VolunteerTaskHistoryCardState();
}

class _VolunteerTaskHistoryCardState extends State<VolunteerTaskHistoryCard> {
  final GlobalKey _shareKey = GlobalKey();

  Future<void> _shareImpactCard(
    BuildContext context,
    String ngoName,
    String itemInfo,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: widget.themeColor)),
    );
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      RenderRepaintBoundary boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      if (context.mounted) Navigator.pop(context);

      String shareMessage =
          "I just completed a delivery of $itemInfo to $ngoName through Fourth Idly!\n\n"
          "Join me in helping families in need. Download Fourth Idly and make an impact today!\n\n"
          "#Fourth Idly #Volunteer #SocialImpact";

      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'charitey_volunteer_impact.png',
      );
      await Share.shareXFiles([xFile], text: shareMessage);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCompleted = widget.status == 'delivery_completed' || widget.status == 'fully_completed' || widget.status == 'completed_awaiting_payment';
    bool isPendingNGO = widget.status == 'pending_ngo_confirmation';

    String itemName =
        widget.taskData['items'] ?? widget.taskData['itemName'] ?? 'Items';
    String ngoName = widget.taskData['ngoName'] ?? 'NGO Partner';
    String ngoLocation =
        widget.taskData['ngoLocation'] ?? 'Location not provided';
    String donorName = widget.taskData['donorName'] ?? 'Donor';
    String donorLocation =
        widget.taskData['donorLocation'] ?? 'Location not provided';
    String rawQty =
        widget.taskData['quantity']?.toString() ??
        widget.taskData['qty']?.toString() ??
        widget.taskData['donatedAmount']?.toString() ??
        '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('ngo_listings')
          .doc(widget.taskData['listingId'])
          .get(),
      builder: (context, snapshot) {
        String unit = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          var listingData = snapshot.data!.data() as Map<String, dynamic>;
          unit = listingData['unit'] ?? '';
          if (listingData['type'] == 'food') {
            itemName = listingData['foodType'] ?? itemName;
          } else {
            itemName = listingData['productName'] ?? itemName;
          }
          if (ngoName == 'NGO Partner' && listingData.containsKey('ngoName')) {
            ngoName = listingData['ngoName'];
          }
          if (ngoLocation == 'Location not provided' &&
              listingData.containsKey('ngoLocation')) {
            ngoLocation = listingData['ngoLocation'];
          }
        }

        String itemInfo = "$rawQty $unit $itemName".trim();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -5000,
              top: -5000,
              child: RepaintBoundary(
                key: _shareKey,
                child: Material(
                  color: Colors.transparent,
                  child: VolunteerShareTemplate(
                    ngoName: ngoName,
                    itemInfo: itemInfo,
                    themeColor: widget.themeColor,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Delivery: $itemName",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.shade50
                              : (isPendingNGO ? Colors.orange.shade50 : widget.themeColor.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green.shade200
                                : (isPendingNGO ? Colors.orange.shade200 : widget.themeColor.withOpacity(0.3)),
                          ),
                        ),
                        child: Text(
                          isCompleted ? "Completed" : (isPendingNGO ? "Waiting for NGO" : "In Transit"),
                          style: TextStyle(
                            color: isCompleted
                                ? Colors.green.shade700
                                : (isPendingNGO ? Colors.orange.shade700 : widget.themeColor),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Delivery Item: $itemInfo",
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PICKUP FROM",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.themeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    donorName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    donorLocation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DELIVER TO (NGO)",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.themeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ngoName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ngoLocation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (widget.status == 'delivery_accepted')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                           bool confirm = await showDialog(
                             context: context,
                             builder: (ctx) => AlertDialog(
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                               title: Row(
                                 children: [
                                   Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 24),
                                   const SizedBox(width: 8),
                                   Text("Confirm Drop-off", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 20)),
                                 ],
                               ),
                               content: const Text(
                                 "Have you physically handed over the items to the NGO?",
                                 style: TextStyle(height: 1.5, fontSize: 15, color: Colors.black87),
                               ),
                               actions: [
                                 TextButton(
                                   onPressed: () => Navigator.pop(ctx, false),
                                   child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                 ),
                                 ElevatedButton(
                                   onPressed: () => Navigator.pop(ctx, true),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.green.shade600,
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                   ),
                                   child: const Text("Yes, Dropped Off", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 ),
                               ],
                             ),
                           ) ?? false;

                           if (!confirm) return; 

                           await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
                              'status': 'pending_ngo_confirmation'
                           });
                           
                           final authProvider = Provider.of<AuthProvider>(context, listen: false);
                           final currentUserId = authProvider.currentFirebaseUser?.uid;
                           final currentUserName = authProvider.currentUserModel?.name ?? 'Volunteer';
                           String ngoId = widget.taskData['ngoId'] ?? widget.taskData['ngold'] ?? '';

                           String notifIdNgo = FirebaseFirestore.instance.collection('notifications').doc().id;
                           NotificationModel ngoNotif = NotificationModel(
                             id: notifIdNgo,
                             receiverId: ngoId, 
                             senderId: currentUserId!,
                             senderName: currentUserName,
                             type: 'delivery_arrived',
                             title: 'Delivery Arrived! 📦',
                             message: '$currentUserName has dropped off $itemName. Please open your profile and confirm receipt to release their payment.',
                             relatedItemId: widget.donationId,
                             createdAt: DateTime.now(),
                             isRead: false,
                           );
                           await FirestoreService().sendNotification(ngoNotif);

                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                               content: Text('NGO Notified! Awaiting their confirmation.'),
                               backgroundColor: Colors.orange,
                             ));
                           }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12)
                        ),
                        child: const Text("Mark Delivery as Completed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else if (isPendingNGO)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                      child: Center(child: Text("Waiting for NGO to confirm receipt...", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold))),
                    )
                  else if (widget.status == 'completed_awaiting_payment')
                     Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)),
                      child: Center(child: Text("Delivery Verified! Awaiting Payment from Donor.", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold))),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _shareImpactCard(context, ngoName, itemInfo),
                        icon: Icon(
                          Icons.share,
                          size: 18,
                          color: widget.themeColor,
                        ),
                        label: Text(
                          "Share Impact",
                          style: TextStyle(
                            color: widget.themeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: widget.themeColor.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// =========================================================================
// VOLUNTEER SHARE TEMPLATE
// =========================================================================
class VolunteerShareTemplate extends StatelessWidget {
  final String ngoName;
  final String itemInfo;
  final Color themeColor;

  const VolunteerShareTemplate({
    Key? key,
    required this.ngoName,
    required this.itemInfo,
    required this.themeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(color: Color(0xFFFDF7F8)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism, color: themeColor, size: 28),
                const SizedBox(width: 10),
                Text(
                  "Fourth Idly",
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              "I delivered",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              itemInfo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    "Safely dropped off to",
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ngoName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Text(
              "Join me as a volunteer and make an impact.",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              "#Fourth Idly Volunteer",
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// ENHANCED DONATION HISTORY CARD
// =========================================================================
class EnhancedDonationHistoryCard extends StatefulWidget {
  final String ngoName;
  final String itemName;
  final String displayDonatedQty;
  final int mathDonatedQty;
  final int totalQty;
  final int fulfilledQty;
  final int remainingQty;
  final String unit;
  final String type;
  final String dateText;
  final String status;
  final bool isCancelled;
  final bool canCancel;
  final Color themeColor;
  final VoidCallback onCancel;

  const EnhancedDonationHistoryCard({
    Key? key,
    required this.ngoName,
    required this.itemName,
    required this.displayDonatedQty,
    required this.mathDonatedQty,
    required this.totalQty,
    required this.fulfilledQty,
    required this.remainingQty,
    required this.unit,
    required this.type,
    required this.dateText,
    required this.status,
    required this.isCancelled,
    required this.canCancel,
    required this.themeColor,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<EnhancedDonationHistoryCard> createState() =>
      EnhancedDonationHistoryCardState();
}

class EnhancedDonationHistoryCardState
    extends State<EnhancedDonationHistoryCard> {
  final GlobalKey _shareKey = GlobalKey();

  Future<void> _shareDonationCard(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: widget.themeColor)),
    );
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      RenderRepaintBoundary boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      if (context.mounted) Navigator.pop(context);

      String formattedQty = widget.displayDonatedQty;
      if (!formattedQty.toLowerCase().contains(RegExp(r'[a-z]')) &&
          widget.unit.isNotEmpty) {
        formattedQty = '$formattedQty ${widget.unit}';
      }

      String shareMessage =
          "I just donated $formattedQty of ${widget.itemName} to ${widget.ngoName} through Fourth Idly!\n\n";
      if (widget.remainingQty > 0 && widget.type.toUpperCase() != 'FOOD') {
        shareMessage +=
            "They still need ${widget.remainingQty} ${widget.unit}. Every contribution helps change lives.\n\n";
      }
      shareMessage +=
          "Join me in helping families in need. Download Fourth Idly and make an impact today!\n\n#Fourth Idly #Donate #SocialImpact";

      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'charitey_impact.png',
      );
      await Share.shareXFiles([xFile], text: shareMessage);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to share card')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = widget.totalQty > 0
        ? (widget.fulfilledQty / widget.totalQty)
        : 0.0;
    bool isFood = widget.type.toUpperCase() == 'FOOD';
    String formattedQty = widget.isCancelled ? "0" : widget.displayDonatedQty;

    if (!formattedQty.toLowerCase().contains(RegExp(r'[a-z]')) &&
        widget.unit.isNotEmpty) {
      formattedQty = '$formattedQty ${widget.unit}';
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -5000,
          top: -5000,
          child: RepaintBoundary(
            key: _shareKey,
            child: Material(
              color: Colors.transparent,
              child: DonationShareTemplate(
                ngoName: widget.ngoName,
                itemName: widget.itemName,
                formattedDonatedQty: formattedQty,
                remainingQty: widget.remainingQty,
                unit: widget.unit,
                totalQty: widget.totalQty,
                fulfilledQty: widget.fulfilledQty,
                type: widget.type,
                themeColor: widget.themeColor,
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: widget.themeColor.withOpacity(0.1),
                    child: Text(
                      widget.ngoName.isNotEmpty
                          ? widget.ngoName[0].toUpperCase()
                          : 'N',
                      style: TextStyle(
                        color: widget.themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.ngoName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Verified Organization",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.itemName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.volunteer_activism,
                          size: 16,
                          color: widget.themeColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "You donated $formattedQty",
                          style: TextStyle(
                            color: widget.themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.type,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!isFood) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${widget.fulfilledQty} collected out of ${widget.totalQty}",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "${widget.remainingQty} needed",
                      style: TextStyle(
                        color: widget.themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.themeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.dateText,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.isCancelled)
                    const Text(
                      'Cancelled by you',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    )
                  else if (widget.canCancel)
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: Text(
                        'Cancel Request',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (widget.status == 'pending')
                    TextButton(
                      onPressed: null,
                      child: Text(
                        '24h Expired',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    
                  if (!widget.isCancelled)
                    ElevatedButton.icon(
                      onPressed: () => _shareDonationCard(context),
                      icon: const Icon(
                        Icons.share,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Share Impact",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// DONATION SHARE TEMPLATE
// =========================================================================
class DonationShareTemplate extends StatelessWidget {
  final String ngoName;
  final String itemName;
  final String formattedDonatedQty;
  final int remainingQty;
  final String unit;
  final int totalQty;
  final int fulfilledQty;
  final String type;
  final Color themeColor;

  const DonationShareTemplate({
    Key? key,
    required this.ngoName,
    required this.itemName,
    required this.formattedDonatedQty,
    required this.remainingQty,
    required this.unit,
    required this.totalQty,
    required this.fulfilledQty,
    required this.type,
    required this.themeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double progress = totalQty > 0 ? (fulfilledQty / totalQty) : 0.0;
    bool isFood = type.toUpperCase() == 'FOOD';

    return Container(
      width: 400,
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(color: Color(0xFFFDF7F8)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism, color: themeColor, size: 28),
                const SizedBox(width: 10),
                Text(
                  "Fourth Idly",
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              "I supported",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ngoName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.verified, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    "I Donated",
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "$formattedDonatedQty of $itemName",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            if (!isFood) ...[
              if (remainingQty > 0) ...[
                Text(
                  "Still Needed: $remainingQty $unit",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$fulfilledQty / $totalQty collected",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ] else ...[
                const Text(
                  "Goal Fully Reached!",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
              ],
            ] else ...[
              Text(
                "Providing essential food relief.",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 30),
            const Text(
              "Every donation changes lives.",
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              "Join me and support families in need.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Text(
              "#Fourth Idly",
              style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// FULL SCREEN IMAGE VIEWER
// =========================================================================
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String name;
  final Color themeColor;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Hero(
            tag: 'profile_$imageUrl',
            child: CircleAvatar(
              radius: MediaQuery.of(context).size.width * 0.42,
              backgroundImage: NetworkImage(imageUrl),
              backgroundColor: themeColor.withOpacity(0.1),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// NGO DUAL RATING DIALOG
// After the NGO submits ratings for the donor (and volunteer, if any), the
// dialog no longer just closes. It switches into a mandatory "Create Post"
// step — the only way to leave the dialog at that point is to tap
// "Create Post Now", which takes the NGO straight into CreatePostScreen.
// =========================================================================
class NgoRatingDialog extends StatefulWidget {
  final String donorId;
  final String donorName;
  final String volunteerId;
  final String volunteerName;
  final String donationId;
  final Color themeColor;

  const NgoRatingDialog({
    Key? key,
    required this.donorId,
    required this.donorName,
    required this.volunteerId,
    required this.volunteerName,
    required this.donationId,
    required this.themeColor,
  }) : super(key: key);

  @override
  State<NgoRatingDialog> createState() => _NgoRatingDialogState();
}

class _NgoRatingDialogState extends State<NgoRatingDialog> {
  int _donorRating = 0;
  int _volunteerRating = 0;
  bool _isSubmitting = false;

  // NEW: once true, the dialog shows the mandatory "Create Post" prompt
  // instead of the rating form.
  bool _showPostPrompt = false;

  Future<void> _updateUserRating(String uid, int newStars) async {
    if (uid.isEmpty || newStars == 0) return;

    DocumentReference ref =
        FirebaseFirestore.instance.collection('users').doc(uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snap = await transaction.get(ref);

      double currentAvg = 0.0;
      int currentTotal = 0;
      if (snap.exists) {
        Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
        currentAvg = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        currentTotal = (data['totalReviews'] as num?)?.toInt() ?? 0;
      }

      double newAvg =
          ((currentAvg * currentTotal) + newStars) / (currentTotal + 1);

      transaction.set(
        ref,
        {
          'averageRating': double.parse(newAvg.toStringAsFixed(1)),
          'totalReviews': currentTotal + 1,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _submitRatings() async {
    if (_donorRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please rate the Donor.')),
      );
      return;
    }
    if (widget.volunteerId.isNotEmpty && _volunteerRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please rate the Volunteer.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _updateUserRating(widget.donorId, _donorRating);
      if (widget.volunteerId.isNotEmpty) {
        await _updateUserRating(widget.volunteerId, _volunteerRating);
      }

      await FirebaseFirestore.instance
          .collection('donations')
          .doc(widget.donationId)
          .update({
        'ngoRated': true,
        'ngoToDonorRating': _donorRating,
        'ngoToVolunteerRating': _volunteerRating,
      });

      if (!mounted) return;

      // CHANGED: don't close the dialog here anymore. Instead, flip it into
      // the mandatory "create a post" prompt — the dialog stays open until
      // the NGO taps through to CreatePostScreen.
      setState(() {
        _isSubmitting = false;
        _showPostPrompt = true;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit ratings: $e')),
      );
    }
  }

  Widget _buildStarRow(int currentRating, Function(int) onRate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return IconButton(
          onPressed: () => onRate(index + 1),
          icon: Icon(
            index < currentRating
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: Colors.amber,
            size: 36,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      }),
    );
  }

  // NEW: the only exit from the post-rating prompt — closes this dialog and
  // pushes straight into CreatePostScreen (the same screen the "+" / Post
  // button on the activity tab opens).
  void _goToCreatePost() {
    final navigator = Navigator.of(context);
    navigator.pop(); // close the rating/prompt dialog
    navigator.push(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
  }

  // NEW: mandatory post-submission prompt UI.
  Widget _buildPostPromptContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Ratings Submitted!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Now let's share this impact with the community. Please create a post about this donation to continue.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _goToCreatePost,
              icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: const Text(
                "Create Post Now",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingFormContent(bool hasVolunteer) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.amber,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Rate Your Experience",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Text(
            "Rate the Donor: ${widget.donorName}",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _buildStarRow(
            _donorRating,
            (r) => setState(() => _donorRating = r),
          ),
          if (hasVolunteer) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              "Rate the Volunteer: ${widget.volunteerName}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _buildStarRow(
              _volunteerRating,
              (r) => setState(() => _volunteerRating = r),
            ),
          ],
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRatings,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      "Submit Ratings",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Skip for now",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasVolunteer = widget.volunteerId.isNotEmpty;

    return WillPopScope(
      // NEW: once ratings are submitted and the "create post" prompt is
      // showing, block the Android back button too — the NGO must tap
      // "Create Post Now" to proceed. This is what makes the post-review
      // navigation compulsory rather than optional.
      onWillPop: () async => !_showPostPrompt,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: _showPostPrompt
            ? _buildPostPromptContent()
            : _buildRatingFormContent(hasVolunteer),
      ),
    );
  }
}