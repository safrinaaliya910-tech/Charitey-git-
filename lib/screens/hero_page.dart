import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'donor_listing_screen.dart';
import 'community_hubs.dart'; 
import '../providers/auth_provider.dart'; // Ensure AuthProvider is imported
import 'package:provider/provider.dart'; // Ensure Provider is imported

// Theme Colors
final Color primary = const Color(0xFF7D444C);
final Color accent = const Color(0xFFCD5E77);
final Color soft = const Color(0xFFF4C2C2);

class HeroPage extends StatefulWidget {
  const HeroPage({super.key});

  @override
  State<HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<HeroPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ScrollController _ngoScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 0;
  bool _isNgoScrollingManually = false;

  late AnimationController _buttonPulseController;
  late Animation<double> _buttonPulseAnimation;
  late AnimationController _magicHoverController;

  Timer? _heroTimer;
  Timer? _ctaTimer;

  int _ctaIndex = 0;
  int _tickerIndex = 0;
  
  final List<String> _tickerItems = [
    "Sree just donated 20 fresh meals to Aishwaryam NGO",
    "Rahul shipped a bundle of winter clothes & care kits",
    "Priya sponsored 15 textbook sets for the evening shelter",
    "Fresh fruits drive completed by 4 local donors just now"
  ];

  final List<String> _heroImages = [
    "https://i.ibb.co/HDvrQdj8/5fcecbbb-9e5e-40fb-b211-9450657130f3.png",
    "https://i.ibb.co/BHd9Bn7R/60fba639-7917-47c8-ae1a-370aed7382b3.png",
    "https://i.ibb.co/gbsTJBPC/kowsi2.jpg",
    "https://i.ibb.co/0RP8J410/kowsi6.jpg",
  ];

  // --- NEW: Added Top Texts Array ---
  final List<String> _topTexts = [
    "Share hope.\nCreate smiles.",
    "Small Help.\nBig Impact.",
    "Give More\nThan Things.",
    "Turn Kindness\nInto Change."
  ];

  final List<String> _heroTexts = [
    "Someone’s Tomorrow Starts With You.",
    "Every act of kindness matters.",
    "Share care. Spread happiness.",
    "Support real needs today."
  ];

