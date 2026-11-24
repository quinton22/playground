/// Caddies (heroes): one passive and one active ability each (spec 7). Plain data.
enum CaddiePassive { foreBurstDamage, bossDamage }

enum CaddieActive {
  /// Fires a huge piercing ball straight up the middle.
  bigDrive,

  /// Snipes and marks the toughest enemy on screen.
  markAndSnipe,
}

class CaddieSpec {
  const CaddieSpec({
    required this.id,
    required this.name,
    required this.passive,
    required this.passiveValue,
    required this.passiveText,
    required this.active,
    required this.activeName,
    required this.activeText,
    required this.cooldown,
    required this.activePower,
    required this.unlockCoins,
    required this.colorValue,
  });

  final String id;
  final String name;
  final CaddiePassive passive;
  final double passiveValue;
  final String passiveText;
  final CaddieActive active;
  final String activeName;
  final String activeText;

  /// Seconds between uses of the active ability.
  final double cooldown;
  final double activePower;

  /// Meta coins to unlock; 0 = granted by the first-time experience.
  final int unlockCoins;
  final int colorValue;
}

const List<CaddieSpec> caddies = [
  CaddieSpec(
    id: 'big_earl',
    name: 'Big Earl',
    passive: CaddiePassive.foreBurstDamage,
    passiveValue: 0.4,
    passiveText: 'Fore! bursts hit 40% harder.',
    active: CaddieActive.bigDrive,
    activeName: 'Big Drive',
    activeText: 'Smashes a giant ball up the middle that pierces everything.',
    cooldown: 25,
    activePower: 40,
    unlockCoins: 0,
    colorValue: 0xFFFF7043,
  ),
  CaddieSpec(
    id: 'dottie',
    name: 'Dottie',
    passive: CaddiePassive.bossDamage,
    passiveValue: 0.2,
    passiveText: 'Bosses take 20% more damage from everything.',
    active: CaddieActive.markAndSnipe,
    activeName: 'Mark & Snipe',
    activeText: 'Shoots the toughest enemy for 60 damage and marks it.',
    cooldown: 20,
    activePower: 60,
    unlockCoins: 400,
    colorValue: 0xFF7E57C2,
  ),
];

CaddieSpec caddieById(String id) => caddies.firstWhere((c) => c.id == id);
