//fare_calculater_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:charity_app/services/fare_calculator.dart';

void main() {
  group('FareCalculator', () {
    test('charges more for larger vehicles over the same distance', () {
      final bikeFee = FareCalculator.calculate(vehicle: VehicleType.bike, distanceKm: 10);
      final tempoFee = FareCalculator.calculate(vehicle: VehicleType.tempo, distanceKm: 10);
      final vanFee = FareCalculator.calculate(vehicle: VehicleType.van, distanceKm: 10);
      final lorryFee = FareCalculator.calculate(vehicle: VehicleType.lorry, distanceKm: 10);

      expect(bikeFee, greaterThan(0));
      expect(tempoFee, greaterThan(bikeFee));
      expect(vanFee, greaterThan(tempoFee));
      expect(lorryFee, greaterThan(vanFee));
    });

    test('calculates tempo fare correctly for 318.9 km', () {
      final fee = FareCalculator.calculate(vehicle: VehicleType.tempo, distanceKm: 318.9);
      expect(fee, 5830);
    });

    test('returns rounded base fare values at zero distance for every vehicle', () {
      expect(FareCalculator.calculate(vehicle: VehicleType.scooty, distanceKm: 0), 20);
      expect(FareCalculator.calculate(vehicle: VehicleType.bike, distanceKm: 0), 20);
      expect(FareCalculator.calculate(vehicle: VehicleType.auto, distanceKm: 0), 40);
      expect(FareCalculator.calculate(vehicle: VehicleType.car, distanceKm: 0), 60);
      expect(FareCalculator.calculate(vehicle: VehicleType.tempo, distanceKm: 0), 90);
      expect(FareCalculator.calculate(vehicle: VehicleType.van, distanceKm: 0), 100);
      expect(FareCalculator.calculate(vehicle: VehicleType.lorry, distanceKm: 0), 130);
    });
  });
}