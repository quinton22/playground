import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_of_u/services/submission_service.dart';

void main() {
  group('SubmissionService', () {
    test('currentDateKey returns YYYY-MM-DD format', () {
      final dateKey = SubmissionService.currentDateKey();
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateKey), isTrue);
    });

    test('currentDateKey uses UTC date', () {
      final dateKey = SubmissionService.currentDateKey();
      final now = DateTime.now().toUtc();
      final expected =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(dateKey, equals(expected));
    });
  });
}
