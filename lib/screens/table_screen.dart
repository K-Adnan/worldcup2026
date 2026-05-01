import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/world_cup_data.dart';
import '../utils/flag_asset.dart';

Widget _stripeGradientHeader(String titleUpper, {double fontSize = 20, bool expandTitle = false}) {
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
        if (expandTitle)
          Expanded(
            child: Text(
              titleUpper,
              style: GoogleFonts.bebasNeue(
                fontSize: fontSize,
                letterSpacing: 1.05,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
                ],
              ),
            ),
          )
        else
          Text(
            titleUpper,
            style: GoogleFonts.bebasNeue(
              fontSize: fontSize,
              letterSpacing: 1.25,
              color: Colors.white,
              shadows: const [
                Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
              ],
            ),
          ),
      ],
    ),
  );
}

class TableScreen extends StatefulWidget {
  const TableScreen({super.key, required this.scheduleByDay, required this.teams});

  final List<DaySchedule> scheduleByDay;
  final List<TeamInfo> teams;

  static const List<String> _groupLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'];

  static const String _thirdPlaceChipLabel = '3rd Places';

  static String _groupLabel(String letter) => 'Group $letter';

  /// Display title for gradient header inside the third-placed standings card.
  static const String _sectionHeaderThirdPlaceRanking = 'Ranking of third-placed teams';

  static int get _sectionCount => _groupLetters.length + 1;

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

  static _RunningStats _runningStatsFromStandingRow(_StandingRow r) {
    final s = _RunningStats()
      ..wins = r.wins
      ..draws = r.draws
      ..losses = r.losses
      ..goalsFor = r.goalsFor
      ..goalsAgainst = r.goalsAgainst;
    return s;
  }

  static int _compareThirdPlacedAcrossGroups(_StandingRow a, _StandingRow b) {
    final cPts = b.points.compareTo(a.points);
    if (cPts != 0) return cPts;
    final sa = _runningStatsFromStandingRow(a);
    final sb = _runningStatsFromStandingRow(b);
    return _compareOverallStats(sa, sb, a.team, b.team);
  }

  static List<_ThirdPlaceRankingRow> _sortedThirdPlaceRanking(
    List<MatchFixture> allMatches,
    List<TeamInfo> teamList,
  ) {
    final picks = <_ThirdPlacePick>[];
    for (final letter in _groupLetters) {
      final label = _groupLabel(letter);
      final raw = _statsForGroup(label, allMatches, teamList);
      final rows = _sortedStandings(label, allMatches, raw);
      if (rows.length < 3) continue;
      picks.add(_ThirdPlacePick(groupLabel: label, thirdPlacedRow: rows[2]));
    }
    picks.sort(
      (a, b) => _compareThirdPlacedAcrossGroups(a.thirdPlacedRow, b.thirdPlacedRow),
    );
    return List<_ThirdPlaceRankingRow>.generate(picks.length, (i) {
      final pick = picks[i];
      return _ThirdPlaceRankingRow(
        leaderboardRank: i + 1,
        sourceGroupLabel: pick.groupLabel,
        row: pick.thirdPlacedRow,
      );
    });
  }

