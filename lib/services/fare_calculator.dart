//service/fare_calculator.dart

enum VehicleType { scooty, bike, auto, car, tempo, van, lorry }

/// All rates sourced from ACTUAL app prices in Coimbatore (verified Aug 2026):
///   Bike/Scooty/Tempo/Van/Lorry → Porter app, Coimbatore, 1km fare
///   Car                         → Rapido app, Coimbatore, 1km fare
///   Auto                        → Tamil Nadu govt meter rate
///
/// Formula:
///   Billable KM    = max(Distance − IncludedKm, 0)
///   Distance Charge = Billable KM × PerKmRate
///   Subtotal        = BaseFare + DistanceCharge + (Duration × PerMinRate)
///   Subtotal        = Subtotal × SurgeMultiplier  (if surge active)
///   Final Fare      = max(Subtotal + PlatformFee + Toll + Parking, MinimumFare)
///   Final Fare      = rounded to nearest ₹5
class VehicleRateConfig {
  final double baseFare;
  final double includedKm;
  final double perKmRate;
  final double perMinuteRate;
  final double minimumFare;

  const VehicleRateConfig({
    required this.baseFare,
    required this.includedKm,
    required this.perKmRate,
    required this.perMinuteRate,
    required this.minimumFare,
  });
}

class FareCalculator {
  static const Map<VehicleType, VehicleRateConfig> _rates = {
    // ✅ Porter Coimbatore app — 2-wheeler: 1km = ₹37
    VehicleType.bike: VehicleRateConfig(
      baseFare: 37.0,
      includedKm: 1.0,
      perKmRate: 8.0,
      perMinuteRate: 0.5,
      minimumFare: 37.0,
    ),
    // ✅ Porter Coimbatore app — scooty: 1km = ₹42
    VehicleType.scooty: VehicleRateConfig(
      baseFare: 42.0,
      includedKm: 1.0,
      perKmRate: 10.0,
      perMinuteRate: 0.5,
      minimumFare: 42.0,
    ),
    // ✅ Tamil Nadu govt auto meter — 1.9km base ₹30, ₹15/km after
    VehicleType.auto: VehicleRateConfig(
      baseFare: 30.0,
      includedKm: 1.9,
      perKmRate: 15.0,
      perMinuteRate: 1.0,
      minimumFare: 30.0,
    ),
    // ✅ Rapido Coimbatore app — car: 1km = ₹90
    VehicleType.car: VehicleRateConfig(
      baseFare: 80.0,
      includedKm: 0.0,
      perKmRate: 10.0,
      perMinuteRate: 1.0,
      minimumFare: 90.0,
    ),
    // ✅ Porter Coimbatore app — 3-wheeler: 1km = ₹191
    VehicleType.tempo: VehicleRateConfig(
      baseFare: 191.0,
      includedKm: 1.0,
      perKmRate: 18.0,
      perMinuteRate: 2.0,
      minimumFare: 191.0,
    ),
    // ✅ Porter Coimbatore app — Tata Ace: 1km = ₹216
    VehicleType.van: VehicleRateConfig(
      baseFare: 216.0,
      includedKm: 1.0,
      perKmRate: 20.0,
      perMinuteRate: 2.5,
      minimumFare: 216.0,
    ),
    // ✅ Porter Coimbatore app — Pickup 8ft: 1km = ₹291
    VehicleType.lorry: VehicleRateConfig(
      baseFare: 291.0,
      includedKm: 1.0,
      perKmRate: 25.0,
      perMinuteRate: 3.0,
      minimumFare: 291.0,
    ),
  };

  static double calculate({
    required VehicleType vehicle,
    required double distanceKm,
    double durationMinutes = 0.0,
    double surgeMultiplier = 1.0,
    double platformFee = 0.0,
    double toll = 0.0,
    double parking = 0.0,
  }) {
    final config = _rates[vehicle]!;

    final d = distanceKm < 0 ? 0.0 : distanceKm;
    final duration = durationMinutes < 0 ? 0.0 : durationMinutes;
    final surge = surgeMultiplier <= 0 ? 1.0 : surgeMultiplier;
    final fee = platformFee < 0 ? 0.0 : platformFee;
    final tollAmt = toll < 0 ? 0.0 : toll;
    final parkingAmt = parking < 0 ? 0.0 : parking;

    final billableKm = d - config.includedKm;
    final distanceCharge =
        (billableKm > 0 ? billableKm : 0.0) * config.perKmRate;
    final timeCharge = duration * config.perMinuteRate;

    double subtotal = config.baseFare + distanceCharge + timeCharge;
    if (surge != 1.0) subtotal *= surge;

    double finalFare = subtotal + fee + tollAmt + parkingAmt;
    if (finalFare < config.minimumFare) finalFare = config.minimumFare;

    return _roundToNearest5(finalFare);
  }

  // ₹5 rounding — matches Porter/Rapido display (₹25, ₹35, ₹42 etc)
  static double _roundToNearest5(double value) =>
      (value / 5).roundToDouble() * 5;
}