import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/ngo_listing_model.dart';
import '../models/donation_model.dart';
import '../models/notification_model.dart'; 
import '../providers/auth_provider.dart';

class DonationPage extends StatefulWidget {
  final NgoListingModel listing;

  const DonationPage({Key? key, required this.listing}) : super(key: key);

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  final Color themeColor = const Color(0xFF7D444C); // Matched to new darker theme

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
      if (user != null) {
        _nameController.text = user.name;
        _locationController.text = user.location;
        _phoneController.text = user.phone;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _donate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found. Please log in again.')));
      return;
    }

    String name = _nameController.text.trim();
    String location = _locationController.text.trim();
    String phone = _phoneController.text.trim();

    if (name.isEmpty || location.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String newDonationId = FirebaseFirestore.instance.collection('donations').doc().id;

      DonationModel donation = DonationModel(
        donationId: newDonationId, 
        listingId: widget.listing.listingId,
        ngoId: widget.listing.ngoId,
        donorId: user.uid,
        donorName: name,
        donorPhone: phone,
        donorLocation: location,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _firestoreService.processDonation(donation);

      String itemName = widget.listing.type == 'food' 
          ? (widget.listing.foodType ?? "Food") 
          : (widget.listing.productName ?? "Items");

      NotificationModel alert = NotificationModel(
        id: FirebaseFirestore.instance.collection('notifications').doc().id,
        receiverId: widget.listing.ngoId, 
        senderId: user.uid,               
        senderName: name,
        type: 'donation_offer',
        title: 'New Donation Offer! 🎉',
        message: '$name wants to donate $itemName to you. Tap to view details and start chatting.',
        relatedItemId: newDonationId,     
        createdAt: DateTime.now(),
      );

      await _firestoreService.sendNotification(alert);

      if (!mounted) return;

      // --- "BOOM" SUCCESS ANIMATION DIALOG ---
      showGeneralDialog(
        context: context,
        barrierDismissible: false, 
        barrierColor: Colors.black.withValues(alpha: 0.6), 
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.elasticOut), 
            ),
            child: FadeTransition(
              opacity: animation,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.all(30),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.volunteer_activism_rounded, color: themeColor, size: 60),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Donation Confirmed!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Your generosity is making a real difference. An NGO will review this shortly.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); 
                          Navigator.pop(context); 
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Awesome!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Donation failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Confirm Donation', 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context), 
        ),
      ),
      body: Stack(
        children: [
          // BACKGROUND GRADIENT
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    themeColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // FOREGROUND CONTENT
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 20, 
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          
                          // --- "RECEIPT" SUMMARY CARD ---
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.05),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TARGET NGO', 
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor, letterSpacing: 1.0),
                                      ),
                                      Icon(Icons.verified_rounded, size: 16, color: themeColor),
                                    ],
                                  ),
                                ),
                                
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.listing.ngoName, 
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              widget.listing.ngoLocation, 
                                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 20.0),
                                        child: Divider(height: 1, thickness: 1.5), 
                                      ),
                                      
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Item to Donate', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                              const SizedBox(height: 4),
                                              Text(
                                                widget.listing.type == 'food' 
                                                    ? (widget.listing.foodType ?? "Food") 
                                                    : (widget.listing.productName ?? "Product"),
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('Quantity', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: themeColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${widget.listing.quantity ?? ""} ${widget.listing.unit ?? ""}'.trim(),
                                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // --- FORM HEADER ---
                          const Text(
                            'Your Pickup Details', 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Where should the NGO meet you?', 
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 16),

                          // --- NEW: VOLUNTEER ALERT BANNER ---
                          if (widget.listing.isVolunteerAvailable == true) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.directions_run_rounded, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Good News! Volunteer Available",
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "This NGO has a volunteer ready to pick up your donation. Just confirm your address below.",
                                          style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // --- INPUT FIELDS ---
                          _buildInputField(
                            hint: 'Your Full Name', 
                            icon: Icons.person_outline_rounded, 
                            controller: _nameController,
                          ),
                          const SizedBox(height: 12),
                          
                          _buildInputField(
                            hint: 'Exact Pickup Location', 
                            icon: Icons.location_on_outlined, 
                            controller: _locationController,
                          ),
                          const SizedBox(height: 12),
                          
                          _buildInputField(
                            hint: 'Contact Phone Number', 
                            icon: Icons.phone_outlined, 
                            controller: _phoneController, 
                            keyboardType: TextInputType.phone,
                          ),
                          
                          const SizedBox(height: 24),

                          // --- WARM IMPACT NOTE ---
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: themeColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.favorite_rounded, color: themeColor, size: 24), 
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    "Your donation will directly help reduce food waste and feed those in need. Thank you!",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                          const SizedBox(height: 20),
                          
                          // --- SUBMIT BUTTON ---
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _donate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                elevation: 4,
                                shadowColor: themeColor.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isLoading 
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text(
                                      'CONFIRM DONATION', 
                                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                    ),
                            ),
                          ),
                          
                          // Small security text
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, bottom: 20.0),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Your details are shared securely with the NGO",
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({required String hint, required IconData icon, required TextEditingController controller, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  } 
}