import 'package:flutter/material.dart';
import 'dart:async';
import 'donor_listing_screen.dart';
import 'community_hubs.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'volunteer_dashboard.dart'; // Ensure this is imported

// Theme Colors
final Color primary = const Color(0xFF7D444C);
final Color accent = const Color(0xFFCD5E77);
final Color soft = const Color(0xFFF4C2C2);

// SPACING SCALE
class Gap {
  static const double sectionGap = 32; // between one section and the next
  static const double headingToContent = 14; // heading -> its content

  // 👇 NEW: Hero "Browse Donations" button placement (change these numbers to fine-tune) 👇
  // 0  = button's top edge sits EXACTLY on the image's bottom line (no gap).
  // >0 = button overlaps the image by that many pixels (e.g. 12).
  static const double heroButtonOverlap = 0;
  static const double heroToPartners = 14; // gap: button -> "Verified Impact Partners"
}

class HeroPage extends StatefulWidget {
  const HeroPage({super.key});

  @override
  State<HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<HeroPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ScrollController _ngoScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Kept for future use
  int _currentPage = 0;
  bool _isNgoScrollingManually = false;
  // 👇 NEW: timer used to resume auto-scroll after the user stops touching the list 👇
  Timer? _resumeAutoScrollTimer;
  // 👇 NEW: true while the full-name pop-up is open (auto-scroll must stay paused) 👇
  bool _isNgoDialogOpen = false;
  late AnimationController _buttonPulseController;
  late Animation<double> _buttonPulseAnimation;
  late AnimationController _magicHoverController;

