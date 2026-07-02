import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // <-- NEW: Required for input formatters
import '../providers/auth_provider.dart';
import '../main.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String role;
  const ProfileSetupScreen({super.key, required this.role});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isCheckingUsername = false;
  
  bool _agreedToTerms = false; 

  final Color themeColor = const Color(0xFFB56F76);

  @override
  void dispose() {
    _pageController.dispose();
    nameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    licenseController.dispose();
    super.dispose();
  }

  int get _totalPages {
    if (widget.role == "ngo" || widget.role == "travel_agency") return 5;
    if (widget.role == "volunteer") return 4;
    return 3;
  }

  bool get _isCurrentPageValid {
    bool isValid = true;
    
    if (_currentPage == 0) {
      isValid = true;
    } else if (_currentPage == 1) {
      isValid = nameController.text.trim().isNotEmpty && usernameController.text.trim().isNotEmpty;
    } else if (_currentPage == 2) {
      // 👇 NEW: Phone number MUST be exactly 10 digits
      isValid = phoneController.text.trim().length == 10;
    } else if (widget.role == "ngo" || widget.role == "travel_agency") {
      if (_currentPage == 3) isValid = addressController.text.trim().isNotEmpty;
      if (_currentPage == 4) isValid = licenseController.text.trim().isNotEmpty;
    } else if (widget.role == "volunteer") {
      if (_currentPage == 3) isValid = licenseController.text.trim().isNotEmpty;
    }

    if (_currentPage == _totalPages - 1) {
      return isValid && _agreedToTerms;
    }

    return isValid;
  }

  void _onFieldChanged(String value) {
    setState(() {});
  }

  Future<void> _nextPage() async {
    if (_currentPage == 1) {
      String desiredUsername = usernameController.text.trim().toLowerCase();
      
      bool hasLetter = RegExp(r'[a-z]').hasMatch(desiredUsername);
      bool hasNumber = RegExp(r'[0-9]').hasMatch(desiredUsername);
      bool hasUnderscore = desiredUsername.contains('_');
      bool hasInvalidChars = RegExp(r'[^a-z0-9_]').hasMatch(desiredUsername);
      
      if (!hasLetter || !hasNumber || !hasUnderscore || hasInvalidChars) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Username must include at least 1 letter, 1 number, and 1 underscore (_). No spaces allowed."),
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
              SnackBar(content: Text("The username '@$desiredUsername' is already taken. Please choose another.")),
            );
          }
          setState(() => _isCheckingUsername = false);
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error checking username: $e")));
        }
        setState(() => _isCheckingUsername = false);
        return;
      }
      setState(() => _isCheckingUsername = false);
    }

    if (_currentPage < _totalPages - 1) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    } else {
      saveProfile();
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
    if (widget.role == 'ngo') {
      return "NGO Terms & Conditions:\n\n1. Accuracy: You agree to provide accurate and truthful information regarding your organization and its operations.\n\n2. Usage of Donations: You agree to use donated food and products strictly for charitable purposes and not for resale or profit.\n\n3. Volunteer Arrangement: You are fully responsible for arranging your own volunteers for the pickup of donations from the donor's location.\n\n4. Platform Misuse: Any misuse of the platform, fraudulent requests, or harassment of donors will result in an immediate ban.\n\n5. Liability: Charitey is a facilitating platform and is not liable for the quality of food or products provided by donors.";
    } else if (widget.role == 'donor') {
      return "Donor Terms & Conditions:\n\n1. Quality of Goods: You agree that all food and products donated are safe, hygienic, and in good condition.\n\n2. Accurate Information: You agree to provide an accurate pickup location and reliable contact information.\n\n3. Commitment: You understand that once a donation is accepted by an NGO, you should not cancel the request without a valid and urgent reason.\n\n4. Respect & Privacy: You agree to treat NGOs and their volunteers with respect and maintain their privacy.\n\n5. Liability: You donate at your own free will. Charitey is not responsible for any incidents occurring during the handover process.";
    } else if (widget.role == 'travel_agency') {
      return "Travel Agency Terms & Conditions:\n\n1. Timeliness: You agree to transport donations safely and timely to the designated NGO locations.\n\n2. Vehicle Information: You must provide accurate vehicle, driver, and tracking details to ensure transparency.\n\n3. No Hidden Fees: You agree to not charge extra fees outside the initial platform agreement.\n\n4. Goods Handling: You are responsible for handling all donated items with extreme care to prevent damage or spoilage during transit.";
    } else if (widget.role == 'volunteer') {
      return "Volunteer Terms & Conditions:\n\n1. Reliability: You agree to strictly adhere to the schedule provided for donation pickups.\n\n2. Verification: You must present a valid ID to donors upon request for security purposes.\n\n3. Care: You agree to handle all donated items with care and ensure they reach the NGO exactly as they were provided.\n\n4. Conduct: Professional and polite conduct is expected at all times when interacting with Donors and NGOs.";
    }
    return "General Terms & Conditions:\n\n1. You agree to use the platform responsibly.\n2. Be respectful to other users.";
  }

  // 👇 NEW: Premium Professional Terms & Conditions UI 👇
  void _showTermsPopup() {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to click a button
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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
                const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 16),
                
                // Scrollable Content
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
                const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 16),
                
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        setState(() => _agreedToTerms = true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "I Agree",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
        ),
        centerTitle: true,
        leading: _currentPage > 0
            ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: _previousPage)
            : null,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthWrapper()),
                (Route<dynamic> route) => false,
              );
            },
            child: Text("Skip", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
          )
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -80,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), shape: BoxShape.circle)),
          ),
          Positioned(
            bottom: 50, left: -100,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.05), shape: BoxShape.circle)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                  child: Row(
                    children: List.generate(
                      _totalPages,
                      (index) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          height: 6,
                          decoration: BoxDecoration(
                            color: index <= _currentPage ? themeColor : Colors.grey.shade300,
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
                    onPageChanged: (int page) => setState(() => _currentPage = page),
                    children: pages,
                  ),
                ),
                
                // BOTTOM CONTAINER
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, -10))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentPage == _totalPages - 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0, left: 4.0, right: 4.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _agreedToTerms,
                                    activeColor: themeColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) {
                                      setState(() {
                                        _agreedToTerms = val ?? false;
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
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                                        children: [
                                          TextSpan(
                                            text: "Terms & Conditions",
                                            style: TextStyle(
                                              color: themeColor, 
                                              fontWeight: FontWeight.bold, 
                                              decoration: TextDecoration.underline,
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: (_isCurrentPageValid && !_isCheckingUsername) ? _nextPage : null,
                            child: _isCheckingUsername
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(_getButtonText(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
    if (_currentPage == 0 && _selectedImage == null && _selectedImageBytes == null) return "SKIP PHOTO";
    if (_currentPage == _totalPages - 1) return "COMPLETE SETUP";
    return "CONTINUE";
  }

  List<Widget> _buildPages() {
    List<Widget> pages = [_buildImageStep(), _buildNameStep(), _buildPhoneStep()];
    if (widget.role == "ngo" || widget.role == "travel_agency") {
      pages.add(_buildAddressStep());
      pages.add(_buildLicenseStep());
    } else if (widget.role == "volunteer") {
      pages.add(_buildLicenseStep());
    }
    return pages;
  }

  Widget _buildStepContainer({required String title, required String subtitle, required Widget child, IconData? icon}) {
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
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))]
                  ),
                  child: Icon(icon, size: 40, color: themeColor),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF2D3142), height: 1.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
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
                  border: Border.all(color: themeColor.withValues(alpha: 0.2), width: 4),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: ClipOval(
                  child: (_selectedImage == null && _selectedImageBytes == null)
                      ? Icon(Icons.person_rounded, size: 70, color: Colors.grey.shade300)
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
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 👇 NEW: Upgraded TextField to handle strict formatting limits 👇
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        onChanged: _onFieldChanged,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        decoration: InputDecoration(
          counterText: '', // Hides the "0/10" text below the input field for a cleaner UI
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 14),
          prefixIcon: Icon(icon, color: themeColor, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    String label = widget.role == "ngo" ? "NGO Name" : (widget.role == "travel_agency" ? "Agency Name" : "Full Name");
    return _buildStepContainer(
      title: "What's your name?",
      subtitle: "Let us know how to address you",
      icon: Icons.badge_rounded,
      child: Column(
        children: [
          _buildTextField(controller: nameController, label: label, hint: "Enter $label", icon: Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _buildTextField(controller: usernameController, label: "Unique Username", hint: "e.g. safrin_99", icon: Icons.alternate_email_rounded),
          const SizedBox(height: 6),
          Text("Must include 1 letter, 1 number, and 1 underscore.", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // 👇 NEW: Enforced 10 digit exact entry limit 👇
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
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly // Prevents letters, spaces, or special characters
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return _buildStepContainer(
      title: "Location",
      subtitle: "Where is your base of operations located?",
      icon: Icons.location_on_rounded,
      child: _buildTextField(controller: addressController, label: "City / Area", hint: "Enter city name", icon: Icons.home_outlined),
    );
  }

  Widget _buildLicenseStep() {
    String label = widget.role == "volunteer" ? "Driving License ID" : (widget.role == "travel_agency" ? "Registration No." : "NGO License ID");
    return _buildStepContainer(
      title: "Verification",
      subtitle: "Please provide your $label for trust and verification",
      icon: Icons.verified_user_rounded,
      child: _buildTextField(controller: licenseController, label: label, hint: "Enter $label", icon: Icons.credit_card_outlined),
    );
  }

  void saveProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String finalUsername = usernameController.text.trim().toLowerCase();
    
    String? profileImageUrl;
    if (_selectedImage != null || _selectedImageBytes != null) {
      profileImageUrl = await StorageService().uploadImage(_selectedImage, _selectedImageBytes);
    }
    
    await authProvider.updateProfile(
      name: nameController.text.trim().isNotEmpty ? nameController.text.trim() : null,
      username: finalUsername.isNotEmpty ? finalUsername : null,
      phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
      location: (widget.role == "ngo" || widget.role == "travel_agency") && addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
      license: licenseController.text.trim().isNotEmpty ? licenseController.text.trim() : null,
      profileImage: profileImageUrl,
    );
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (Route<dynamic> route) => false,
      );
    }
  }
}