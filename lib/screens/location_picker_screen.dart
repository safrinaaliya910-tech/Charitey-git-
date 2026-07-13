import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({Key? key}) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late GoogleMapController _mapController;
  final TextEditingController _searchController = TextEditingController();

  LatLng _selectedLatLng = const LatLng(11.0168, 76.9558); // Coimbatore Default
  bool _isLoading = true;
  String _currentAddressText = "Move or tap map to select location";

  // 👇 NEW: tracks which search call is the "latest" one, so stale
  // results/errors from a duplicate call can be safely ignored.
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _goToCurrentDeviceLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentDeviceLocation() async {
    try {
      Position? position = await LocationHelperService.determinePosition(context);
      if (position != null) {
        setState(() {
          _selectedLatLng = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _getAddressFromCoordinates(_selectedLatLng);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Native Android Search (Free, No API Keys)
  Future<void> _searchAndMoveToAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // 👇 NEW: if a search is already running, ignore this duplicate trigger
    // (this is what was causing the false "Location not found" error while
    // the map was actually moving correctly from the first call)
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    // 👇 NEW: give this specific call a unique token
    final int requestId = ++_searchRequestId;
    setState(() => _isLoading = true);

    try {
      List<Location> locations = await locationFromAddress(query);

      // 👇 NEW: if a newer search has started since this one began, drop this result
      if (requestId != _searchRequestId) return;

      if (locations.isNotEmpty) {
        final target = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _selectedLatLng = target;
          _isLoading = false;
        });
        _mapController.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
        _getAddressFromCoordinates(target);
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location not found. Try a clearer address or pincode.")),
          );
        }
      }
    } catch (e) {
      // 👇 NEW: if a newer search has started since this one began, this is a
      // stale error from a superseded call — ignore it silently
      if (requestId != _searchRequestId) return;

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location not found. Try a clearer address or pincode.")),
        );
      }
    }
  }

  // Native Android Address Reader (Free, No API Keys)
  Future<void> _getAddressFromCoordinates(LatLng coords) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(coords.latitude, coords.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _currentAddressText = "${p.street ?? p.name ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}, ${p.postalCode ?? ''}".replaceAll(RegExp(r'^,\s*'), '').trim();
        });
      }
    } catch (_) {
      setState(() {
        _currentAddressText = "Selected Location Pin";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7D444C),
        foregroundColor: Colors.white,
        title: const Text("Select Share Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Base Map
          if (!_isLoading)
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _selectedLatLng, zoom: 16),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              // 👇 THIS IS THE FIX FOR YOUR CLICKS! 👇
              onTap: (LatLng tappedPoint) {
                // When you tap, the camera smoothly flies to your finger
                _mapController.animateCamera(CameraUpdate.newLatLng(tappedPoint));
              },
              onCameraMoveStarted: () {
                setState(() {
                  _currentAddressText = "Reading map location...";
                });
              },
              onCameraMove: (position) {
                _selectedLatLng = position.target;
              },
              onCameraIdle: () {
                _getAddressFromCoordinates(_selectedLatLng);
              },
            ),

          // High-Precision Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Icon(Icons.location_on_rounded, size: 44, color: const Color(0xFF7D444C)),
            ),
          ),

          // Floating Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchAndMoveToAddress(),
                decoration: InputDecoration(
                  hintText: "Search Share location/address...",
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  suffixIcon: IconButton(
                    // 👇 NEW: disable the button visually while a search is in flight,
                    // as extra protection against accidental double taps
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7D444C)),
                          )
                        : const Icon(Icons.send_rounded, color: Color(0xFF7D444C)),
                    onPressed: _isLoading ? null : _searchAndMoveToAddress,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Bottom Confirmation Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.map_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentAddressText,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _selectedLatLng),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7D444C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("Confirm & Share Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF7D444C))),
        ],
      ),
    );
  }
}