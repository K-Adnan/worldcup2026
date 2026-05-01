import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/world_cup_data.dart';
import '../utils/flag_asset.dart';

class TableScreen extends StatelessWidget {
  const TableScreen({super.key, required this.scheduleByDay, required this.teams});

  final List<DaySchedule> scheduleByDay;
  final List<TeamInfo> teams;

  static const List<String> _groupLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'];

  static String _groupLabel(String letter) => 'Group $letter';

  // ... (Keep existing _allMatches, _isPlaceholderTeam, _parseScore, _statsForGroup, _sortedStandings logic)

  @override
  Widget build(BuildContext context) {
    final allMatches = _allMatches(scheduleByDay);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: _groupLetters.length,
        itemBuilder: (context, index) {
          final letter = _groupLetters[index];
          final label = _groupLabel(letter);
          final raw = _statsForGroup(label, allMatches, teams);
          final rows = _sortedStandings(label, allMatches, raw);

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(label),
                if (rows.isEmpty) _buildEmptyState() else _StandingsTable(rows: rows),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF002855), Color(0xFF001D3D)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF7BD389).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.bebasNeue(
              fontSize: 23,
              letterSpacing: 1.3,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Text(
        'Waiting for group assignments...',
        style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontStyle: FontStyle.italic),
      ),
    );
  }

  // --- Logic methods remain the same as your provided code ---
  static List<MatchFixture> _allMatches(List<DaySchedule> days) {
    final out = <MatchFixture>[];
    for (final d in days) {
      out.addAll(d.matches);
    }
    return out;
  }

  static bool _isPlaceholderTeam(String name) {
    final t = name.trim();
    if (t.isEmpty) return true;
    if (t.startsWith('Group ') || t.startsWith('Match ')) return true;
    if (RegExp(r'^[A-L]-[123]$').hasMatch(t.toUpperCase())) return true;
    return RegExp(r'^[A-L](?:/[A-L])+-3$').hasMatch(t.toUpperCase());
  }

  static (int, int)? _parseScore(MatchFixture m) {
    final h = int.tryParse(m.homeScore.trim());
    final a = int.tryParse(m.awayScore.trim());
    if (h == null || a == null) return null;
    return (h, a);
  }

  static Map<String, _RunningStats> _statsForGroup(
    String groupLabel,
    List<MatchFixture> allMatches,
    List<TeamInfo> teamList,
  ) {
    final names = <String>{};
    for (final t in teamList) {
      if ((t.group ?? '').trim() == groupLabel) names.add(t.name);
    }
    for (final m in allMatches) {
      if (m.stage.trim() != groupLabel) continue;
      if (!_isPlaceholderTeam(m.homeTeam)) names.add(m.homeTeam);
      if (!_isPlaceholderTeam(m.awayTeam)) names.add(m.awayTeam);
    }
    final stats = <String, _RunningStats>{for (final n in names) n: _RunningStats()};
    for (final m in allMatches) {
      if (m.stage.trim() != groupLabel) continue;
      if (_isPlaceholderTeam(m.homeTeam) || _isPlaceholderTeam(m.awayTeam)) continue;
      final parsed = _parseScore(m);
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

  /// Group-stage fixtures used for standings (scores may be unfinished).
  static List<MatchFixture> _groupStageMatches(String groupLabel, List<MatchFixture> allMatches) {
    final out = <MatchFixture>[];
    for (final m in allMatches) {
      if (m.stage.trim() != groupLabel) continue;
      if (_isPlaceholderTeam(m.homeTeam) || _isPlaceholderTeam(m.awayTeam)) continue;
      out.add(m);
    }
    return out;
  }

  static List<_StandingRow> _sortedStandings(
    String groupLabel,
    List<MatchFixture> allMatches,
    Map<String, _RunningStats> stats,
  ) {
    final groupMatches = _groupStageMatches(groupLabel, allMatches);
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

    return List<_StandingRow>.generate(orderedKeys.length, (idx) {
      final key = orderedKeys[idx];
      final e = stats[key]!;
      return _StandingRow(
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

  /// Head-to-head mini-table among [tieSubset]; only matches involving both clubs count.
  static Map<String, _HeadToHeadMini> _computeHeadToHeadMini(
    Set<String> tieSubset,
    List<MatchFixture> groupMatches,
  ) {
    final map = <String, _HeadToHeadMini>{for (final t in tieSubset) t: _HeadToHeadMini()};
    for (final m in groupMatches) {
      final h = m.homeTeam.trim();
      final a = m.awayTeam.trim();
      if (!tieSubset.contains(h) || !tieSubset.contains(a)) continue;
      final parsed = _parseScore(m);
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

  /// Negative ⇒ [a] is ordered above [b] (better head-to-head).
  static int _compareHeadToHeadMini(_HeadToHeadMini a, _HeadToHeadMini b) {
    final cPt = b.points.compareTo(a.points);
    if (cPt != 0) return cPt;
    final cGd = b.goalDifference.compareTo(a.goalDifference);
    if (cGd != 0) return cGd;
    return b.goalsFor.compareTo(a.goalsFor);
  }

  static int _compareOverallStats(
    _RunningStats a,
    _RunningStats b,
    String nameA,
    String nameB,
  ) {
    final cGd = b.goalDifference.compareTo(a.goalDifference);
    if (cGd != 0) return cGd;
    final cGf = b.goalsFor.compareTo(a.goalsFor);
    if (cGf != 0) return cGf;
    return nameA.toLowerCase().compareTo(nameB.toLowerCase());
  }

  /// When teams are tied on total points: head-to-head among the subset, recursively for
  /// sub-ties; if head-to-head is completely level, falls back to overall GD, GF, name.
  static List<String> _resolveHeadToHeadOrder(
    List<String> tiedTeams,
    Map<String, _RunningStats> stats,
    List<MatchFixture> groupMatches,
  ) {
    if (tiedTeams.length <= 1) return List.from(tiedTeams);

    final h2h = _computeHeadToHeadMini(tiedTeams.toSet(), groupMatches);
    final ref = h2h[tiedTeams.first]!;
    final allMiniEqual = tiedTeams.every((t) => _h2hMiniEqual(h2h[t]!, ref));
    if (allMiniEqual) {
      final out = List<String>.from(tiedTeams)
        ..sort(
          (a, b) => _compareOverallStats(stats[a]!, stats[b]!, a, b),
        );
      return out;
    }

    final sorted = List<String>.from(tiedTeams)
      ..sort((a, b) => _compareHeadToHeadMini(h2h[a]!, h2h[b]!));

    final ordered = <String>[];
    var k = 0;
    while (k < sorted.length) {
      var m = k + 1;
      while (m < sorted.length && _h2hMiniEqual(h2h[sorted[m]]!, h2h[sorted[k]]!)) {
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

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.rows});

  final List<_StandingRow> rows;

  static Color _rowBackground(int rank) {
    switch (rank) {
      case 1:
      case 2:
        return const Color(0xFFE8F5E9);
      case 3:
        return const Color(0xFFE3F2FD);
      case 4:
        return const Color(0xFFEEEEEE);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: [
              _label('RANK', width: 42, align: TextAlign.center),
              Expanded(child: _label('TEAM', align: TextAlign.left)),
              _label('W', width: 22),
              _label('D', width: 22),
              _label('L', width: 22),
              _label('GF : GA', width: 52),
              _label('PTS', width: 38, isBold: true),
            ],
          ),
        ),
        // Body Rows
        ...rows.asMap().entries.map((entry) {
          final r = entry.value;
          final isQualifying = r.rank <= 2;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: _rowBackground(r.rank),
              border: Border(
                bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                // Rank with qualification bar
                SizedBox(
                  width: 42,
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isQualifying ? Colors.green : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${r.rank}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                // Team + Flag
                Expanded(
                  child: Row(
                    children: [
                      _flag(r.team),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.team,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                _stat('${r.wins}', width: 22),
                _stat('${r.draws}', width: 22),
                _stat('${r.losses}', width: 22),
                _stat('${r.goalsFor} : ${r.goalsAgainst}', width: 52, fontSize: 11.5),
                _stat(
                  '${r.points}',
                  width: 38,
                  isBold: true,
                  color: const Color(0xFF001D3D),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _label(String text, {double? width, TextAlign align = TextAlign.center, bool isBold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: Colors.blueGrey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _stat(
    String text, {
    double? width,
    bool isBold = false,
    Color? color,
    double fontSize = 12,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }

  Widget _flag(String team) {
    return SizedBox(
      width: 28,
      height: 18,
      child: Center(
        child: Image.asset(
          flagAssetForTeam(team),
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => const Icon(Icons.flag, size: 14, color: Colors.grey),
        ),
      ),
    );
  }
}

class _RunningStats {
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get points => wins * 3 + draws;

  int get goalDifference => goalsFor - goalsAgainst;
}

class _StandingRow {
  const _StandingRow({
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
