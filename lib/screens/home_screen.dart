//home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';
import '../models/notification_model.dart';
import '../models/chat_preview_model.dart';
import 'donor_listing_screen.dart';
import 'ngo_dashboard.dart';
import 'profile_screen.dart';
import 'create_listing_screen.dart';
import 'role_selection_screen.dart';
import 'hero_page.dart';
import 'notifications_screen.dart';
import 'chat_screen.dart';
import 'travel_agency_dashboard.dart';
import 'volunteer_dashboard.dart';
import 'rating_dialog.dart';
import 'volunteer_payment_screen.dart';

// ==========================================
// 1. HOME SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final String? targetPostId;
  const HomeScreen({Key? key, this.initialIndex = 0, this.targetPostId})
      : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  String? targetPostId;

  // Tracks if payment lock dialog is currently shown to prevent duplicate popups
  bool _isPaymentLockShown = false;

  bool _hasInitializedForUser = false;

  StreamSubscription<QuerySnapshot>? _pendingPaymentSub;

  // 👇 All statuses that must keep the donor phone locked
  static const List<String> _lockStatuses = [
    'completed_awaiting_payment',
    'payment_verification_pending',
    'admin_verification_pending',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    targetPostId = widget.targetPostId;
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserDependentLogic();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initUserDependentLogic();
  }

  void _initUserDependentLogic() {
    if (_hasInitializedForUser) return;
    final user = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUserModel;
    if (user == null) return;

    _hasInitializedForUser = true;

    if (user.role == 'ngo') {
      FirestoreService().cleanUpExpiredRequests(user.uid);
    }
    if (user.role == 'donor') {
      _listenForPendingPayments(user.uid);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUserModel;
      if (user != null && user.role == 'donor') {
        _checkPendingPaymentOnce(user.uid);
      }
    }
  }

  // 👇 Strong one-time check (also used on app resume)
  Future<void> _checkPendingPaymentOnce(String donorUid) async {
    if (_isPaymentLockShown || !mounted) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: donorUid)
          .where('status', whereIn: _lockStatuses)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty && !_isPaymentLockShown && mounted) {
        _showPaymentLock(snap.docs.first.id);
      }
    } catch (e) {
      debugPrint('Pending payment re-check failed: $e');
    }
  }

  // 👇 Continuous real-time listener – now watches ALL lock statuses
  void _listenForPendingPayments(String donorUid) {
    _pendingPaymentSub?.cancel(); // safety

    _pendingPaymentSub = FirebaseFirestore.instance
        .collection('donations')
        .where('donorId', isEqualTo: donorUid)
        .where('status', whereIn: _lockStatuses)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && !_isPaymentLockShown && mounted) {
        _showPaymentLock(snapshot.docs.first.id);
      }
    }, onError: (e) {
      debugPrint('Pending payment listener error: $e');
    });
  }

  void _showPaymentLock(String donationId) {
    if (!mounted) return;
    setState(() => _isPaymentLockShown = true);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerPaymentScreen(donationId: donationId),
      ),
    ).then((_) {
      // After the screen is closed we re-check immediately.
      // If the status is still one of the lock statuses, the lock will
      // appear again. This prevents any “escape” by force-closing the app.
      if (mounted) {
        setState(() => _isPaymentLockShown = false);
        final user = Provider.of<AuthProvider>(context, listen: false)
            .currentUserModel;
        if (user != null && user.role == 'donor') {
          _checkPendingPaymentOnce(user.uid);
        }
      }
    });
  }

  void switchTab(int index, {String? postId}) {
    setState(() {
      _currentIndex = index;
      targetPostId = postId;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingPaymentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFB56F76)),
        ),
      );
    }

    List<Widget> screens;
    List<BottomNavigationBarItem> navItems;

    // --- 1. NGO ROLE ---
    if (user.role == 'ngo') {
      screens = [
        const HeroPage(),
        NgoDashboard(targetPostId: targetPostId),
        const CreateListingScreen(),
        const ChatListScreen(),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Activity',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_rounded),
          label: 'Request',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_rounded),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];
    }
    // --- 2. TRAVEL AGENCY ROLE ---
    else if (user.role == 'travel_agency') {
      screens = [
        const HeroPage(),
        NgoDashboard(targetPostId: targetPostId),
        const TravelAgencyDashboard(),
        const ChatListScreen(),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Activity',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping_rounded),
          label: 'Deliveries',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_rounded),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];
    }
    // 👇 3. VOLUNTEER ROLE 👇
    else if (user.role == 'volunteer') {
      screens = [
        const HeroPage(),
        NgoDashboard(targetPostId: targetPostId),
        const VolunteerDashboard(),
        const ChatListScreen(),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Activity',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_car_rounded),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_rounded),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];
    }
    // --- 4. DONOR ROLE (Default) ---
    else {
      screens = [
        const HeroPage(),
        NgoDashboard(targetPostId: targetPostId),
        const DonorListingScreen(),
        const ChatListScreen(),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Activity',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_rounded),
          label: 'Donate',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_rounded),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];
    }

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 12),
            Container(
              height: 32,
              width: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.asset(
                'assets/app_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image,
                      size: 18, color: Colors.grey);
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Fourth Idly",
              style: TextStyle(
                color: Color(0xFF6F313E),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFamily: 'serif',
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: FirestoreService().getUserNotifications(user.uid),
            builder: (context, snapshot) {
              bool hasUnread = false;
              if (snapshot.hasData) {
                hasUnread = snapshot.data!.any(
                  (notification) => !notification.isRead,
                );
              }
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black87,
                      size: 26,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          height: 10,
                          width: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white,
                                spreadRadius: 1,
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.black87,
              size: 26,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            offset: const Offset(0, 50),
            color: const Color(0xFFFFF0F1),
            onSelected: (String result) async {
              if (result == 'contact') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                );
              } else if (result == 'about') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                );
              } else if (result == 'feedback') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                );
              } else if (result == 'recent_donations') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecentDonationsScreen(),
                  ),
                );
              } else if (result == 'logout') {
                await authProvider.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectionScreen(),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'contact',
                child: Row(
                  children: const [
                    Icon(
                      Icons.contact_mail_rounded,
                      color: Color(0xFF7D444C),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Contact Support',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'about',
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF7D444C),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'About Fouth Idly',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'feedback',
                child: Row(
                  children: const [
                    Icon(
                      Icons.feedback_rounded,
                      color: Color(0xFF7D444C),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Share Feedback',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          height: 85,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7D444C).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(navItems.length, (index) {
                      if (index == 2) {
                        return const Expanded(child: SizedBox.shrink());
                      }
                      final item = navItems[index];
                      final icon = (item.icon as Icon).icon!;
                      final label = item.label ?? '';
                      final isActive = _currentIndex == index;
                      final themeColor = const Color(0xFF7D444C);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentIndex = index;
                            });
                            if (index != 1) targetPostId = null;
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                color: isActive ? themeColor : Colors.black38,
                                size: 24,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                label,
                                style: TextStyle(
                                  color: isActive ? themeColor : Colors.black38,
                                  fontSize: 10,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = 2;
                        targetPostId = null;
                      });
                    },
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7D444C),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7D444C)
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            (navItems[2].icon as Icon).icon!,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            navItems[2].label ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... The rest of your ChatListScreen, AboutUs, and Feedback screens stay EXACTLY as they are ...

