// donation_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // 👇 NEW
import 'package:geocoding/geocoding.dart'; // 👇 NEW
import 'package:geolocator/geolocator.dart'; // 👇 NEW

import '../services/firestore_service.dart';
import '../models/ngo_listing_model.dart';
import '../models/donation_model.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../services/fare_calculator.dart';
import '../services/location_service.dart';
import 'location_picker_screen.dart'; // 👇 NEW: For map picking
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';

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
  final TextEditingController _donationQuantityController = TextEditingController();
  
  bool _isLoading = false;
  bool _isConfirmed = false;
  final Color themeColor = const Color(0xFF7D444C);
  int totalNeeded = 0;
  int alreadyFulfilled = 0;
  int remainingNeeded = 0;
  double _sliderValue = 0.0;

  // 👇 NEW: Variables for Distance Math 👇
  LatLng? _donorLatLng;
  double _distanceKm = 0.0;
  double _calculatedFee = 0.0;

  @override
  void initState() {
    super.initState();
    BirdImageCache().load().then((_) {
      if (mounted) setState(() {});
    });
    totalNeeded = widget.listing.quantity ?? 0;
    alreadyFulfilled = widget.listing.fulfilledQuantity ?? 0;
    remainingNeeded = totalNeeded - alreadyFulfilled;
    if (remainingNeeded < 0) remainingNeeded = 0;
    if (widget.listing.type == 'product') {
      _donationQuantityController.text = remainingNeeded.toString();
      _sliderValue = remainingNeeded.toDouble();
    }
    _donationQuantityController.addListener(_updateSliderFromText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUserModel;
      if (user != null) {
        _nameController.text = user.name;
        _locationController.text = user.location;
        _phoneController.text = user.phone;
      }
    });
  }

  void _updateSliderFromText() {
    if (_donationQuantityController.text.isEmpty) {
      setState(() => _sliderValue = 0.0);
      return;
    }
    double? val = double.tryParse(_donationQuantityController.text);
    if (val != null) {
      if (val > remainingNeeded) val = remainingNeeded.toDouble();
      if (val < 0) val = 0.0;
      setState(() => _sliderValue = val!);
    }
  }

  @override
  void dispose() {
    _donationQuantityController.removeListener(_updateSliderFromText);
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _donationQuantityController.dispose();
    super.dispose();
  }

  // 👇 NEW: Opens the map to get Donor's exact coordinates 👇
  Future<void> _selectDonorLocation() async {
    final LatLng? picked = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );
    if (picked != null) {
      setState(() => _donorLatLng = picked);
      await _getAddressFromCoordinates(picked);
    }
  }

  // 👇 NEW: Converts coordinates to a clean address string 👇
  Future<void> _getAddressFromCoordinates(LatLng coords) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(coords.latitude, coords.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _locationController.text = "${p.street ?? p.name ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}, ${p.postalCode ?? ''}".replaceAll(RegExp(r'^,\s*'), '').trim();
        });
      }
    } catch (_) {
      setState(() {
        _locationController.text = "Pinned Location on Map";
      });
    }
  }

  String? _validateAddress(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return 'Please enter your pickup address';
    }
    // We bypass strict manual check if they used the map picker
    if (_donorLatLng != null) return null;

    final pincodeRegex = RegExp(r'\b\d{6}\b');
    final hasPincode = pincodeRegex.hasMatch(text);
    if (!hasPincode) {
      return 'Please include your 6-digit pincode (e.g., 641001)';
    }
    final textParts = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(e)).toList();
    if (textParts.length < 2) {
      return 'Please Type your Full Address with City and Country';
    }
    return null; 
  }

  Future<void> donate() async {
    if (!_isConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm that you have donated this item')),
      );
      return;
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please log in again.')),
      );
      return;
    }
    
    String name = _nameController.text.trim();
    String location = _locationController.text.trim();
    String phone = _phoneController.text.trim();
    int inputDonatedAmount = remainingNeeded;
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your full name')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your contact phone number')));
      return;
    }

    final addressError = _validateAddress(location);
    if (addressError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(addressError)));
      return;
    }

    // 👇 PHASE 2 MATH: Distance & Fee Calculation 👇
    if (widget.listing.isVolunteerAvailable == false) {
      if (_donorLatLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please tap the map icon to pin your exact pickup location for the volunteer.')),
        );
        return;
      }

      if (widget.listing.pickupLat != null && widget.listing.pickupLng != null) {
        double distanceMeters = Geolocator.distanceBetween(
          _donorLatLng!.latitude,
          _donorLatLng!.longitude,
          widget.listing.pickupLat!,
          widget.listing.pickupLng!,
        );

        final double straightDistanceKm = distanceMeters / 1000;
        final double? routeDistanceKm = await LocationHelperService.getRouteDistanceKm(
          originLat: _donorLatLng!.latitude,
          originLng: _donorLatLng!.longitude,
          destLat: widget.listing.pickupLat!,
          destLng: widget.listing.pickupLng!,
        );

        final double distanceKm = routeDistanceKm ?? straightDistanceKm;
        _distanceKm = distanceKm;

        // Use the shared vehicle fare calculator so volunteer pricing stays
        // consistent across donor and volunteer screens.
        // The listing model does not carry a vehicle field, so we default to
        // bike for now and keep the logic centralized in FareCalculator.
        _calculatedFee = FareCalculator.calculate(
          vehicle: VehicleType.bike,
          distanceKm: distanceKm,
        );
      }
    }
    // 👆 END MATH 👆

    if (widget.listing.type == 'product') {
      final inputQty = int.tryParse(_donationQuantityController.text.trim());
      if (inputQty == null || inputQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid donation quantity')));
        return;
      }
      if (inputQty > remainingNeeded) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You cannot donate more than remaining items needed ($remainingNeeded)')));
        return;
      }
      inputDonatedAmount = inputQty;
    }

    setState(() => _isLoading = true);
    
    try {
      String newDonationId = FirebaseFirestore.instance.collection('donations').doc().id;
      String newNotificationId = FirebaseFirestore.instance.collection('notifications').doc().id;
      
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
        donatedQuantity: inputDonatedAmount,
        
        // 👇 NEW: Attaching Phase 2 Math Data 👇
        deliveryFee: _calculatedFee > 0 ? _calculatedFee : null,
        distanceKm: _distanceKm > 0 ? _distanceKm : null,
        donorLat: _donorLatLng?.latitude,
        donorLng: _donorLatLng?.longitude,
      );

      String itemName = widget.listing.type == 'food'
          ? (widget.listing.foodType ?? "Food")
          : "$inputDonatedAmount ${widget.listing.unit ?? 'Items'} of ${widget.listing.productName ?? 'Products'}";
          
      NotificationModel alertForNGO = NotificationModel(
        id: newNotificationId,
        receiverId: widget.listing.ngoId,
        senderId: user.uid,
        senderName: name,
        type: 'donation_offer',
        title: 'New Donation Offer! 🎉',
        message: '$name wants to donate $itemName to you. Tap to view details and start chatting.',
        relatedItemId: newDonationId,
        createdAt: DateTime.now(),
        isRead: false,
      );
      
      NotificationModel alertForDonor = NotificationModel(
        id: FirebaseFirestore.instance.collection('notifications').doc().id,
        receiverId: user.uid,
        senderId: widget.listing.ngoId,
        senderName: widget.listing.ngoName,
        type: 'donation_offer',
        title: 'Donation Confirmed! ✅',
        message: 'Thank you for offering $itemName! Tap to view details and start a chat with the NGO.',
        relatedItemId: newDonationId,
        createdAt: DateTime.now(),
        isRead: false,
      );
      
      await _firestoreService.processDonation(
        donation: donation,
        notification: alertForNGO,
      );
      
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(newDonationId)
          .update({'quantity': inputDonatedAmount});
          
      await _firestoreService.sendNotification(alertForDonor);
      
      if (!mounted) return;
      
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.6),
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
                        color: themeColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.volunteer_activism_rounded, color: themeColor, size: 60),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Donation Confirmed! ✅",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Your generosity is making a real difference. An NGO will review this shortly.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
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
                        child: const Text(
                          "Awesome!",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Donation failed: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildInputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E4E8),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Confirm Donation',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
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
                  colors: [themeColor.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 10.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 20,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          // TARGET NGO CARD 
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
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
                                    color: themeColor.withOpacity(0.05),
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: themeColor,
                                          letterSpacing: 1.0,
                                        ),
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
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Item to Donate',
                                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                              ),
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
                                              Text(
                                                widget.listing.type == 'food' ? 'Quantity' : 'Total Request',
                                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: themeColor.withOpacity(0.1),
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
                                      if (widget.listing.description != null && widget.listing.description!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text('Description:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                        const SizedBox(height: 6),
                                        Text(widget.listing.description!, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
                                      ],
                                      if (widget.listing.type == 'product') ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('Already Received:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                                  Text('$alreadyFulfilled ${widget.listing.unit ?? ""}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('Remaining Needed:', style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.w600)),
                                                  Text('$remainingNeeded ${widget.listing.unit ?? ""}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor)),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: LinearProgressIndicator(
                                                  value: totalNeeded > 0 ? (alreadyFulfilled / totalNeeded) : 0,
                                                  backgroundColor: Colors.grey.shade200,
                                                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Slider Section
                          if (widget.listing.type == 'product') ...[
                            const Text(
                              'Specify Your Donation Quantity',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'How many ${widget.listing.unit ?? "items"} are you able to provide today?',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 12),
                            _buildInputField(
                              hint: 'Enter quantity (Max: $remainingNeeded)',
                              icon: Icons.numbers_rounded,
                              controller: _donationQuantityController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: themeColor,
                                inactiveTrackColor: themeColor.withOpacity(0.2),
                                thumbColor: themeColor,
                                overlayColor: themeColor.withOpacity(0.1),
                                trackHeight: 8.0,
                                thumbShape: BirdSliderThumb(thumbRadius: 20.0, thumbColor: themeColor),
                              ),
                              child: Slider(
                                value: _sliderValue,
                                min: 0,
                                max: remainingNeeded > 0 ? remainingNeeded.toDouble() : 1.0,
                                divisions: remainingNeeded > 0 ? remainingNeeded : 1,
                                onChanged: remainingNeeded > 0
                                    ? (value) {
                                        setState(() {
                                          _sliderValue = value;
                                          _donationQuantityController.value = TextEditingValue(
                                            text: value.toInt().toString(),
                                            selection: TextSelection.collapsed(offset: value.toInt().toString().length),
                                          );
                                        });
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // Pickup Details
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
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
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
                                          widget.listing.type == 'product'
                                              ? "This NGO has a volunteer ready to pick up your donation. Since they are coming to you, please consider donating as many items as possible! Just confirm your address below."
                                              : "This NGO has a volunteer ready to pick up your donation. Just confirm your address below.",
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
                          
                          if (widget.listing.isVolunteerAvailable == false) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5),
                              ),
                              child: Text(
                                "The NGO has requested a platform volunteer for this pickup. There may be a slight delay, but you will be notified instantly the moment a volunteer accepts the task.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: themeColor.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0.3),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          _buildInputField(
                            hint: 'Your Full Name',
                            icon: Icons.person_outline_rounded,
                            controller: _nameController,
                          ),
                          const SizedBox(height: 12),
                          
                          // 👇 NEW: Location Field with Map Picker 👇
                         GestureDetector(
  onTap: _selectDonorLocation,
  child: _buildInputField(
    hint: widget.listing.isVolunteerAvailable == false 
        ? 'Tap to Pin Pickup Location 📍' 
        : 'Area, City, Country, Pincode',
    icon: _donorLatLng == null ? Icons.location_on_outlined : Icons.location_on_rounded,
    controller: _locationController,
    readOnly: widget.listing.isVolunteerAvailable == false,// Force map if volunteer needed
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _donorLatLng == null ? Icons.map_rounded : Icons.check_circle_rounded, 
                                  color: _donorLatLng == null ? themeColor : Colors.green
                                ),
                                onPressed: _selectDonorLocation,
                              ),
                            ),
                          ),
                          
                          if (widget.listing.isVolunteerAvailable != false)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                'e.g., 12 Mill Road, Coimbatore, India, 641001',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          const SizedBox(height: 12),
                          
                          _buildInputField(
                            hint: 'Contact Phone Number',
                            icon: Icons.phone_outlined,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 24),
                          
                          // Confirmation Checkbox
                          GestureDetector(
                            onTap: () => setState(() => _isConfirmed = !_isConfirmed),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _isConfirmed ? themeColor.withOpacity(0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _isConfirmed ? themeColor : Colors.grey.shade300,
                                  width: _isConfirmed ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _isConfirmed ? themeColor : Colors.grey.shade400, width: 2),
                                      borderRadius: BorderRadius.circular(6),
                                      color: _isConfirmed ? themeColor : Colors.white,
                                    ),
                                    child: _isConfirmed ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Are you sure you want to donate this item? Once confirmed, your donation request will be sent to the NGO.",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _isConfirmed ? themeColor : Colors.grey.shade700,
                                        fontWeight: _isConfirmed ? FontWeight.w600 : FontWeight.normal,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 20),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : donate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                elevation: 4,
                                shadowColor: themeColor.withOpacity(0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'CONFIRM DONATION',
                                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                    ),
                            ),
                          ),
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
}

