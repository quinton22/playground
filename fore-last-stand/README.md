# Fore! Last Stand (working title)

One-thumb, portrait golf tower-defense. A virus has overrun the golf course with animals and you are the last person standing at the clubhouse. Swing real clubs at golf balls with your thumb while towers (placed only on the clubhouse grounds) back you up.

**Stack:** Flutter + [Flame](https://flame-engine.org). iOS and Android, portrait only.

## Status

Swing-feel prototype only: drag back from the tee, release to swing; geese, gators and raccoons walk toward the clubhouse. Clubs and enemies are plain data in `lib/data/` so new content needs no code changes.

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
