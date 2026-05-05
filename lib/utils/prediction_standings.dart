import '../data/world_cup_data.dart';
import 'group_standings_calculator.dart';
import 'knockout_round32_resolver.dart';

/// Builds group tables / knockout placeholders using real results when present,
/// otherwise predicted scores, then runs [KnockoutRound32Resolver].
abstract final class PredictionStandings {
  static MatchFixture _mergeForStandings(MatchFixture m) {
    if (GroupStandingsCalculator.parseScore(m) != null) {
      return m;
    }
    final h = m.predictionHomeScore.trim();
    final a = m.predictionAwayScore.trim();
    if (int.tryParse(h) != null && int.tryParse(a) != null) {
      return m.copyWith(homeScore: h, awayScore: a);
    }
    return m;
  }

  static List<DaySchedule> _daysWithMerged(List<DaySchedule> days) {
    return days
        .map(
          (d) => DaySchedule(
            date: d.date,
            matches: d.matches.map(_mergeForStandings).toList(),
          ),
        )
        .toList();
  }

  /// Schedule used by Predictor **Table** tab: standings + knockouts from predictions
  /// (and real results where they exist).
  static List<DaySchedule> tableSchedule(
    List<DaySchedule> original,
    List<TeamInfo> teams,
  ) {
    final merged = _daysWithMerged(original);
    return KnockoutRound32Resolver.apply(merged, teams);
  }
}
