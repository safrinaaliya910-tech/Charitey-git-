//utils/upi_reference_validator.dart
class UpiReferenceValidator {
  static const int requiredLength = 12;

  static bool isValid(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return RegExp(r'^\d{12}$').hasMatch(trimmed);
  }

  static String? validate(String? value) {
    if (!isValid(value)) {
      return 'Please enter a valid 12-digit UPI reference number';
    }
    return null;
  }
}

bool isValidUpiReference(String? value) => UpiReferenceValidator.isValid(value);

String? validateUpiReference(String? value) => UpiReferenceValidator.validate(value);