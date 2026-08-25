//profile_setup_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/fare_calculator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 👈 for the UPI QR preview in the confirmation dialog
import 'pending_verification_screen.dart'; // 👈 "awaiting admin verification" screen

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

  // Verification document (PDF) for NGO license / volunteer driving license.
  File? _licenseDocumentFile;
  Uint8List? _licenseDocumentBytes;
  String? _licenseDocumentFileName;
  int? _licenseDocumentSizeBytes;
  String? _licenseDocumentUrl;
  bool _isUploadingLicenseDoc = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  static const int _maxDocumentSizeBytes = 5 * 1024 * 1024; // 5 MB

  bool get _requiresLicenseDocument =>
      widget.role == 'ngo' || widget.role == 'volunteer';

  bool get _isLicenseDocumentValid =>
      !_requiresLicenseDocument || _licenseDocumentUrl != null;

  // 👇 NEW: Phone OTP verification state.
  // Phone entry + OTP verification is now always the LAST step, for every
  // role. Verifying last — right before "Complete Setup" — means we only
  // ever send a billed SMS to someone who is actually finishing signup,
  // instead of burning SMS credit on people who abandon the form midway.
  final TextEditingController otpController = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  bool _isPhoneVerified = false;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;
  String? _otpError;
  // 👇 NEW: shown under the "SEND OTP" button itself (before the OTP field
  // even appears), so a send-time failure is visible on-screen even when
  // there's no USB cable connected to read the VS Code debug console.
  String? _sendOtpError;

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
    otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // 👇 NEW: page order is now expressed as a list of keys instead of magic
  // index numbers. This is what decides both _buildPages() and
  // _isCurrentPageValid — so the two can never drift out of sync, and the
  // "phone_otp" step is guaranteed to always be last for every role.
  List<String> get _pageKeys {
    final List<String> keys = ['image', 'name'];

    if (widget.role == 'volunteer') {
      keys.add('profession');
    }
    if (widget.role == 'volunteer' || widget.role == 'travel_agency') {
      keys.add('upi');
      keys.add('vehicle');
    }

    keys.add('address');

    if (widget.role == 'ngo' ||
        widget.role == 'travel_agency' ||
        widget.role == 'volunteer') {
      keys.add('license');
    }

    keys.add('phone_otp'); // 👈 Always the final step, for every role.
    return keys;
  }

  int get _totalPages => _pageKeys.length;

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

  // 👇 UPDATED: validity is now looked up by page KEY, not by page index.
  bool get _isCurrentPageValid {
    final String key = _pageKeys[_currentPage];
    bool isValid;

    switch (key) {
      case 'image':
        isValid = true;
        break;
      case 'name':
        isValid = nameController.text.trim().isNotEmpty &&
            usernameController.text.trim().isNotEmpty;
        break;
      case 'profession':
        if (_selectedProfessionType == 'Student') {
          isValid = true;
        } else if (_selectedProfessionType == 'Professional') {
          isValid = professionController.text.trim().isNotEmpty;
        } else {
          isValid = false;
        }
        break;
      case 'upi':
        isValid = _isUpiFormatValid;
        break;
      case 'vehicle':
        isValid = _selectedVehicle != null;
        break;
      case 'address':
        isValid = addressController.text.trim().isNotEmpty;
        break;
      case 'license':
        isValid = _isLicenseFormatValid && _isLicenseDocumentValid;
        break;
      case 'phone_otp':
        // 👇 The final step only counts as valid once the OTP has actually
        // been verified — not just once a 10-digit number is typed in.
        isValid = _isPhoneVerified;
        break;
      default:
        isValid = true;
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
    String safeName = Uri.encodeComponent(nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : "Fourth Idly User");
    String previewUri = "upi://pay?pa=$upiId&pn=$safeName&cu=INR";

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
                child: SingleChildScrollView(
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: previewUri,
                              version: QrVersions.auto,
                              size: 140,
                              gapless: false,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Scan this with your own UPI app.\nCheck the name it shows matches you, then tap Confirm.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please ensure this address is active and accurate.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
              ),
            );
          },
        ) ??
        false;
  }

  // 👇 UPDATED: driven by page KEY instead of hardcoded per-role indices.
  Future<void> _nextPage() async {
    final String key = _pageKeys[_currentPage];

    // Username availability check (Name step)
    if (key == 'name') {
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

    // UPI confirmation dialog trigger
    if (key == 'upi') {
      bool confirmed = await _showUpiConfirmationDialog(upiController.text.trim().toLowerCase());
      if (!confirmed) return; // Stay on page if user clicks "Edit ID"
    }

    if (_currentPage < _totalPages - 1) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    } else {
      // Last page is always 'phone_otp'; _isCurrentPageValid already
      // guarantees _isPhoneVerified and agreedToTerms are both true before
      // this button is even tappable.
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

  // ============================================================
  // 👇 NEW: Phone OTP verification logic (Firebase Phone Auth)
  // ============================================================

  Future<void> _sendOtp() async {
    final String phone = phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 10-digit mobile number.")),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _otpError = null;
      _sendOtpError = null;
    });

    final String fullPhoneNumber = "+91$phone";

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      // 👇 UPDATED: 120 seconds instead of 60 — gives slow-delivery Indian
      // carrier routes more room before the verification session expires,
      // and reduces the chance of a stale/mismatched verificationId if the
      // SMS arrives late.
      timeout: const Duration(seconds: 120),
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-retrieval: the code was confirmed automatically in
        // the background without the user typing anything.
        await _linkPhoneCredential(credential, autoVerified: true);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        String message = "Couldn't send the OTP. Please try again.";
        if (e.code == 'invalid-phone-number') {
          message = "That doesn't look like a valid phone number.";
        } else if (e.code == 'too-many-requests') {
          message = "Too many attempts. Please wait a while before trying again.";
        } else if (e.code == 'quota-exceeded') {
          message = "SMS limit reached for now. Please try again later.";
        }
        // 👇 NEW: append the raw Firebase error code so it's visible right
        // on the screen — no cable/debug console needed to diagnose it.
        final String detailedMessage = "$message\n(code: ${e.code})";
        setState(() {
          _isSendingOtp = false;
          _sendOtpError = detailedMessage;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detailedMessage)));
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _otpSent = true;
          _isSendingOtp = false;
          _otpError = null;
        });
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("A 6-digit code has been sent to +91 $phone via SMS.")),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    // 👇 UPDATED: matches the 120-second verification window above, so
    // "Resend" only becomes available once the previous session has fully
    // expired — avoids creating a second, stale verificationId while the
    // first one is still valid.
    setState(() => _resendSecondsLeft = 120);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft -= 1);
      }
    });
  }

  Future<void> _verifyOtp() async {
    final String smsCode = otpController.text.trim();
    if (smsCode.length != 6 || _verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter the 6-digit code sent to your phone.")),
      );
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _otpError = null;
    });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    await _linkPhoneCredential(credential, autoVerified: false);
  }

  // Attaches the verified phone number to the CURRENT signed-in account
  // (rather than creating a brand-new account), so phone OTP acts purely as
  // a verification step on top of however the user already signed up.
  Future<void> _linkPhoneCredential(
    PhoneAuthCredential credential, {
    required bool autoVerified,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No signed-in user found.");
      }

      await user.linkWithCredential(credential);

      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _isVerifyingOtp = false;
        _isPhoneVerified = true;
        _otpError = null;
      });
      _resendTimer?.cancel();

      if (!autoVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number verified successfully.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = "Verification failed. Please try again.";
      if (e.code == 'invalid-verification-code') {
        message = "That code is incorrect. Please check and try again.";
      } else if (e.code == 'session-expired') {
        message = "This code has expired. Please request a new one.";
      } else if (e.code == 'credential-already-in-use') {
        message = "This phone number is already linked to another account.";
      } else if (e.code == 'invalid-verification-id') {
        message = "That code no longer matches this session. Tap Resend and use the newest code.";
      }
      // 👇 NEW: raw Firebase error code shown on-screen — visible without a
      // cable/debug console, so you can tell us exactly what's happening.
      final String detailedMessage = "$message\n(code: ${e.code})";
      setState(() {
        _isSendingOtp = false;
        _isVerifyingOtp = false;
        _otpError = detailedMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detailedMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _isVerifyingOtp = false;
        _otpError = "Something went wrong.\n($e)";
      });
    }
  }

  void _changePhoneNumber() {
    setState(() {
      _otpSent = false;
      _isPhoneVerified = false;
      _verificationId = null;
      _resendToken = null;
      otpController.clear();
      _otpError = null;
      _sendOtpError = null;
      _resendTimer?.cancel();
      _resendSecondsLeft = 0;
    });
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
                            onPressed: (_isCurrentPageValid &&
                                    !_isCheckingUsername &&
                                    !_isUploadingLicenseDoc)
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

  // 👇 UPDATED: now also nudges the user toward the in-page Send/Verify OTP
  // buttons while they're on the final step and not yet verified.
  String _getButtonText() {
    if (_currentPage == 0 &&
        _selectedImage == null &&
        _selectedImageBytes == null) return "SKIP PHOTO";

    final String key = _pageKeys[_currentPage];
    if (key == 'phone_otp' && !_isPhoneVerified) return "VERIFY TO CONTINUE";
    if (_currentPage == _totalPages - 1) return "COMPLETE SETUP";
    return "CONTINUE";
  }

  // 👇 UPDATED: pages are now built by mapping over _pageKeys, so the page
  // WIDGETS list and the page VALIDATION logic can never fall out of sync.
  List<Widget> _buildPages() {
    return _pageKeys.map((key) {
      switch (key) {
        case 'image':
          return _buildImageStep();
        case 'name':
          return _buildNameStep();
        case 'profession':
          return _buildProfessionStep();
        case 'upi':
          return _buildUpiStep();
        case 'vehicle':
          return _buildVehicleTypeStep();
        case 'address':
          return _buildAddressStep();
        case 'license':
          return _buildLicenseStep();
        case 'phone_otp':
          return _buildPhoneOtpStep();
        default:
          return const SizedBox.shrink();
      }
    }).toList();
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  Future<void> _pickAndUploadLicenseDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb, // need raw bytes on web; path is enough on mobile
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final int sizeBytes = picked.size;

      if (sizeBytes > _maxDocumentSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "That PDF is ${_formatFileSize(sizeBytes)}. Please upload a file under ${_formatFileSize(_maxDocumentSizeBytes)}.",
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() {
        _licenseDocumentFileName = picked.name;
        _licenseDocumentSizeBytes = sizeBytes;
        _licenseDocumentUrl = null;
        _uploadError = null;
        if (kIsWeb) {
          _licenseDocumentBytes = picked.bytes;
          _licenseDocumentFile = null;
        } else {
          _licenseDocumentFile = File(picked.path!);
          _licenseDocumentBytes = null;
        }
      });

      await _uploadLicenseDocument();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't open file picker: $e")),
        );
      }
    }
  }

  Future<void> _uploadLicenseDocument() async {
    setState(() {
      _isUploadingLicenseDoc = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    final String docLabel = widget.role == 'volunteer' ? 'driving_license' : 'ngo_license';
    final String safeFileName = '${docLabel}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final String? url = await StorageService().uploadDocument(
      file: _licenseDocumentFile,
      bytes: _licenseDocumentBytes,
      fileName: safeFileName,
      folder: 'license_documents',
      onProgress: (progress) {
        if (mounted) setState(() => _uploadProgress = progress);
      },
    );

    if (!mounted) return;

    setState(() {
      _isUploadingLicenseDoc = false;
      if (url != null) {
        _licenseDocumentUrl = url;
      } else {
        _uploadError = "Upload failed. Check your connection and try again.";
      }
    });
  }

  void _removeLicenseDocument() {
    setState(() {
      _licenseDocumentFile = null;
      _licenseDocumentBytes = null;
      _licenseDocumentFileName = null;
      _licenseDocumentSizeBytes = null;
      _licenseDocumentUrl = null;
      _uploadError = null;
      _uploadProgress = 0.0;
    });
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

  // 👇 UPDATED: added an optional `onChanged` override so the phone field
  // (on the new phone_otp step) can reset OTP state when the number is
  // edited, while every other field keeps using the default _onFieldChanged.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
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
        onChanged: onChanged ?? _onFieldChanged,
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
          if (_requiresLicenseDocument) ...[
            const SizedBox(height: 20),
            _buildLicenseDocumentUploadCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildLicenseDocumentUploadCard() {
    final String docTitle = widget.role == 'volunteer'
        ? "Driving License (PDF)"
        : "NGO License Certificate (PDF)";

    if (_licenseDocumentFileName == null) {
      return GestureDetector(
        onTap: _pickAndUploadLicenseDocument,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeColor.withOpacity(0.4), width: 1.4),
          ),
          child: Column(
            children: [
              Icon(Icons.upload_file_rounded, color: themeColor, size: 32),
              const SizedBox(height: 10),
              Text(
                "Upload $docTitle",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "PDF only • Max ${_formatFileSize(_maxDocumentSizeBytes)}",
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _uploadError != null
              ? Colors.red.shade200
              : (_licenseDocumentUrl != null ? Colors.green.shade200 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_uploadError != null
                      ? Colors.red
                      : (_licenseDocumentUrl != null ? Colors.green : themeColor))
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: _uploadError != null
                  ? Colors.red.shade400
                  : (_licenseDocumentUrl != null ? Colors.green.shade600 : themeColor),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _licenseDocumentFileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                if (_isUploadingLicenseDoc) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(themeColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Uploading… ${(100 * _uploadProgress).toStringAsFixed(0)}%",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ] else if (_uploadError != null) ...[
                  Text(
                    _uploadError!,
                    style: TextStyle(fontSize: 11.5, color: Colors.red.shade400, fontWeight: FontWeight.w600),
                  ),
                ] else if (_licenseDocumentUrl != null) ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${_licenseDocumentSizeBytes != null ? _formatFileSize(_licenseDocumentSizeBytes!) : ''} • Uploaded",
                        style: TextStyle(fontSize: 11.5, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_uploadError != null)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: themeColor),
              onPressed: _uploadLicenseDocument,
              tooltip: "Retry upload",
            )
          else if (!_isUploadingLicenseDoc)
            IconButton(
              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
              onPressed: _removeLicenseDocument,
              tooltip: "Remove",
            ),
        ],
      ),
    );
  }

  // ============================================================
  // 👇 NEW: Phone number + OTP verification step (always the LAST page,
  // for donor, ngo, volunteer, and travel_agency alike).
  // ============================================================
  Widget _buildPhoneOtpStep() {
    return _buildStepContainer(
      title: "Verify Your Phone",
      subtitle: "We'll send a one-time code to confirm this number is yours",
      icon: Icons.sms_rounded,
      child: Column(
        children: [
          _buildTextField(
            controller: phoneController,
            label: "Phone Number",
            hint: "Enter 10-digit Mobile Number",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              setState(() {
                // Editing the number after it's been sent/verified must
                // invalidate the old OTP session — it was tied to the
                // previous number.
                if (_isPhoneVerified || _otpSent) {
                  _isPhoneVerified = false;
                  _otpSent = false;
                  _verificationId = null;
                  otpController.clear();
                  _otpError = null;
                  _sendOtpError = null;
                  _resendTimer?.cancel();
                  _resendSecondsLeft = 0;
                }
              });
            },
          ),

          if (_isPhoneVerified) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green.shade600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "+91 ${phoneController.text.trim()} is verified.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _changePhoneNumber,
                    child: Text(
                      "Change",
                      style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!_otpSent) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: (_isSendingOtp || phoneController.text.trim().length != 10)
                    ? null
                    : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSendingOtp
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("SEND OTP", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Standard SMS charges may apply. Please double-check the number above.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            if (_sendOtpError != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _sendOtpError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.red.shade600, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 16),
            Text(
              "Enter the 6-digit code sent to +91 ${phoneController.text.trim()}",
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: otpController,
              label: "OTP Code",
              hint: "6-digit code",
              icon: Icons.lock_clock_rounded,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                setState(() {
                  if (_otpError != null) _otpError = null;
                });
              },
            ),
            if (_otpError != null) ...[
              const SizedBox(height: 6),
              Text(
                _otpError!,
                style: TextStyle(fontSize: 11, color: Colors.red.shade400, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: (_isVerifyingOtp || otpController.text.trim().length != 6)
                    ? null
                    : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isVerifyingOtp
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("VERIFY OTP", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text(
                  _resendSecondsLeft > 0
                      ? "Resend code in ${_resendSecondsLeft}s"
                      : "Didn't get the code?",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                if (_resendSecondsLeft == 0)
                  GestureDetector(
                    onTap: _isSendingOtp ? null : _sendOtp,
                    child: Text(
                      "Resend",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                    ),
                  ),
                const SizedBox(width: 6),
                Text("•", style: TextStyle(color: Colors.grey.shade400)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _changePhoneNumber,
                  child: Text(
                    "Change number",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
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

    // If this role requires admin verification (ngo / volunteer) and the
    // account isn't already approved/active, mark it 'pending' — this is
    // what makes the admin panel pick it up in the review queue AND routes
    // the user to the "awaiting verification" screen below instead of the
    // home screen.
    final String? currentStatus = authProvider.currentUserModel?.status;
    final bool alreadyVerified = currentStatus == 'approved' || currentStatus == 'active';
    final bool needsVerification = _requiresLicenseDocument && !alreadyVerified;

    await authProvider.updateProfile(
      name: nameController.text.trim().isNotEmpty
          ? nameController.text.trim()
          : null,
      username: finalUsername.isNotEmpty ? finalUsername : null,
      // 👇 By this point _isPhoneVerified is guaranteed true (the button
      // that calls _saveProfile is disabled otherwise), so this number has
      // actually been confirmed via OTP, not just typed in.
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

      upiId: (widget.role == 'volunteer' || widget.role == 'travel_agency') &&
              upiController.text.trim().isNotEmpty
          ? upiController.text.trim().toLowerCase()
          : null,

      vehicleType: (widget.role == 'volunteer' || widget.role == 'travel_agency') &&
              _selectedVehicle != null
          ? _selectedVehicle!.name
          : null,

      licenseDocumentUrl: _requiresLicenseDocument ? _licenseDocumentUrl : null,
      status: needsVerification ? 'pending' : null,
    );

    if (mounted) {
      if (needsVerification) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PendingVerificationScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }
}