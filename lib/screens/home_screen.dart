//home_screen.dart
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
import 'volunteer_payment_screen.dart'; // 👇 ADD THIS// 👇 FIX: ADDED THIS MISSING IMPORT!

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

class HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  String? targetPostId;
  
  // 👇 Tracks if payment lock dialog is currently shown to prevent duplicate popups
  bool _isPaymentLockShown = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    targetPostId = widget.targetPostId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUserModel;
      if (user != null) {
        if (user.role == 'ngo') {
          FirestoreService().cleanUpExpiredRequests(user.uid);
        }
        // 👇 Start listening for pending delivery fee payments if user is a donor 👇
        if (user.role == 'donor') {
          _listenForPendingPayments(user.uid);
        }
      }
    });
  }

 void _listenForPendingPayments(String donorUid) {
    FirebaseFirestore.instance
        .collection('donations')
        .where('donorId', isEqualTo: donorUid)
        .where('status', isEqualTo: 'completed_awaiting_payment')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && !_isPaymentLockShown && mounted) {
        setState(() => _isPaymentLockShown = true); // Mark as shown
        String donationId = snapshot.docs.first.id;
        
        // Push the new standalone payment screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VolunteerPaymentScreen(donationId: donationId),
          ),
        ).then((_) {
          // When they finish and it pops back, reset the flag
          if (mounted) setState(() => _isPaymentLockShown = false);
        });
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
    // 👇 3. NEW: VOLUNTEER ROLE 👇
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
        titleSpacing: 0, // 👈 CRUCIAL: Removes default alignment padding and snaps layout to the left
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 12), // 👈 Provides a clean, standardized margin from the screen edge
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
                  return const Icon(Icons.broken_image, size: 18, color: Colors.grey);
                },
              ),
            ),
            const SizedBox(width: 8), // 👈 Snaps the text close right next to the bird icon
          const Text(
            "Fourth Idly",
            style: TextStyle(
              color: Color(0xFF6F313E), // Premium dark burgundy to match the hero image
              fontSize: 20,             // Increased size for a better logo presence
              fontWeight: FontWeight.w900, // Heavy, bold weight for the whole text
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
      // ==========================================
      // CUSTOM ARCHED OVERFLOW FLOATING NAV BAR
      // ==========================================
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
                            color: const Color(
                              0xFF7D444C,
                            ).withValues(alpha: 0.35),
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
          "About Charitey",
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
            "About Charitey",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Charitey brings donors, NGOs, and volunteers together in one powerful community to move help quickly, safely, and responsibly to people who need it most.",
            style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
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
            "To build a trusted platform that enables individuals, organizations, and volunteers to work together in delivering essential resources efficiently, transparently, and responsibly.",
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
            "To become the world's most trusted community platform for social impact, where every act of generosity creates lasting change and every community thrives through collective responsibility.",
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
          _bullet("Compassion – Every action begins with empathy."),
          _bullet(
            "Integrity – Transparency and honesty guide every interaction.",
          ),
          _bullet(
            "Trust – Building lasting confidence among donors, NGOs, and volunteers.",
          ),
          _bullet("Community – Stronger together, greater impact."),
          _bullet(
            "Responsibility – Every contribution is handled with care and accountability.",
          ),
          _bullet(
            "Innovation – Using technology to make kindness more accessible.",
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              "Together, we don't just give. We create hope.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "One community. One purpose. Endless impact.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
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
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  // Empty strings mean unanswered
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
    // 1. Validate that all questions have been answered
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
      // 2. Safely grab the current user's data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUserModel;

      if (user == null) {
        throw Exception("User not found. Please log in again.");
      }

      // 3. Package the data for the Admin Panel
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

      // 4. Send to Firebase
      await FirestoreService().submitFeedback(feedbackData);

      if (!mounted) return;

      // 5. Success UI
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