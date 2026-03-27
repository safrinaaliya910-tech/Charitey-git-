import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // REQUIRED for time formatting
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart'; // REQUIRED for inbox stream
import '../models/notification_model.dart';
import '../models/chat_preview_model.dart'; // REQUIRED for the inbox list
import 'donor_listing_screen.dart';
import 'ngo_dashboard.dart';
import 'volunteer_dashboard.dart';
import 'profile_screen.dart';
import 'create_listing_screen.dart';
import 'role_selection.dart';
import 'hero_page.dart'; 
import 'notifications_screen.dart'; 
import 'chat_screen.dart'; // REQUIRED to open a specific chat

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

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
        const NgoDashboard(),
        const CreateListingScreen(), 
        const ChatListScreen(), // NOW USES THE REAL CHAT INBOX BELOW
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Activity'),
        BottomNavigationBarItem(icon: Icon(Icons.add_circle_rounded), label: 'Request'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ];
    } 
    // --- 2. TRAVEL AGENCY ROLE ---
    else if (user.role == 'travel_agency') {
      screens = [
        const HeroPage(), 
        const TravelAgencyDashboardPlaceholder(), 
        const Center(child: Text("Available Deliveries Page Coming Soon!")), 
        const ChatListScreen(), // NOW USES THE REAL CHAT INBOX BELOW
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Activity'),
        BottomNavigationBarItem(icon: Icon(Icons.local_shipping_rounded), label: 'Deliveries'), 
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ];
    } 
    // --- 3. DONOR / VOLUNTEER ROLE (Default) ---
    else {
      screens = [
        const HeroPage(), 
        const VolunteerDashboard(),
        const DonorListingScreen(),
        const ChatListScreen(), // NOW USES THE REAL CHAT INBOX BELOW
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Activity'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Donate'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ];
    }

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      // --- Styled AppBar with Notifications Added ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            // --- YOUR CUSTOM BIRD LOGO ---
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/app_logo.png', // Correctly pointing to your new file
                height: 36,
                width: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback just in case the image fails to load
                  return Container(
                    height: 36, width: 36, color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 20),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "CHARITEY",
              style: TextStyle(color: Color(0xFF7D444C), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          // 🔔 SMART NOTIFICATION BELL
          StreamBuilder<List<NotificationModel>>(
            stream: FirestoreService().getUserNotifications(user.uid),
            builder: (context, snapshot) {
              // Check if there are any unread notifications
              bool hasUnread = false;
              if (snapshot.hasData) {
                hasUnread = snapshot.data!.any((notification) => !notification.isRead);
              }

              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 26),
                    // ONLY show the red dot if hasUnread is TRUE
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
                               BoxShadow(color: Colors.white, spreadRadius: 1, blurRadius: 1)
                            ]
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                },
              );
            }
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await authProvider.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              );
            },
          )
        ],
      ),
      body: screens[_currentIndex],      
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFB56F76), 
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          elevation: 0,
          items: navItems, 
        ),
      ),
    );
  }
}

// ==========================================
// 3. PLACEHOLDER WIDGETS
// ==========================================

class TravelAgencyDashboardPlaceholder extends StatelessWidget {
  const TravelAgencyDashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFB56F76).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.airport_shuttle_rounded, size: 60, color: Color(0xFFB56F76)),
          ),
          const SizedBox(height: 20),
          const Text(
            "Logistics Dashboard",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            "Fleet tracking and food delivery\nroutes will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}
// ==========================================
// 4. REAL CHAT INBOX SCREEN 
// ==========================================
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final ChatService chatService = ChatService();
    final Color themeColor = const Color(0xFFB56F76);

    if (user == null) return const Center(child: Text("Please log in."));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: StreamBuilder<List<ChatPreviewModel>>(
        stream: chatService.getChatInbox(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: themeColor));
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading chats."));
          }

          final chatPreviews = snapshot.data ?? [];

          // --- EMPTY STATE ---
          if (chatPreviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No conversations yet",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your active chats will appear here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4),
                  ),
                ],
              ),
            );
          }

          // --- INBOX LIST ---
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: chatPreviews.length,
            itemBuilder: (context, index) {
              final preview = chatPreviews[index];
              String formattedTime = DateFormat('h:mm a').format(preview.lastMessageTime);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: themeColor.withValues(alpha: 0.15),
                    child: Text(
                      preview.participantName.isNotEmpty ? preview.participantName[0].toUpperCase() : '?',
                      style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  title: Text(
                    preview.participantName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      preview.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: preview.hasUnread ? Colors.black87 : Colors.grey.shade600,
                        fontWeight: preview.hasUnread ? FontWeight.w600 : FontWeight.normal,
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
                          style: TextStyle(fontSize: 12, color: preview.hasUnread ? themeColor : Colors.grey.shade500),
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
                        ]
                      ],
                    ),
                  ),
                  onTap: () {
                    // Mark as read in Firestore to remove the dot
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('chat_previews')
                        .doc(preview.chatRoomId)
                        .update({'hasUnread': false});

                    // Navigate to the Direct Chat Screen
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
    );
  }
}