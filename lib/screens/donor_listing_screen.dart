import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/ngo_listing_model.dart';
import '../services/firestore_service.dart';
import 'donation_page.dart';
import 'home_screen.dart';


class DonorListingScreen extends StatefulWidget {
  final String initialSearchQuery;
  const DonorListingScreen({super.key, this.initialSearchQuery = ''});

  @override
  State<DonorListingScreen> createState() => _DonorListingScreenState();
}

class _DonorListingScreenState extends State<DonorListingScreen> {
  final FirestoreService firestoreService = FirestoreService();
  String _filterContext = 'all';
  late TextEditingController _searchController;
  String _currentSearchQuery = '';
  String _selectedQuantityFilter = "Any";
  String _selectedCategoryFilter = "All";

  //--- PREMIUM COLOR PALETTE
  final Color themeColor = const Color(0xFF7D444C); 
  final Color accentColor = const Color(0xFFCD5E77); 
  final Color backgroundColor = const Color(0xFFF5E8EB);
  final Color surfaceColor = Colors.white;
  final Color textPrimary = const Color(0xFF1A1A1A);
  final Color textSecondary = const Color(0xFF757575);

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

  void _navigateSafelyHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  String getFormattedDate(NgoListingModel listing) {
    if (listing.availability.isNotEmpty &&
        listing.availability != 'Flexible Schedule' &&
        listing.availability != 'Open') {
      return listing.availability;
    }
    final DateTime date = listing.createdAt;
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

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
                left: 24, right: 24, top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32.0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Refine Search", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5)),
                      InkWell(
                        onTap: () {
                          setModalState(() {
                            _selectedQuantityFilter = "Any";
                            _selectedCategoryFilter = "All";
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Reset All", style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 15)),
                        )
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("Quantity Required", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 12,
                    children: [
                      _buildFilterChip("Any", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                      _buildFilterChip("Below 10", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                      _buildFilterChip("10 - 50", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                      _buildFilterChip("50 - 100", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                      _buildFilterChip("Above 100", _selectedQuantityFilter, (val) => setModalState(() => _selectedQuantityFilter = val)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text("Category", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 12,
                    children: [
                      _buildFilterChip("All", _selectedCategoryFilter, (val) => setModalState(() => _selectedCategoryFilter = val)),
                      _buildFilterChip("Food", _selectedCategoryFilter, (val) => setModalState(() => _selectedCategoryFilter = val)),
                      _buildFilterChip("Products", _selectedCategoryFilter, (val) => setModalState(() => _selectedCategoryFilter = val)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedCategoryFilter == "All") _filterContext = 'all';
                          if (_selectedCategoryFilter == "Food") _filterContext = 'food';
                          if (_selectedCategoryFilter == "Products") _filterContext = 'product';
                          if (_selectedCategoryFilter == "Urgent") _filterContext = 'urgent';
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Apply Filters", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildFilterChip(String label, String selectedValue, Function(String) onSelect) {
    bool isSelected = label == selectedValue;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? themeColor : Colors.grey.shade300, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: themeColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  Widget buildSegmentTab(String title, String contextValue, String filterValue) {
    bool isSelected = _filterContext == contextValue;
    return GestureDetector(
      onTap: () => setState(() {
        _filterContext = contextValue;
        _selectedCategoryFilter = filterValue;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? surfaceColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? textPrimary : textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.currentUserModel?.role;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textPrimary),
          onPressed: _navigateSafelyHome,
        ),
        title: Text('Browse Requests', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _currentSearchQuery = value),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Search items, NGO, location...",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
                        suffixIcon: _currentSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.grey),
                                onPressed: () => setState(() { _searchController.clear(); _currentSearchQuery = ''; }),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showFilterBottomSheet,
                  child: Container(
                    height: 52, width: 52,
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: buildSegmentTab('All', 'all', "All")),
                Expanded(child: buildSegmentTab('Food', 'food', "Food")),
                Expanded(child: buildSegmentTab('Products', 'product', "Products")),
                Expanded(child: buildSegmentTab('Urgent', 'urgent', "Urgent")),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<List<NgoListingModel>>(
              stream: firestoreService.getOpenListingsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: themeColor, strokeWidth: 3));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Failed to load data.', style: TextStyle(color: textSecondary)));
                }
                
                List<NgoListingModel> listings = (snapshot.data ?? []).toList();

                // 👇 NEW LAZY FILTER LOGIC: INSTANTLY HIDE EXPIRED OR FULLY DONATED ITEMS 👇
                listings = listings.where((listing) {
                  bool isNotExpired = listing.liveUntil.isAfter(DateTime.now());
                  bool isNotFullyDonated = (listing.fulfilledQuantity ?? 0) < (listing.quantity ?? 1);
                  return isNotExpired && isNotFullyDonated;
                }).toList();

                listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (_filterContext == 'food') {
                  listings = listings.where((l) => l.type == 'food').toList();
                }
                if (_filterContext == 'product') {
                  listings = listings.where((l) => l.type == 'product').toList();
                }
                if (_filterContext == 'urgent') {
                  listings.sort((a, b) => a.liveUntil.compareTo(b.liveUntil));
                }

                if (_selectedQuantityFilter != "Any") {
                  listings = listings.where((listing) {
                    if (listing.quantity == null) return false;
                    int qty = listing.quantity!;
                    if (_selectedQuantityFilter == "Below 10" && qty < 10) return true;
                    if (_selectedQuantityFilter == "10 - 50" && qty >= 10 && qty <= 50) return true;
                    if (_selectedQuantityFilter == "50 - 100" && qty > 50 && qty <= 100) return true;
                    if (_selectedQuantityFilter == "Above 100" && qty > 100) return true;
                    return false;
                  }).toList();
                }

                if (_currentSearchQuery.isNotEmpty) {
                  String query = _currentSearchQuery.toLowerCase();
                  listings = listings.where((listing) {
                    String title = (listing.type == 'food' ? listing.foodType : listing.productName)?.toLowerCase() ?? '';
                    String location = listing.ngoLocation.toLowerCase();
                    String ngoName = listing.ngoName.toLowerCase();
                    String quantity = listing.quantity?.toString() ?? '';
                    return title.contains(query) || location.contains(query) || ngoName.contains(query) || quantity.contains(query);
                  }).toList();
                }

                if (listings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                          child: Icon(Icons.inbox_rounded, size: 50, color: Colors.grey.shade300),
                        ),
                        const SizedBox(height: 20),
                        Text("No requests found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                        const SizedBox(height: 8),
                        Text("Try adjusting your filters or search term.", style: TextStyle(fontSize: 14, color: textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
  // 👇 INCREASED BOTTOM PADDING TO 120 👇
  padding: const EdgeInsets.only(top: 10, bottom: 120, left: 20, right: 20), 
  physics: const BouncingScrollPhysics(),
  itemCount: listings.length,
  itemBuilder: (context, index) =>
      buildUltraPremiumCard(listings[index], userRole),
);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUltraPremiumCard(NgoListingModel listing, String? userRole) {
    String title = listing.type == 'food' ? (listing.foodType ?? 'Food Donation') : (listing.productName ?? 'Product Donation');
    String quantityBadge = '${listing.quantity ?? ''} ${listing.unit ?? ''}'.trim();
    if (quantityBadge.isEmpty) quantityBadge = '1 Unit';
    
    final int totalQty = listing.quantity ?? 0;
    final int fulfilledQty = listing.fulfilledQuantity ?? 0;
    final int remainingQty = (totalQty - fulfilledQty) < 0 ? 0 : (totalQty - fulfilledQty);
    
    final double progress = totalQty > 0 ? (fulfilledQty / totalQty).clamp(0.0, 1.0) : 0.0;
    
    String requestDateTime = getFormattedDate(listing);
    final int daysLeft = listing.liveUntil.difference(DateTime.now()).inDays;
    
    String actualNgoName = (listing.ngoName.isNotEmpty) ? listing.ngoName : 'Verified NGO';
    String ngoInitial = actualNgoName.substring(0, 1).toUpperCase();
    bool hasImage = listing.imageUrl != null && listing.imageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44, width: 44,
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: hasImage
                      ? ClipOval(
                          child: Image.network(
                            listing.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(child: Text(ngoInitial, style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 18))),
                          ),
                        )
                      : Center(child: Text(ngoInitial, style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(actualNgoName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text("Verified Organization", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                if (_filterContext == 'urgent' && daysLeft >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: daysLeft <= 2 ? Colors.red.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: daysLeft <= 2 ? Colors.red.shade300 : Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: daysLeft <= 2 ? Colors.red : Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          daysLeft == 0 ? "Ends Today" : "$daysLeft days left",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: daysLeft <= 2 ? Colors.red : Colors.orange),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: themeColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 14, color: themeColor),
                      const SizedBox(width: 6),
                      Text(quantityBadge, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: themeColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text(listing.type.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade600, letterSpacing: 0.5)),
                ),
              ],
            ),
            if (listing.type == 'product') ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$fulfilledQty donated out of $totalQty', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                  Text('$remainingQty needed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: themeColor)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(themeColor),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
            const SizedBox(height: 16),
            
           // 3. FOOTER: Date, Location, Description & Donate Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Changed to start so description flows down neatly
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.schedule_rounded, size: 16, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              requestDateTime,
                              style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600),
                              maxLines: 2, // Allows wrapping so it never cuts off
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Location Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              listing.ngoLocation,
                              style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600),
                              maxLines: 2, // Allows wrapping so it never cuts off
                            ),
                          ),
                        ],
                      ),
                      
                      // 👇 Description Block (Now safely below the Location Row) 👇
                      if (listing.description != null && listing.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Description:',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          listing.description!,
                          style: TextStyle(
                            fontSize: 13, 
                            color: textSecondary, 
                            height: 1.4,
                          ),
                        ),
                      ],
                      // 👆 End Description Block 👆

                    ],
                  ),
                ),
                
                // Donate Button
                if (userRole != 'ngo') ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DonationPage(listing: listing))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Donate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}