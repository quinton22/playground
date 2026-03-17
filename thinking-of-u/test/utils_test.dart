import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_of_u/utils/crypto_utils.dart';
import 'package:thinking_of_u/utils/phone_utils.dart';

void main() {
  group('CryptoUtils', () {
    test('hashPhoneNumber produces consistent hashes for same input', () {
      const phone = '+12025551234';
      final hash1 = CryptoUtils.hashPhoneNumber(phone);
      final hash2 = CryptoUtils.hashPhoneNumber(phone);
      expect(hash1, equals(hash2));
    });

    test('hashPhoneNumber produces different hashes for different inputs', () {
      final hash1 = CryptoUtils.hashPhoneNumber('+12025551234');
      final hash2 = CryptoUtils.hashPhoneNumber('+12025551235');
      expect(hash1, isNot(equals(hash2)));
    });

    test('hashPhoneNumber produces 64-character hex string', () {
      final hash = CryptoUtils.hashPhoneNumber('+12025551234');
      expect(hash.length, equals(64));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });

    test('hashPhoneNumber normalizes phone with spaces/dashes', () {
      final hash1 = CryptoUtils.hashPhoneNumber('+1 202 555 1234');
      final hash2 = CryptoUtils.hashPhoneNumber('+1-202-555-1234');
      final hash3 = CryptoUtils.hashPhoneNumber('+12025551234');
      expect(hash1, equals(hash2));
      expect(hash2, equals(hash3));
    });
  });

  group('PhoneUtils', () {
    test('isValidPhoneNumber accepts valid E.164 numbers', () {
      expect(PhoneUtils.isValidPhoneNumber('+12025551234'), isTrue);
      expect(PhoneUtils.isValidPhoneNumber('+447911123456'), isTrue);
      expect(PhoneUtils.isValidPhoneNumber('+61412345678'), isTrue);
    });

    test('isValidPhoneNumber rejects invalid numbers', () {
      expect(PhoneUtils.isValidPhoneNumber('12025551234'), isFalse);
      expect(PhoneUtils.isValidPhoneNumber('+1'), isFalse);
      expect(PhoneUtils.isValidPhoneNumber(''), isFalse);
      expect(PhoneUtils.isValidPhoneNumber('not-a-number'), isFalse);
    });

    test('normalize strips formatting characters', () {
      expect(PhoneUtils.normalize('+1 (202) 555-1234'), equals('+12025551234'));
      expect(PhoneUtils.normalize('+1-202-555-1234'), equals('+12025551234'));
    });

    test('maskPhoneNumber hides middle digits', () {
      final masked = PhoneUtils.maskPhoneNumber('+12025551234');
      expect(masked, contains('1234'));
      expect(masked, contains('****'));
    });
  });
}
