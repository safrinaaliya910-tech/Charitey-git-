//main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart'; 
import 'screens/home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'screens/forgot_password_screen.dart';

// --- FIX 1: Removed the underscore from HomeScreenState ---
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    final notificationService = NotificationService();
    await notificationService.initNotifications();
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fourth Idly',
      theme: ThemeData(
        primaryColor: const Color(0xFFB56F76),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB56F76),
          primary: const Color(0xFFB56F76),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFB56F76))),
      );
    }

    // 1. Not logged in
    if (user == null) {
      return const SplashScreen();
    }

    // 2. THE LOOP FIX: Only force setup if the user has NO data at all.
    // If they have either a phone OR a location, we treat them as finished.
    // This allows users to skip parts of the setup without getting stuck.
    if (user.phone.isEmpty && user.location.isEmpty) {
      return ProfileSetupScreen(role: user.role);
    } 
    
    // 3. Go Home
    // --- FIX 2: Attach the GlobalKey to the HomeScreen! ---
    return HomeScreen(key: homeScreenKey); 
  }
}