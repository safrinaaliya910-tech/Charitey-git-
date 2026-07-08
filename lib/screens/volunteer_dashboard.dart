//volunteer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'chat_screen.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({Key? key}) : super(key: key);

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final Color themeColor = const Color(0xFFB56F76);
  final ScrollController _scrollController = ScrollController();
  
  // Controls which tab is active
  bool showAvailable = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _acceptTask(String donationId, String volunteerId) async {
    try {
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'delivery_accepted',
        'assignedVolunteerId': volunteerId, // Tags the donation to this volunteer
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Pickup Task Accepted!', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        showAvailable = false; // Switch to the Accepted tab automatically
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept task: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUserModel;
    
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          // TOP TOGGLE BUTTONS (Available vs Accepted)
          SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => showAvailable = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: showAvailable ? themeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            "Available",
                            style: TextStyle(
                              color: showAvailable ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => showAvailable = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !showAvailable ? themeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            "Accepted",
                            style: TextStyle(
                              color: !showAvailable ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // MAIN LIST VIEW (Streams Donations)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('status', whereIn: ['pending', 'delivery_accepted'])
                  .snapshots(),
              builder: (context, donationSnapshot) {
                if (donationSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: themeColor));
                }
                
                if (!donationSnapshot.hasData || donationSnapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }
                
                // Sort donations so newest is always at the top
                var donations = donationSnapshot.data!.docs.toList();
                donations.sort((a, b) {
                  var aData = a.data() as Map<String, dynamic>;
                  var bData = b.data() as Map<String, dynamic>;
                  DateTime aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  DateTime bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  return bTime.compareTo(aTime);
                });
                
                List<Widget> cardList = [];
                
                for (var donationDoc in donations) {
                  var donationData = donationDoc.data() as Map<String, dynamic>;
                  var donationId = donationDoc.id;
                  
                  String listingId = donationData['listingId'] ?? '';
                  String donorId = donationData['donorId'] ?? '';
                  
                  if (listingId.isEmpty || donorId.isEmpty) continue;
                  
                  String donorName = donationData['donorName'] ?? 'Unknown Donor';
                  String donorLocation = donationData['donorLocation'] ?? 'Location unavailable';
                  String donorPhone = donationData['donorPhone'] ?? 'Phone unavailable';
                  String status = donationData['status'] ?? 'pending';
                  String? assignedVolunteerId = donationData['assignedVolunteerId'];
                  
                  bool isAcceptedByMe = (status == 'delivery_accepted' && assignedVolunteerId == user.uid);
                  
                  // TAB FILTERING LOGIC
                  if (showAvailable) {
                    if (status == 'delivery_accepted') continue; // Hide if already accepted by anyone
                  } else {
                    if (!isAcceptedByMe) continue; // Hide if not accepted by ME
                  }
                  
                  cardList.add(
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('ngo_listings').doc(listingId).get(),
                      builder: (context, listingSnapshot) {
                        if (!listingSnapshot.hasData || !listingSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }
                        
                        var listingData = listingSnapshot.data!.data() as Map<String, dynamic>;
                        
                        // 👇 THE CORE LOGIC: Hide the task if the NGO toggled "I have volunteer for pickup"
                        bool? isVolunteerAvailable = listingData['isVolunteerAvailable'] as bool?;
                        if (isVolunteerAvailable == true) {
                          return const SizedBox.shrink();
                        }
                        
                        String type = listingData['type'] ?? 'food';
                        String itemName = type == 'food'
                            ? (listingData['foodType'] ?? "Food")
                            : (listingData['productName'] ?? "Product");
                            
                        String quantityVal = listingData['quantity']?.toString() ?? '';
                        String unitVal = listingData['unit']?.toString() ?? '';
                        String quantity = quantityVal.isEmpty ? '1 Item' : '$quantityVal $unitVal';
                        String availability = listingData['availability'] ?? 'Time not specified';
                        String ngoName = listingData['ngoName'] ?? 'Unknown NGO';
                        String ngoLocation = listingData['ngoLocation'] ?? 'Location unavailable';
                        String ngoId = listingData['ngoId'] ?? '';
                        
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(ngoId).get(),
                          builder: (context, ngoUserSnapshot) {
                            String ngoPhone = 'Phone unavailable';
                            if (ngoUserSnapshot.hasData && ngoUserSnapshot.data!.exists) {
                              var ngoUserData = ngoUserSnapshot.data!.data() as Map<String, dynamic>;
                              ngoPhone = ngoUserData['phone'] ?? 'Phone unavailable';
                            }
                            
                            return _buildDeliveryCard(
                              donationId: donationId,
                              itemName: itemName,
                              quantity: quantity,
                              availability: availability,
                              ngoName: ngoName,
                              ngoLocation: ngoLocation,
                              ngoPhone: ngoPhone,
                              donorName: donorName,
                              donorLocation: donorLocation,
                              donorPhone: donorPhone,
                              donorId: donorId,
                              myId: user.uid,
                              isAcceptedByMe: isAcceptedByMe,
                            );
                          },
                        );
                      },
                    ),
                  );
                }
                
                if (cardList.isEmpty) {
                  return _buildEmptyState();
                }
                
                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thickness: 6.0,
                  radius: const Radius.circular(10),
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 100),
                    children: cardList,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard({
    required String donationId,
    required String itemName,
    required String quantity,
    required String availability,
    required String ngoName,
    required String ngoLocation,
    required String ngoPhone,
    required String donorName,
    required String donorLocation,
    required String donorPhone,
    required String donorId,
    required String myId,
    required bool isAcceptedByMe,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, 
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAcceptedByMe ? Colors.green.shade50 : themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isAcceptedByMe ? Colors.green.shade200 : Colors.transparent),
                  ),
                  child: Text(
                    isAcceptedByMe ? "Task Accepted" : "Pickup Needed",
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: isAcceptedByMe ? Colors.green.shade700 : themeColor,
                    ),
                  ),
                ),
                Text(
                  quantity, 
                  style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              itemName, 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Required by: $availability",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PICKUP FROM", 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.person_outline, donorName),
                       
                        const SizedBox(height: 4),
                        _buildDetailRow(Icons.location_on_outlined, donorLocation),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DELIVER TO (NGO)", 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.account_balance_outlined, ngoName),
                        
                        const SizedBox(height: 4),
                        _buildDetailRow(Icons.location_on_outlined, ngoLocation),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!isAcceptedByMe)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _acceptTask(donationId, myId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Accept Task", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(otherUserId: donorId, otherUserName: donorName),
                      ),
                    );
                  },
                  icon: Icon(Icons.chat_bubble_outline_rounded, color: themeColor, size: 20),
                  label: Text(
                    "Open Chat with Donor", 
                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: themeColor.withValues(alpha: 0.5), width: 1.5),
                    backgroundColor: themeColor.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1), 
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_car_filled_outlined, size: 60, color: themeColor),
          ),
          const SizedBox(height: 24),
          Text(
            showAvailable ? "No tasks available" : "No accepted tasks",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            showAvailable ? "Check back later for new pickup requests." : "Accept a task to see it here.",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}