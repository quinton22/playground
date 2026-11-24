/// Hushed golf-broadcast commentary (spec 11), keyed by game event.
enum CommentEvent {
  holeStart,
  firstKill,
  sweetSpot,
  combo,
  foreBurst,
  towerTag,
  bossArrives,
  flagLost,
  holeUnderPar,
  holeClear,
  coinsStolen,
  runWon,
  runLost,
}

const Map<CommentEvent, List<String>> commentary = {
  CommentEvent.holeStart: [
    'A hush falls over the gallery.',
    'Conditions look... feathery.',
    'The course is in rough shape today.',
    'Here they come, right on the tee time.',
  ],
  CommentEvent.firstKill: [
    'And the goose is in the bunker... that\'s a tough lie.',
    'First blood. Lovely tempo.',
    'That one won\'t be making the cut.',
  ],
  CommentEvent.sweetSpot: [
    'Oh, pure. Right off the sweet spot.',
    'You could hear that one in the parking lot.',
    'Textbook strike.',
    'Flushed it.',
    'That is a tour-quality contact.',
  ],
  CommentEvent.combo: [
    'Birdie run continues!',
    'The crowd is on its feet. Quietly.',
    'Eagle! Eagle! ...sorry, I meant the score.',
    'An Albatross. I may need a moment.',
  ],
  CommentEvent.foreBurst: [
    'FORE! Everybody duck.',
    'That\'s not in the rule book, but it\'s working.',
    'A barrage from the tee box!',
  ],
  CommentEvent.towerTag: [
    'Off the machine and into the rough! Overcharged!',
    'Bank shot off the tower. Bold.',
    'Using the infrastructure. Smart golf.',
  ],
  CommentEvent.bossArrives: [
    'Ladies and gentlemen... the Goose King.',
    'Something large is honking on the back nine.',
  ],
  CommentEvent.flagLost: [
    'A flag has fallen. That will sting.',
    'They\'re through to the clubhouse. Repairs underway.',
  ],
  CommentEvent.holeUnderPar: [
    'Under par! Bonus coins for the pro.',
    'Ahead of the pace. Very tidy.',
  ],
  CommentEvent.holeClear: [
    'Hole complete. Let\'s see the draft.',
    'Cleared. Time for a quick sip of water.',
    'Signed, sealed, scorecard delivered.',
  ],
  CommentEvent.coinsStolen: [
    'The raccoon has taken the purse!',
    'Thief on the fairway!',
  ],
  CommentEvent.runWon: [
    'A champion\'s round. Somebody get the green jacket.',
    'The clubhouse stands!',
  ],
  CommentEvent.runLost: [
    'And that\'s the round. The animals have the clubhouse.',
    'A brave stand. The bar is now under new management.',
  ],
};

/// Picks lines without repeating the last few used for an event.
class Commentator {
  Commentator(this._pick);

  /// Returns an index in [0, n).
  final int Function(int n) _pick;
  final Map<CommentEvent, List<int>> _recent = {};

  String line(CommentEvent event) {
    final lines = commentary[event]!;
    final recent = _recent.putIfAbsent(event, () => []);
    final options = [for (var i = 0; i < lines.length; i++) if (!recent.contains(i)) i];
    final choice = options.isEmpty ? _pick(lines.length) : options[_pick(options.length)];
    recent.add(choice);
    final memory = (lines.length / 2).floor().clamp(1, 4);
    while (recent.length > memory) {
      recent.removeAt(0);
    }
    return lines[choice];
  }
}