  @override
  State<TableScreen> createState() => _TableScreenState();
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

class _TableScreenState extends State<TableScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final Map<int, GlobalKey> _sectionChipKeys = <int, GlobalKey>{};
  int _selectedSectionIndex = 0;
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_syncSectionFromScroll);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_syncSectionFromScroll);
    super.dispose();
  }

  void _syncSectionFromScroll() {
    if (_isProgrammaticScroll) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final visible = positions.where((item) => item.itemTrailingEdge > 0).toList();
    if (visible.isEmpty) return;

    visible.sort((a, b) {
      final aDistance = (a.itemLeadingEdge).abs();
      final bDistance = (b.itemLeadingEdge).abs();
      return aDistance.compareTo(bDistance);
    });

    final current = visible.first;
    if (current.index != _selectedSectionIndex && mounted) {
      setState(() {
        _selectedSectionIndex = current.index;
      });
      _ensureSelectedChipVisible();
    }
  }

  Future<void> _jumpToSection(int index) async {
    if (index < 0 || index >= TableScreen._sectionCount) return;
    setState(() {
      _selectedSectionIndex = index;
      _isProgrammaticScroll = true;
    });
    await _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.02,
    );
    if (!mounted) return;
    setState(() {
      _isProgrammaticScroll = false;
      _selectedSectionIndex = index;
    });
    _ensureSelectedChipVisible();
  }

  void _ensureSelectedChipVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _sectionChipKeys[_selectedSectionIndex];
      final ctx = key?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  Widget _buildGroupTitleHeader(String label) =>
      _stripeGradientHeader(label.toUpperCase(), fontSize: 23);

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Text(
        'Waiting for group assignments...',
        style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontStyle: FontStyle.italic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMatches = TableScreen._allMatches(widget.scheduleByDay);
    final thirdPlaceRankings =
        TableScreen._sortedThirdPlaceRanking(allMatches, widget.teams);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          SizedBox(
            height: 74,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: TableScreen._sectionCount,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isThirdSection = index == TableScreen._groupLetters.length;
                final isSelected = index == _selectedSectionIndex;
                final chipKey =
                    _sectionChipKeys.putIfAbsent(index, () => GlobalKey());

                return ChoiceChip(
                  key: chipKey,
                  showCheckmark: false,
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      isThirdSection
                          ? TableScreen._thirdPlaceChipLabel
                          : TableScreen._groupLetters[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isThirdSection ? 11 : 14,
                        fontWeight: FontWeight.w700,
                        height: isThirdSection ? 1.1 : 1.0,
                      ),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => _jumpToSection(index),
                );
              },
            ),
          ),
          Expanded(
            child: ScrollablePositionedList.builder(
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: TableScreen._sectionCount,
              itemBuilder: (context, index) {
                if (index == TableScreen._groupLetters.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: _ThirdPlaceRankingCard(
                      rankings: thirdPlaceRankings,
                      sectionHeaderTitle: TableScreen._sectionHeaderThirdPlaceRanking,
                    ),
                  );
                }
                final letter = TableScreen._groupLetters[index];
                final label = TableScreen._groupLabel(letter);
                final raw =
                    TableScreen._statsForGroup(label, allMatches, widget.teams);
                final rows =
                    TableScreen._sortedStandings(label, allMatches, raw);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
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
                        _buildGroupTitleHeader(label),
                        if (rows.isEmpty)
                          _buildEmptyState()
                        else
                          _StandingsTable(rows: rows),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThirdPlacePick {
  const _ThirdPlacePick({required this.groupLabel, required this.thirdPlacedRow});

  final String groupLabel;
  final _StandingRow thirdPlacedRow;
}

class _ThirdPlaceRankingRow {
  const _ThirdPlaceRankingRow({
    required this.leaderboardRank,
    required this.sourceGroupLabel,
    required this.row,
  });

  final int leaderboardRank;
  final String sourceGroupLabel;
  final _StandingRow row;
}

class _ThirdPlaceRankingCard extends StatelessWidget {
  const _ThirdPlaceRankingCard({
    required this.rankings,
    required this.sectionHeaderTitle,
  });

  final List<_ThirdPlaceRankingRow> rankings;
  final String sectionHeaderTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stripeGradientHeader(
            sectionHeaderTitle.toUpperCase(),
            fontSize: 17.5,
            expandTitle: true,
          ),
          if (rankings.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              child: Text(
                'Shows when every group has at least three teams so a 3rd place exists in each.',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            )
          else
            _ThirdPlacesRankingsBody(rankings: rankings),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ThirdPlacesRankingsBody extends StatelessWidget {
  const _ThirdPlacesRankingsBody({required this.rankings});

  final List<_ThirdPlaceRankingRow> rankings;

  /// Same fills as `_StandingsTable._rowBackground`: top-two green, fourth grey.
  static const Color _topBandGreen = Color(0xFFE8F5E9);
  static const Color _outerBandGrey = Color(0xFFEEEEEE);

  static Color _rowFill(int leaderboardRank) =>
      leaderboardRank <= 8 ? _topBandGreen : _outerBandGrey;

  static String _signedGoalDiff(_StandingRow r) {
    final d = r.goalsFor - r.goalsAgainst;
    if (d > 0) return '+$d';
    return '$d';
  }

  Widget _hdr(String text, {double? width, TextAlign align = TextAlign.center, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: Colors.blueGrey.shade600,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: [
              _hdr('RK', width: 34),
              _hdr('GRP', width: 36),
              Expanded(child: _hdr('TEAM', align: TextAlign.left)),
              _hdr('PTS', width: 32, bold: true),
              _hdr('GD', width: 28),
              _hdr('GF : GA', width: 54),
            ],
          ),
        ),
        ...rankings.map((e) {
          final r = e.row;
          final grpLetter = e.sourceGroupLabel.replaceFirst(RegExp(r'^group\s+', caseSensitive: false), '');
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            decoration: BoxDecoration(
              color: _rowFill(e.leaderboardRank),
              border: Border(
                bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${e.leaderboardRank}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    grpLetter,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 18,
                        child: Center(
                          child: Image.asset(
                            flagAssetForTeam(r.team),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.flag, size: 13, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.team,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${r.points}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    _signedGoalDiff(r),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 54,
                  child: Text(
                    '${r.goalsFor} : ${r.goalsAgainst}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
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
