import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'services/navigation_keys.dart';
import 'package:flutter/foundation.dart';
import 'screens/pending_verification_screen.dart';

final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authProvider = AuthProvider();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: authProvider)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _notificationService.initNotifications();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fourth Idly',
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: notificationScaffoldMessengerKey, // ← THIS WAS MISSING
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

    if (user == null) {
      return const SplashScreen();
    }

    if (user.phone.isEmpty && user.location.isEmpty) {
      return ProfileSetupScreen(role: user.role);
    }

    final bool requiresVerification = user.role == 'ngo' || user.role == 'volunteer';
    final bool isVerified = user.status == 'approved' || user.status == 'active';
    if (requiresVerification && !isVerified) {
      return const PendingVerificationScreen();
    }

    return HomeScreen(key: homeScreenKey);
  }
}