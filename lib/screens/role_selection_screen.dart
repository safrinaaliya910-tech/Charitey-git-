//role_selection_screen
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'donor_login_screen.dart';
import 'ngo_login_screen.dart';
import 'volunteer_login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _bgController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 👇 NEW: controls the swipeable role carousel (Receiver / Provider / Kindness Champion)
  late PageController _pageController;
  double _currentPage =
      1; // starts on "Provider" (center card), matches screenshot

  static const Color primary = Color(0xFF8C4149);

  // 👇 NEW: role data list used to build the carousel — keeps card content in one place
  late final List<_RoleData> _roles;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();

    // 👇 CHANGED: viewportFraction lowered further from 0.64 → 0.52. This
    // shrinks how much screen width each card's page slot takes, which
    // directly shrinks the card itself (card width is derived from page
    // width in _buildRoleCarousel) — addresses "button still too big".
    // initialPage: 1 so "Provider" (Donor) is centered first, matching screenshot
    _pageController = PageController(viewportFraction: 0.52, initialPage: 1);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 1;
      });
    });

    _roles = [
      // 👇 CHANGED: icon swapped from holiday_village_rounded → home_rounded +
      // favorite overlay style not needed; using a clearer "home with heart"
      // stand-in (favorite icon inside a house isn't a single glyph in
      // Material Icons, so home_rounded reads more clearly at small button size)
      _RoleData(
        title: "Receiver",
        subtitle: "NGOs/ Orphans",
        icon: Icons
            .home_rounded, // 👈 CHANGED: was holiday_village_rounded — clearer at small size
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NgoLoginScreen()),
        ),
      ),
      _RoleData(
        title: "Provider",
        subtitle: "Donor",
        icon: Icons
            .volunteer_activism_rounded, // 👈 CHANGED: rounded variant, sharper at small button size
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DonorLoginScreen()),
        ),
      ),
      _RoleData(
        title: "Kindness Champion",
        subtitle: "Volunteer",
        icon: Icons
            .groups_rounded, // 👈 CHANGED: was diversity_3_rounded — reads clearer as "people/volunteers" at small button size
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VolunteerLoginScreen()),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bgController.dispose();
    _pageController.dispose(); // 👈 NEW: dispose the carousel controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: primary,
              gradient: LinearGradient(
                begin: Alignment(
                  math.cos(_bgController.value * 2 * math.pi),
                  math.sin(_bgController.value * 2 * math.pi),
                ),
                end: Alignment(
                  math.cos((_bgController.value + 0.5) * 2 * math.pi),
                  math.sin((_bgController.value + 0.5) * 2 * math.pi),
                ),
                colors: const [
                  Color(0xFF8C4149),
                  Color(0xFF7A3540),
                  Color(0xFFA05060),
                  Color(0xFF8C4149),
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: isWide
                  ? _buildWideLayout(context)
                  : _buildNarrowLayout(context),
            ),
          ),
        ),
      ),
    );
  }

  // --- MOBILE LAYOUT (Fixed Overflow, No Scroll) ---
  // 👇 CHANGED: wrapped in LayoutBuilder + ConstrainedBox(minHeight) +
  // SingleChildScrollView. This is a *safety net only* — on normal-height
  // phones the content still fits exactly like before (Spacers keep doing
  // the layout work), but on short screens / small emulator windows it now
  // scrolls instead of throwing "BOTTOM OVERFLOWED BY N PIXELS".
  Widget _buildNarrowLayout(BuildContext context) {
    // 👇 CHANGED: Spacer() needs a bounded height, which breaks once wrapped
    // in a scroll view (unbounded height). So instead we measure the
    // available height with LayoutBuilder and turn it into *fixed* gaps
    // that are proportional to the screen — this keeps the exact same
    // visual balance as before (top gap > middle gap) while being 100%
    // overflow-safe on any screen size.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight;
        final double topGap = (h * 0.05).clamp(12.0, 40.0);
        final double midGap = (h * 0.035).clamp(10.0, 28.0);
        final double bottomGap = (h * 0.04).clamp(14.0, 32.0);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: topGap), // Flexible-equivalent top spacing
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _buildCenteredTitle(),
                ),
                const SizedBox(height: 16),
                _buildDecorativeLine(),
                SizedBox(height: midGap), // Flexible-equivalent middle spacing
                // 👇 swipeable carousel replaces the stacked column of role cards
                _buildRoleCarousel(),
                const SizedBox(height: 18), // 👈 spacing before swipe hint
                _buildSwipeHint(), // 👈 "Swipe right to left to choose your role" + hand icon
                SizedBox(
                    height: bottomGap), // Flexible-equivalent bottom spacing
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDE LAYOUT ---
  // 👇 CHANGED: wrapped in SingleChildScrollView as the same overflow safety
  // net used in the narrow layout (e.g. short-height tablets in landscape).
  Widget _buildWideLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCenteredTitle(),
                const SizedBox(height: 24),
                _buildDecorativeLine(),
                const SizedBox(height: 40),
                // 👇 same swipeable carousel used on wide layout
                _buildRoleCarousel(),
                const SizedBox(height: 22),
                _buildSwipeHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 👇 NEW: builds the horizontal swipeable carousel of role cards
  Widget _buildRoleCarousel() {
    // 👇 CHANGED: uses LayoutBuilder instead of MediaQuery.of(context).size.width
    // so the card width is based on the space actually available to the
    // carousel — this stays correct on the wide layout too, where the
    // whole screen is constrained to maxWidth: 460 (MediaQuery alone would
    // have used the full device width there and thrown the sizing off).
    return LayoutBuilder(
      builder: (context, constraints) {
        // Card width is derived from the actual page width
        // (availableWidth * viewportFraction) instead of a fixed 168px. A
        // fixed width left a big empty margin inside each page slot
        // whenever the page was wider than the card — that empty margin
        // was read as "too much gap" in your screenshot. Sizing the card
        // to (pageWidth - 14) makes it hug its slot, with just a small
        // 7px gap on each side between neighboring cards, matching the
        // target image.
        final double pageWidth = constraints.maxWidth *
            0.52; // must match PageController viewportFraction
        final double cardWidth = (pageWidth - 14).clamp(120.0, 190.0);

        return SizedBox(
          height:
              260, // 📏 CAROUSEL HEIGHT — reduced further from 300 to match smaller card
          child: PageView.builder(
            controller: _pageController,
            itemCount: _roles.length,
            itemBuilder: (context, index) {
              // distance of this page from the currently centered page,
              // used to scale/fade/lift the card like the screenshot
              // 👇 gentler falloff (0.10 scale / 0.35 opacity) so side cards
              // stay close to full size and only mildly dimmed — matching
              // the tight, subtle look in the target screenshot instead of
              // a large gap + heavy fade.
              double distance = (index - _currentPage).abs().clamp(0.0, 1.0);
              double scale = 1 - (distance * 0.10); // center card is largest
              double opacity =
                  1 - (distance * 0.35); // side cards are mildly dimmed

              return Center(
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: _roleCard(
                      title: _roles[index].title,
                      subtitle: _roles[index].subtitle,
                      icon: _roles[index].icon,
                      onTap: _roles[index].onTap,
                      isCentered:
                          distance < 0.15, // drives white-vs-tinted card style
                      cardWidth:
                          cardWidth, // dynamic width so the card fills its page slot
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // 👇 NEW: "Swipe right to left to choose your role" caption with arrow/hand icons
  Widget _buildSwipeHint() {
    return Column(
      children: [
        Text(
          'Swipe right to left\nto choose your role',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xffF9E9EA).withValues(alpha: 0.9),
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              color: const Color(0xffF9E9EA).withValues(alpha: 0.85),
              size: 20,
            ),
            const SizedBox(width: 14),
            Icon(
              Icons.back_hand_outlined,
              color: const Color(0xffF9E9EA).withValues(alpha: 0.9),
              size: 26,
            ),
            const SizedBox(width: 14),
            Icon(
              Icons.arrow_forward_rounded,
              color: const Color(0xffF9E9EA).withValues(alpha: 0.85),
              size: 20,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDecorativeLine() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 75, height: 2, color: const Color(0xffD99AA2)),
        const SizedBox(width: 12),
        const Icon(Icons.favorite, color: Color(0xffD99AA2), size: 20),
        const SizedBox(width: 12),
        Container(width: 75, height: 2, color: const Color(0xffD99AA2)),
      ],
    );
  }

  Widget _buildCenteredTitle() {
    return Column(
      children: [
        Text(
          'FOURTH IDLY',
          textAlign: TextAlign.center,
          style: GoogleFonts.quattrocento(
            color: Colors.white,
            fontSize: 35,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: const [
              Shadow(
                blurRadius: 12,
                color: Colors.black26,
                offset: Offset(0, 5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Three idlies satisfy your hunger,\nbut the fourth idly is for others.',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xffF9E9EA),
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.normal,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        _buildTaglineDivider(),
        const SizedBox(height: 12),
        Text(
          'மூன்று இட்லிகள் உங்களுடைய பசியாற்றிய பின்,\nநான்காவது இட்லி அடுத்தவருக்கு.',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansTamil(
            color: const Color(0xffF9E9EA).withValues(alpha: 0.9),
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTaglineDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 1,
          color: const Color(0xffD99AA2).withValues(alpha: 0.55),
        ),
        const SizedBox(width: 8),
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0xffD99AA2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 28,
          height: 1,
          color: const Color(0xffD99AA2).withValues(alpha: 0.55),
        ),
      ],
    );
  }

  // 👇 CHANGED: added `isCentered` param — drives white/large "active" card style
  // vs. dimmed/tinted "inactive" side-card style, matching the screenshot.
  // 👇 CHANGED: added `cardWidth` param — width now comes from the carousel
  // (based on actual page width) instead of being hardcoded, so the card
  // always fills its slot with no dead space.
  // Layout switched from horizontal Row (icon+title inline) to vertical Column
  // (icon on top, title below) to match the tall carousel card in your image.
  Widget _roleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isCentered = false,
    double cardWidth =
        168, // 👈 NEW: default kept for safety if called without carousel
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:
            cardWidth, // 👈 CHANGED: was a fixed 168, now dynamic per screen size
        constraints: const BoxConstraints(
            minHeight: 225), // 📏 CARD HEIGHT — reduced further from 260
        decoration: BoxDecoration(
          // 👇 CHANGED: centered card is solid white (like screenshot's active card),
          // side cards are a translucent tint over the background
          color:
              isCentered ? Colors.white : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(28),
          boxShadow: isCentered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:
                  48, // 📏 ICON CIRCLE SIZE — reduced further from 58 ("reduce button size")
              height: 48,
              decoration: BoxDecoration(
                // 👇 CHANGED: icon circle is solid primary on the centered card,
                // and a lighter translucent circle on side cards
                color:
                    isCentered ? primary : Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                boxShadow: isCentered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size:
                    22, // 👈 CHANGED: reduced from 26 to fit the smaller circle
              ),
            ),
            const SizedBox(height: 10), // 👈 CHANGED: reduced from 14
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.quattrocento(
                fontSize:
                    17, // 🔠 TITLE FONT SIZE — reduced from 19 for the more compact card
                fontWeight: FontWeight.w900,
                color: isCentered ? primary : Colors.white,
                letterSpacing: 0.5,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.ubuntu(
                fontSize: 11, // 🔠 SUBTITLE FONT SIZE — reduced from 12
                fontWeight: FontWeight.w400,
                color: isCentered
                    ? primary.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10), // 👈 CHANGED: reduced from 14
            Container(
              width: 24, // 👈 CHANGED: reduced from 28 ("reduce button size")
              height: 24,
              decoration: BoxDecoration(
                color: isCentered
                    ? const Color(0xffF7ECEC)
                    : Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: isCentered ? primary : Colors.white,
                size: 11, // 👈 CHANGED: reduced from 12
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 👇 NEW: small helper class to hold role card data for the carousel builder
class _RoleData {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _RoleData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}