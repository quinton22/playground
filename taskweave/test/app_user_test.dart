import 'package:flutter_test/flutter_test.dart';
import 'package:taskweave/models/app_user.dart';

void main() {
  group('AppUser', () {
    test('name returns displayName when set', () {
      final user = AppUser(
        uid: 'uid-1',
        email: 'test@example.com',
        displayName: 'John Doe',
      );
      expect(user.name, equals('John Doe'));
    });

    test('name returns email prefix when displayName is null', () {
      final user = AppUser(
        uid: 'uid-1',
        email: 'johndoe@example.com',
        displayName: null,
      );
      expect(user.name, equals('johndoe'));
    });

    test('toMap and fromMap round-trip preserves all fields', () {
      final original = AppUser(
        uid: 'uid-123',
        email: 'user@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
      );

      final map = original.toMap();
      final restored = AppUser.fromMap(map);

      expect(restored.uid, equals(original.uid));
      expect(restored.email, equals(original.email));
      expect(restored.displayName, equals(original.displayName));
      expect(restored.photoUrl, equals(original.photoUrl));
    });

    test('toMap handles null optional fields', () {
      final user = AppUser(
        uid: 'uid-1',
        email: 'user@example.com',
      );

      final map = user.toMap();
      expect(map['displayName'], isNull);
      expect(map['photoUrl'], isNull);
    });
  });
}
