/// Enemies are plain data; behaviour is picked by [EnemyAbility].
enum EnemyAbility {
  none,

  /// Honk stuns nearby towers.
  honk,

  /// Steals coins on reaching the base, then runs off.
  thief,

  /// Flies (only Driver/Iron balls and some towers can hit it) and dives at towers.
  diveTowers,

  /// Charges in a straight line and ignores slows.
  charge,

  /// Explodes on towers.
  bomber,

  /// Releases a gas cloud that disables towers.
  gas,

  /// Pack leader: buffs nearby pack members while alive.
  packLeader,

  /// Pack member.
  pack,

  /// Boss: periodically summons geese.
  summonFlock,
}

enum EnemyShape { circle, square, triangle, diamond }

class EnemySpec {
  const EnemySpec({
    required this.id,
    required this.name,
    required this.health,
    required this.speed,
    required this.colorValue,
    required this.coins,
    required this.baseDamage,
    this.radius = 13,
    this.ability = EnemyAbility.none,
    this.shape = EnemyShape.circle,
    this.flier = false,
    this.boss = false,
    this.behavior = '',
    this.counter = '',
  });

  final String id;
  final String name;
  final double health;

  /// Walking speed in world units/second.
  final double speed;
  final int colorValue;

  /// Coins dropped on kill.
  final int coins;

  /// Damage dealt to the clubhouse on arrival.
  final double baseDamage;
  final double radius;
  final EnemyAbility ability;
  final EnemyShape shape;
  final bool flier;
  final bool boss;
  final String behavior;
  final String counter;
}

const List<EnemySpec> enemies = [
  EnemySpec(
    id: 'goose',
    name: 'Goose',
    health: 10,
    speed: 72,
    colorValue: 0xFFEEEEEE,
    coins: 3,
    baseDamage: 8,
    radius: 11,
    ability: EnemyAbility.honk,
    behavior: 'Fast, honk stuns nearby towers for 2 s',
    counter: 'Driver, kill early',
  ),
  EnemySpec(
    id: 'gator',
    name: 'Gator',
    health: 48,
    speed: 24,
    colorValue: 0xFF2E7D32,
    coins: 8,
    baseDamage: 22,
    radius: 16,
    shape: EnemyShape.square,
    behavior: 'Slow tank that surfaces from water hazards',
    counter: 'Wedge, Cart Cannon',
  ),
  EnemySpec(
    id: 'raccoon',
    name: 'Raccoon',
    health: 14,
    speed: 56,
    colorValue: 0xFF757575,
    coins: 5,
    baseDamage: 4,
    ability: EnemyAbility.thief,
    behavior: 'Steals coins and runs off if not killed',
    counter: 'Putter, Sniper',
  ),
  EnemySpec(
    id: 'crow',
    name: 'Crow',
    health: 8,
    speed: 82,
    colorValue: 0xFF263238,
    coins: 3,
    baseDamage: 6,
    radius: 10,
    ability: EnemyAbility.diveTowers,
    shape: EnemyShape.triangle,
    flier: true,
    behavior: 'Flier that dives at towers',
    counter: 'Driver, Tee-Tesla',
  ),
  EnemySpec(
    id: 'boar',
    name: 'Boar',
    health: 32,
    speed: 42,
    colorValue: 0xFF6D4C41,
    coins: 6,
    baseDamage: 18,
    radius: 15,
    ability: EnemyAbility.charge,
    shape: EnemyShape.square,
    behavior: 'Charges in a straight line, ignores slows',
    counter: 'Sand Trap, Ripper',
  ),
  EnemySpec(
    id: 'squirrel',
    name: 'Squirrel Bomber',
    health: 12,
    speed: 60,
    colorValue: 0xFFE65100,
    coins: 4,
    baseDamage: 10,
    radius: 10,
    ability: EnemyAbility.bomber,
    shape: EnemyShape.diamond,
    behavior: 'Explodes on towers',
    counter: 'Kill at range, Iron',
  ),
  EnemySpec(
    id: 'skunk',
    name: 'Skunk',
    health: 22,
    speed: 38,
    colorValue: 0xFF212121,
    coins: 6,
    baseDamage: 10,
    ability: EnemyAbility.gas,
    behavior: 'Gas cloud disables towers in an area',
    counter: 'Burst from range, then reposition',
  ),
  EnemySpec(
    id: 'coyote',
    name: 'Coyote Pack',
    health: 32,
    speed: 58,
    colorValue: 0xFFBCAAA4,
    coins: 7,
    baseDamage: 12,
    radius: 14,
    ability: EnemyAbility.packLeader,
    shape: EnemyShape.triangle,
    behavior: 'Buffs allies while the leader lives',
    counter: 'Sniper marks the leader',
  ),
  // Spawned with a coyote leader, not on its own.
  EnemySpec(
    id: 'coyote_pup',
    name: 'Coyote',
    health: 14,
    speed: 58,
    colorValue: 0xFFD7CCC8,
    coins: 2,
    baseDamage: 6,
    radius: 10,
    ability: EnemyAbility.pack,
    shape: EnemyShape.triangle,
  ),
];

const List<EnemySpec> bosses = [
  EnemySpec(
    id: 'goose_king',
    name: 'Goose King',
    health: 520,
    speed: 16,
    colorValue: 0xFFFFD54F,
    coins: 80,
    baseDamage: 60,
    radius: 30,
    ability: EnemyAbility.summonFlock,
    boss: true,
    behavior: 'Summons flocks of geese',
    counter: 'Sniper marks, Fore! burst',
  ),
];

final Map<String, EnemySpec> _byId = {for (final e in [...enemies, ...bosses]) e.id: e};

EnemySpec enemyById(String id) => _byId[id]!;

/// Enemies shown in the bestiary (pups are part of the Coyote Pack entry).
List<EnemySpec> get bestiaryEntries =>
    [...enemies.where((e) => e.ability != EnemyAbility.pack), ...bosses];