  @override
  void initState() {
    super.initState();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _currentPage = (_currentPage + 1) % _heroImages.length;
        _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 900), curve: Curves.fastOutSlowIn);
      }
    });

    _buttonPulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _buttonPulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOut));
    
    _magicHoverController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

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
    _ngoScrollController.animateTo(maxScroll, duration: Duration(milliseconds: durationMs), curve: Curves.linear).then((_) {
      if (mounted && !_isNgoScrollingManually) Future.delayed(const Duration(milliseconds: 50), _autoScrollNgos);
    });
  }

  void _performSearch() {
    String query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DonorListingScreen(initialSearchQuery: query)));
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
    _heroTimer?.cancel();
    _ctaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFDF7F8), Color(0xFFEEDAE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.1, 1.0],
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 10, 0, MediaQuery.of(context).padding.bottom + 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HERO CAROUSEL =================
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _heroImages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (_, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _heroImages[index], 
                            fit: BoxFit.cover, 
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image))
                          ),
                          // --- UPDATED GRADIENT: Protects both top and bottom text ---
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, 
                                end: Alignment.bottomCenter, 
                                colors: [
                                  Colors.black.withOpacity(0.6), 
                                  Colors.transparent, 
                                  Colors.black.withOpacity(0.9)
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                          
                          // --- FIRST TEXT ALIGNED TO TOP LEFT ---
                          Positioned(
                            top: 25, 
                            left: 20, 
                            right: 20,
                            child: Text(
                              _topTexts[index], 
                              style: const TextStyle(
                                fontFamily: 'serif', 
                                color: Colors.white, 
                                fontSize: 22, 
                                fontWeight: FontWeight.w600, 
                                height: 1.2,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          
                          // --- SECOND TEXT ALIGNED TO BOTTOM LEFT ---
                          Positioned(
                            bottom: 20, 
                            left: 20, 
                            right: 20,
                            child: Text(
                              _heroTexts[index], 
                              style: TextStyle(
                                fontFamily: 'serif', 
                                color: soft, 
                                fontSize: 13, 
                                fontWeight: FontWeight.w600, 
                                height: 1.4,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_heroImages.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: _currentPage == index ? primary : Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                );
              }),
            ),
           // === CTA & SEARCH ===
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final userRole = authProvider.currentUserModel?.role;

                // 👇 NEW: Dual Buttons specifically for Volunteers (Identical Colors) 👇
                if (userRole == 'volunteer') {
                  return Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerNgoHubScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [primary, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))],
                            ),
                            child: const Center(
                              child: Text("NGOs & Requests", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerDonorHubScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              // 👇 Fixed: Now uses the exact same gradient and shadow as the first button 👇
                              gradient: LinearGradient(colors: [primary, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))],
                            ),
                            child: const Center(
                              // 👇 Fixed: Text color changed to white to match the gradient 👇
                              child: Text("Donors & Donate", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                
                // 👇 OLD: Keep the single button for everyone else (Donors) 👇
                else {
                  return ScaleTransition(
                    scale: _buttonPulseAnimation,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonorListingScreen(initialSearchQuery: ''))),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [primary, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volunteer_activism, color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text("Browse Donation", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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

            // ================= LIVE COMMUNITY HEARTS =================
            const SizedBox(height: 30),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Live Community Hearts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tickerIndex = (_tickerIndex + 1) % _tickerItems.length),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: soft.withOpacity(0.5)), boxShadow: [BoxShadow(color: primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      key: ValueKey<int>(_tickerIndex),
                      children: [
                        Expanded(child: Text(_tickerItems[_tickerIndex], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary.withOpacity(0.9), height: 1.3))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 30),
           // ================= 4 DETAILED IMPACT STORIES WITH IMAGES =================
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text("Impact We've Created ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 190,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _successStoryCard(
                  "Rahul's New School Kit", 
                  "\"Thanks to a private kit donor, Rahul received notebooks and a bag for his primary school term!\"", 
                  "https://i.ibb.co/gZ8NgcR4/4b4ca906-c0db-4f15-9b79-e8591c9b99c1.jpg",
                  "Products"
                ),
                _successStoryCard(
                  "A Neighborhood Fed", 
                  "\"Surplus food from a local wedding banquet served over 40 families in our community cluster.\"", 
                  "https://i.ibb.co/HLGQV2Cb/714ae8ec-1ad6-4929-bba7-8712a9bf8dca.jpg",
                  "Food"
                ),
                _successStoryCard(
                  "Warmth for the Elderly", 
                  "\"30 clean blankets and clothing essentials were delivered safely to the neighborhood shelter.\"", 
                  "https://i.ibb.co/WvfmnmYY/43032ab9-d09e-4477-83be-09be65f276ce.jpg",
                  "Products"
                ),
                _successStoryCard(
                  "Nutrition Drive Secured", 
                  "\"A micro-donor matched an emergency grocery request to keep a shelter kitchen fully open.\"", 
                  "https://media.istockphoto.com/id/1457738274/photo/unrecognizable-woman-hands-out-food-donations-during-charity-drive.jpg?s=612x612&w=0&k=20&c=6GjDAHu02Epgu19Zwlc7-YSxFsMmiPZWFfZTU5S2a5I=",
                  "Food"
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
          _buildBeforeAfterSection(),
          const SizedBox(height: 25),

            // ================= TRUSTED NGOs =================
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Trusted NGOs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87))),
            const SizedBox(height: 15),
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
            const SizedBox(height: 40),

            // ================= FLOATING/HOVERING CHARITEY MAGIC =================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text("The Charitey Magic ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 15),
            
            AnimatedBuilder(
              animation: _magicHoverController,
              builder: (context, child) {
                return Column(
                  children: [
                    _magicWhyCard(
                      Icons.campaign_rounded, 
                      "Smart Needs Matching", 
                      "Verified agencies broadcast real-time shortages for food and daily essentials.",
                      _magicHoverController.value,
                      0
                    ),
                    _magicWhyCard(
                      Icons.pan_tool_alt_rounded, 
                      "One-Tap Fulfillment", 
                      "Browse live local requests and pledge your surplus inventory instantly.",
                      _magicHoverController.value,
                      1
                    ),
                    _magicWhyCard(
                      Icons.forum_rounded, 
                      "Transparent Impact", 
                      "Connect directly via live chat to coordinate delivery and track your impact.",
                      _magicHoverController.value,
                      2
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 35),


            // ================= NEW UPGRADED PLATFORM METRICS =================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text("Our Milestone Tracker", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black54)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildAnimatedStatCard("120+", "Meals\nDistributed", Icons.restaurant_rounded),
                  _buildAnimatedStatCard("85+", "Essential Products\nDonated", Icons.favorite_rounded),
                  _buildAnimatedStatCard("30+", "Verified\nNGOs", Icons.verified_user_rounded),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UPDATED: REFINED BEFORE & AFTER IMPACT SECTION ---
  Widget _buildBeforeAfterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white, // Changed to white to pop against the new dusky rose background
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Stories of Change",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color.fromARGB(255, 0, 0, 0)),
          ),
          const SizedBox(height: 6),
          Text(
            "Every donation changes a painful reality into a hopeful future.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220, 
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _emotionalTransformationCard(
                  beforeImage: "https://i.ibb.co/qMwdWgTm/pngtree-hopeful-child-looking-at-an-empty-plate-raising-awareness-for-food-image-17048640.jpg",
                  afterImage: "https://i.ibb.co/gb4XLxXy/images.jpg",
                  beforeText: "Empty\nPlates",
                  afterText: "Meals for many\nhungry families",
                ),
                _emotionalTransformationCard(
                  beforeImage: "https://i.ibb.co/WpVj1Nnd/1.webp",
                  afterImage: "https://i.ibb.co/jkqVL0P8/Classroom-Management-for-an-Effective-Learning-Environment-768x512.jpg",
                  beforeText: "Empty\nClassroom",
                  afterText: "Dignity through\nessential care",
                ),
                _emotionalTransformationCard(
                  beforeImage: "https://i.ibb.co/nqRjKq2P/clothes-worn-out-bunch-old-127716444.webp",
                  afterImage: "https://i.ibb.co/fd1LD2sz/hands-holding-a-cardboard-box-filled-with-neatly-folded-colorful-clothes-for-donation-or-organizatio.jpg",
                  beforeText: "Worn out\nCloths",
                  afterText: "Clean & useful\nproducts",
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              "Together, our community helped 10,000 lives this year.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary.withOpacity(0.8), fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emotionalTransformationCard({
    required String beforeImage,
    required String afterImage,
    required String beforeText,
    required String afterText,
  }) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          // The Image Section
          SizedBox(
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Expanded(child: Image.network(beforeImage, fit: BoxFit.cover, height: 130)),
                      Container(width: 2, color: Colors.white),
                      Expanded(child: Image.network(afterImage, fit: BoxFit.cover, height: 130)),
                    ],
                  ),
                ),
                // Center Icon
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // The Text Section Below Images
          Row(
            children: [
              Expanded(child: Text(beforeText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text("→", style: TextStyle(color: Colors.grey))),
              Expanded(child: Text(afterText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  // --- STAT CARD UI ---
  Widget _buildAnimatedStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 26),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              label, 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w600, height: 1.2)
            ),
          ],
        ),
      ),
    );
  }

  // --- SUCCESS STORY CARD UI ---
  Widget _successStoryCard(String title, String quote, String imageUrl, String tag) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {}, 
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300, child: const Icon(Icons.image)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                        child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(quote, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
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

  /// --- NGO CARD UI ---
  Widget _trustedNgoCard(String name) {
    return Container(
      width: 210,
      margin: const EdgeInsets.only(left: 15, right: 5, top: 4, bottom: 8),
      decoration: BoxDecoration(
        // 1. FIX: Changed from a transparent gradient to Solid White
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        // 2. FIX: Lighter border so it looks cleaner
        border: Border.all(color: soft.withOpacity(0.3)), 
        // 3. FIX: Slightly stronger shadow so the card "lifts" off the background
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12), // Increased from 0.05
            blurRadius: 15,                   // Increased from 10
            offset: const Offset(0, 6)
          )
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
                            child: Text(
                              name, 
                              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold), 
                              overflow: TextOverflow.ellipsis
                            )
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blue, size: 14),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Trusted Partner", 
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)
                      ),
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
  // --- MAGIC CARDS ---
  Widget _magicWhyCard(IconData icon, String title, String subtitle, double animValue, int index) {
    double floatOffset = math.sin((animValue * math.pi) + (index * math.pi / 2)) * 3.0;

    return Transform.translate(
      offset: Offset(0, floatOffset),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: soft.withOpacity(0.4)),
            boxShadow: [BoxShadow(color: accent.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8))],
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
                        gradient: LinearGradient(colors: [soft, Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: soft.withOpacity(0.6), blurRadius: 8)]
                      ),
                      child: Icon(icon, color: primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                          const SizedBox(height: 5),
                          Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.35)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}