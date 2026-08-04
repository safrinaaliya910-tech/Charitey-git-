//lib/services/location_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../firebase_options.dart';

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

  /// Gets the driving route distance between two coordinates using
  /// Google Directions API.
  ///
  /// Returns kilometers, or null if the API call fails.
  static Future<double?> getRouteDistanceKm({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      final Uri uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        {
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          'mode': 'driving',
          'units': 'metric',
          'key': apiKey,
        },
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final firstRoute = routes.first as Map<String, dynamic>;
      final legs = firstRoute['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) return null;

      num totalDistance = 0;
      for (final leg in legs) {
        final distance = (leg as Map<String, dynamic>)['distance'] as Map<String, dynamic>?;
        if (distance == null) return null;
        final value = distance['value'] as num?;
        if (value == null) return null;
        totalDistance += value;
      }

      return totalDistance.toDouble() / 1000.0;
    } catch (_) {
      return null;
    }
  }

  /// Opens the native Google Maps app securely via Deep-Link
  static Future<void> openGoogleMaps(String coordinates) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$coordinates";

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    }
  }
}