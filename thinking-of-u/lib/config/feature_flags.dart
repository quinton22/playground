/// Feature flags for optional features.
/// Set to `true` to enable, `false` to disable.
abstract class FeatureFlags {
  /// Show a history screen with past matches.
  static const bool enableHistoryScreen = true;

  /// Enable streak tracking (consecutive days of matches).
  static const bool enableStreakTracking = true;

  /// Enable social sharing / invite friends feature.
  static const bool enableSocialSharing = false;

  /// Enable "lucky guess" — randomly reveal one anonymous match hint per day.
  static const bool enableLuckyGuess = false;

  /// Enable detailed analytics tracking.
  static const bool enableAnalytics = true;

  /// Enable in-app purchases.
  static const bool enableInAppPurchases = true;

  /// Maximum number of "thinking of u" sends per day (with no purchases).
  static const int defaultDailyLimit = 3;

  /// Maximum number of "thinking of u" sends per day (absolute cap, even with purchases).
  static const int maxDailyLimit = 10;

  /// Default extension window (in hours) before daily reset.
  /// If a user buys an extension, this is added to the reset time.
  static const int extensionHours = 24;

  /// Maximum number of extension days a user can accumulate.
  static const int maxExtensionDays = 7;
}
