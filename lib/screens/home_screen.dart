//home_screen.dart
import 'dart:async';
import 'dart:ui'; // 👈 NEW: needed for the frosted-glass blur (ImageFilter)
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
import 'faq_screen.dart';

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
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    if (user == null) return;

    _hasInitializedForUser = true;

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
      if (mounted) {
        setState(() => _isPaymentLockShown = false);
        final user =
            Provider.of<AuthProvider>(context, listen: false).currentUserModel;
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

  // Colours sampled from the top edge of the hero banner (left -> right),
  // used so the header and the banner join without a visible seam.
  static const List<Color> _bannerTopColors = [
    Color(0xFFFED3CA),
    Color(0xFFFEDCD3),
    Color(0xFFFEE0D8),
    Color(0xFFFDDCD3),
    Color(0xFFFED7D0),
    Color(0xFFFDD2CB),
    Color(0xFFFDCDC3),
  ];
  // How far (in px) the hero banner is pulled up under the header to close
  // the empty strip between the pill and the banner. Set to 0 to disable.
  static const double _heroLift = 14;
  static const List<double> _bannerTopStops = [
    0.0, 0.14, 0.29, 0.48, 0.71, 0.86, 1.0,
  ];

  // Round white button used for the bell and menu inside the header pill
  Widget _pillButton(Widget child) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFF6DDE2).withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7D444C).withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: child),
    );
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

    // The gradient lives OUTSIDE the Scaffold so the area behind the header
    // pill shows the same soft page gradient (no separate header rectangle).
    return Container(
      decoration: _currentIndex == 0
          ? const BoxDecoration(color: Color(0xFFFAFAFA))
          : const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFDF7F8), Color(0xFFEEDAE0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.1, 1.0],
              ),
            ),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 66,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        // Soft pink backdrop (same tone as the hero banner) so the floating
        // pill below looks like it sits on the page, not on a white strip.
        flexibleSpace: _currentIndex == 0
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // bottom edge = exact colours of the banner's top edge
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _bannerTopColors,
                        stops: _bannerTopStops,
                      ),
                    ),
                  ),
                  // lighter cream at the very top, fading into the banner tone
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFFF6F4).withValues(alpha: 0.95),
                          const Color(0xFFFFF6F4).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : null, // no extra header rectangle on other tabs
        // Floating rounded "pill" header: logo + name on the left,
        // notification and menu buttons on the right.
        title: Container(
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0.96),
                const Color(0xFFFFEDF0).withValues(alpha: 0.90),
                const Color(0xFFFFE3E8).withValues(alpha: 0.82),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC25A70).withValues(alpha: 0.09),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo: the PNG has an opaque white background, so this filter turns
              // the white into transparent and keeps only the maroon elephant.
              // That way it blends into the pill instead of showing a white box.
              SizedBox(
                height: 44,
                width: 44,
                child: Transform.scale(
                  scale: 1.5,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0, 0, 0, 0, 139, //  R  -> brand maroon
                      0, 0, 0, 0, 19, //   G
                      0, 0, 0, 0, 54, //   B
                      -2.3, 0, 0, 2.3, -2.3, // A -> white = transparent
                    ]),
                    child: Image.asset(
                      'assets/app_logo.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image,
                          size: 18,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  "Fourth Idly",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF8B1E3F),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              StreamBuilder<List<NotificationModel>>(
                stream: FirestoreService().getUserNotifications(user.uid),
                builder: (context, snapshot) {
                  bool hasUnread = false;
                  if (snapshot.hasData) {
                    hasUnread = snapshot.data!.any(
                      (notification) => !notification.isRead,
                    );
                  }
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                    child: _pillButton(
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF8B1E3F),
                            size: 25,
                          ),
                          if (hasUnread)
                            Positioned(
                              right: 1,
                              top: 1,
                              child: Container(
                                height: 10,
                                width: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: 'Menu',
                child: _pillButton(
                  const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF8B1E3F),
                    size: 25,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                offset: const Offset(0, 50),
                color: const Color(0xFFFFF0F1),
                onSelected: (String result) async {
                  if (result == 'about') {
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
                  } else if (result == 'faq') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FaqScreen(initialRole: user.role),
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
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<String>>[
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
                  PopupMenuItem<String>(
                    value: 'faq',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.help_outline_rounded,
                          color: Color(0xFF7D444C),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Help & FAQs',
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
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_currentIndex == 0)
            Positioned(
              top: -_heroLift,
              left: 0,
              right: 0,
              bottom: 0,
              child: screens[_currentIndex],
            )
          else
            screens[_currentIndex],
          // Home tab only: softly fades the banner's top edge into the header
          // so there is no hard line between the two. Touches pass through.
          if (_currentIndex == 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 16,
              child: IgnorePointer(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.transparent],
                  ).createShader(rect),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _bannerTopColors,
                        stops: _bannerTopStops,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // ======================================================================
      // ✨ BLENDED "FROSTED GLASS" BOTTOM NAVIGATION BAR
      // - The Scaffold already has extendBody: true, so every page scrolls
      //   BEHIND this bar.
      // - BackdropFilter blurs whatever page is behind it, and the very light
      //   translucent tint lets the page colours show through, so the bar
      //   always matches the page instead of looking like a separate white card.
      // - No navigation logic was changed (same indices, same setState calls).
      // ======================================================================
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          height: 85,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ---- Glass bar ----
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 65,
                  // soft, wide, low-opacity shadow (no hard edge)
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7D444C).withValues(alpha: 0.10),
                        blurRadius: 24,
                        spreadRadius: -2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        decoration: BoxDecoration(
                          // translucent glass tint (page colours show through)
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.55),
                              const Color(0xFFFFE9ED).withValues(alpha: 0.30),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          // thin bright rim = glass edge highlight
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.65),
                            width: 1.2,
                          ),
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
                            const themeColor = Color(0xFF7D444C);
                            final inactiveColor =
                                themeColor.withValues(alpha: 0.45);
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
                                    // soft highlight capsule behind active icon
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                      width: isActive ? 46 : 34,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? themeColor.withValues(
                                                alpha: 0.13)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: isActive
                                            ? themeColor
                                            : inactiveColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        color: isActive
                                            ? themeColor
                                            : inactiveColor,
                                        fontSize: 10,
                                        fontWeight: isActive
                                            ? FontWeight.w700
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
                  ),
                ),
              ),

              // ---- Centre action button (Donate / Request / Deliveries / Tasks) ----
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
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF9A5560), Color(0xFF6E363E)],
                        ),
                        shape: BoxShape.circle,
                        // glass-like white ring so it floats on the bar
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.70),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7D444C)
                                .withValues(alpha: 0.40),
                            blurRadius: 16,
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