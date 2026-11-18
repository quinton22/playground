import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import '../models/sms_message.dart';

/// Patterns used to detect actionable items in SMS messages.
/// Each pattern represents a regex that matches a potential todo trigger.
const _actionPatterns = [
  r'\b(don\'?t forget|remember to|make sure to|please)\b',
  r'\b(pick up|buy|get|grab|order|book|schedule|call|email|text|send)\b',
  r'\b(tomorrow|tonight|this week|by [a-z]+day|before [0-9])\b',
  r'\b(need to|have to|must|should|going to|will)\b',
  r'\b(appointment|meeting|deadline|due|event|party|dinner)\b',
];

/// Patterns used to extract potential deadlines from messages.
const _deadlinePatterns = [
  r'(by|before|on|at|this|next)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month|[0-9]+(?:st|nd|rd|th)?)',
  r'\b([0-9]{1,2})[/-]([0-9]{1,2})(?:[/-]([0-9]{2,4}))?\b',
  r'\btomorrow\b',
  r'\btonight\b',
  r'\bthis (morning|afternoon|evening|weekend)\b',
];

class SmsService {
  final Telephony? _telephony;

  SmsService({Telephony? telephony}) : _telephony = telephony;

  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return false;

    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> hasSmsPermission() async {
    if (!Platform.isAndroid) return false;
    return await Permission.sms.isGranted;
  }

  Future<List<SmsMessage>> getRecentMessages({int limit = 50}) async {
    if (!Platform.isAndroid) return [];

    final hasPermission = await hasSmsPermission();
    if (!hasPermission) return [];

    final telephony = _telephony ?? Telephony.instance;

    try {
      final messages = await telephony.getInboxSms(
        columns: [
          SmsColumn.ID,
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
        ],
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThan(
              DateTime.now()
                  .subtract(const Duration(days: 7))
                  .millisecondsSinceEpoch
                  .toString(),
            ),
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      return messages
          .take(limit)
          .map((msg) => SmsMessage(
                id: msg.id?.toString() ?? '',
                sender: msg.address ?? 'Unknown',
                body: msg.body ?? '',
                receivedAt: DateTime.fromMillisecondsSinceEpoch(
                  msg.date ?? DateTime.now().millisecondsSinceEpoch,
                ),
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching SMS messages: $e');
      return [];
    }
  }

  List<TodoSuggestion> analyzeSmsForSuggestions(
      List<SmsMessage> messages) {
    final suggestions = <TodoSuggestion>[];

    for (final message in messages) {
      if (message.body.isEmpty) continue;

      final analysis = _analyzeMessage(message);
      if (analysis != null) {
        suggestions.add(analysis);
      }
    }

    // Sort by confidence descending
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions;
  }

  TodoSuggestion? _analyzeMessage(SmsMessage message) {
    final body = message.body.toLowerCase();
    double confidence = 0.0;
    int matchCount = 0;

    for (final pattern in _actionPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      if (regex.hasMatch(body)) {
        matchCount++;
        confidence += 0.2;
      }
    }

    if (matchCount == 0) return null;

    // Cap confidence at 1.0
    confidence = confidence.clamp(0.0, 1.0);

    final title = _extractTitle(message.body);
    final deadline = _extractDeadline(message.body);

    final snippet = message.body.length > 80
        ? '${message.body.substring(0, 77)}...'
        : message.body;

    return TodoSuggestion(
      suggestedTitle: title,
      suggestedDescription: 'From: ${message.sender}\n\n"${message.body}"',
      suggestedDeadline: deadline,
      sourceMessageId: message.id,
      sourceMessageSnippet: snippet,
      confidence: confidence,
    );
  }

  String _extractTitle(String body) {
    // Try to find a clean action sentence
    final sentences = body.split(RegExp(r'[.!?]'));
    String bestSentence = body;
    int bestScore = 0;

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      int score = 0;
      for (final pattern in _actionPatterns) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(trimmed)) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestSentence = trimmed;
      }
    }

    // Clean up and capitalize
    String title = bestSentence
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Truncate if too long
    if (title.length > 60) {
      title = '${title.substring(0, 57)}...';
    }

    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }

    return title.isEmpty ? 'Follow up on message' : title;
  }

  DateTime? _extractDeadline(String body) {
    final lower = body.toLowerCase();

    if (RegExp(r'\btomorrow\b').hasMatch(lower)) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
    }

    if (RegExp(r'\btonight\b').hasMatch(lower)) {
      final today = DateTime.now();
      return DateTime(today.year, today.month, today.day, 20, 0);
    }

    // Check for day of week
    final days = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };

    for (final entry in days.entries) {
      if (lower.contains(entry.key)) {
        return _nextWeekday(entry.value);
      }
    }

    // Check for date pattern MM/DD or MM-DD
    final dateMatch =
        RegExp(r'\b([0-9]{1,2})[/-]([0-9]{1,2})\b').firstMatch(lower);
    if (dateMatch != null) {
      final month = int.tryParse(dateMatch.group(1) ?? '');
      final day = int.tryParse(dateMatch.group(2) ?? '');
      final now = DateTime.now();
      if (month != null && day != null && month >= 1 && month <= 12) {
        int year = now.year;
        final candidate = DateTime(year, month, day);
        if (candidate.isBefore(now)) {
          year++;
        }
        return DateTime(year, month, day, 9, 0);
      }
    }

    return null;
  }

  DateTime _nextWeekday(int targetWeekday) {
    final now = DateTime.now();
    int daysUntil = targetWeekday - now.weekday;
    if (daysUntil < 0) daysUntil += 7;
    final target = now.add(Duration(days: daysUntil));
    return DateTime(target.year, target.month, target.day, 9, 0);
  }
}
