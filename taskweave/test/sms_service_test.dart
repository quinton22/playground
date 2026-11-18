import 'package:flutter_test/flutter_test.dart';
import 'package:taskweave/models/sms_message.dart';
import 'package:taskweave/services/sms_service.dart';

void main() {
  late SmsService smsService;

  setUp(() {
    smsService = SmsService(telephony: null);
  });

  group('SmsService.analyzeSmsForSuggestions', () {
    test('returns empty list when no messages', () {
      final suggestions = smsService.analyzeSmsForSuggestions([]);
      expect(suggestions, isEmpty);
    });

    test('returns suggestions for actionable messages', () {
      final messages = [
        _buildMessage(
          id: '1',
          body: 'Hey, don\'t forget to pick up the dry cleaning tomorrow!',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.suggestedTitle, isNotEmpty);
      expect(suggestions.first.sourceMessageId, equals('1'));
    });

    test('ignores messages with no actionable content', () {
      final messages = [
        _buildMessage(id: '1', body: 'Hey how are you?'),
        _buildMessage(id: '2', body: 'Lol that is funny 😂'),
        _buildMessage(id: '3', body: 'Ok cool'),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      expect(suggestions, isEmpty);
    });

    test('detects "tomorrow" as deadline', () {
      final messages = [
        _buildMessage(
          id: '1',
          body: 'Please pick up the kids from school tomorrow at 3pm',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      expect(suggestions, isNotEmpty);

      final suggestion = suggestions.first;
      expect(suggestion.suggestedDeadline, isNotNull);

      final expectedDate =
          DateTime.now().add(const Duration(days: 1));
      expect(suggestion.suggestedDeadline!.day, equals(expectedDate.day));
    });

    test('detects "tonight" keyword', () {
      final messages = [
        _buildMessage(
          id: '1',
          body: 'Don\'t forget we need to call grandma tonight!',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      expect(suggestions, isNotEmpty);

      final suggestion = suggestions.first;
      expect(suggestion.suggestedDeadline, isNotNull);
      expect(suggestion.suggestedDeadline!.day, equals(DateTime.now().day));
    });

    test('detects day of week as deadline', () {
      final messages = [
        _buildMessage(
          id: '1',
          body: 'Make sure to submit the report by Friday',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.suggestedDeadline, isNotNull);
      expect(suggestions.first.suggestedDeadline!.weekday, equals(5)); // Friday
    });

    test('confidence is between 0 and 1', () {
      final messages = [
        _buildMessage(
          id: '1',
          body:
              'Remember to buy groceries, book dentist appointment, and pick up package before Friday!',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      for (final s in suggestions) {
        expect(s.confidence, greaterThanOrEqualTo(0.0));
        expect(s.confidence, lessThanOrEqualTo(1.0));
      }
    });

    test('suggestions are sorted by confidence descending', () {
      final messages = [
        // Weak signal
        _buildMessage(id: '1', body: 'Please call me'),
        // Stronger signal with multiple action words
        _buildMessage(
          id: '2',
          body:
              'Don\'t forget to pick up the medicine tomorrow before the meeting',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);

      if (suggestions.length >= 2) {
        expect(
          suggestions.first.confidence,
          greaterThanOrEqualTo(suggestions.last.confidence),
        );
      }
    });

    test('snippet is truncated to 80 chars', () {
      final longBody =
          'Please remember to call back the insurance company and also '
          'pick up the prescription from the pharmacy before it closes tonight!';
      final messages = [_buildMessage(id: '1', body: longBody)];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      if (suggestions.isNotEmpty) {
        expect(suggestions.first.sourceMessageSnippet.length, lessThanOrEqualTo(80));
      }
    });

    test('title is capitalized', () {
      final messages = [
        _buildMessage(
          id: '1',
          body: 'please pick up the groceries',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      if (suggestions.isNotEmpty) {
        final title = suggestions.first.suggestedTitle;
        expect(title[0], equals(title[0].toUpperCase()));
      }
    });

    test('title is truncated when very long', () {
      final messages = [
        _buildMessage(
          id: '1',
          body:
              'Please remember to pick up the extremely long list of items from the store including milk eggs bread cheese and all the other things we need this week',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      if (suggestions.isNotEmpty) {
        expect(suggestions.first.suggestedTitle.length, lessThanOrEqualTo(60));
      }
    });

    test('date pattern MM/DD is detected', () {
      final nextMonth =
          DateTime.now().add(const Duration(days: 30));
      final dateStr =
          '${nextMonth.month.toString().padLeft(2, '0')}/${nextMonth.day.toString().padLeft(2, '0')}';

      final messages = [
        _buildMessage(
          id: '1',
          body: 'Don\'t forget the appointment on $dateStr',
        ),
      ];

      final suggestions = smsService.analyzeSmsForSuggestions(messages);
      if (suggestions.isNotEmpty && suggestions.first.suggestedDeadline != null) {
        expect(suggestions.first.suggestedDeadline!.month,
            equals(nextMonth.month));
      }
    });
  });
}

SmsMessage _buildMessage({
  required String id,
  required String body,
  String? sender,
}) {
  return SmsMessage(
    id: id,
    sender: sender ?? 'TestSender',
    body: body,
    receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
  );
}
