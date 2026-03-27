import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../providers/auth_provider.dart'; 
import '../services/firestore_service.dart';
import '../models/ngo_listing_model.dart';
import 'donation_page.dart';
import 'home_screen.dart'; // REQUIRED: To navigate back safely

class DonorListingScreen extends StatefulWidget {
  final String initialSearchQuery;
  
  const DonorListingScreen({Key? key, this.initialSearchQuery = ''}) : super(key: key);

  @override
  State<DonorListingScreen> createState() => _DonorListingScreenState();
}

class _DonorListingScreenState extends State<DonorListingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _filterContext = 'all'; 
  
  // Controller for the active search bar on this page
  late TextEditingController _searchController;
  String _currentSearchQuery = '';

  // --- Filter State Variables ---
  String _selectedQuantityFilter = "Any";
  String _selectedCategoryFilter = "All";

  final Color themeColor = const Color(0xFF7D444C); // Deep matching red
  final Color accentColor = const Color(0xFFCD5E77); // Lighter accent

  @override
  void initState() {
    super.initState();
    _currentSearchQuery = widget.initialSearchQuery;
    _searchController = TextEditingController(text: widget.initialSearchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- NEW: Safe Navigation Function ---
  void _navigateSafelyHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  // --- FILTER BOTTOM SHEET ---
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24, 
                right: 24, 
                top: 16, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 24, 
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header with Close Icon and Clear Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 28, color: Colors.black87),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Filters",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedQuantityFilter = "Any";
                            _selectedCategoryFilter = "All";
                          });
                        },
                        child: Text("Clear All", style: TextStyle(color: accentColor, fontWeight: FontWeight.w700)),
                      )
                    ],
                  ),
                  Divider(thickness: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          // Category 1: Quantity
                          const Text("Quantity / Weight", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 12,
                            children: [
                              _buildFilterChip("Any", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                              _buildFilterChip("Below 10 kg", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                              _buildFilterChip("10 kg - 50 kg", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                              _buildFilterChip("50 kg - 100 kg", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                              _buildFilterChip("Above 100 kg", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                            ],
                          ),
                          
                          const SizedBox(height: 30),

                          // Category 2: Type
                          const Text("Category", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 12,
                            children: [
                              _buildFilterChip("All", _selectedCategoryFilter, (val) => setModalState(() => _selectedCategoryFilter = val)),
                              _buildFilterChip("Food", _selectedCategoryFilter, (val) => setModalState(() => _selectedCategoryFilter = val)),
                              _buildFilterChip("Products", _selectedCategoryFilter, (val) => setModalState(() => _selectedCategoryFilter = val)),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apply Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: themeColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedCategoryFilter == "All") _filterContext = 'all';
                          if (_selectedCategoryFilter == "Food") _filterContext = 'food';
                          if (_selectedCategoryFilter == "Products") _filterContext = 'product';
                        });
                        Navigator.pop(context); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Apply Filters", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      },
    );
  }

  // Helper widget for Filter Chips
  Widget _buildFilterChip(String label, String selectedValue, Function(String) onSelect) {
    bool isSelected = label == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) onSelect(label);
      },
      selectedColor: themeColor.withValues(alpha: 0.15),
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? themeColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        fontSize: 13,
      ),
      side: BorderSide(color: isSelected ? themeColor : Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.currentUserModel?.role;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        centerTitle: true,
        // --- FIXED: Safe Navigation Back Button ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: Colors.black87),
          onPressed: _navigateSafelyHome,
        ),
        title: const Text(
          'Browse Requests',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // --- ACTIVE SEARCH BAR & NEW CLEAR FILTER BUTTON ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50, // Fixed height to match filter button
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _currentSearchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search requests...",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _currentSearchQuery.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _currentSearchQuery = '';
                                });
                              },
                            )
                          : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: themeColor),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                
                // --- EXPLICIT "FILTER" BUTTON ---
                InkWell(
                  onTap: _showFilterBottomSheet,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    height: 50, // Matches search bar height
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)
                      ]
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tune_rounded, color: themeColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          "Filter",
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // --- CUSTOM MODERN FILTER TABS ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Expanded(child: _buildFilterTab('All', 'all', "All")),
                Expanded(child: _buildFilterTab('Food', 'food', "Food")),
                Expanded(child: _buildFilterTab('Products', 'product', "Products")),
              ],
            ),
          ),
          
          const SizedBox(height: 4),

          // --- LISTINGS STREAM WITH SMART FILTERING ---
          Expanded(
            child: StreamBuilder<List<NgoListingModel>>(
              stream: _firestoreService.getOpenListingsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: themeColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.grey.shade600)));
                }
                
                List<NgoListingModel> listings = snapshot.data ?? [];
                
                // 1. Apply Category Filter (All/Food/Product) driven by _filterContext
                if (_filterContext != 'all') {
                  listings = listings.where((l) => l.type == _filterContext).toList();
                }

                // 2. APPLY SMART QUANTITY FILTER from Bottom Sheet
                if (_selectedQuantityFilter != "Any") {
                  listings = listings.where((listing) {
                    if (listing.quantity == null) return false;
                    int qty = listing.quantity!;
                    
                    if (_selectedQuantityFilter == "Below 10 kg" && qty < 10) return true;
                    if (_selectedQuantityFilter == "10 kg - 50 kg" && qty >= 10 && qty <= 50) return true;
                    if (_selectedQuantityFilter == "50 kg - 100 kg" && qty > 50 && qty <= 100) return true;
                    if (_selectedQuantityFilter == "Above 100 kg" && qty > 100) return true;
                    
                    return false;
                  }).toList();
                }

                // 3. APPLY SMART SEARCH FILTER
                if (_currentSearchQuery.isNotEmpty) {
                  String query = _currentSearchQuery.toLowerCase();
                  
                  listings = listings.where((listing) {
                    String title = (listing.type == 'food' ? listing.foodType : listing.productName)?.toLowerCase() ?? '';
                    String location = listing.ngoLocation?.toLowerCase() ?? '';
                    String ngoName = listing.ngoName?.toLowerCase() ?? '';
                    String quantity = listing.quantity?.toString() ?? '';
                    String unit = listing.unit?.toLowerCase() ?? '';
                    String fullQuantity = "$quantity $unit".trim();

                    return title.contains(query) || 
                           location.contains(query) || 
                           ngoName.contains(query) || 
                           fullQuantity.contains(query) ||
                           quantity.contains(query); 
                  }).toList();
                }

                // Empty State Design
                if (listings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _currentSearchQuery.isNotEmpty || _selectedQuantityFilter != "Any" 
                              ? "No matching requests found." 
                              : 'No active requests.',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentSearchQuery.isNotEmpty || _selectedQuantityFilter != "Any" 
                              ? "Try adjusting your filters or search term." 
                              : 'Check back later for new opportunities.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 30),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return _buildListingCard(listing, userRole);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Modified to sync Tab clicks with the Bottom Sheet selection
  Widget _buildFilterTab(String title, String contextValue, String filterValue) {
    bool isSelected = _filterContext == contextValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterContext = contextValue;
          _selectedCategoryFilter = filterValue; 
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? themeColor : Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListingCard(NgoListingModel listing, String? userRole) {
    String title = listing.type == 'food' 
        ? (listing.foodType ?? 'Food Donation') 
        : (listing.productName ?? 'Product Donation');
        
    String quantityBadge = '${listing.quantity ?? ''} ${listing.unit ?? ''}'.trim();
    if (quantityBadge.isEmpty) quantityBadge = '1 Unit'; 
    
    IconData icon = listing.type == 'food' ? Icons.restaurant_rounded : Icons.inventory_2_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding( 
        padding: const EdgeInsets.all(16.0), 
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(icon, color: themeColor, size: 36)),
            ),
            const SizedBox(width: 16), 
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.15), 
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          quantityBadge,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  Text(
                    listing.ngoName ?? 'Unknown NGO', 
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                listing.ngoLocation ?? 'Location unavailable', 
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // --- ROLE-BASED DONATE BUTTON ---
                      if (userRole != 'ngo')
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DonationPage(listing: listing),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Donate',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}