import 'dart:math';

/// Historical-style score frequencies; each asymmetric line splits 50/50 home vs away.
class RandomMatchScores {
  RandomMatchScores._();

  static final Random _random = Random();

  /// (homeGoals, awayGoals, percentage mass for this *pairing* — draws use full mass;
  /// wins use full mass split equally between (h,a) and (a,h)).
  static const List<(int home, int away, double pct)> _distribution = [
    (1, 0, 17.17),
    (2, 1, 14.34),
    (2, 0, 10.47),
    (1, 1, 8.68),
    (0, 0, 7.36),
    (3, 1, 6.42),
    (3, 0, 5.38),
    (3, 2, 4.06),
    (2, 2, 3.30),
    (4, 1, 2.92),
    (4, 0, 2.26),
    (4, 2, 1.60),
    (6, 1, 1.04),
    (5, 2, 0.85),
    (5, 0, 0.66),
    (3, 3, 0.66),
    (5, 1, 0.66),
    (6, 0, 0.47),
    (7, 0, 0.47),
    (4, 3, 0.28),
    (7, 1, 0.28),
    (8, 1, 0.28),
    (4, 4, 0.19),
    (6, 3, 0.19),
    (9, 0, 0.19),
    (5, 3, 0.09),
    (6, 2, 0.09),
    (7, 2, 0.09),
    (7, 3, 0.09),
    (6, 5, 0.09),
    (8, 3, 0.09),
    (10, 1, 0.09),
    (7, 5, 0.09),
  ];

  static List<({int home, int away, double weight})>? _entries;
  static double _totalWeight = 0;

  static void _ensureBuilt() {
    if (_entries != null) return;
    final built = <({int home, int away, double weight})>[];
    for (final row in _distribution) {
      final (h, a, pct) = row;
      if (h == a) {
        built.add((home: h, away: a, weight: pct));
      } else {
        final half = pct / 2.0;
        built.add((home: h, away: a, weight: half));
        built.add((home: a, away: h, weight: half));
      }
    }
    _totalWeight = built.fold<double>(0, (s, e) => s + e.weight);
    _entries = built;
  }

  /// One random scoreline; home / away aligned to the schedule row (fixture home/away).
  static (int home, int away) pickScoreline() {
    _ensureBuilt();
    final entries = _entries!;
    var roll = _random.nextDouble() * _totalWeight;
    for (final e in entries) {
      if (roll < e.weight) return (e.home, e.away);
      roll -= e.weight;
    }
    final last = entries.last;
    return (last.home, last.away);
  }
}
