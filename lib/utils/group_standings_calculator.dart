import '../data/world_cup_data.dart';

/// Single row after sorting a group table (matches Table rules: points → H2H → GD/GF/name).
class GroupStandingRow {
  const GroupStandingRow({
    required this.rank,
    required this.team,
    required this.points,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  final int rank;
  final String team;
  final int points;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
}

/// Goals/points tally for tie-break ladders (same group table).
class GroupTableStats {
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get points => wins * 3 + draws;

  int get goalDifference => goalsFor - goalsAgainst;
}

class _HeadToHeadMini {
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get points => wins * 3 + draws;

  int get goalDifference => goalsFor - goalsAgainst;
}

/// Group-phase standings (same algorithm as `TableScreen`).
abstract final class GroupStandingsCalculator {
  static const List<String> groupLetters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
  ];

  static String groupLabel(String letter) => 'Group $letter';

  /// True for first-round group labels only (`Group A` … `Group L`), not knockouts.
  static bool isGroupStage(String stage) {
    final t = stage.trim();
    return RegExp(r'^Group\s+[A-L]$', caseSensitive: false).hasMatch(t);
  }

  static List<MatchFixture> allMatchesFromDays(List<DaySchedule> days) {
    final out = <MatchFixture>[];
    for (final d in days) {
      out.addAll(d.matches);
    }
    return out;
  }

  static bool isPlaceholderTeamName(String name) {
    final t = name.trim();
    if (t.isEmpty) return true;
    if (t.startsWith('Group ') || t.startsWith('Match ')) return true;
    final u = t.toUpperCase();
    if (RegExp(r'^[A-L]-[123]$').hasMatch(u)) return true;
    if (RegExp(r'^[123][A-L]$').hasMatch(u)) return true;
    return RegExp(r'^[A-L](?:/[A-L])+-3$').hasMatch(u);
  }

  static (int, int)? parseScore(MatchFixture m) {
    final h = int.tryParse(m.homeScore.trim());
    final a = int.tryParse(m.awayScore.trim());
    if (h == null || a == null) return null;
    return (h, a);
  }

  static Map<String, GroupTableStats> statsForGroup(
    String groupLabelText,
    List<MatchFixture> allMatches,
    List<TeamInfo> teamList,
  ) {
    final names = <String>{};
    for (final t in teamList) {
      if ((t.group ?? '').trim() == groupLabelText) names.add(t.name);
    }
    for (final m in allMatches) {
      if (m.stage.trim() != groupLabelText) continue;
      if (!isPlaceholderTeamName(m.homeTeam)) names.add(m.homeTeam);
      if (!isPlaceholderTeamName(m.awayTeam)) names.add(m.awayTeam);
    }
    final stats = <String, GroupTableStats>{
      for (final n in names) n: GroupTableStats(),
    };
    for (final m in allMatches) {
      if (m.stage.trim() != groupLabelText) continue;
      if (isPlaceholderTeamName(m.homeTeam) || isPlaceholderTeamName(m.awayTeam)) continue;
      final parsed = parseScore(m);
      if (parsed == null) continue;
      final (hg, ag) = parsed;
      final home = stats[m.homeTeam];
      final away = stats[m.awayTeam];
      if (home == null || away == null) continue;
      home.goalsFor += hg;
      home.goalsAgainst += ag;
      away.goalsFor += ag;
      away.goalsAgainst += hg;
      if (hg > ag) {
        home.wins++;
        away.losses++;
      } else if (hg < ag) {
        home.losses++;
        away.wins++;
      } else {
        home.draws++;
        away.draws++;
      }
    }
    return stats;
  }

  static List<MatchFixture> groupStageMatches(
    String groupLabelText,
    List<MatchFixture> allMatches,
  ) {
    final out = <MatchFixture>[];
    for (final m in allMatches) {
      if (m.stage.trim() != groupLabelText) continue;
      if (isPlaceholderTeamName(m.homeTeam) || isPlaceholderTeamName(m.awayTeam)) continue;
      out.add(m);
    }
    return out;
  }

  static List<GroupStandingRow> sortedStandingRows(
    String groupLabelText,
    List<MatchFixture> allMatches,
    Map<String, GroupTableStats> stats,
  ) {
    final groupMatches = groupStageMatches(groupLabelText, allMatches);
    final names = stats.keys.toList()
      ..sort((a, b) => stats[b]!.points.compareTo(stats[a]!.points));

    final orderedKeys = <String>[];
    var i = 0;
    while (i < names.length) {
      var j = i + 1;
      final p = stats[names[i]]!.points;
      while (j < names.length && stats[names[j]]!.points == p) {
        j++;
      }
      final bucket = names.sublist(i, j);
      if (bucket.length == 1) {
        orderedKeys.add(bucket.single);
      } else {
        orderedKeys.addAll(_resolveHeadToHeadOrder(bucket, stats, groupMatches));
      }
      i = j;
    }

    return List<GroupStandingRow>.generate(orderedKeys.length, (idx) {
      final key = orderedKeys[idx];
      final e = stats[key]!;
      return GroupStandingRow(
        rank: idx + 1,
        team: key,
        points: e.points,
        wins: e.wins,
        draws: e.draws,
        losses: e.losses,
        goalsFor: e.goalsFor,
        goalsAgainst: e.goalsAgainst,
      );
    });
  }

  static Map<String, _HeadToHeadMini> _computeHeadToHeadMini(
    Set<String> tieSubset,
    List<MatchFixture> groupMatches,
  ) {
    final map = <String, _HeadToHeadMini>{
      for (final t in tieSubset) t: _HeadToHeadMini(),
    };
    for (final m in groupMatches) {
      final h = m.homeTeam.trim();
      final a = m.awayTeam.trim();
      if (!tieSubset.contains(h) || !tieSubset.contains(a)) continue;
      final parsed = parseScore(m);
      if (parsed == null) continue;
      final (hg, ag) = parsed;
      final miH = map[h]!;
      final miA = map[a]!;
      miH.goalsFor += hg;
      miH.goalsAgainst += ag;
      miA.goalsFor += ag;
      miA.goalsAgainst += hg;
      if (hg > ag) {
        miH.wins++;
        miA.losses++;
      } else if (hg < ag) {
        miH.losses++;
        miA.wins++;
      } else {
        miH.draws++;
        miA.draws++;
      }
    }
    return map;
  }

  static bool _h2hMiniEqual(_HeadToHeadMini x, _HeadToHeadMini y) {
    return x.points == y.points &&
        x.goalDifference == y.goalDifference &&
        x.goalsFor == y.goalsFor;
  }

  static int _compareHeadToHeadMini(_HeadToHeadMini a, _HeadToHeadMini b) {
    final cPt = b.points.compareTo(a.points);
    if (cPt != 0) return cPt;
    final cGd = b.goalDifference.compareTo(a.goalDifference);
    if (cGd != 0) return cGd;
    return b.goalsFor.compareTo(a.goalsFor);
  }

  static int _compareOverallStats(
    GroupTableStats a,
    GroupTableStats b,
    String nameA,
    String nameB,
  ) {
    final cGd = b.goalDifference.compareTo(a.goalDifference);
    if (cGd != 0) return cGd;
    final cGf = b.goalsFor.compareTo(a.goalsFor);
    if (cGf != 0) return cGf;
    return nameA.toLowerCase().compareTo(nameB.toLowerCase());
  }

  static List<String> _resolveHeadToHeadOrder(
    List<String> tiedTeams,
    Map<String, GroupTableStats> stats,
    List<MatchFixture> groupMatches,
  ) {
    if (tiedTeams.length <= 1) return List.from(tiedTeams);

    final h2h = _computeHeadToHeadMini(tiedTeams.toSet(), groupMatches);
    final ref = h2h[tiedTeams.first]!;
    final allMiniEqual =
        tiedTeams.every((t) => _h2hMiniEqual(h2h[t]!, ref));
    if (allMiniEqual) {
      final out = List<String>.from(tiedTeams)
        ..sort((a, b) => _compareOverallStats(stats[a]!, stats[b]!, a, b));
      return out;
    }

    final sorted = List<String>.from(tiedTeams)
      ..sort((a, b) => _compareHeadToHeadMini(h2h[a]!, h2h[b]!));

    final ordered = <String>[];
    var k = 0;
    while (k < sorted.length) {
      var m = k + 1;
      while (
          m < sorted.length &&
          _h2hMiniEqual(h2h[sorted[m]]!, h2h[sorted[k]]!)) {
        m++;
      }
      final group = sorted.sublist(k, m);
      if (group.length == 1) {
        ordered.add(group.single);
      } else {
        ordered.addAll(_resolveHeadToHeadOrder(group, stats, groupMatches));
      }
      k = m;
    }
    return ordered;
  }

  static GroupTableStats _runningStatsFromRow(GroupStandingRow r) {
    final s = GroupTableStats()
      ..wins = r.wins
      ..draws = r.draws
      ..losses = r.losses
      ..goalsFor = r.goalsFor
      ..goalsAgainst = r.goalsAgainst;
    return s;
  }

  static int compareThirdPlaceAcrossGroups(GroupStandingRow a, GroupStandingRow b) {
    final cPts = b.points.compareTo(a.points);
    if (cPts != 0) return cPts;
    final sa = _runningStatsFromRow(a);
    final sb = _runningStatsFromRow(b);
    return _compareOverallStats(sa, sb, a.team, b.team);
  }
}
