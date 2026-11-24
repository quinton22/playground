/// Towers are plain data; behaviour is picked by [TowerKind].
enum TowerKind { ballMachine, sprinkler, teeTesla, ripper, cartCannon, sniper }

class TowerSpec {
  const TowerSpec({
    required this.id,
    required this.name,
    required this.kind,
    required this.cost,
    required this.range,
    required this.damage,
    required this.fireInterval,
    required this.health,
    required this.colorValue,
    required this.role,
    required this.synergy,
    required this.badge,
    this.hitsFliers = true,
  });

  final String id;
  final String name;
  final TowerKind kind;

  /// Coins to place at level 1. Each upgrade costs the same again times the next level.
  final int cost;
  final double range;
  final double damage;

  /// Seconds between shots (0 = continuous aura, damage is per second).
  final double fireInterval;
  final double health;
  final int colorValue;
  final String role;
  final String synergy;

  /// Two-letter label drawn on the tower until real art exists.
  final String badge;
  final bool hitsFliers;
}

const int maxTowerLevel = 3;

/// Spec 4: selling refunds 70%.
const double sellRefund = 0.7;

/// Spec 4: placing during a hole costs double (with a 2 s slow-mo).
const double livePlacementMultiplier = 2;

const List<TowerSpec> towers = [
  TowerSpec(
    id: 'ball_machine',
    badge: 'RB',
    name: 'Range Ball Machine',
    kind: TowerKind.ballMachine,
    cost: 30,
    range: 170,
    damage: 3,
    fireInterval: 0.3,
    health: 40,
    colorValue: 0xFF1E88E5,
    role: 'Rapid weak fire',
    synergy: 'Hit it to overcharge for 3 s',
  ),
  TowerSpec(
    id: 'sprinkler',
    badge: 'SP',
    name: 'Sprinkler Turret',
    kind: TowerKind.sprinkler,
    cost: 35,
    range: 90,
    damage: 1.5,
    fireInterval: 0,
    health: 40,
    colorValue: 0xFF4FC3F7,
    role: 'Soaks and slows',
    synergy: 'Wet enemies take +50% lightning damage',
    hitsFliers: false,
  ),
  TowerSpec(
    id: 'tee_tesla',
    badge: 'TT',
    name: 'Tee-Tesla',
    kind: TowerKind.teeTesla,
    cost: 50,
    range: 140,
    damage: 8,
    fireInterval: 1.2,
    health: 40,
    colorValue: 0xFFFFEB3B,
    role: 'Chain lightning',
    synergy: 'Pairs with Sprinkler for a chain bonus',
  ),
  TowerSpec(
    id: 'ripper',
    badge: 'LR',
    name: 'Lawnmower Ripper',
    kind: TowerKind.ripper,
    cost: 40,
    range: 55,
    damage: 7,
    fireInterval: 0,
    health: 70,
    colorValue: 0xFFE53935,
    role: 'Spinning blades guard the base edge',
    synergy: 'Ball hits spin it faster',
    hitsFliers: false,
  ),
  TowerSpec(
    id: 'cart_cannon',
    badge: 'CC',
    name: 'Cart Cannon',
    kind: TowerKind.cartCannon,
    cost: 60,
    range: 230,
    damage: 22,
    fireInterval: 2.5,
    health: 50,
    colorValue: 0xFF8E24AA,
    role: 'Slow, heavy splash',
    synergy: 'Sweet Spot balls reload it instantly',
    hitsFliers: false,
  ),
  TowerSpec(
    id: 'sniper',
    badge: 'CS',
    name: 'Caddie Sniper',
    kind: TowerKind.sniper,
    cost: 55,
    range: 520,
    damage: 26,
    fireInterval: 2.0,
    health: 35,
    colorValue: 0xFF43A047,
    role: 'Single target, long range',
    synergy: 'Marks bosses for extra damage',
  ),
];

TowerSpec towerById(String id) => towers.firstWhere((t) => t.id == id);

/// Coins to go from [level] to level + 1.
int upgradeCost(TowerSpec spec, int level) => (spec.cost * 0.75 * level).round();

/// Damage/strength multiplier at a tower level (1-based).
double towerLevelMultiplier(int level) => 1 + 0.4 * (level - 1);
