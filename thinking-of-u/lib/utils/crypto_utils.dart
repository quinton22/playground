import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility class for cryptographic operations.
class CryptoUtils {
  CryptoUtils._();

  /// Hash a phone number using SHA-256 after normalizing it.
  /// The hash is used as the user's identifier in Firestore, ensuring
  /// phone numbers are never stored in plaintext.
  ///
  /// [phoneNumber] should be in E.164 format (e.g., "+12025551234").
  static String hashPhoneNumber(String phoneNumber) {
    final normalized = _normalizePhone(phoneNumber);
    final bytes = utf8.encode(normalized);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Normalize a phone number to a consistent format before hashing.
  /// Strips all non-digit characters except the leading '+'.
  static String _normalizePhone(String phone) {
    // Remove all whitespace, dashes, parentheses
    final stripped = phone.replaceAll(RegExp(r'[\s\-\(\)\.]+'), '');
    // Ensure it starts with '+'
    if (!stripped.startsWith('+')) {
      return '+$stripped';
    }
    return stripped;
  }
}
