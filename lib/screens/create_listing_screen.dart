import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ngo_listing_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'home_screen.dart'; // REQUIRED: To navigate back safely

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({Key? key}) : super(key: key);

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  String _listingType = 'food';
  bool _isStep1 = true; // Controls Progressive Disclosure (The "Next" logic)
  
  // --- NEW: Volunteer Availability State ---
  bool? _isVolunteerAvailable; 

  final TextEditingController _foodTypeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String _unit = 'kg';

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();

  final TextEditingController _availabilityController = TextEditingController();

  bool _isLoading = false;

  File? _selectedImage;
  Uint8List? _webImage;
  final ImagePicker _picker = ImagePicker();

  final Color themeColor = const Color(0xFF7D444C); // App Theme Color

  // Suggestion Lists for Autocomplete
  static const List<String> _foodSuggestions = [
    'Biriyani', 'Chappathi', 'Curry', 'Dal', 'Dosa', 'Idli', 'Meals', 
    'Parotta', 'Pongal', 'Puri', 'Rice', 'Roll', 'Sambar', 'Sandwich'
  ];

  static const List<String> _productSuggestions = [
    'Blankets', 'Books', 'Clothes', 'Footwear', 'Furniture', 'Medicines',
    'School Supplies', 'Stationery', 'Toys', 'Utensils', 'Winter Wear'
  ];

  @override
  void dispose() {
    _foodTypeController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    _productNameController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (kIsWeb) {
        _webImage = await picked.readAsBytes();
      } else {
        _selectedImage = File(picked.path);
      }
      setState(() {});
    }
  }

  // --- Interactive Date and Time Picker (SCALED DOWN) ---
  Future<void> _selectDateTime(BuildContext context) async {
    // 1. Pick the Date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), 
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        // SCALING DOWN THE CALENDAR
        return Transform.scale(
          scale: 0.85, 
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: themeColor, 
                onPrimary: Colors.white, 
                onSurface: Colors.black87, 
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null) {
      // 2. Pick the Time
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(), 
        builder: (context, child) {
          // SCALING DOWN THE CLOCK
          return Transform.scale(
            scale: 0.85,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: themeColor,
                  onPrimary: Colors.white,
                  onSurface: Colors.black87,
                ),
              ),
              child: child!,
            ),
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          String day = pickedDate.day.toString().padLeft(2, '0');
          String month = pickedDate.month.toString().padLeft(2, '0');
          String year = pickedDate.year.toString();
          String time = pickedTime.format(context);
          
          _availabilityController.text = "$day-$month-$year  $time";
        });
      }
    }
  }

  // Helper to progress to details
  void _goToNextStep() {
    if (_listingType == 'food' && _foodTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a Food Type')));
      return;
    }
    if (_listingType == 'product' && (_categoryController.text.trim().isEmpty || _productNameController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Category and Product Name')));
      return;
    }
    
    setState(() {
      _isStep1 = false;
    });
  }

  // --- Safe Navigation Function ---
  void _navigateSafelyHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _createListing() async {
    // Validate all fields
    if (_listingType == 'food' && _quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a Quantity')));
      return;
    }
    if (_availabilityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Date & Time')));
      return;
    }
    // Validate Volunteer Selection
    if (_isVolunteerAvailable == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select if a Volunteer is Available')));
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;

    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl;

      if (_selectedImage != null || _webImage != null) {
        final storageService = StorageService();
        imageUrl = await storageService.uploadImage(_selectedImage, _webImage);
      }

      String listingId = FirebaseFirestore.instance.collection('ngo_listings').doc().id;

      // PASSING THE VOLUNTEER BOOLEAN TO THE MODEL
      NgoListingModel newListing = NgoListingModel(
        listingId: listingId,
        ngoId: user.uid,
        ngoName: user.name,
        ngoLocation: user.location,
        type: _listingType,
        imageUrl: imageUrl,
        foodType: _listingType == 'food' ? _foodTypeController.text.trim() : null,
        quantity: _listingType == 'food' && _quantityController.text.trim().isNotEmpty
            ? int.parse(_quantityController.text.trim())
            : null,
        unit: _listingType == 'food' ? _unit : null,
        category: _listingType == 'product' ? _categoryController.text.trim() : null,
        productName: _listingType == 'product' ? _productNameController.text.trim() : null,
        availability: _availabilityController.text.trim(),
        liveUntil: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        status: 'open',
        isVolunteerAvailable: _isVolunteerAvailable, // <-- NEW DATA PASSED HERE
      );

      await _firestoreService.createNgoListing(newListing);

      if (!mounted) return;

      // --- Exciting Success Snackbar! ---
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🎉 Request created successfully!', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
          ),
          backgroundColor: Colors.green, 
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Safe Navigation instead of pop()
      _navigateSafelyHome();

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // SMART AUTOCOMPLETE BUILDER
  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String hintText,
    required List<String> suggestions,
    required bool isEnabled, 
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        }
        
        String query = textEditingValue.text.toLowerCase();
        
        var startsWithMatches = suggestions.where((option) => option.toLowerCase().startsWith(query)).toList();
        var containsMatches = suggestions.where((option) => option.toLowerCase().contains(query) && !option.toLowerCase().startsWith(query)).toList();
        
        return [...startsWithMatches, ...containsMatches];
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
        fieldTextEditingController.addListener(() {
          controller.text = fieldTextEditingController.text;
        });
        
        if (controller.text.isNotEmpty && fieldTextEditingController.text.isEmpty) {
             fieldTextEditingController.text = controller.text;
        }

        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          enabled: isEnabled,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: themeColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        );
      },
      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: MediaQuery.of(context).size.width - 32,
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: Colors.black87),
          onPressed: _navigateSafelyHome,
        ),
        title: const Text(
          "Create Request",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP TOGGLE BUTTONS ---
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _isStep1 ? () {
                        setState(() {
                          _listingType = 'food';
                        });
                      } : null, 
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _listingType == 'food' ? themeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            "Food Registration",
                            style: TextStyle(
                              color: _listingType == 'food' ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isStep1 ? () {
                        setState(() {
                          _listingType = 'product';
                        });
                      } : null, 
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _listingType == 'product' ? themeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            "Product Request",
                            style: TextStyle(
                              color: _listingType == 'product' ? Colors.white : Colors.grey.shade600,
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

            const SizedBox(height: 30),

            // --- NAME / CATEGORY (Step 1) ---
            if (_listingType == 'food') ...[
              _buildAutocompleteField(
                controller: _foodTypeController,
                hintText: "Food Type (e.g., Rice, Meals)",
                suggestions: _foodSuggestions,
                isEnabled: _isStep1, 
              ),
            ] else ...[
              Opacity(
                opacity: _isStep1 ? 1.0 : 0.5,
                child: IgnorePointer(
                  ignoring: !_isStep1,
                  child: CustomTextField(
                    controller: _categoryController,
                    hintText: "Category (Clothes, Books)",
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildAutocompleteField(
                controller: _productNameController,
                hintText: "Product Name",
                suggestions: _productSuggestions,
                isEnabled: _isStep1,
              ),
            ],

            const SizedBox(height: 20),

            // --- NEXT BUTTON ---
            if (_isStep1)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Next", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

            // --- DETAILS & PUBLISH (Expanded when Next is clicked) ---
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isStep1 ? const SizedBox.shrink() : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // Edit Details Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isStep1 = true; // Go back to edit name
                        });
                      },
                      icon: Icon(Icons.edit, size: 16, color: themeColor),
                      label: Text("Edit Details", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_listingType == 'food')
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: CustomTextField(
                            controller: _quantityController,
                            hintText: "Quantity",
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _unit,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                items: ['kg', 'packs', 'members'].map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _unit = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                        )
                      ],
                    ),

                  if (_listingType == 'food') const SizedBox(height: 16),

                  // --- INTERACTIVE DATE/TIME FIELD ---
                  TextFormField(
                    controller: _availabilityController,
                    readOnly: true, 
                    onTap: () => _selectDateTime(context), 
                    decoration: InputDecoration(
                      hintText: "dd-mm-yyyy  --:--",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: Icon(Icons.calendar_month_outlined, color: Colors.grey.shade700, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Image Preview
                  if (_selectedImage != null || _webImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.memory(
                              _webImage!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              _selectedImage!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Image Upload Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.add_photo_alternate_outlined, color: themeColor),
                      label: Text(_selectedImage != null || _webImage != null ? "Change Image" : "Upload Image", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: themeColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- VOLUNTEER SELECTION TOGGLE ---
                  const Text(
                    "Volunteer Available?",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isVolunteerAvailable = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _isVolunteerAvailable == true ? themeColor : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _isVolunteerAvailable == true ? themeColor : Colors.grey.shade300),
                              boxShadow: _isVolunteerAvailable == true ? [BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                            ),
                            child: Center(
                              child: Text("Yes ✅", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isVolunteerAvailable == true ? Colors.white : Colors.black87)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isVolunteerAvailable = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _isVolunteerAvailable == false ? themeColor : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _isVolunteerAvailable == false ? themeColor : Colors.grey.shade300),
                              boxShadow: _isVolunteerAvailable == false ? [BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                            ),
                            child: Center(
                              child: Text("No ❌", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isVolunteerAvailable == false ? Colors.white : Colors.black87)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Publish Button
                  CustomButton(
                    text: "Publish Listing",
                    isLoading: _isLoading,
                    onPressed: _createListing,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}