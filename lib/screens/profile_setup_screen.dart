//profile_setup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/fare_calculator.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String role;
  const ProfileSetupScreen({super.key, required this.role});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();

  // Controllers & State for Volunteer Profession Step
  final TextEditingController professionController = TextEditingController();
  String? _selectedProfessionType;
  VehicleType? _selectedVehicle;

  // Controller for Volunteer UPI ID Step
  final TextEditingController upiController = TextEditingController();

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isCheckingUsername = false;
  bool agreedToTerms = false;
  final Color themeColor = const Color(0xFFB56F76);

  @override
  void dispose() {
    _pageController.dispose();
    nameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    licenseController.dispose();
    professionController.dispose();
    upiController.dispose();
    super.dispose();
  }

  // 👇 UPDATED: Volunteers now have 8 pages (Image, Name, Profession, Phone,
  // UPI ID, Vehicle, Location, License). Travel agency stays at 7 (no
  // Profession step). Vehicle step is now shared by BOTH roles, right after
  // the UPI step, matching the flow order Raj wants.
  int get _totalPages {
    if (widget.role == "volunteer") {
      return 8; // Image, Name, Profession, Phone, UPI, Vehicle, Location, License
    }
    if (widget.role == "travel_agency") {
      return 7; // Image, Name, Phone, UPI, Vehicle, Location, License
    }
    if (widget.role == "ngo") {
      return 5; // Image, Name, Phone, Location, License
    }
    return 4; // Donors: Image, Name, Phone, Location
  }

  bool _isValidNGOLicense(String value) {
    final cleaned = value.trim().toUpperCase();
    final regex = RegExp(r'^TN\/(19|20)\d{2}\/\d{7}$');
    return regex.hasMatch(cleaned);
  }

  bool _isValidDrivingLicense(String value) {
    final cleaned = value.trim().toUpperCase().replaceAll(
      RegExp(r'[\s\-]'),
      '',
    );
    final regex = RegExp(r'^TN\d{2}(19|20)\d{2}\d{7}$');
    return regex.hasMatch(cleaned);
  }

  bool _isValidRegistrationNo(String value) {
    final cleaned = value.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z0-9\/\-]{5,20}$');
    return regex.hasMatch(cleaned);
  }

  // UPI ID Format Validation (e.g., name@upi, 9876543210@paytm)
  bool get _isUpiFormatValid {
    String value = upiController.text.trim().toLowerCase();
    final upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    return upiRegex.hasMatch(value);
  }

  bool get _isLicenseFormatValid {
    String value = licenseController.text.trim();
    if (value.isEmpty) return false;
    if (widget.role == 'ngo') return _isValidNGOLicense(value);
    if (widget.role == 'volunteer') return _isValidDrivingLicense(value);
    if (widget.role == 'travel_agency') return _isValidRegistrationNo(value);
    return value.isNotEmpty;
  }

  // 👇 UPDATED: volunteer branch now has a Vehicle step at index 5, pushing
  // Location to 6 and License to 7 (previously 5 and 6).
  bool get _isCurrentPageValid {
    bool isValid = true;

    if (_currentPage == 0) {
      isValid = true;
    } else if (_currentPage == 1) {
      isValid = nameController.text.trim().isNotEmpty &&
          usernameController.text.trim().isNotEmpty;
    } else if (widget.role == 'volunteer') {
      if (_currentPage == 2) {
        if (_selectedProfessionType == 'Student') {
          isValid = true;
        } else if (_selectedProfessionType == 'Professional') {
          isValid = professionController.text.trim().isNotEmpty;
        } else {
          isValid = false;
        }
      } else if (_currentPage == 3) {
        isValid = phoneController.text.trim().length == 10;
      } else if (_currentPage == 4) {
        isValid = _isUpiFormatValid; // Validates UPI ID page
      } else if (_currentPage == 5) {
        isValid = _selectedVehicle != null; // 👈 NEW: Vehicle step
      } else if (_currentPage == 6) {
        isValid = addressController.text.trim().isNotEmpty; // shifted from 5
      } else if (_currentPage == 7) {
        isValid = _isLicenseFormatValid; // shifted from 6
      }
    } else if (widget.role == 'travel_agency') {
      if (_currentPage == 2) {
        isValid = phoneController.text.trim().length == 10;
      } else if (_currentPage == 3) {
        isValid = _isUpiFormatValid;
      } else if (_currentPage == 4) {
        isValid = _selectedVehicle != null;
      } else if (_currentPage == 5) {
        isValid = addressController.text.trim().isNotEmpty;
      } else if (_currentPage == 6) {
        isValid = _isLicenseFormatValid;
      }
    } else if (widget.role == 'ngo') {
      if (_currentPage == 2) {
        isValid = phoneController.text.trim().length == 10;
      } else if (_currentPage == 3) {
        isValid = addressController.text.trim().isNotEmpty;
      } else if (_currentPage == 4) {
        isValid = _isLicenseFormatValid;
      }
    } else {
      if (_currentPage == 2) {
        isValid = phoneController.text.trim().length == 10;
      } else if (_currentPage == 3) {
        isValid = addressController.text.trim().isNotEmpty;
      }
    }

    if (_currentPage == _totalPages - 1) {
      return isValid && agreedToTerms;
    }
    return isValid;
  }

  void _onFieldChanged(String value) {
    setState(() {});
  }

  // Confirmation Dialog for UPI ID
  Future<bool> _showUpiConfirmationDialog(String upiId) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          color: themeColor, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Confirm Payment UPI ID",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF2D3142),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                        children: [
                          const TextSpan(text: "All donor delivery fee payments will be sent directly to:\n\n"),
                          TextSpan(
                            text: upiId,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: themeColor,
                            ),
                          ),
                          const TextSpan(text: "\n\nPlease ensure this address is active and accurate."),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              "Edit ID",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Confirm"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  Future<void> _nextPage() async {
    // Username Check
    if (_currentPage == 1) {
      String desiredUsername = usernameController.text.trim().toLowerCase();
      bool hasLetter = RegExp(r'[a-z]').hasMatch(desiredUsername);
      bool hasNumber = RegExp(r'[0-9]').hasMatch(desiredUsername);
      bool hasUnderscore = desiredUsername.contains('_');
      bool hasInvalidChars = RegExp(r'[^a-z0-9_]').hasMatch(desiredUsername);

      if (!hasLetter || !hasNumber || !hasUnderscore || hasInvalidChars) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Username must include at least 1 letter, 1 number, and 1 underscore (_). No spaces allowed.",
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() => _isCheckingUsername = true);
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: desiredUsername)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "The username '@$desiredUsername' is already taken. Please choose another.",
                ),
              ),
            );
          }
          setState(() => _isCheckingUsername = false);
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error checking username: $e")),
          );
        }
        setState(() => _isCheckingUsername = false);
        return;
      }
      setState(() => _isCheckingUsername = false);
    }

    // 👇 UPDATED: UPI confirmation dialog trigger — volunteer's UPI page is
    // now index 4 (unchanged), travel_agency's is index 3 (unchanged).
    if ((widget.role == 'volunteer' && _currentPage == 4) ||
        (widget.role == 'travel_agency' && _currentPage == 3)) {
      bool confirmed = await _showUpiConfirmationDialog(upiController.text.trim().toLowerCase());
      if (!confirmed) return; // Stay on page if user clicks "Edit ID"
    }

    if (_currentPage < _totalPages - 1) {
      // 👇 UPDATED: Vehicle validation now checked for BOTH roles —
      // travel_agency at index 4, volunteer at index 5.
      if (((widget.role == 'travel_agency' && _currentPage == 4) ||
              (widget.role == 'volunteer' && _currentPage == 5)) &&
          _selectedVehicle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select the vehicle you'll use for deliveries."),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    } else {
      // 👇 UPDATED: final-page vehicle guard now covers both roles.
      if ((widget.role == 'travel_agency' || widget.role == 'volunteer') &&
          _selectedVehicle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select the vehicle you'll use for deliveries."),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      _saveProfile();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  String _getTermsText() {
    const generalTerms =
        "General Terms & Conditions:\n\n1. Charitey is a platform connecting donors, NGOs, and volunteers.\n\n2. Users are responsible for complying with applicable laws.\n\n3. Charitey reserves the right to modify these Terms & Conditions.\n\n4. Continued use of the platform indicates acceptance of the latest policies.\n\nAgreement:\n\nBy selecting \"I Agree\", you confirm that you have read, understood, and accepted these Terms & Conditions.";

    if (widget.role == 'ngo') {
      return "NGO Terms & Conditions:\n\n1. Organization details and documents submitted are genuine and accurate.\n\n2. Donations will only be used for charitable purposes.\n\n3. Accepted donations will be collected within the agreed timeframe.\n\n4. Donated items will not be resold or misused.\n\n5. You will maintain respectful communication with donors and volunteers.\n\n6. Donor information will remain confidential.\n\n7. Any disputes or suspicious activities will be reported to Charitey.\n\n8. Charitey may verify your organization at any time.\n\n9. Policy violations may result in suspension or permanent removal.\n\n$generalTerms";
    } else if (widget.role == 'donor') {
      return "Donor Terms & Conditions:\n\n1. All donated items are safe, clean, legal, and in usable condition.\n\n2. Food donations are hygienically prepared and safe for consumption.\n\n3. You will provide accurate donation, pickup, and contact details.\n\n4. You will be available during the agreed pickup schedule.\n\n5. You will not cancel an accepted donation without a valid reason.\n\n6. You will not donate expired, damaged, hazardous, or prohibited items.\n\n7. You will communicate respectfully with NGOs and volunteers.\n\n8. False information or misuse may result in account suspension.\n\n9. Charitey may verify donations before approval.\n\n10. Repeated policy violations may lead to permanent account removal.\n\n$generalTerms";
    } else if (widget.role == 'travel_agency') {
      return "Travel Agency Terms & Conditions:\n\n1. Timeliness: You agree to transport donations safely and timely to the designated NGO locations.\n\n2. Vehicle Information: You must provide accurate vehicle, driver, and tracking details to ensure transparency.\n\n3. No Hidden Fees: You agree to not charge extra fees outside the initial platform agreement.\n\n4. Goods Handling: You are responsible for handling all donated items with extreme care to prevent damage or spoilage during transit.\n\n$generalTerms";
    } else if (widget.role == 'volunteer') {
      return "Volunteer Terms & Conditions:\n\n1. You will complete assigned pickups and deliveries responsibly.\n\n2. You will handle donated items carefully and safely.\n\n3. Delivery fees paid directly by donors must match the pre-calculated platform rate.\n\n4. You will maintain professional and respectful behaviour.\n\n5. You will protect the privacy of donors and NGOs.\n\n6. You will report accidents, delays, or issues immediately.\n\n7. You will follow Charitey's safety guidelines and platform policies.\n\n8. Misconduct or repeated cancellations may result in suspension.\n\n$generalTerms";
    }
    return generalTerms;
  }

  void _showTermsPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 10,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: themeColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Terms & Conditions",
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F0F0),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      _getTermsText(),
                      style: const TextStyle(
                        height: 1.6,
                        color: Color(0xFF4A4A4A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F0F0),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => agreedToTerms = true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "I Agree",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = _buildPages();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: Text(
          "${widget.role.toUpperCase().replaceAll('_', ' ')} SETUP",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: _previousPage,
              )
            : null,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                (Route<dynamic> route) => false,
              );
            },
            child: Text(
              "Skip",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    children: List.generate(
                      _totalPages,
                      (index) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          height: 6,
                          decoration: BoxDecoration(
                            color: index <= _currentPage
                                ? themeColor
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (int page) =>
                        setState(() => _currentPage = page),
                    children: pages,
                  ),
                ),
                // BOTTOM CONTAINER
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentPage == _totalPages - 1)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 16.0,
                              left: 4.0,
                              right: 4.0,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: agreedToTerms,
                                    activeColor: themeColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        agreedToTerms = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _showTermsPopup,
                                    child: RichText(
                                      text: TextSpan(
                                        text: "I have read and agree to the ",
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: "Terms & Conditions",
                                            style: TextStyle(
                                              color: themeColor,
                                              fontWeight: FontWeight.bold,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade500,
                              elevation: _isCurrentPageValid ? 4 : 0,
                              shadowColor: themeColor.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed:
                                (_isCurrentPageValid && !_isCheckingUsername)
                                    ? _nextPage
                                    : null,
                            child: _isCheckingUsername
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _getButtonText(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText() {
    if (_currentPage == 0 &&
        _selectedImage == null &&
        _selectedImageBytes == null) return "SKIP PHOTO";
    if (_currentPage == _totalPages - 1) return "COMPLETE SETUP";
    return "CONTINUE";
  }

  // 👇 UPDATED: Vehicle step now added for BOTH 'volunteer' and
  // 'travel_agency' roles, immediately after the UPI step and before Address.
  List<Widget> _buildPages() {
    List<Widget> pages = [
      _buildImageStep(),
      _buildNameStep(),
    ];

    if (widget.role == "volunteer") {
      pages.add(_buildProfessionStep());
    }

    pages.add(_buildPhoneStep());

    if (widget.role == "volunteer" || widget.role == "travel_agency") {
      pages.add(_buildUpiStep());
    }
    if (widget.role == "volunteer" || widget.role == "travel_agency") {
      pages.add(_buildVehicleTypeStep()); // 👈 now shared by both roles
    }

    pages.add(_buildAddressStep());

    if (widget.role == "ngo" ||
        widget.role == "travel_agency" ||
        widget.role == "volunteer") {
      pages.add(_buildLicenseStep());
    }
    return pages;
  }

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget child,
    IconData? icon,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 40, color: themeColor),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3142),
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        });
      } else {
        setState(() {
          _selectedImage = File(picked.path);
          _selectedImageBytes = null;
        });
      }
    }
  }

  Widget _buildImageStep() {
    return _buildStepContainer(
      title: "Add a Photo",
      subtitle: "Help your community recognize you easily",
      child: Center(
        child: GestureDetector(
          onTap: _pickProfileImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.2),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (_selectedImage == null && _selectedImageBytes == null)
                      ? Icon(
                          Icons.person_rounded,
                          size: 70,
                          color: Colors.grey.shade300,
                        )
                      : kIsWeb
                      ? Image.memory(
                          _selectedImageBytes!,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          _selectedImage!,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
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
        onChanged: _onFieldChanged,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          counterText: '',
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: themeColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    String label = widget.role == "ngo"
        ? "NGO Name"
        : (widget.role == "travel_agency" ? "Agency Name" : "Full Name");
    return _buildStepContainer(
      title: "What's your name?",
      subtitle: "Let us know how to address you",
      icon: Icons.badge_rounded,
      child: Column(
        children: [
          _buildTextField(
            controller: nameController,
            label: label,
            hint: "Enter $label",
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: usernameController,
            label: "Unique Username",
            hint: "e.g. safrin_99",
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 6),
          Text(
            "Must include 1 letter, 1 number, and 1 underscore.",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionStep() {
    return _buildStepContainer(
      title: "Your Profession",
      subtitle: "Help us understand your background better",
      icon: Icons.work_outline_rounded,
      child: Column(
        children: [
          _buildProfessionOption("Student", Icons.school_rounded),
          const SizedBox(height: 12),
          _buildProfessionOption("Professional", Icons.business_center_rounded),
          
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _selectedProfessionType == 'Professional'
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildTextField(
                      controller: professionController,
                      label: "Specific Profession",
                      hint: "e.g. Software Engineer, Teacher",
                      icon: Icons.work_rounded,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionOption(String type, IconData icon) {
    bool isSelected = _selectedProfessionType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProfessionType = type;
          if (type == 'Student') {
            professionController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? themeColor : Colors.grey.shade500),
            const SizedBox(width: 16),
            Text(
              type,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? themeColor : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: themeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return _buildStepContainer(
      title: "Phone Number",
      subtitle: "We'll use this to keep your account secure and for contact",
      icon: Icons.phone_android_rounded,
      child: _buildTextField(
        controller: phoneController,
        label: "Phone Number",
        hint: "Enter 10-digit Mobile Number",
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }

  // Step for Volunteer/Travel Agency UPI ID Setup
  Widget _buildUpiStep() {
    bool showError = upiController.text.trim().isNotEmpty && !_isUpiFormatValid;

    return _buildStepContainer(
      title: "UPI ID for Payments",
      subtitle: "Enter your active UPI ID to receive delivery payments directly from donors (GPay, PhonePe, Paytm)",
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        children: [
          _buildTextField(
            controller: upiController,
            label: "UPI VPA ID",
            hint: "e.g. mobile@paytm or name@oksbi",
            icon: Icons.qr_code_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          if (showError) ...[
            const SizedBox(height: 6),
            Text(
              "Invalid UPI ID format. Include your handle with '@' (e.g. user@ybl)",
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You will receive 100% of donor delivery fees directly into this account.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVehicleTypeStep() {
    return _buildStepContainer(
      title: "What vehicle will you use for deliveries?",
      subtitle: "Select the vehicle you will use for delivery tasks.",
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: VehicleType.values.map((vehicle) {
              final bool isSelected = _selectedVehicle == vehicle;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedVehicle = vehicle);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 150,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? themeColor.withOpacity(0.14) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? themeColor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _vehicleIcon(vehicle),
                        color: isSelected ? themeColor : Colors.grey.shade700,
                        size: 30,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _vehicleLabel(vehicle),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? themeColor : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedVehicle == null) ...[
            const SizedBox(height: 14),
            Text(
              "Please select a vehicle to continue.",
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _vehicleIcon(VehicleType vehicleType) {
    switch (vehicleType) {
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

  String _vehicleLabel(VehicleType vehicleType) {
    return vehicleType.name[0].toUpperCase() + vehicleType.name.substring(1);
  }

  Widget _buildAddressStep() {
    return _buildStepContainer(
      title: "Location",
      subtitle: "Which city in Tamil Nadu are you based in?",
      icon: Icons.location_on_rounded,
      child: _buildTextField(
        controller: addressController,
        label: "City / Area",
        hint: "e.g. Chennai, Coimbatore, Madurai",
        icon: Icons.home_outlined,
      ),
    );
  }

  Widget _buildLicenseStep() {
    String label = widget.role == "volunteer"
        ? "Driving License ID"
        : (widget.role == "travel_agency"
              ? "Registration No."
              : "NGO License ID");

    String hint = widget.role == "volunteer"
        ? "e.g. TN0120211234567"
        : (widget.role == "travel_agency"
              ? "e.g. TA-2021-4521"
              : "e.g. TN/2015/0123456");

    bool showError =
        licenseController.text.trim().isNotEmpty && !_isLicenseFormatValid;

    return _buildStepContainer(
      title: "Verification",
      subtitle:
          "Please provide your $label for trust and verification",
      icon: Icons.verified_user_rounded,
      child: Column(
        children: [
          _buildTextField(
            controller: licenseController,
            label: label,
            hint: hint,
            icon: Icons.credit_card_outlined,
          ),
          if (showError) ...[
            const SizedBox(height: 6),
            Text(
              "Invalid ${widget.role == 'volunteer' ? 'Driving License' : (widget.role == 'travel_agency' ? 'Registration Number' : 'NGO License')} ID",
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _saveProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String finalUsername = usernameController.text.trim().toLowerCase();
    String? profileImageUrl;

    String? finalProfession;
    if (widget.role == 'volunteer') {
      if (_selectedProfessionType == 'Student') {
        finalProfession = 'Student';
      } else if (_selectedProfessionType == 'Professional') {
        finalProfession = professionController.text.trim();
      }
    }

    if (_selectedImage != null || _selectedImageBytes != null) {
      profileImageUrl = await StorageService().uploadImage(
        _selectedImage,
        _selectedImageBytes,
      );
    }

    await authProvider.updateProfile(
      name: nameController.text.trim().isNotEmpty
          ? nameController.text.trim()
          : null,
      username: finalUsername.isNotEmpty ? finalUsername : null,
      phone: phoneController.text.trim().isNotEmpty
          ? phoneController.text.trim()
          : null,
      location: addressController.text.trim().isNotEmpty
          ? addressController.text.trim()
          : null,
      license: licenseController.text.trim().isNotEmpty
          ? licenseController.text.trim()
          : null,
      profileImage: profileImageUrl,
      profession: finalProfession,

      // Pass upiId to AuthProvider / Firestore UserModel
      upiId: (widget.role == 'volunteer' || widget.role == 'travel_agency') &&
              upiController.text.trim().isNotEmpty
          ? upiController.text.trim().toLowerCase()
          : null,

      // 👇 UPDATED: vehicleType now saved for BOTH volunteer and travel_agency
      vehicleType: (widget.role == 'volunteer' || widget.role == 'travel_agency') &&
              _selectedVehicle != null
          ? _selectedVehicle!.name
          : null,
    );

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (Route<dynamic> route) => false,
      );
    }
  }
}