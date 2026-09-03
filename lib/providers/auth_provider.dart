//auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Holds a user-friendly message after a failed email/password sign-in
  // OR sign-up attempt. Read this from AuthProvider.lastError right after
  // a failed signIn/signUp call.
  String? lastError;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Single source of truth for "what status does a brand-new user start
  // with". ngo/volunteer accounts require admin document review and must
  // start 'pending'; everyone else starts 'active'. Both signup paths below
  // (email/password AND Google) call this instead of relying on UserModel's
  // constructor default.
  String _initialStatusForRole(String role) {
    final r = role.toLowerCase();
    return (r == 'ngo' || r == 'volunteer') ? 'pending' : 'active';
  }

  // ================= SIGN UP =================
  //
  // 👇 FIXED: Previously, if createUserWithEmailAndPassword succeeded but
  // the subsequent Firestore .set() write failed for any reason (security
  // rules, network blip, etc.), the error was silently swallowed via
  // debugPrint only — leaving a real Firebase Auth account with NO matching
  // Firestore profile. That email would then be permanently stuck as
  // "already in use" on every future signup attempt, with no data visible
  // anywhere. This version rolls back (deletes) the orphaned Auth user if
  // the Firestore write fails, and surfaces a proper error via `lastError`
  // instead of failing silently.

  Future<UserModel?> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    required String location,
  }) async {
    lastError = null;
    User? user;

    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = result.user;
      if (user == null) {
        lastError = 'Something went wrong creating your account. Please try again.';
        return null;
      }

      UserModel newUser = UserModel(
        uid: user.uid,
        name: name,
        phone: phone,
        email: email,
        role: role,
        location: location,
        profileImage: '',
        createdAt: DateTime.now(),
        status: _initialStatusForRole(role),
      );

      await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      return newUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error signing up (auth): ${e.code}');
      switch (e.code) {
        case 'email-already-in-use':
          lastError = 'An account with this email already exists. Try logging in instead.';
          break;
        case 'weak-password':
          lastError = 'Please choose a stronger password (at least 6 characters).';
          break;
        case 'invalid-email':
          lastError = 'Please enter a valid email address.';
          break;
        case 'network-request-failed':
          lastError = 'No internet connection. Please check your internet connection.';
          break;
        default:
          lastError = e.message ?? 'Unable to sign up. Please try again.';
      }
      return null;
    } catch (e) {
      // Firestore write (or anything else) failed AFTER the Auth account
      // was already created. Roll back the orphaned Auth account so this
      // email isn't permanently stuck as "already in use" with no profile.
      debugPrint('Error signing up (firestore write failed): $e');
      if (user != null) {
        try {
          await user.delete();
          debugPrint('Rolled back orphaned Auth user ${user.uid}');
        } catch (deleteError) {
          debugPrint('Failed to roll back orphaned Auth user: $deleteError');
        }
      }
      lastError = 'Something went wrong setting up your profile. Please try again.';
      return null;
    }
  }

  // ================= SIGN IN =================

  Future<UserModel?> signInWithEmailAndPassword(
      String email, String password) async {
    lastError = null; // reset before each attempt

    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        } else {
          // Auth account exists but no Firestore profile — an orphaned
          // account from before the rollback fix above. Sign them back out
          // and tell them clearly, instead of returning null with no reason.
          await _auth.signOut();
          lastError =
              'Your account setup was incomplete. Please sign up again.';
          return null;
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Error signing in: ${e.code}');
      lastError = await _buildSignInErrorMessage(email, e);
    } catch (e) {
      debugPrint('Error signing in: $e');
      lastError = 'Something went wrong. Please try again.';
    }
    return null;
  }

  // Returns a user-friendly message for email/password sign-in failures.
  Future<String> _buildSignInErrorMessage(
      String email, FirebaseAuthException e) async {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'Incorrect email or password. If you originally signed up with Google, please use Continue with Google.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your internet connection.';
      default:
        return e.message ?? 'Unable to sign in. Please try again.';
    }
  }

  // ================= GOOGLE SIGN IN =================
  // Pass [assignRole] when registering via Google so new users get
  // the correct role. For login screens pass null — existing role is kept.
  //
  // FIX: Both web and mobile flows now force the account chooser to
  // appear on every sign-in attempt, instead of silently reusing the
  // last signed-in Google session.

  Future<UserModel?> signInWithGoogle({String? assignRole}) async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb(assignRole: assignRole);
      } else {
        return await _signInWithGoogleMobile(assignRole: assignRole);
      }
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return null;
    }
  }

  Future<UserModel?> _signInWithGoogleMobile({String? assignRole}) async {
    final GoogleSignIn googleSignIn = GoogleSignIn();

    // FIX: disconnect() fully revokes the previous session (not just
    // clearing the local cache like signOut() does), guaranteeing the
    // account picker shows every time — even with a single Google
    // account on the device.
    try {
      await googleSignIn.disconnect();
    } catch (_) {
      // Throws if there was no previous session — safe to ignore.
    }

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      debugPrint('Google Sign In: User cancelled.');
      return null;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _completeSignIn(credential, assignRole);
  }

  Future<UserModel?> _signInWithGoogleWeb({String? assignRole}) async {
    // On web, use FirebaseAuth's built-in popup provider instead of google_sign_in's signIn()
    GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    // FIX: forces Google to always show the account chooser on web,
    // instead of silently reusing the existing browser session.
    googleProvider.setCustomParameters({
      'prompt': 'select_account',
    });

    UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
    User? user = userCredential.user;

    if (user == null) return null;
    return await _saveOrFetchUser(user, assignRole);
  }

  Future<UserModel?> _completeSignIn(AuthCredential credential, String? assignRole) async {
    UserCredential result = await _auth.signInWithCredential(credential);
    User? user = result.user;
    if (user == null) return null;
    return await _saveOrFetchUser(user, assignRole);
  }

  Future<UserModel?> _saveOrFetchUser(User user, String? assignRole) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final role = assignRole ?? 'user';
      UserModel newUser = UserModel(
        uid: user.uid,
        name: user.displayName ?? '',
        phone: '',
        email: user.email ?? '',
        role: role,
        location: '',
        profileImage: user.photoURL ?? '',
        createdAt: DateTime.now(),
        status: _initialStatusForRole(role),
      );
      await docRef.set(newUser.toMap());
      return newUser;
    } else {
      if (assignRole != null) {
        await docRef.update({'role': assignRole});
      }
      final updatedDoc = await docRef.get();
      return UserModel.fromMap(
        updatedDoc.data() as Map<String, dynamic>,
        updatedDoc.id,
      );
    }
  }

  // ================= FORGOT PASSWORD =================
  // Calls the `sendPasswordReset` Firebase Cloud Function, which generates
  // a real Firebase Auth reset link via the Admin SDK and sends it through
  // Resend (replaces the old Cloudflare Worker + Brevo setup).

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendPasswordReset');
      await callable.call({'email': email.trim()});
      return null; // success
    } on FirebaseFunctionsException catch (e) {
      debugPrint('sendPasswordReset error: ${e.code} ${e.message}');
      switch (e.code) {
        case 'not-found':
          return 'No account found with this email address.';
        case 'invalid-argument':
          return e.message ?? 'The email address is not valid.';
        default:
          return 'Something went wrong. Please try again.';
      }
    } catch (e) {
      debugPrint('sendPasswordResetEmail unexpected error: $e');
      return 'Something went wrong. Please check your connection and try again.';
    }
  }

  // ================= SIGN OUT =================

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // ================= GET PROFILE =================

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    return null;
  }
}