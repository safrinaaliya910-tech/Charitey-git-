import 'package:flutter/material.dart';
import 'donor_listing_screen.dart';

// Friend's Theme Colors
final Color primary = const Color(0xFF7D444C);
final Color accent =  const Color(0xFFCD5E77);
final Color soft = const Color(0xFFF4C2C2);

class HeroPage extends StatefulWidget {
  const HeroPage({super.key});

  @override
  State<HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<HeroPage> {
  // --- UI Variables (Friend's Code) ---
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> images = [
    "https://media.istockphoto.com/id/1372606861/photo/volunteers-hand-giving-donations-to-a-person-at-a-community-center.jpg?s=612x612&w=0&k=20&c=wB_AfqhVewFDXEpTjHIggOwS3BVXVHktNLBxgQAcl2M=",
    "https://img.freepik.com/free-photo/close-up-volunteer-oganizing-stuff-donation_23-2149134438.jpg?semt=ais_hybrid&w=740&q=80",
    "https://www.shutterstock.com/image-photo/ramadan-volunteer-program-team-packing-600nw-2735566693.jpg",
    "https://thumbs.dreamstime.com/b/volunteer-holding-donation-box-food-products-indoors-closeup-space-text-419851175.jpg",
    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSu_ls7eD_vqvWLhAEaCkYKb-xk6HjY50SIFg&s",
    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTGw8Wv6LcOKmYUbGLK0wV5lFJ7od-IVQ6alg&s",
    "https://media.istockphoto.com/id/1457738274/photo/unrecognizable-woman-hands-out-food-donations-during-charity-drive.jpg?s=612x612&w=0&k=20&c=6GjDAHu02Epgu19Zwlc7-YSxFsMmiPZWFfZTU5S2a5I=",
    "https://img.freepik.com/free-photo/close-up-people-collecting-food_23-2149182014.jpg?semt=ais_hybrid&w=740&q=80",
  ];

  // --- Logic Variables ---
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto scroll logic
    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    _currentPage++;
    if (_currentPage >= images.length) _currentPage = 0;

    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  // --- Smart Search Function ---
  void _performSearch() {
    String query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DonorListingScreen(initialSearchQuery: query),
        ),
      );
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // ================= CAROUSEL =================
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (_, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // DOT INDICATOR
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 12 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index ? primary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // ================= DONATE BUTTON =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                // Navigate with empty query for full browsing
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DonorListingScreen(initialSearchQuery: ''),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCD5E77), Color(0xFFCD5E77)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: const Center(
                  child: Text(
                    "Browse Donations",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ================= SEARCH (Original simple search bar) =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
                ],
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _performSearch(), // Triggers when "Enter" is pressed
                decoration: InputDecoration(
                  hintText: "Search food, NGO, location...",
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: primary),
                    onPressed: _performSearch, // Triggers when icon is tapped
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ================= NGO SUGGESTIONS =================
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text("Suggested NGOs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ngoCard("Aishwaryam NGO", "Coimbatore"),
                _ngoCard("Helping Hands", "Chennai"),
                _ngoCard("Food Bridge", "Bangalore"),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ================= WHY SECTION =================
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text("Why choose CHARITEY?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          _buildCard(Icons.fastfood, "Zero Food Waste", "Turn surplus food into hope"),
          _buildCard(Icons.favorite, "Support NGOs", "Directly help people in need"),
          _buildCard(Icons.flash_on, "Fast & Easy", "Donate in seconds"),

          const SizedBox(height: 20),

          // ================= STATS =================
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatItem("120+", "Meals"),
                StatItem("30+", "NGOs"),
                StatItem("50+", "Donors"),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- NGO CARD UI ---
  Widget _ngoCard(String name, String location) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(left: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFDEDEE)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent,
            child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- WHY CARD UI ---
  Widget _buildCard(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF9E4E6)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF7D444C)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final String value;
  final String label;

  const StatItem(this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF7D444C))),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}