// =========================================================================
// 2. CHAT LIST SCREEN
// =========================================================================

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final ChatService chatService = ChatService();
    final Color themeColor = const Color(0xFFB56F76);

    if (user == null) return const Center(child: Text("Please log in."));

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
        body: StreamBuilder<List<ChatPreviewModel>>(
          stream: chatService.getChatInbox(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: themeColor),
              );
            }
            if (snapshot.hasError) {
              return const Center(child: Text("Error loading chats."));
            }

            final chatPreviews = snapshot.data ?? [];

            if (chatPreviews.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "No conversations yet",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Your active chats will appear here.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: chatPreviews.length,
              itemBuilder: (context, index) {
                final preview = chatPreviews[index];
                String formattedTime = DateFormat(
                  'h:mm a',
                ).format(preview.lastMessageTime);

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: themeColor.withOpacity(0.15),
                      child: Text(
                        preview.participantName.isNotEmpty
                            ? preview.participantName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Text(
                      preview.participantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        preview.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: preview.hasUnread
                              ? Colors.black87
                              : Colors.grey.shade600,
                          fontWeight: preview.hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    trailing: SizedBox(
                      width: 65,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: preview.hasUnread
                                  ? themeColor
                                  : Colors.grey.shade500,
                            ),
                          ),
                          if (preview.hasUnread) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: themeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    onTap: () {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('chat_previews')
                          .doc(preview.chatRoomId)
                          .update({'hasUnread': false});
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: preview.participantId,
                            otherUserName: preview.participantName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// =========================================================================
// 3. POPUP MENU SCREENS
// =========================================================================

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  final Color themeColor = const Color(0xFF7D444C);
  final Color bgColor = const Color(0xFFFBEBEB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "About Fourth Idly",
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            "About Fourth Idly",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Give what is needed. Reach who needs it. See the impact.",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: themeColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Fourth Idly makes giving simple, meaningful, and transparent. We connect people who want to help with verified NGOs and communities that have real, current needs. Instead of donating blindly, you can discover what is needed, pledge what you can provide, coordinate directly, and follow the journey of your contribution.",
            style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
          ),
          const SizedBox(height: 24),
          Text(
            "Our Giving Flow",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _numbered(
            1,
            "Discover Needs",
            "Explore real-time requests from verified NGOs and communities and understand what they actually need.",
          ),
          _numbered(
            2,
            "Smart Match",
            "Find the right opportunity for your donation based on the item, quantity, location, urgency, and need.",
          ),
          _numbered(
            3,
            "Pledge to Help",
            "Choose a request and pledge your available food, essentials, or resources in just a few taps.",
          ),
          _numbered(
            4,
            "Connect Directly",
            "Chat with the requesting organization to confirm details and coordinate the pickup or drop-off.",
          ),
          _numbered(
            5,
            "Deliver",
            "Get your contribution to the right place through a clear and coordinated handover.",
          ),
          _numbered(
            6,
            "See the Impact",
            "Track your contribution and receive updates on how your help reached the people who needed it.",
          ),
          const SizedBox(height: 24),
          Text(
            "Our Mission",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "To make every act of giving reach the right need at the right time.",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Fourth Idly aims to create a trusted community where donors, NGOs, volunteers, and people in need can work together to reduce wastage, respond to real needs, and deliver help efficiently and responsibly.",
            style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
          ),
          const SizedBox(height: 24),
          Text(
            "Our Vision",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "A world where nothing useful goes to waste and no genuine need goes unanswered.",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We envision a connected community where surplus resources find their way to people who need them, creating a more responsible, transparent, and compassionate way of giving.",
            style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
          ),
          const SizedBox(height: 24),
          Text(
            "Our Core Values",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _bullet(
            "Compassion – Understand the need before deciding how to help.",
          ),
          _bullet(
            "Transparency – Make every request, pledge, and contribution clear and accountable.",
          ),
          _bullet(
            "Trust – Connect people with verified organizations and genuine needs.",
          ),
          _bullet(
            "Responsibility – Encourage giving based on what is actually needed, not simply what is available.",
          ),
          _bullet(
            "Community – Bring donors, NGOs, volunteers, and communities together to create meaningful impact.",
          ),
          const SizedBox(height: 28),
          Text(
            "Our Tagline",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Give what is needed. Reach who needs it. See the impact.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "Close",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "• ",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numbered(int number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: themeColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              "$number",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87.withOpacity(0.75),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  Map<int, String> answers = {1: '', 2: '', 3: '', 4: '', 5: ''};
  final Color themeColor = const Color(0xFF7D444C);
  final Color cardColor = const Color(0xFFFFF0F1);
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Share Feedback",
          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildQuestionWithOptions(
            1,
            "Q1. How would you rate your overall experience with Fouth Idly?",
            [
              '⭐☆☆☆☆ 1 Star',
              '⭐⭐☆☆☆ 2 Stars',
              '⭐⭐⭐☆☆ 3 Stars',
              '⭐⭐⭐⭐☆ 4 Stars',
              '⭐⭐⭐⭐⭐ 5 Stars',
            ],
          ),
          _buildQuestionWithOptions(
            2,
            "Q2. How easy was it to use the Fouth Idly app?",
            ['Very Easy', 'Easy', 'Somewhat Difficult', 'Difficult'],
          ),
          _buildQuestionWithOptions(
            3,
            "Q3. How satisfied are you with the services provided by Fourth Idly?",
            [
              'Very Satisfied',
              'Satisfied',
              'Somewhat Satisfied',
              'Not Satisfied',
            ],
          ),
          _buildQuestionWithOptions(
            4,
            "Q4. How helpful was Fourth Idly in meeting your needs?",
            ['Very Helpful', 'Helpful', 'Slightly Helpful', 'Not Helpful'],
          ),
          _buildQuestionWithOptions(
            5,
            "Q5. How likely are you to recommend Fourth Idly to your friends or family?",
            ['Definitely', 'Probably', 'Maybe', 'No'],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Submit",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (answers.values.contains('')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all 5 questions before submitting.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUserModel;

      if (user == null) {
        throw Exception("User not found. Please log in again.");
      }

      Map<String, dynamic> feedbackData = {
        'userId': user.uid,
        'userName': user.name,
        'userEmail': user.email,
        'userRole': user.role,
        'q1_overall_experience': answers[1],
        'q2_ease_of_use': answers[2],
        'q3_satisfaction': answers[3],
        'q4_helpfulness': answers[4],
        'q5_recommendation': answers[5],
        'submittedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService().submitFeedback(feedbackData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback Submitted! Thank you.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildQuestionWithOptions(
    int qIndex,
    String question,
    List<String> options,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...options.map((option) {
            bool isSelected = answers[qIndex] == option;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => answers[qIndex] = option),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? themeColor : Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(option, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class RecentDonationsScreen extends StatelessWidget {
  const RecentDonationsScreen({super.key});
  final Color themeColor = const Color(0xFF7D444C);
  final Color cardColor = const Color(0xFFFFF0F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Recent Donations",
          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Overview",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Raised", style: TextStyle(color: Colors.grey)),
                    Text(
                      "N/A",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "0",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("Completed", style: TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Total Donations",
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      "93",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "93",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("Pending", style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Recent Donations",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDonationCard(
            "quFu5DfaelN06vmaaNjQ",
            "13 Apr 2026, 10:41 AM",
            "PENDING",
            Colors.grey.shade400,
          ),
          _buildDonationCard(
            "88XkROatWB9TaLCCNKC8",
            "13 Apr 2026, 9:16 AM",
            "DELIVERY_ACCEPTED",
            Colors.orange,
          ),
          _buildDonationCard(
            "gwTgwflYOQfFvgHOf274",
            "13 Apr 2026, 9:13 AM",
            "DELIVERY_ACCEPTED",
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard(
    String id,
    String date,
    String status,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sree",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("ID: $id", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            "Date: $date",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Contact Support",
          style: TextStyle(
            color: const Color(0xFF7D444C),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Text(
          "Contact Support: support@fouthidly.com\nPhone: +91 xxxxxxxxxx",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}