// BirdImageCache and BirdSliderThumb
class BirdImageCache extends ChangeNotifier {
  static final BirdImageCache _instance = BirdImageCache._internal();
  factory BirdImageCache() => _instance;
  BirdImageCache._internal();
  ui.Image? image;
  bool _isLoading = false;
  Future<void> load() async {
    if (image != null || _isLoading) return;
    _isLoading = true;
    try {
      final ByteData data = await rootBundle.load('assets/charitey_bird.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      image = await completer.future;
      notifyListeners();
    } catch (e) {
      debugPrint('Bird image load error: $e');
    }
    _isLoading = false;
  }
}

class BirdSliderThumb extends SliderComponentShape {
  final double thumbRadius;
  final Color thumbColor;
  const BirdSliderThumb({required this.thumbRadius, required this.thumbColor});
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(thumbRadius);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final double size = thumbRadius * 5;
    final ui.Image? img = BirdImageCache().image;
    if (img != null) {
      final Paint paint = Paint()..colorFilter = ColorFilter.mode(thumbColor, BlendMode.srcIn);
      final Rect srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final Rect dstRect = Rect.fromCenter(center: center, width: size, height: size);
      canvas.drawImageRect(img, srcRect, dstRect, paint);
    } else {
      final Paint fallback = Paint()..color = thumbColor;
      canvas.drawCircle(center, thumbRadius, fallback);
    }
  }
}