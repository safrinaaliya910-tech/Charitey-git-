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
  late AnimationController _buttonPulseController;
  late Animation<double> _buttonPulseAnimation;
  late AnimationController _magicHoverController;

  @override
  void initState() {
    super.initState();
    _buttonPulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _buttonPulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
        CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOut));
    _magicHoverController = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), _autoScrollNgos);
    });
  }

  void _autoScrollNgos() {
    if (!mounted || _isNgoScrollingManually || !_ngoScrollController.hasClients) return;
    
    double maxScroll = _ngoScrollController.position.maxScrollExtent;
    double currentScroll = _ngoScrollController.offset;
    
    if (currentScroll >= maxScroll) {
      _ngoScrollController.jumpTo(0);
      currentScroll = 0;
    }
    
    double distanceRemaining = maxScroll - currentScroll;
    int durationMs = (distanceRemaining / 80 * 1000).toInt();
    
    _ngoScrollController
        .animateTo(maxScroll, duration: Duration(milliseconds: durationMs), curve: Curves.linear)
        .then((_) {
      if (mounted && !_isNgoScrollingManually) {
        Future.delayed(const Duration(milliseconds: 50), _autoScrollNgos);
      }
    });
  }

  void _performSearch() {
    String query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DonorListingScreen(initialSearchQuery: query)));
      _searchController.clear();
    }
  }

  @override
  void dispose() {
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
        padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom + 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HERO IMAGE & CTA =================
            _buildHeroHeaderSection(),

            const SizedBox(height: Gap.sectionGap),

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
              height: 90,
              child: ListView(
                controller: _ngoScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _trustedNgoCard("Aishwaryam NGO"),
                  _trustedNgoCard("Helping Hands"),
                  _trustedNgoCard("Hope Foundation"),
                  _trustedNgoCard("Food Bridge"),
                  _trustedNgoCard("Donation Center"),
                ],
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
                  _buildAnimatedStatCard("85+", "Essentials\nDelivered",
                      Icons.favorite_rounded),
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
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 38), 
          child: ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.88, 1.0], 
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: SizedBox(
              width: double.infinity,
              child: Image.asset(
                'assets/hero_banner.jpg', 
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 20,
          right: 20,
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final userRole = authProvider.currentUserModel?.role;
              
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
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
                              onPressed: () => Navigator.pop(context),
                            ),
                            title: const Text(
                              "Tasks",
                              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
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
                      child: const Center(
                        child: Text(
                          "Tasks",
                          style: TextStyle(
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
                            builder: (_) => const DonorListingScreen(initialSearchQuery: ''))),
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
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volunteer_activism, color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Text("Browse Donation",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
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
      width: 210,
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
          onTap: () {},
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
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
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
                                height: 1.45)), // Increased height for premium readability
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