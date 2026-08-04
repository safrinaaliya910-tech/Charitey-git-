import '../lib/services/fare_calculator.dart';

void main() {
  final distances = [0.0, 0.5, 1.0, 2.5, 5.0, 11.0, 20.0, 50.0];

  for (var vehicle in VehicleType.values) {
    print('\n=== ${vehicle.name.toUpperCase()} ===');
    for (var d in distances) {
      final fee = FareCalculator.calculate(vehicle: vehicle, distanceKm: d);
      print('${d.toString().padLeft(5)} km -> ₹${fee.toStringAsFixed(2)}');
    }
  }
}