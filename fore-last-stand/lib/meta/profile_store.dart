import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

/// Holds the profile, notifies the UI and persists it to local storage.
class ProfileStore extends ChangeNotifier {
  ProfileStore(this.profile, [this._prefs]);

  static const _key = 'fore_profile_v1';

  Profile profile;
  final SharedPreferences? _prefs;

  static Future<ProfileStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    var profile = Profile();
    if (raw != null) {
      try {
        profile = Profile.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      } catch (_) {
        // Corrupt save: start fresh rather than crash.
      }
    }
    return ProfileStore(profile, prefs);
  }

  /// Runs [change] on the profile, saves and notifies. Returns what [change] returned.
  T update<T>(T Function(Profile p) change) {
    final out = change(profile);
    save();
    notifyListeners();
    return out;
  }

  Future<void> save() async => _prefs?.setString(_key, jsonEncode(profile.toJson()));
}
