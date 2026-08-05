///auth_provider.dart
//auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  late final StreamSubscription<User?> _authSubscription;

  // 👇 NEW: live listener on the signed-in user's own Firestore document.
  // This is what makes admin approve/reject/block actions reflect in the
  // app INSTANTLY, without the user needing to log out and back in.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSubscription;

  UserModel? _currentUserModel;
  bool _isLoading = false;

  UserModel? get currentUserModel => _currentUserModel;
  UserModel? get user => _currentUserModel;
  bool get isLoading => _isLoading;

  // EXPOSE AUTH SERVICE: This allows login screens to reference authProvider.authService
  AuthService get authService => _authService;
  User? get currentFirebaseUser => FirebaseAuth.instance.currentUser;

  // User-friendly message set after a failed email/password sign-in attempt.
  // Populated by AuthService.signInWithEmailAndPassword via signIn/signInWithRole.
  String? get lastError => _authService.lastError;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _authSubscription =
        _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _fetchUserData(firebaseUser.uid);
      } else {
        _userDocSubscription?.cancel();
        _userDocSubscription = null;
        _currentUserModel = null;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserData(String uid) async {
    _isLoading = true;
    notifyListeners();

    _currentUserModel = await _authService.getUserProfile(uid);

    _isLoading = false;
    notifyListeners();

    // 👇 NEW: start (or restart) the live listener for this uid.
    _listenToUserStatusChanges(uid);
  }

  // 👇 NEW: subscribes to the user's own document. Any Firestore write to it
  // — most importantly an admin approving/rejecting/blocking them from the
  // web panel — rebuilds anything watching `currentUserModel` immediately.
  void _listenToUserStatusChanges(String uid) {
    _userDocSubscription?.cancel();
    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) return;
        _currentUserModel = UserModel.fromMap(data, snapshot.id);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('User status listener error: $e');
      },
    );
  }

  // ================= SIGN IN =================

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    UserModel? user = await _authService.signInWithEmailAndPassword(
      email,
      password,
    );

    _isLoading = false;

    if (user != null) {
      _currentUserModel = user;
      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  // ================= ROLE BASED EMAIL SIGN IN =================

  Future<bool> signInWithRole(
    String email,
    String password,
    String expectedRole,
  ) async {
    _isLoading = true;
    notifyListeners();

    UserModel? user = await _authService.signInWithEmailAndPassword(
      email,
      password,
    );

    _isLoading = false;

    if (user == null) {
      notifyListeners();
      return false;
    }

    if (user.role.toLowerCase() != expectedRole.toLowerCase()) {
      //await FirebaseAuth.instance.signOut();
      await _authService.signOut();
      notifyListeners();
      return false;
    }

    _currentUserModel = user;
    notifyListeners();
    return true;
  }

  // ================= GOOGLE SIGN IN =================
  //
  // LOGIN screens  → pass expectedRole only (no assignRole)
  //   signInWithGoogle(expectedRole: 'ngo')
  //   → new users blocked, existing users role-checked
  //
  // REGISTER screens → pass role only
  //   signInWithGoogle(role: 'ngo')
  //   → new users created with that role, existing users role updated

  Future<bool> signInWithGoogle({
    String? expectedRole, // used by LOGIN screens — validates existing role
    String? role,         // used by REGISTER screens — assigns role to new/existing user
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Register flow: pass the role down so new users get it saved correctly
      final String? assignRole = role;

      UserModel? googleUser =
          await _authService.signInWithGoogle(assignRole: assignRole);

      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // LOGIN screen role check — reject if role doesn't match
      if (expectedRole != null &&
          googleUser.role.toLowerCase() != expectedRole.toLowerCase()) {
        //await FirebaseAuth.instance.signOut();
        await _authService.signOut();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUserModel = googleUser;
      await _fetchUserData(googleUser.uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
    }

    _isLoading = false;
    //notifyListeners();
    return false;
  }

  // ================= SIGN UP =================

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    required String location,
    String username = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    UserModel? user = await _authService.signUpWithEmailAndPassword(
      name: name,
      email: email,
      password: password,
      phone: phone,
      role: role,
      location: location,
    );

    _isLoading = false;

    if (user != null) {
      if (username.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'username': username});
      }

      await _fetchUserData(user.uid);

      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  // ================= FORGOT PASSWORD =================

  Future<String?> forgotPassword(String email) async {
    _isLoading = true;
    notifyListeners();

    final error = await _authService.sendPasswordResetEmail(email);

    _isLoading = false;
    notifyListeners();

    return error; // null = success, non-null = error message
  }

  // ================= SIGN OUT =================

  Future<void> signOut() async {
    try {
      //await FirebaseAuth.instance.signOut();
      await _authService.signOut();
      await _userDocSubscription?.cancel(); // 👈 NEW: stop listening on sign out
      _userDocSubscription = null;
      _currentUserModel = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  // ================= UPDATE PROFILE =================

  Future<bool> updateProfile({
    String? name,
    String? username,
    String? phone,
    String? location,
    String? profileImage,
    String? license,
    String? profession,
    String? upiId,
    String? vehicleType,
    String? licenseDocumentUrl,
    String? status, // 👈 NEW: e.g. set to 'pending' right after doc upload
  }) async {
    if (_currentUserModel == null) return false;

    try {
      Map<String, dynamic> data = {};

      if (name != null) data['name'] = name;
      if (username != null) data['username'] = username;
      if (phone != null) data['phone'] = phone;
      if (location != null) data['location'] = location;
      if (profileImage != null) data['profileImage'] = profileImage;
      if (license != null) data['license'] = license;
      if (profession != null) data['profession'] = profession;
      if (upiId != null) data['upiId'] = upiId;
      if (vehicleType != null) data['vehicleType'] = vehicleType;
      if (licenseDocumentUrl != null) data['licenseDocumentUrl'] = licenseDocumentUrl;
      if (status != null) data['status'] = status; // 👈 NEW

      if (data.isNotEmpty) {
        final uid = _currentUserModel!.uid;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(data);

        // When profile image changes, propagate to all listings and posts
        if (profileImage != null) {
          // Update ngo_listings
          final listingsSnap = await FirebaseFirestore.instance
              .collection('ngo_listings')
              .where('ngoId', isEqualTo: uid)
              .get();

          if (listingsSnap.docs.isNotEmpty) {
            final listingsBatch = FirebaseFirestore.instance.batch();
            for (final doc in listingsSnap.docs) {
              listingsBatch.update(doc.reference, {'ngoProfileImage': profileImage});
            }
            await listingsBatch.commit();
          }

          // Update posts
          final postsSnap = await FirebaseFirestore.instance
              .collection('posts')
              .where('ngoId', isEqualTo: uid)
              .get();

          if (postsSnap.docs.isNotEmpty) {
            final postsBatch = FirebaseFirestore.instance.batch();
            for (final doc in postsSnap.docs) {
              postsBatch.update(doc.reference, {'ngoProfileImage': profileImage});
            }
            await postsBatch.commit();
          }
        }

        await _fetchUserData(uid);
      }

      return true;
    } catch (e) {
      debugPrint('Update Profile Error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _userDocSubscription?.cancel(); // 👈 NEW
    super.dispose();
  }
}