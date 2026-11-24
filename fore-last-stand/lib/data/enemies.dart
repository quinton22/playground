class EnemySpec {
  const EnemySpec({
    required this.id,
    required this.name,
    required this.health,
    required this.speed,
    required this.colorValue,
  });

  final String id;
  final String name;
  final double health;

  /// Walking speed in logical px/second.
  final double speed;
  final int colorValue;
}

const List<EnemySpec> enemies = [
  EnemySpec(id: 'goose', name: 'Goose', health: 10, speed: 90, colorValue: 0xFFEEEEEE),
  EnemySpec(id: 'gator', name: 'Gator', health: 40, speed: 40, colorValue: 0xFF2E7D32),
  EnemySpec(id: 'raccoon', name: 'Raccoon', health: 15, speed: 70, colorValue: 0xFF757575),
];
