import '../data/clubs.dart';

enum GoreLevel { fullSplat, classic, squeakyClean }

/// Player settings (spec 3 accessibility, spec 11 gore and feel).
class Settings {
  Settings({
    this.aimAssist = 0.3,
    this.autoCaddie = false,
    this.leftHanded = false,
    this.gore = GoreLevel.classic,
    this.screenShake = true,
  });

  double aimAssist;
  bool autoCaddie;
  bool leftHanded;
  GoreLevel gore;
  bool screenShake;

  Map<String, Object?> toJson() => {
        'aimAssist': aimAssist,
        'autoCaddie': autoCaddie,
        'leftHanded': leftHanded,
        'gore': gore.name,
        'screenShake': screenShake,
      };

  factory Settings.fromJson(Map<String, Object?> j) => Settings(
        aimAssist: (j['aimAssist'] as num?)?.toDouble() ?? 0.3,
        autoCaddie: j['autoCaddie'] as bool? ?? false,
        leftHanded: j['leftHanded'] as bool? ?? false,
        gore: GoreLevel.values.firstWhere((g) => g.name == j['gore'], orElse: () => GoreLevel.classic),
        screenShake: j['screenShake'] as bool? ?? true,
      );
}

/// Everything that persists between runs (spec 7).
class Profile {
  Profile({
    this.coins = 0,
    this.clubTokens = 0,
    this.gems = 0,
    this.xp = 0,
    this.runsPlayed = 0,
    this.lossStreak = 0,
    this.bestSuddenDeath = 0,
    this.lastDailySeed = 0,
    this.bestDailyScore = 0,
    List<String>? unlockedClubs,
    List<String>? bag,
    Map<String, int>? clubLevels,
    Map<String, int>? clubhouse,
    List<String>? caddiesUnlocked,
    this.equippedCaddie,
    Map<String, int>? bestiary,
    Settings? settings,
  })  : unlockedClubs = unlockedClubs ?? List.of(starterBag),
        bag = bag ?? List.of(starterBag),
        clubLevels = clubLevels ?? {},
        clubhouse = clubhouse ?? {},
        caddiesUnlocked = caddiesUnlocked ?? [],
        bestiary = bestiary ?? {},
        settings = settings ?? Settings();

  int coins;
  int clubTokens;
  int gems;
  int xp;
  int runsPlayed;
  int lossStreak;
  int bestSuddenDeath;
  int lastDailySeed;
  int bestDailyScore;
  List<String> unlockedClubs;

  /// Equipped 3-club bag.
  List<String> bag;
  Map<String, int> clubLevels;

  /// Clubhouse upgrade id -> level.
  Map<String, int> clubhouse;
  List<String> caddiesUnlocked;
  String? equippedCaddie;

  /// Enemy id -> kills.
  Map<String, int> bestiary;
  Settings settings;

  int clubLevel(String id) => clubLevels[id] ?? 1;
  int clubhouseLevel(String id) => clubhouse[id] ?? 0;

  /// Spec 10: meta systems unlock gradually.
  bool get clubhouseUnlocked => runsPlayed >= 2;
  bool get bagUnlocked => runsPlayed >= 3;
  bool get firstRun => runsPlayed == 0;

  Map<String, Object?> toJson() => {
        'v': 1,
        'coins': coins,
        'clubTokens': clubTokens,
        'gems': gems,
        'xp': xp,
        'runsPlayed': runsPlayed,
        'lossStreak': lossStreak,
        'bestSuddenDeath': bestSuddenDeath,
        'lastDailySeed': lastDailySeed,
        'bestDailyScore': bestDailyScore,
        'unlockedClubs': unlockedClubs,
        'bag': bag,
        'clubLevels': clubLevels,
        'clubhouse': clubhouse,
        'caddiesUnlocked': caddiesUnlocked,
        'equippedCaddie': equippedCaddie,
        'bestiary': bestiary,
        'settings': settings.toJson(),
      };

  factory Profile.fromJson(Map<String, Object?> j) {
    Map<String, int> ints(Object? o) => (o as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {};
    List<String> strs(Object? o) => (o as List?)?.cast<String>().toList() ?? [];
    final p = Profile(
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      clubTokens: (j['clubTokens'] as num?)?.toInt() ?? 0,
      gems: (j['gems'] as num?)?.toInt() ?? 0,
      xp: (j['xp'] as num?)?.toInt() ?? 0,
      runsPlayed: (j['runsPlayed'] as num?)?.toInt() ?? 0,
      lossStreak: (j['lossStreak'] as num?)?.toInt() ?? 0,
      bestSuddenDeath: (j['bestSuddenDeath'] as num?)?.toInt() ?? 0,
      lastDailySeed: (j['lastDailySeed'] as num?)?.toInt() ?? 0,
      bestDailyScore: (j['bestDailyScore'] as num?)?.toInt() ?? 0,
      unlockedClubs: j['unlockedClubs'] == null ? null : strs(j['unlockedClubs']),
      bag: j['bag'] == null ? null : strs(j['bag']),
      clubLevels: ints(j['clubLevels']),
      clubhouse: ints(j['clubhouse']),
      caddiesUnlocked: strs(j['caddiesUnlocked']),
      equippedCaddie: j['equippedCaddie'] as String?,
      bestiary: ints(j['bestiary']),
      settings: j['settings'] == null ? null : Settings.fromJson((j['settings'] as Map).cast<String, Object?>()),
    );
    // Drop anything that no longer exists in data.
    final known = clubs.map((c) => c.id).toSet();
    p.unlockedClubs.retainWhere(known.contains);
    p.bag.retainWhere(p.unlockedClubs.contains);
    if (p.bag.isEmpty) p.bag = List.of(starterBag);
    return p;
  }
}
