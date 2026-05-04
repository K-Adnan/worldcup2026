import '../data/third_place_matrix_data.dart';
import '../data/world_cup_data.dart';
import 'group_standings_calculator.dart';

/// Fills Round of 32 seeds from computed group tables.
/// Supports `A-1` / `I-3` and FIFA-style `1A` / `3I` (same meaning).
/// Combined slots `A/B/…-3` use [ThirdPlaceMatrixData] plus the opponent’s group-winner
/// column (`A-1` or `1A`; only A,B,D,E,G,I,K,L face a third-placed qualifier in the matrix).
abstract final class KnockoutRound32Resolver {
  /// `A/B/C/D/F-3` style (one or more group letters before `-3`).
  static final RegExp _combinedThirdPath =
      RegExp(r'^([A-L](?:/[A-L])+)-3$', caseSensitive: false);

  /// `E-1`, `F-2`; also accepts `E1`, `f2`.
  static final RegExp _groupFinishSlot =
      RegExp(r'^([A-L])-?([123])$', caseSensitive: false);

  /// FIFA-style knockout tokens: `1A` winner group A, `2B` runner-up, `3I` third place.
  static final RegExp _fifaFirst = RegExp(r'^1([A-L])$', caseSensitive: false);
  static final RegExp _fifaSecond = RegExp(r'^2([A-L])$', caseSensitive: false);
  static final RegExp _fifaThird = RegExp(r'^3([A-L])$', caseSensitive: false);

  /// Group winners whose Round-of-32 tie is vs a third-placed qualifier (matrix column order).
  static const String _winnerColumnsFacingThird = 'ABDEGIKL';

  static const String roundOf32Stage = 'Round of 32';

  static Map<String, List<GroupStandingRow>> _rankingsCache(
    List<MatchFixture> allMatches,
    List<TeamInfo> teams,
  ) {
    final cache = <String, List<GroupStandingRow>>{};
    for (final letter in GroupStandingsCalculator.groupLetters) {
      final lbl = GroupStandingsCalculator.groupLabel(letter);
      final rawStats = GroupStandingsCalculator.statsForGroup(
        lbl,
        allMatches,
        teams,
      );
      cache[lbl] = GroupStandingsCalculator.sortedStandingRows(
        lbl,
        allMatches,
        rawStats,
      );
    }
    return cache;
  }

  /// Bit i set iff group `A`+i is among the eight best third-placed teams, or null if tables incomplete.
  static int? _advancingThirdsMask(Map<String, List<GroupStandingRow>> cacheByGroupLabel) {
    final letters = GroupStandingsCalculator.groupLetters;
    final thirdRows = <GroupStandingRow>[];
    for (final letter in letters) {
      final label = GroupStandingsCalculator.groupLabel(letter);
      final rows = cacheByGroupLabel[label];
      if (rows == null || rows.length < 3) return null;
      thirdRows.add(rows[2]);
    }
    // Best thirds first: compareThirdPlaceAcrossGroups(x, y) is positive when y is better,
    // so sort (a,b) with (thirdRows[a], thirdRows[b]) puts higher-ranked thirds earlier.
    final idx = List<int>.generate(12, (i) => i)
      ..sort((a, b) {
        final c = GroupStandingsCalculator.compareThirdPlaceAcrossGroups(
          thirdRows[a],
          thirdRows[b],
        );
        if (c != 0) return c;
        return a.compareTo(b);
      });
    var mask = 0;
    for (final i in idx.take(8)) {
      mask |= 1 << i;
    }
    return mask;
  }

  /// Index into [ThirdPlaceMatrixData] third-vs-winner string, or null if [opponentRaw] is not `X-1` for a fixed column.
  static int? _winnerThirdColumnIndex(String opponentRaw) {
    final t = opponentRaw.trim();
    final hy = RegExp(r'^([A-L])-?1$', caseSensitive: false).firstMatch(t);
    if (hy != null) {
      final letter = hy.group(1)!.toUpperCase();
      final i = _winnerColumnsFacingThird.indexOf(letter);
      return i < 0 ? null : i;
    }
    final fifa = _fifaFirst.firstMatch(t.toUpperCase());
    if (fifa != null) {
      final letter = fifa.group(1)!;
      final i = _winnerColumnsFacingThird.indexOf(letter);
      return i < 0 ? null : i;
    }
    return null;
  }

