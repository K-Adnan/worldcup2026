import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/world_cup_data.dart';
import '../utils/group_standings_calculator.dart';
import '../utils/flag_asset.dart';
import 'match_center_screen.dart';
import 'team_detail_screen.dart';

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({
    super.key,
    required this.scheduleByDay,
    required this.teams,
    required this.starredTeams,
  });

  final List<DaySchedule> scheduleByDay;
  final List<TeamInfo> teams;
  final Set<String> starredTeams;

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<MatchFixture> get _starredUpcomingMatches {
    if (widget.starredTeams.isEmpty) return const <MatchFixture>[];

    final allMatches = GroupStandingsCalculator.allMatchesFromDays(
      widget.scheduleByDay,
    );
    final filtered = allMatches.where((match) {
      final involvesStarredTeam =
          widget.starredTeams.contains(match.homeTeam) ||
          widget.starredTeams.contains(match.awayTeam);
      final isUpcoming = match.homeScore == '-' && match.awayScore == '-';
      return involvesStarredTeam && isUpcoming;
    }).toList()
      ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    return filtered;
  }

  DateTime? _matchKickoff(MatchFixture match) {
    final dayMonthYear = RegExp(r'(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)\s+(\d{4})')
        .firstMatch(match.date);
    if (dayMonthYear == null) return null;

    const months = <String, int>{
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };

    final day = int.tryParse(dayMonthYear.group(1)!);
    final month = months[dayMonthYear.group(2)!.toLowerCase()];
    final year = int.tryParse(dayMonthYear.group(3)!);
    final timeParts = match.time.split(':');
    final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) : null;
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;

    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    return DateTime(year, month, day, hour, minute);
  }

  String _countdownText(MatchFixture match) {
    final kickoff = _matchKickoff(match);
    if (kickoff == null) return 'Countdown unavailable';
    final remaining = kickoff.difference(_now);
    if (remaining.isNegative) return 'Starting soon';

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    return '${days}d ${hours}:${minutes}:${seconds}';
  }

  void _openMatchCenter(BuildContext context, MatchFixture match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchCenterScreen(
          match: match,
          teams: widget.teams,
          allScheduleMatchesForBracket: GroupStandingsCalculator.allMatchesFromDays(
            widget.scheduleByDay,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _starredUpcomingMatches;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            "My Team's Upcoming Matches",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.starredTeams.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Star teams from Search > Teams to see matches here.'),
              ),
            )
          else if (upcoming.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No upcoming matches for starred teams.'),
              ),
            )
          else
            ...upcoming.map(
              (match) => _buildScheduleLikeMatchCard(context, match),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleLikeMatchCard(BuildContext context, MatchFixture match) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openMatchCenter(context, match),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 22,
                  color: _getStageColor(match.stage),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        match.stage.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              match.date,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.blueGrey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _teamSlot(context, match.homeTeam, score: match.homeScore),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'MATCH ${match.matchNumber}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Colors.blueGrey.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _timeSlot(match.time),
                                const SizedBox(height: 5),
                                _countdownTimer(match),
                              ],
                            ),
                            _teamSlot(context, match.awayTeam, score: match.awayScore),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1, thickness: 0.5),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${match.city} | ${match.stadium}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _broadcasterBadge(match.broadcaster),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamSlot(
    BuildContext context,
    String teamName, {
    String? score,
  }) {
    final tn = teamName.trim();
    final u = tn.toUpperCase();
    final isPlaceholder = tn.isEmpty ||
        tn.startsWith('Group ') ||
        tn.startsWith('Match ') ||
        RegExp(r'^[A-L]-[123]$').hasMatch(u) ||
        RegExp(r'^[123][A-L]$').hasMatch(u) ||
        RegExp(r'^[A-L](?:/[A-L])+-3$').hasMatch(u);

    final team = _findTeamByName(teamName);
    final canOpenTeam = !isPlaceholder && team != null;
    void openTeam() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeamDetailScreen(team: team!),
        ),
      );
    }

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: canOpenTeam ? openTeam : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 56,
              height: 44,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: isPlaceholder
                        ? const Icon(Icons.help_outline, size: 16, color: Colors.grey)
                        : ClipOval(
                            child: SvgPicture.asset(
                              roundFlagAssetForTeam(teamName),
                              key: ValueKey(teamName),
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: canOpenTeam ? openTeam : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                teamName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            score ?? '-',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: score != null ? Colors.black : Colors.grey[300],
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeSlot(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        time,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _countdownTimer(MatchFixture match) {
    const Color brandNavy = Color(0xFF001D3D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent, // Removed solid background
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: brandNavy, // The border now carries the primary color
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_rounded,
            size: 13,
            color: brandNavy,
          ),
          const SizedBox(width: 6),
          Text(
            _countdownText(match).toUpperCase(),
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: brandNavy,
            ),
          ),
        ],
      ),
    );
  }
  Widget _broadcasterBadge(String broadcaster) {
    final color = _getBroadcasterColor(broadcaster);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        broadcaster,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  TeamInfo? _findTeamByName(String teamName) {
    final normalizedTarget = _normalizeTeamName(teamName);
    for (final team in widget.teams) {
      if (_normalizeTeamName(team.name) == normalizedTarget) {
        return team;
      }
    }
    return null;
  }

  String _normalizeTeamName(String name) {
    return name
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
  }

  Color _getBroadcasterColor(String broadcaster) {
    if (broadcaster.contains('ARD') || broadcaster.contains('ZDF')) {
      return Colors.orange[700]!;
    }
    if (broadcaster.contains('BBC')) return Colors.red[800]!;
    if (broadcaster.contains('ITV')) return Colors.blue[800]!;
    return Colors.blueGrey;
  }

  Color _getStageColor(String stage) {
    const colors = {
      'Group A': Color(0xFF1E88E5),
      'Group B': Color(0xFF00897B),
      'Group C': Color(0xFFD81B60),
      'Group D': Color(0xFF43A047),
      'Group E': Color(0xFFF4511E),
      'Group F': Color(0xFF8E24AA),
      'Group G': Color(0xFFFDD835),
      'Group H': Color(0xFF7CB342),
      'Group I': Color(0xFFE53935),
      'Group J': Color(0xFF00ACC1),
      'Group K': Color(0xFF5E35B1),
      'Group L': Color(0xFFFB8C00),
      'Round of 32': Color(0xFF757575),
      'Round of 16': Color(0xFF424242),
      'Quarter Final': Color(0xFF1565C0),
      'Semi Final': Color(0xFF6A1B9A),
      'Third Place': Color(0xFFCD7F32),
      'Final': Color(0xFFD4AF37),
    };
    return colors[stage] ?? Colors.blueGrey;
  }
}
