import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/ngo_listing_model.dart';
import 'donor_listing_screen.dart'; // To route volunteers to the donation flow
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'role_selection_screen.dart';

final Color themeColor = const Color(0xFF7D444C);
final Color accentColor = const Color(0xFFCD5E77);

// ============================================================================
// 1. NGO & REQUESTS HUB (For Volunteers)
// ============================================================================
class VolunteerNgoHubScreen extends StatefulWidget {
  const VolunteerNgoHubScreen({Key? key}) : super(key: key);

  @override
  State<VolunteerNgoHubScreen> createState() => _VolunteerNgoHubScreenState();
}

class _VolunteerNgoHubScreenState extends State<VolunteerNgoHubScreen> {
  bool showRequests = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text("NGOs & Requests", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // TOGGLE BUTTONS
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => showRequests = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: showRequests ? themeColor : Colors.transparent, borderRadius: BorderRadius.circular(30)),
                      child: Center(child: Text("Live Requests", style: TextStyle(color: showRequests ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => showRequests = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: !showRequests ? themeColor : Colors.transparent, borderRadius: BorderRadius.circular(30)),
                      child: Center(child: Text("Verified NGOs", style: TextStyle(color: !showRequests ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // LIST VIEW
          Expanded(
            child: showRequests ? _buildRequestsList() : _buildNgoDirectory(),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ngo_listings').where('status', isEqualTo: 'open').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: themeColor));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No active requests right now."));
        }

        var requests = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const BouncingScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var data = requests[index].data() as Map<String, dynamic>;
            
            // Extracting and formatting data
            String type = (data['type'] ?? 'PRODUCT').toString().toUpperCase();
            bool isFood = type == 'FOOD';
            String itemName = isFood ? (data['foodType'] ?? 'Food') : (data['productName'] ?? 'Product');
            
            int totalQty = int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
            int fulfilledQty = int.tryParse(data['fulfilledQuantity']?.toString() ?? '0') ?? 0;
            int remainingQty = totalQty - fulfilledQty;
            if (remainingQty < 0) remainingQty = 0;
            
            String unit = data['unit'] ?? '';
            double progress = totalQty > 0 ? (fulfilledQty / totalQty) : 0.0;
            
            String ngoName = data['ngoName'] ?? 'Unknown NGO';
            String ngoLocation = data['ngoLocation'] ?? 'Location not provided';
            String availability = data['availability'] ?? 'Time not specified';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- NGO Header ---
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: themeColor.withValues(alpha: 0.1),
                        child: Text(
                          ngoName.isNotEmpty ? ngoName[0].toUpperCase() : 'N',
                          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ngoName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.verified, color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Text("Verified Organization", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Item Name ---
                  Text(itemName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),

                  // --- Badges ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 14, color: themeColor),
                            const SizedBox(width: 6),
                            Text("$totalQty $unit", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(type, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 👇 FIXED: Progress Bar only shows if it's NOT food 👇
                  if (!isFood) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("$fulfilledQty donated out of $totalQty", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text("$remainingQty needed", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                  ] else ...[
                    // For food, we just need a clean divider before the footer
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 16),
                      child: Divider(height: 1),
                    ),
                  ],

                  // 👇 FIXED: Footer with Date & Location only (Donate Button Removed!) 👇
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Expanded(child: Text(availability, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Expanded(child: Text(ngoLocation, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNgoDirectory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'ngo').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: themeColor));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No NGOs registered yet."));

        var ngos = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: ngos.length,
          itemBuilder: (context, index) {
            var data = ngos[index].data() as Map<String, dynamic>;
            String name = data['name'] ?? data['ngoName'] ?? 'Unknown NGO';
            String location = data['location'] ?? 'Location not provided';
            
            // Format the joined date
            String joinedDate = "Unknown Date";
            if (data['createdAt'] != null) {
              DateTime date = DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now();
              joinedDate = DateFormat('MMM d, yyyy').format(date);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: themeColor.withValues(alpha: 0.15),
                    backgroundImage: (data['profileImage'] != null && data['profileImage'].toString().isNotEmpty) ? NetworkImage(data['profileImage']) : null,
                    child: (data['profileImage'] == null || data['profileImage'].toString().isEmpty) ? Icon(Icons.account_balance, color: themeColor) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: Colors.green, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(child: Text(location, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text("Joined: $joinedDate", style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// 2. DONOR & DONATE HUB (For Volunteers)
// ============================================================================
class VolunteerDonorHubScreen extends StatefulWidget {
  const VolunteerDonorHubScreen({Key? key}) : super(key: key);

  @override
  State<VolunteerDonorHubScreen> createState() => _VolunteerDonorHubScreenState();
}

class _VolunteerDonorHubScreenState extends State<VolunteerDonorHubScreen> {
  bool showDonate = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text("Donors & Donate", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // TOGGLE BUTTONS
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => showDonate = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: showDonate ? themeColor : Colors.transparent, borderRadius: BorderRadius.circular(30)),
                      child: Center(child: Text("Donate to NGO", style: TextStyle(color: showDonate ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => showDonate = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: !showDonate ? themeColor : Colors.transparent, borderRadius: BorderRadius.circular(30)),
                      child: Center(child: Text("Active Donors", style: TextStyle(color: !showDonate ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // LIST VIEW
          Expanded(
            child: showDonate ? _buildDonatePrompt(context) : _buildDonorDirectory(),
          ),
        ],
      ),
    );
  }

  Widget _buildDonatePrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.volunteer_activism, size: 60, color: themeColor),
            ),
            const SizedBox(height: 24),
            const Text("Make a Difference", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Text(
              "To keep our community secure and organized, donations must be made from a dedicated Donor account.\n\nPlease create an account as a Donor and donate as much as possible. Every contribution makes a massive impact!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Safely signs the volunteer out and takes them to the role selection screen
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.signOut();
                  
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                      (Route<dynamic> route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                label: const Text("Sign Out & Register as Donor", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
  Widget _buildDonorDirectory() {
    return StreamBuilder<QuerySnapshot>(
      // Fetches users who are donors (or standard 'user' roles acting as donors)
      stream: FirebaseFirestore.instance.collection('users').where('role', whereIn: ['donor', 'user']).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: themeColor));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No donors registered yet."));

        var donors = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: donors.length,
          itemBuilder: (context, index) {
            var data = donors[index].data() as Map<String, dynamic>;
            String name = data['name'] ?? 'Generous Donor';
            String location = data['location'] ?? 'Location not provided';
            
            // Format the joined date
            String joinedDate = "Unknown Date";
            if (data['createdAt'] != null) {
              DateTime date = DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now();
              joinedDate = DateFormat('MMM d, yyyy').format(date);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: accentColor.withValues(alpha: 0.15),
                    backgroundImage: (data['profileImage'] != null && data['profileImage'].toString().isNotEmpty) ? NetworkImage(data['profileImage']) : null,
                    child: (data['profileImage'] == null || data['profileImage'].toString().isEmpty) ? Icon(Icons.person, color: accentColor) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(child: Text(location, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text("Joined: $joinedDate", style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}