  /// Returns [raw] unchanged if not Round of 32 or not a resolvable placeholder.
  static String resolveTeamField(
    String raw,
    Map<String, List<GroupStandingRow>> cacheByGroupLabel, {
    required bool isHome,
    required String homeRaw,
    required String awayRaw,
  }) {
    final t = raw.trim();
    if (t.isEmpty) return '';

    final combined = _combinedThirdPath.firstMatch(t.toUpperCase());
    if (combined != null) {
      final advMask = _advancingThirdsMask(cacheByGroupLabel);
      if (advMask == null) return '';
      final slots = ThirdPlaceMatrixData.thirdSlotsForAdvancingMask(advMask);
      if (slots == null || slots.length != _winnerColumnsFacingThird.length) return '';

      final opponentRaw = isHome ? awayRaw : homeRaw;
      final col = _winnerThirdColumnIndex(opponentRaw);
      if (col == null) return '';

      final thirdLetter = slots[col].toUpperCase();
      final allowed = combined.group(1)!.split('/');
      if (!allowed.contains(thirdLetter)) return '';

      final label = GroupStandingsCalculator.groupLabel(thirdLetter);
      final rows = cacheByGroupLabel[label] ?? const [];
      if (rows.length < 3) return '';
      return rows[2].team;
    }

    final tUp = t.toUpperCase();
    final f1 = _fifaFirst.firstMatch(tUp);
    if (f1 != null) {
      final letter = f1.group(1)!;
      final label = GroupStandingsCalculator.groupLabel(letter);
      final rows = cacheByGroupLabel[label] ?? [];
      if (rows.isEmpty) return raw;
      return rows[0].team;
    }
    final f2 = _fifaSecond.firstMatch(tUp);
    if (f2 != null) {
      final letter = f2.group(1)!;
      final label = GroupStandingsCalculator.groupLabel(letter);
      final rows = cacheByGroupLabel[label] ?? [];
      if (rows.length < 2) return raw;
      return rows[1].team;
    }
    final f3 = _fifaThird.firstMatch(tUp);
    if (f3 != null) {
      final letter = f3.group(1)!;
      final label = GroupStandingsCalculator.groupLabel(letter);
      final rows = cacheByGroupLabel[label] ?? [];
      if (rows.length < 3) return raw;
      return rows[2].team;
    }

    final m = _groupFinishSlot.firstMatch(tUp);
    if (m == null) {
      return raw;
    }
    final letter = m.group(1)!;
    final finish = int.parse(m.group(2)!);
    final label = GroupStandingsCalculator.groupLabel(letter);
    final rows = cacheByGroupLabel[label] ?? [];
    if (finish < 1 || finish > rows.length) {
      return raw;
    }
    return rows[finish - 1].team;
  }

  static List<DaySchedule> apply(
    List<DaySchedule> scheduleByDay,
    List<TeamInfo> teams,
  ) {
    final allMatches = GroupStandingsCalculator.allMatchesFromDays(scheduleByDay);
    final cache = _rankingsCache(allMatches, teams);

    return scheduleByDay.map((day) {
      return DaySchedule(
        date: day.date,
        matches: day.matches.map((match) => _maybeResolveMatch(match, cache)).toList(),
      );
    }).toList();
  }

  static MatchFixture _maybeResolveMatch(
    MatchFixture match,
    Map<String, List<GroupStandingRow>> cache,
  ) {
    if (match.stage.trim() != roundOf32Stage) {
      return match;
    }
    final hr = match.homeTeam;
    final ar = match.awayTeam;
    final ht = resolveTeamField(hr, cache, isHome: true, homeRaw: hr, awayRaw: ar);
    final at = resolveTeamField(ar, cache, isHome: false, homeRaw: hr, awayRaw: ar);
    return match.copyWith(homeTeam: ht, awayTeam: at);
  }

  /// Re-run resolution for one fixture (e.g. after reloading from Firestore in Match Centre).
  static MatchFixture applyToSingle(
    MatchFixture match,
    List<MatchFixture> allMatches,
    List<TeamInfo> teams,
  ) {
    final cache = _rankingsCache(allMatches, teams);
    return _maybeResolveMatch(match, cache);
  }
}
