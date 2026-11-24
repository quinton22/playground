# Fore! Last Stand (working title)

One-thumb, portrait golf tower-defense. A virus has overrun the golf course with animals and you are the last person standing at the clubhouse. Swing real clubs at golf balls with your thumb while towers (placed only on the clubhouse grounds) back you up.

**Stack:** Flutter (3.47+, uses `material_ui`) + [Flame](https://flame-engine.org). iOS and Android, portrait only.

## Status

Playable MVP of the [feature spec](https://claude.ai/code/artifact/f2b2c67e-0ef5-49d5-abc2-055c1d0f03cb) (section 12 scope). Shapes stand in for art and text for the commentator's voice.

**In the build**

- **Swing:** drag back anywhere, release on the timing ring's green zone for a Sweet Spot (+50% damage, +1 pierce, screen shake). Dotted preview of the first wall bounce, ~0.8 s cooldown, aim-assist slider.
- **Depth:** ricochets off walls, enemies and your own towers (a tagged tower overcharges), combo ladder Bogey → Albatross (coin multiplier, Fore! meter), 3-second Fore! barrage.
- **Clubs:** Driver (pierce 3), Iron (2 bounces), Wedge (lob + blast), Putter (ground roll, unlocked in the Bag). 3-club bag, tap to swap.
- **Towers (6):** Range Ball Machine, Sprinkler, Tee-Tesla, Lawnmower Ripper, Cart Cannon, Caddie Sniper on a 4x4 plot grid (5x5/6x6 via Clubhouse). Build between holes, or live at double cost with 2 s slow-mo. Sell for 70%, free re-placement in the first 10 s. Sprinkler + Tee-Tesla pair bonus; 3 tower levels.
- **Enemies (8) + boss:** Goose (honk stuns towers), Gator (surfaces from water), Raccoon (steals coins), Crow (flier, dives towers), Boar (charges, ignores slows), Squirrel Bomber, Skunk (gas disables towers), Coyote Pack (leader buffs pups), Goose King boss (summons flocks).
- **Holes:** Suburban Muni, 9 holes with par times, breathers on 3 and 6, boss on 9. Clubhouse has 3 flags; a fallen flag repairs 30% and grows swarms.
- **Modes:** Quick Round (5 holes, mini-boss), Full Round (9 holes), Sudden Death (endless, one flag), Daily Tournament (date seed + daily modifier, local best score).
- **Run layer:** 20 Mulligan-card perks in 4 rarities and 3 sets (set bonus), 1 of 3 draft after every hole, one free reroll.
- **Caddies (2):** Big Earl (Fore! +40%, Big Drive), Dottie (+20% vs bosses, Mark & Snipe). First caddie free after the first round.
- **Meta (saved locally):** coins, Club Tokens, XP; club levels 1-20 with traits; Clubhouse upgrades (grid, starting coins, walls); bestiary; "three nearest unlocks" on results and home. Clubhouse unlocks after 2 rounds, Bag after 3.
- **First-time experience:** first round is scripted with hints; hidden adaptive difficulty (about 10% fewer enemies after 2 losses in a row).
- **Settings:** aim assist, Auto-Caddie (swings for you at 60% damage), left-handed layout, screen shake, Gore (Full Splat / Classic / Squeaky Clean).

**Not built yet** (needs a backend, store setup or art): rewarded ads, IAP, Season Pass, Gems shop, leaderboards, Weekly Invitational, notifications, share clips, voiced commentary, Tour Ranks/prestige, other courses, mid-run save, real art and audio.

## Code layout

| Path | What |
|---|---|
| `lib/data/` | All content as plain data: clubs, enemies, towers, perks, caddies, courses/holes, modes, commentary |
| `lib/sim/` | Pure-Dart simulation (`Battle`), wave scheduling, combo, swing math. No Flame imports, fully unit-tested |
| `lib/game/fore_game.dart` | Flame game: runs the sim loop and draws it |
| `lib/meta/` | Profile, persistence (`shared_preferences`), rewards and upgrade rules |
| `lib/ui/` | Flutter screens: home, run HUD/draft/build sheet, results, Bag, Clubhouse, Caddies, Bestiary, Settings |

New content is usually a data entry: add an enemy to `enemies.dart` and reference it from a hole in `courses.dart`.

## Design summary

- **Pillars:** every swing matters; the base is the fortress; quirky carnage; one more hole.
- **Loop:** moment (2-10 s) → hole/wave (30-90 s) → round (3-15 min) → meta (clubs, caddies, clubhouse).
- **Swing:** drag back to aim/power, release on the timing ring for a Sweet Spot (+50% damage); ~0.8 s cooldown; Fore! burst when the meter is full.
- **Clubs:** Driver (pierce), Iron (bounces), Wedge (blast), Putter (ground roll).
- **Towers:** on a 4x4 plot grid around the clubhouse (grows to 6x6); pairs unlock bonuses.
- **Modes:** Quick Round, Full Round, Sudden Death, Daily Tournament, Weekly Invitational.
- **Meta:** club/tower levels, caddies, clubhouse wings, bestiary, Tour Rank prestige.
- **Monetization:** F2P, opt-in rewarded ads, cosmetic-first IAP, no interstitials during a run.
- **MVP:** 1 course (9 holes), 6 towers, 8 enemies, 1 boss, 3 clubs, 2 caddies, 20 perks, Quick Round + Sudden Death.

## Develop

Platform folders (`android/`, `ios/`) are not committed; generate them once:

```sh
flutter create --platforms=android,ios --project-name fore_last_stand --org com.playground .
flutter pub get
flutter analyze
flutter test
flutter run
```

## CI build

`.github/workflows/fore-last-stand-build.yml` (at the repo root, as GitHub requires) runs analyze + test + build. Trigger it from the **Actions** tab → *fore-last-stand build* → *Run workflow*, choosing `apk`, `appbundle` or `ios`. It also runs automatically when a PR that touches `fore-last-stand/` is merged to `main`; open PRs don't trigger it. Android outputs are uploaded as artifacts; iOS is built with `--no-codesign`.
