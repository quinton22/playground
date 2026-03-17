/// Utility functions for phone number handling.
class PhoneUtils {
  PhoneUtils._();

  /// Validates that a phone number is in a reasonable format.
  /// Accepts E.164 format: +[country code][number]
  static bool isValidPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]+'), '');
    // E.164: starts with +, followed by 7-15 digits
    return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(cleaned);
  }

  /// Format a phone number for display, masking the middle digits for privacy.
  /// E.g., "+12025551234" → "+1 (202) ***-1234"
  static String maskPhoneNumber(String phone) {
    if (phone.length < 8) return '****';
    final last4 = phone.substring(phone.length - 4);
    return '****-$last4';
  }

  /// Normalize a phone number to E.164 format.
  static String normalize(String phone) {
    final stripped = phone.replaceAll(RegExp(r'[\s\-\(\)\.]+'), '');
    if (!stripped.startsWith('+')) {
      return '+$stripped';
    }
    return stripped;
  }

  /// Format a phone number for user-facing display.
  /// E.g., "+12025551234" → "+1 202-555-1234"
  static String formatForDisplay(String phone) {
    final normalized = normalize(phone);
    // Simple formatting: show +CC then groups
    if (normalized.length == 12 && normalized.startsWith('+1')) {
      // US number
      final digits = normalized.substring(2);
      return '+1 ${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return normalized;
  }
}
