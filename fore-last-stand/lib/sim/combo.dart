/// Combo ladder (spec 3): each hit without a miss climbs the rungs.
class ComboLadder {
  static const List<String> rungNames = ['Bogey', 'Par', 'Birdie', 'Eagle', 'Albatross'];
  static const List<int> thresholds = [0, 3, 6, 10, 15];
  static const List<double> coinMultipliers = [1, 1.25, 1.5, 2, 3];

  int hits = 0;
  int bestRung = 0;

  int get rung {
    var r = 0;
    for (var i = 0; i < thresholds.length; i++) {
      if (hits >= thresholds[i]) r = i;
    }
    return r;
  }

  String get name => rungNames[rung];
  double get coinMultiplier => coinMultipliers[rung];

  /// Fore! meter charge (out of 100) for one hit at the current rung.
  double get foreCharge => 4.0 * (rung + 1);

  /// Records a hit; returns true if this hit climbed to a new rung.
  bool hit() {
    final before = rung;
    hits++;
    if (rung > bestRung) bestRung = rung;
    return rung > before;
  }

  void miss() => hits = 0;
}
