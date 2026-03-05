import 'package:flutter/foundation.dart';
import '../models/sms_message.dart';
import '../services/sms_service.dart';

class SmsProvider extends ChangeNotifier {
  final SmsService _smsService;

  List<SmsMessage> _messages = [];
  List<TodoSuggestion> _suggestions = [];
  bool _hasPermission = false;
  bool _isLoading = false;
  String? _error;

  SmsProvider({required SmsService smsService})
      : _smsService = smsService;

  List<SmsMessage> get messages => List.unmodifiable(_messages);
  List<TodoSuggestion> get suggestions => List.unmodifiable(_suggestions);
  bool get hasPermission => _hasPermission;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSuggestions => _suggestions.isNotEmpty;

  Future<bool> requestPermission() async {
    _setLoading(true);
    final granted = await _smsService.requestSmsPermission();
    _hasPermission = granted;
    _setLoading(false);
    return granted;
  }

  Future<void> checkPermission() async {
    _hasPermission = await _smsService.hasSmsPermission();
    notifyListeners();
  }

  Future<void> loadAndAnalyzeMessages() async {
    _setLoading(true);
    _error = null;

    try {
      _messages = await _smsService.getRecentMessages(limit: 50);
      _suggestions = _smsService.analyzeSmsForSuggestions(_messages);
    } catch (e) {
      _error = 'Failed to analyze messages: $e';
    }

    _setLoading(false);
  }

  void dismissSuggestion(int index) {
    if (index >= 0 && index < _suggestions.length) {
      _suggestions.removeAt(index);
      notifyListeners();
    }
  }

  void clearAll() {
    _messages = [];
    _suggestions = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
