//upi_reference_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:charity_app/utils/upi_reference_validator.dart';

void main() {
  group('UPI reference validation', () {
    test('accepts a valid 12-digit numeric UPI reference', () {
      expect(isValidUpiReference('231456789012'), isTrue);
    });

    test('rejects non-numeric characters', () {
      expect(isValidUpiReference('23145678901A'), isFalse);
      expect(isValidUpiReference('23145678901@2'), isFalse);
    });

    test('rejects values that are not exactly 12 digits', () {
      expect(isValidUpiReference('12345'), isFalse);
      expect(isValidUpiReference('1234567890123'), isFalse);
      expect(isValidUpiReference(''), isFalse);
    });
  });
}