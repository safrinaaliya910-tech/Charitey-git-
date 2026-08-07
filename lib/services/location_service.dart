//location_service.dart
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
  /// Google Routes API (computeRoutes).
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
        'routes.googleapis.com',
        '/directions/v2:computeRoutes',
      );

      final requestBody = json.encode({
        'origin': {
          'location': {
            'latLng': {'latitude': originLat, 'longitude': originLng}
          }
        },
        'destination': {
          'location': {
            'latLng': {'latitude': destLat, 'longitude': destLng}
          }
        },
        'travelMode': 'DRIVE',
        'units': 'METRIC',
      });

      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey ?? '',
        'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration',
      };

      final response = await http.post(uri, headers: headers, body: requestBody);
      if (response.statusCode != 200) {
        debugPrint('Routes API HTTP error: ${response.statusCode}');
        debugPrint('Routes API body: ${response.body}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        debugPrint('Routes API returned no routes: ${response.body}');
        return null;
      }

      final first = routes.first as Map<String, dynamic>;

      // Extract distanceMeters
      num? distanceMeters;
      if (first['distanceMeters'] is num) {
        distanceMeters = first['distanceMeters'] as num;
      } else if (first['legs'] is List) {
        num total = 0;
        for (final leg in (first['legs'] as List)) {
          if (leg is Map<String, dynamic>) {
            if (leg['distanceMeters'] is num) {
              total += leg['distanceMeters'] as num;
            } else if (leg['distance'] is Map && leg['distance']['value'] is num) {
              total += leg['distance']['value'] as num;
            }
          }
        }
        if (total > 0) distanceMeters = total;
      }

      // Extract duration in seconds (may be string like "1234s" or map)
      int? durationSeconds;
      dynamic dur = first['duration'];
      if (dur is String) {
        // e.g. "1234s"
        final m = RegExp(r"^(\d+)").firstMatch(dur);
        if (m != null) durationSeconds = int.tryParse(m.group(1)!);
      } else if (dur is Map) {
        if (dur['seconds'] is num) {
          durationSeconds = (dur['seconds'] as num).toInt();
        } else if (dur['nanos'] is num && dur['seconds'] is num) {
          durationSeconds = (dur['seconds'] as num).toInt();
        }
      } else if (first['legs'] is List) {
        int totalSec = 0;
        bool found = false;
        for (final leg in (first['legs'] as List)) {
          if (leg is Map<String, dynamic>) {
            final ldur = leg['duration'];
            if (ldur is String) {
              final m = RegExp(r"^(\d+)").firstMatch(ldur);
              if (m != null) {
                totalSec += int.tryParse(m.group(1)!) ?? 0;
                found = true;
              }
            } else if (ldur is Map && ldur['seconds'] is num) {
              totalSec += (ldur['seconds'] as num).toInt();
              found = true;
            }
          }
        }
        if (found) durationSeconds = totalSec;
      }

      debugPrint('Routes API distanceMeters: $distanceMeters, durationSeconds: $durationSeconds');

      if (distanceMeters != null) return distanceMeters.toDouble() / 1000.0;
      debugPrint('Routes API response missing distance: ${response.body}');
      return null;
    } catch (e, st) {
      debugPrint('Routes API call failed: $e');
      debugPrint('$st');
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