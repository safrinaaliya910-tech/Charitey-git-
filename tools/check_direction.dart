//check_direction.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Usage: dart run tools/check_directions.dart <originLat> <originLng> <destLat> <destLng>
Future<void> main(List<String> args) async {
  if (args.length < 4) {
    print('Usage: dart run tools/check_directions.dart <originLat> <originLng> <destLat> <destLng>');
    return;
  }

  final originLat = double.parse(args[0]);
  final originLng = double.parse(args[1]);
  final destLat = double.parse(args[2]);
  final destLng = double.parse(args[3]);

  // Read API key from lib/firebase_options.dart (avoid importing Flutter)
  final fb = File('lib/firebase_options.dart');
  if (!fb.existsSync()) {
    print('lib/firebase_options.dart not found');
    return;
  }
  final text = fb.readAsStringSync();
  String? apiKey;
  // Prefer android block
  final androidBlock = RegExp(r"static const FirebaseOptions android = FirebaseOptions\((.|\n)*?\);", multiLine: true);
  final am = androidBlock.firstMatch(text);
  if (am != null) {
    final block = am.group(0)!;
    final km = RegExp(r"apiKey:\s*'([^']+)'", multiLine: true).firstMatch(block);
    if (km != null) apiKey = km.group(1);
  }
  apiKey ??= RegExp(r"apiKey:\s*'([^']+)'", multiLine: true).firstMatch(text)?.group(1);
  if (apiKey == null || apiKey!.isEmpty) {
    print('No apiKey found in lib/firebase_options.dart');
    return;
  }

  final uri = Uri.https('routes.googleapis.com', '/directions/v2:computeRoutes');

  final body = json.encode({
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
    'X-Goog-Api-Key': apiKey!,
    'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration',
  };

  print('Requesting Routes API: $uri');

  try {
    final resp = await http.post(uri, headers: headers, body: body);
    print('\nHTTP status: ${resp.statusCode}');
    print('\nBody:\n${resp.body}');

    if (resp.statusCode != 200) {
      print('Routes API HTTP error: ${resp.statusCode}');
      return;
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      print('Routes API returned no routes');
      return;
    }

    final first = routes.first as Map<String, dynamic>;

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

    int? durationSeconds;
    if (first['duration'] is String) {
      final m = RegExp(r'^(\d+)').firstMatch(first['duration'] as String);
      if (m != null) durationSeconds = int.tryParse(m.group(1)!);
    } else if (first['duration'] is Map) {
      final d = first['duration'] as Map<String, dynamic>;
      if (d['seconds'] is num) durationSeconds = (d['seconds'] as num).toInt();
    } else if (first['legs'] is List) {
      int total = 0;
      bool found = false;
      for (final leg in (first['legs'] as List)) {
        if (leg is Map<String, dynamic>) {
          final ldur = leg['duration'];
          if (ldur is String) {
            final m = RegExp(r'^(\d+)').firstMatch(ldur);
            if (m != null) {
              total += int.tryParse(m.group(1)!) ?? 0;
              found = true;
            }
          } else if (ldur is Map && ldur['seconds'] is num) {
            total += (ldur['seconds'] as num).toInt();
            found = true;
          }
        }
      }
      if (found) durationSeconds = total;
    }

    print('\nParsed Results:');
    if (distanceMeters != null) print('Distance (km): ${(distanceMeters / 1000).toStringAsFixed(3)}');
    else print('Distance not found in response');
    if (durationSeconds != null) print('Duration (sec): $durationSeconds');
    else print('Duration not found in response');
  } catch (e) {
    print('Request failed: $e');
  }
}