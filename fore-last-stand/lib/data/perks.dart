/// Mulligan-card perks drafted after each hole (spec 7). Plain data.
enum PerkRarity { common, rare, epic, legendary }

enum PerkSet { ballistics, groundskeeping, showman }

enum PerkEffect {
  extraBounce,
  extraPierce,
  ballDamage,
  swingCooldown,
  sweetSpotWidth,
  foreFanBalls,
  foreCharge,
  explosiveBalls,
  flamingBalls,
  frozenBalls,
  magneticBalls,
  bouncyBalls,
  rubberChicken,
  sprinklerHeal,
  towerFireRate,
  overchargeDuration,
  coinGain,
  clubhouseHealth,
  caddieCooldown,
  sweetSpotDamage,
}

class PerkSpec {
  const PerkSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.set,
    required this.effect,
    required this.value,
  });

  final String id;
  final String name;
  final String description;
  final PerkRarity rarity;
  final PerkSet set;
  final PerkEffect effect;
  final double value;
}

/// Drafting weight per rarity.
const Map<PerkRarity, int> rarityWeight = {
  PerkRarity.common: 10,
  PerkRarity.rare: 5,
  PerkRarity.epic: 2,
  PerkRarity.legendary: 1,
};

/// Holding this many perks from one set grants the set bonus (+15% ball damage).
const int perkSetSize = 3;

const List<PerkSpec> perks = [
  PerkSpec(id: 'extra_bounce', name: 'Extra Bounce', description: 'Balls bounce one extra time.', rarity: PerkRarity.common, set: PerkSet.ballistics, effect: PerkEffect.extraBounce, value: 1),
  PerkSpec(id: 'piercing', name: 'Piercing Shot', description: 'Balls pierce one more enemy.', rarity: PerkRarity.common, set: PerkSet.ballistics, effect: PerkEffect.extraPierce, value: 1),
  PerkSpec(id: 'heavy', name: 'Heavy Balls', description: '+20% ball damage.', rarity: PerkRarity.common, set: PerkSet.ballistics, effect: PerkEffect.ballDamage, value: 0.2),
  PerkSpec(id: 'quick_hands', name: 'Quick Hands', description: '15% shorter swing cooldown.', rarity: PerkRarity.common, set: PerkSet.showman, effect: PerkEffect.swingCooldown, value: 0.15),
  PerkSpec(id: 'wide_sweet', name: 'Wide Sweet Spot', description: 'Sweet Spot zone is 50% wider.', rarity: PerkRarity.common, set: PerkSet.showman, effect: PerkEffect.sweetSpotWidth, value: 0.5),
  PerkSpec(id: 'fore_fan', name: 'Fore! Fan', description: 'Fore! bursts fire 2 more balls per volley.', rarity: PerkRarity.rare, set: PerkSet.showman, effect: PerkEffect.foreFanBalls, value: 2),
  PerkSpec(id: 'meter_maven', name: 'Meter Maven', description: 'Fore! meter charges 30% faster.', rarity: PerkRarity.common, set: PerkSet.showman, effect: PerkEffect.foreCharge, value: 0.3),
  PerkSpec(id: 'explosive', name: 'Explosive Balls', description: 'Hits explode for 40% splash damage.', rarity: PerkRarity.rare, set: PerkSet.ballistics, effect: PerkEffect.explosiveBalls, value: 0.4),
  PerkSpec(id: 'flaming', name: 'Flaming Balls', description: 'Hits set enemies on fire (4 dmg/s for 3 s).', rarity: PerkRarity.rare, set: PerkSet.ballistics, effect: PerkEffect.flamingBalls, value: 4),
  PerkSpec(id: 'frozen', name: 'Frozen Balls', description: 'Hits slow enemies by 40% for 2 s.', rarity: PerkRarity.rare, set: PerkSet.groundskeeping, effect: PerkEffect.frozenBalls, value: 0.4),
  PerkSpec(id: 'magnetic', name: 'Magnetic Balls', description: 'Balls curve gently toward enemies.', rarity: PerkRarity.epic, set: PerkSet.ballistics, effect: PerkEffect.magneticBalls, value: 2.5),
  PerkSpec(id: 'bouncy', name: 'Bouncy Balls', description: '+2 bounces, but 10% less damage.', rarity: PerkRarity.rare, set: PerkSet.ballistics, effect: PerkEffect.bouncyBalls, value: 2),
  PerkSpec(id: 'rubber_chicken', name: 'Rubber Chicken', description: 'Hits knock enemies back. Squeak.', rarity: PerkRarity.legendary, set: PerkSet.showman, effect: PerkEffect.rubberChicken, value: 40),
  PerkSpec(id: 'sprinkler_heal', name: 'Sprinklers Also Heal', description: 'Each Sprinkler heals the clubhouse 1 HP/s.', rarity: PerkRarity.rare, set: PerkSet.groundskeeping, effect: PerkEffect.sprinklerHeal, value: 1),
  PerkSpec(id: 'overclocked', name: 'Overclocked Towers', description: 'Towers fire 20% faster.', rarity: PerkRarity.common, set: PerkSet.groundskeeping, effect: PerkEffect.towerFireRate, value: 0.2),
  PerkSpec(id: 'long_tag', name: 'Long Tag', description: 'Tower overcharge lasts 2 s longer.', rarity: PerkRarity.common, set: PerkSet.groundskeeping, effect: PerkEffect.overchargeDuration, value: 2),
  PerkSpec(id: 'deep_pockets', name: 'Deep Pockets', description: '+25% coins from kills.', rarity: PerkRarity.common, set: PerkSet.groundskeeping, effect: PerkEffect.coinGain, value: 0.25),
  PerkSpec(id: 'groundskeeper', name: 'Groundskeeper', description: 'Clubhouse +25 max HP and a full repair.', rarity: PerkRarity.rare, set: PerkSet.groundskeeping, effect: PerkEffect.clubhouseHealth, value: 25),
  PerkSpec(id: 'ace_caddie', name: 'Ace Caddie', description: 'Caddie ability recharges 30% faster.', rarity: PerkRarity.epic, set: PerkSet.showman, effect: PerkEffect.caddieCooldown, value: 0.3),
  PerkSpec(id: 'hole_in_one', name: 'Hole-in-One', description: 'Sweet Spot hits deal another +50% damage.', rarity: PerkRarity.legendary, set: PerkSet.showman, effect: PerkEffect.sweetSpotDamage, value: 0.5),
];

PerkSpec perkById(String id) => perks.firstWhere((p) => p.id == id);