  @override
  void initState() {
    super.initState();
    _buttonPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _buttonPulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
        CurvedAnimation(
            parent: _buttonPulseController, curve: Curves.easeInOut));
    _magicHoverController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), _autoScrollNgos);
    });
  }

  void _autoScrollNgos() {
    if (!mounted || _isNgoScrollingManually || !_ngoScrollController.hasClients)
      return;

    double maxScroll = _ngoScrollController.position.maxScrollExtent;
    double currentScroll = _ngoScrollController.offset;

    if (currentScroll >= maxScroll) {
      _ngoScrollController.jumpTo(0);
      currentScroll = 0;
    }

    double distanceRemaining = maxScroll - currentScroll;
    int durationMs = (distanceRemaining / 80 * 1000).toInt();

    _ngoScrollController
        .animateTo(maxScroll,
            duration: Duration(milliseconds: durationMs), curve: Curves.linear)
        .then((_) {
      if (mounted && !_isNgoScrollingManually) {
        Future.delayed(const Duration(milliseconds: 50), _autoScrollNgos);
      }
    });
  }

  // 👇 NEW: Called when the user starts dragging the NGO list.
  // Stops auto-scroll so the user gets full manual control. 👇
  void _onUserStartedScrolling() {
    _resumeAutoScrollTimer?.cancel();
    _isNgoScrollingManually = true;
  }

  // 👇 NEW: Fully pauses auto-scroll (used on tap / mouse hover / pop-up open).
  // It also stops the animation that is currently running, so the card the user
  // is pointing at stays still. 👇
  void _pauseAutoScroll() {
    _resumeAutoScrollTimer?.cancel();
    _isNgoScrollingManually = true;
    if (_ngoScrollController.hasClients) {
      _ngoScrollController.jumpTo(_ngoScrollController.offset);
    }
  }

  // 👇 NEW: Called when the user's drag / fling finishes.
  // Auto-scroll resumes (from the current position) after 2 seconds. 👇
  void _onUserStoppedScrolling() {
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _isNgoDialogOpen) return;
      _isNgoScrollingManually = false;
      _autoScrollNgos();
    });
  }

  void _performSearch() {
    String query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DonorListingScreen(initialSearchQuery: query)));
      _searchController.clear();
    }
  }

  // 👇 UPDATED: Tap on a partner card -> "boom" pop-up (elastic scale + fade)
  // that shows the FULL NGO name (never cut off). 👇
  void _showNgoNameDialog(String name) {
    _isNgoDialogOpen = true;
    _pauseAutoScroll(); // keep the list still while the pop-up is open

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'NGO name',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: soft.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.gpp_good_rounded,
                          color: primary, size: 34),
                    ),
                    const SizedBox(height: 18),
                    // Full name - no maxLines / ellipsis so it is never cut off
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified,
                            color: Colors.blue, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "100% Verified",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.3, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    ).then((_) {
      // Pop-up closed -> allow auto-scroll to continue again
      _isNgoDialogOpen = false;
      if (mounted) _onUserStoppedScrolling();
    });
  }

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _pageController.dispose();
    _ngoScrollController.dispose();
    _searchController.dispose();
    _buttonPulseController.dispose();
    _magicHoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFF7F8),
            Color(0xFFF7E6EB),
            Color(0xFFF0D5DD),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            0, 0, 0, MediaQuery.of(context).padding.bottom + 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HERO IMAGE & CTA =================
            _buildHeroHeaderSection(),

            // 👇 UPDATED: tighter gap between the button and "Verified Impact Partners" 👇
            const SizedBox(height: Gap.heroToPartners),

            // ================= TRUSTED NGOs =================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              // 👇 Premium Heading Update
              child: Text("Verified Impact Partners",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2, // Slight letter spacing for elegance
                      color: Colors.black87)),
            ),
            const SizedBox(height: Gap.headingToContent),
            SizedBox(
              // 👇 UPDATED: height fits a 2-line name (longer names -> tap to see full name) 👇
              height: 92,
              // 👇 NEW: Detects the user's finger scroll so manual scrolling works
              // together with the auto-scroll 👇
              child: MouseRegion(
                // 👇 NEW (web / desktop): pause while the mouse is over the list so
                // the card can be clicked easily 👇
                onEnter: (_) => _pauseAutoScroll(),
                onExit: (_) {
                  if (!_isNgoDialogOpen) _onUserStoppedScrolling();
                },
                child: Listener(
                // 👇 NEW: the moment the list is touched, auto-scroll stops completely.
                // (Before, auto-scroll kept restarting under the finger and the tap was
                // lost, so the pop-up never opened.) 👇
                onPointerDown: (_) => _onUserStartedScrolling(),
                onPointerUp: (_) {
                  if (!_isNgoDialogOpen) _onUserStoppedScrolling();
                },
                onPointerCancel: (_) {
                  if (!_isNgoDialogOpen) _onUserStoppedScrolling();
                },
                child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Only react to the horizontal NGO list
                  if (notification.metrics.axis != Axis.horizontal) {
                    return false;
                  }
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    // User put a finger on the list -> stop auto-scroll
                    _onUserStartedScrolling();
                  } else if (notification is ScrollEndNotification &&
                      _isNgoScrollingManually) {
                    // User's drag / fling ended -> resume auto-scroll after a pause
                    _onUserStoppedScrolling();
                  }
                  return false;
                },
                child: ListView(
                  controller: _ngoScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _trustedNgoCard(
                        "Aishwariam Social Welfare Organisation (ASWO)"),
                    _trustedNgoCard("Imayam Social Welfare Association"),
                    _trustedNgoCard("Maxwell Charitable Trust"),
                    _trustedNgoCard("COORU Organisation"),
                    _trustedNgoCard("G18 Public Charitable Trust"),
                    _trustedNgoCard("REST NGO"),
                    _trustedNgoCard("Chandra Yuva Foundation"),
                    _trustedNgoCard("Sevasram Trust"),
                    _trustedNgoCard("Yettram Trust"),
                    _trustedNgoCard("Annai Old Age Home"),
                    _trustedNgoCard("Pudhiya Paadhai"),
                    _trustedNgoCard("Annai Trust"),
                  ],
                ),
                ),
                ),
              ),
            ),
            const SizedBox(height: Gap.sectionGap),

            // ================= CHARITEY MAGIC =================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              // 👇 Premium Heading Update
              child: Text("Seamless Giving Journey",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: Colors.black87)),
            ),
            const SizedBox(height: Gap.headingToContent),
            AnimatedBuilder(
              animation: _magicHoverController,
              builder: (context, child) {
                return Column(
                  children: [
                    // 👇 Trustable, empathetic copy updates 👇
                    _magicWhyCard(
                        Icons.campaign_rounded,
                        "Intelligent Matching",
                        "We instantly connect your generous donations with verified local organizations facing real-time food shortages.",
                        _magicHoverController.value,
                        0),
                    _magicWhyCard(
                        Icons.pan_tool_alt_rounded,
                        "Effortless Pledging",
                        "Browse live community requests and commit your surplus meals or essentials with a single, seamless tap.",
                        _magicHoverController.value,
                        1),
                    _magicWhyCard(
                        Icons.forum_rounded,
                        "Direct Connection",
                        "Coordinate securely via live chat and see exactly where and how your contribution is changing lives.",
                        _magicHoverController.value,
                        2),
                  ],
                );
              },
            ),
            const SizedBox(height: Gap.sectionGap),

            // ================= MILESTONE TRACKER =================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              // 👇 Premium Heading Update
              child: Text("Community Impact",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.black54)),
            ),
            const SizedBox(height: Gap.headingToContent),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildAnimatedStatCard(
                      "120+", "Meals\nShared", Icons.restaurant_rounded),
                  _buildAnimatedStatCard(
                      "85+", "Essentials\nDelivered", Icons.favorite_rounded),
                  _buildAnimatedStatCard(
                      "30+", "Verified\nNGOs", Icons.verified_user_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= INTEGRATED IMAGE & BUTTON SECTION =================
  Widget _buildHeroHeaderSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // 👇 UPDATED: no extra space under the image -> the button starts exactly at the image's bottom line 👇
          padding: EdgeInsets.zero,
          child: ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                // 👇 UPDATED: fade finishes at 97% (was 100%) so the last pixel rows are
                // fully transparent -> no thin line at the bottom of the image 👇
                stops: [0.0, 0.86, 0.97],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: SizedBox(
              width: double.infinity,
              // 👇 NEW: ClipRect + heightFactor trims the last sub-pixel row of the image
              // (that row caused the thin line). Nothing visible is lost. 👇
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 0.99,
                  child: Image.asset(
                    'assets/hero_banner.jpg',
                    fit: BoxFit.fitWidth,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 👇 UPDATED: button sits directly BELOW the image (no gap). It is a normal
        // Column child now, so it is always fully tappable. 👇
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Transform.translate(
          offset: const Offset(0, -Gap.heroButtonOverlap),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final userRole = authProvider.currentUserModel?.role;

              // ── Button label based on role ──
              final String buttonLabel;
              if (userRole == 'volunteer') {
                buttonLabel = "Browse Tasks";
              } else if (userRole == 'ngo') {
                buttonLabel = "Browse Requests";
              } else {
                // donor (and any other / null)
                buttonLabel = "Browse Donations";
              }

              if (userRole == 'volunteer') {
                return ScaleTransition(
                  scale: _buttonPulseAnimation,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            backgroundColor: const Color(0xFFFCF3F5),
                            elevation: 0,
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.black87),
                              onPressed: () => Navigator.pop(context),
                            ),
                            title: const Text(
                              "Tasks",
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          body: const VolunteerDashboard(),
                        ),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF753342), Color(0xFFC55A70)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.18),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, -4),
                          ),
                          BoxShadow(
                            color: accent.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          buttonLabel, // "Browse Tasks"
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return ScaleTransition(
                  scale: _buttonPulseAnimation,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DonorListingScreen(
                                initialSearchQuery: ''))),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF753342), Color(0xFFC55A70)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.18),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, -4),
                          ),
                          BoxShadow(
                            color: accent.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.volunteer_activism,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              buttonLabel, // "Browse Donations" or "Browse Requests"
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          ),
        ),
      ],
    );
  }

  // ================= OTHER WIDGETS =================
  Widget _buildAnimatedStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [primary, accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: accent.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 26),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _trustedNgoCard(String name) {
    return Container(
      width: 250, // 👇 UPDATED: wider card (was 210) so long names need fewer lines 👇
      margin: const EdgeInsets.only(left: 15, right: 5, top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: primary.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            debugPrint('NGO card tapped: $name');
            _showNgoNameDialog(name);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: soft.withOpacity(0.35),
                  child: Icon(Icons.gpp_good_rounded, color: primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            // 👇 UPDATED: max 2 lines in the card. If the name is longer,
                            // tap the card to see the FULL name in the pop-up
                            // (web: hover also shows the full name in a tooltip). 👇
                            child: Tooltip(
                              message: name,
                              child: Text(name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      height: 1.25)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: Colors.blue, size: 14),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // 👇 Premium Verification Copy
                      Text("100% Verified",
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _magicWhyCard(IconData icon, String title, String subtitle,
      double animValue, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: primary.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [soft, Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: soft.withOpacity(0.6), blurRadius: 8)
                      ],
                    ),
                    child: Icon(icon, color: primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                letterSpacing: 0.2)),
                        const SizedBox(height: 6),
                        // 👇 Polished Typography Line Height
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                height:
                                    1.45)), // Increased height for premium readability
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}