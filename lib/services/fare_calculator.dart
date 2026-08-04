//service/fare_calculator.dart
enum VehicleType {
  scooty,
  bike,
  auto,
  car,
  tempo,
  van,
  lorry,
}

/// Fare formula: fee = baseFare + (distanceKm * perKmRate), rounded to nearest ₹10.
///
/// Rates below are intentionally tuned to keep small two-wheelers affordable
/// while ensuring larger goods vehicles scale appropriately for long-distance
/// pickup/delivery tasks.
///
/// Bike/Auto values remain aligned with nearest available real-world ride
/// estimates; Tempo/Van/Lorry are now adjusted upward from the previous
/// extrapolation so they do not collapse to bike-like pricing at high distance.
class FareCalculator {
  static double calculate({required VehicleType vehicle, required double distanceKm}) {
    final safeDistanceKm = distanceKm < 0 ? 0.0 : distanceKm;

    switch (vehicle) {
      // ⚠️ Estimated - small two-wheeler rate.
      case VehicleType.scooty:
        return _roundToNearest10(20.0 + (safeDistanceKm * 5.0));

      // ✅ Verified against real small-vehicle data.
      case VehicleType.bike:
        return _roundToNearest10(20.0 + (safeDistanceKm * 5.0));

      // ✅ Verified against real auto fare data.
      case VehicleType.auto:
        return _roundToNearest10(40.0 + (safeDistanceKm * 12.0));

      // ⚠️ Estimated from short-distance car fares and longer-distance scaling.
      case VehicleType.car:
        return _roundToNearest10(55.0 + (safeDistanceKm * 15.0));

      // ⚠️ Estimated but raised to prevent tempo pricing from matching bike.
      case VehicleType.tempo:
        return _roundToNearest10(85.0 + (safeDistanceKm * 18.0));

      // ⚠️ Estimated and set higher than tempo for larger cargo vans.
      case VehicleType.van:
        return _roundToNearest10(100.0 + (safeDistanceKm * 20.0));

      // ⚠️ Estimated and tuned for heavy goods transport.
      case VehicleType.lorry:
        return _roundToNearest10(125.0 + (safeDistanceKm * 24.0));
    }
  }

  static double _roundToNearest10(double value) {
    return (value / 10).roundToDouble() * 10;
  }
}