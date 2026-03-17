import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_of_u/models/match_model.dart';

void main() {
  group('MatchModel', () {
    final match = MatchModel(
      matchId: 'test_match',
      dateKey: '2024-01-15',
      user1Hash: 'hash_alice',
      user2Hash: 'hash_bob',
      user1DisplayName: 'Alice',
      user2DisplayName: 'Bob',
      matchedAt: DateTime(2024, 1, 15, 12),
      notificationsSent: false,
    );

    test('otherDisplayName returns user2 name for user1', () {
      expect(match.otherDisplayName('hash_alice'), equals('Bob'));
    });

    test('otherDisplayName returns user1 name for user2', () {
      expect(match.otherDisplayName('hash_bob'), equals('Alice'));
    });

    test('otherDisplayName falls back to user2 name for unknown hash', () {
      expect(match.otherDisplayName('hash_unknown'), equals('Bob'));
    });
  });

  group('PurchaseType', () {
    test('PurchaseType.extraSends has correct name', () {
      expect(PurchaseType.extraSends.name, equals('extraSends'));
    });

    test('PurchaseType.extensionDays has correct name', () {
      expect(PurchaseType.extensionDays.name, equals('extensionDays'));
    });

    test('PurchaseType.values contains all types', () {
      expect(PurchaseType.values.length, equals(2));
      expect(PurchaseType.values, contains(PurchaseType.extraSends));
      expect(PurchaseType.values, contains(PurchaseType.extensionDays));
    });
  });
}
