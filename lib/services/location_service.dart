import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationHelperService {
  /// Requests hardware permissions and grabs the exact live coordinates
  static Future<Position?> determinePosition(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable Location Services in your phone settings.')));
      }
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')));
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      }
      return null;
    }

    // Get the exact live position
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  /// Opens the native Google Maps app securely via Deep-Link
  static Future<void> openGoogleMaps(String coordinates) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$coordinates";

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    }
  }
}