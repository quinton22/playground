/// Clubs are plain data (spec 7a: "every club... is a data file, not code").
enum ClubKind {
  /// Fast and straight, pierces.
  driver,

  /// Medium speed, bounces.
  iron,

  /// Lob that ignores everything in flight and lands as a blast.
  wedge,

  /// Slow ground roll that bowls through; cannot hit fliers.
  putter,
}

class ClubSpec {
  const ClubSpec({
    required this.id,
    required this.name,
    required this.kind,
    required this.speed,
    required this.damage,
    required this.pierce,
    required this.bounces,
    this.blastRadius = 0,
    this.bestAgainst = '',
    this.unlockTokens = 0,
  });

  final String id;
  final String name;
  final ClubKind kind;

  /// Ball speed in world units/second at full power.
  final double speed;
  final double damage;

  /// Enemies a ball can pass through before it stops.
  final int pierce;

  /// Ricochets (walls, towers, enemies) before the ball is spent.
  final int bounces;

  /// Wedge landing blast radius (world units).
  final double blastRadius;
  final String bestAgainst;

  /// Club Tokens needed to unlock in the Bag; 0 = starter club.
  final int unlockTokens;

  bool get canHitFliers => kind == ClubKind.driver || kind == ClubKind.iron;
}

const List<ClubSpec> clubs = [
  ClubSpec(
    id: 'driver',
    name: 'Driver',
    kind: ClubKind.driver,
    speed: 900,
    damage: 10,
    pierce: 3,
    bounces: 0,
    bestAgainst: 'Lines of enemies, fliers',
  ),
  ClubSpec(
    id: 'iron',
    name: 'Iron',
    kind: ClubKind.iron,
    speed: 700,
    damage: 12,
    pierce: 0,
    bounces: 2,
    bestAgainst: 'Mixed crowds',
  ),
  ClubSpec(
    id: 'wedge',
    name: 'Wedge',
    kind: ClubKind.wedge,
    speed: 520,
    damage: 16,
    pierce: 0,
    bounces: 0,
    blastRadius: 48,
    bestAgainst: 'Tanks, clusters',
  ),
  ClubSpec(
    id: 'putter',
    name: 'Putter',
    kind: ClubKind.putter,
    speed: 380,
    damage: 8,
    pierce: 5,
    bounces: 1,
    bestAgainst: 'Swarms, fast ground units',
    unlockTokens: 60,
  ),
];

ClubSpec clubById(String id) => clubs.firstWhere((c) => c.id == id);

/// The starting 3-club bag.
const List<String> starterBag = ['driver', 'iron', 'wedge'];
