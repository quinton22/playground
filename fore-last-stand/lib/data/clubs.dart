/// Clubs are plain data (spec 7a: "every club... is a data file, not code").
class ClubSpec {
  const ClubSpec({
    required this.id,
    required this.name,
    required this.speed,
    required this.damage,
    required this.pierce,
    required this.bounces,
  });

  final String id;
  final String name;

  /// Ball speed in logical px/second at full power.
  final double speed;
  final double damage;

  /// Enemies a ball can pass through before it stops.
  final int pierce;
  final int bounces;
}

const List<ClubSpec> clubs = [
  ClubSpec(id: 'driver', name: 'Driver', speed: 900, damage: 10, pierce: 3, bounces: 0),
  ClubSpec(id: 'iron', name: 'Iron', speed: 700, damage: 12, pierce: 1, bounces: 2),
  ClubSpec(id: 'wedge', name: 'Wedge', speed: 550, damage: 18, pierce: 0, bounces: 0),
  ClubSpec(id: 'putter', name: 'Putter', speed: 350, damage: 8, pierce: 5, bounces: 0),
];
