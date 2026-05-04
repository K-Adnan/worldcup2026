import '../data/world_cup_data.dart';
import 'group_standings_calculator.dart';

/// Fills Round of 32 seeds from computed group tables (winner = *-1, runner-up = *-2).
/// Combined third-path slots `[A]/[B]/…-3` are cleared (`''`) for later wiring.
abstract final class KnockoutRound32Resolver {
  /// `A/B/C/D/F-3` style (one or more group letters before `-3`).
  static final RegExp _combinedThirdPath =
      RegExp(r'^([A-L](?:/[A-L])+)-3$', caseSensitive: false);

  /// `E-1`, `F-2`; also accepts `E1`, `f2`.
  static final RegExp _groupFinishSlot =
      RegExp(r'^([A-L])-?([123])$', caseSensitive: false);

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

  /// Returns [raw] unchanged if not Round of 32 or not a resolvable placeholder.
  static String resolveTeamField(
    String raw,
    Map<String, List<GroupStandingRow>> cacheByGroupLabel,
  ) {
    final t = raw.trim();
    if (t.isEmpty) return '';

    if (_combinedThirdPath.hasMatch(t)) {
      return '';
    }

    final m = _groupFinishSlot.firstMatch(t.toUpperCase());
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
    final ht = resolveTeamField(match.homeTeam, cache);
    final at = resolveTeamField(match.awayTeam, cache);
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
