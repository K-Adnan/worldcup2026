import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/world_cup_data.dart';
import '../utils/flag_asset.dart';
import 'team_detail_screen.dart';
import 'widgets/match_pitch.dart';

class MatchCenterScreen extends StatefulWidget {
  const MatchCenterScreen({
    super.key,
    required this.match,
    required this.teams,
  });

  final MatchFixture match;
  final List<TeamInfo> teams;

  @override
  State<MatchCenterScreen> createState() => _MatchCenterScreenState();
}

class _MatchCenterScreenState extends State<MatchCenterScreen> {
  late final Future<MatchFixture> _matchFuture;

  @override
  void initState() {
    super.initState();
    _matchFuture = _loadLatestMatch();
  }

  Future<MatchFixture> _loadLatestMatch() async {
    final doc = await FirebaseFirestore.instance
        .collection('schedule')
        .doc(widget.match.matchNumber.toString())
        .get();
    if (!doc.exists) return widget.match;
    final data = doc.data();
    if (data == null) return widget.match;
    return MatchFixture.fromJson(data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchFixture>(
      future: _matchFuture,
      builder: (context, snapshot) {
        final match = snapshot.data ?? widget.match;
        final loading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Scaffold(
          backgroundColor: const Color(0xFF001D3D),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              match.stage.toUpperCase(),
              style: GoogleFonts.bebasNeue(
                letterSpacing: 2,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            actions: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              _buildHeroScoreboard(context, match),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7F9),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pitchHeight =
                          (constraints.maxHeight - 48).clamp(320.0, 1200.0);
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('MATCH INFO'),
                            const SizedBox(height: 16),
                            _detailTile(
                              Icons.calendar_today_rounded,
                              'Date & Kickoff',
                              '${_stripYearFromDate(match.date)} • ${match.time}',
                            ),
                            _detailTile(
                              Icons.location_on_rounded,
                              'Stadium & City',
                              '${match.stadium}, ${match.city}',
                            ),
                            _detailTile(
                              Icons.tv_rounded,
                              'Official Broadcaster',
                              match.broadcaster,
                            ),
                            const SizedBox(height: 12),
                            MatchPitch(
                              key: ValueKey<String>(
                                '${match.matchNumber}-${match.homeFormation}-${match.awayFormation}',
                              ),
                              height: pitchHeight,
                              matchNumber: match.matchNumber,
                              initialHomeFormation: match.homeFormation,
                              initialAwayFormation: match.awayFormation,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroScoreboard(BuildContext context, MatchFixture match) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _heroTeam(context, match.homeTeam),
          _heroScoreDisplay(match),
          _heroTeam(context, match.awayTeam),
        ],
      ),
    );
  }

  Widget _heroTeam(BuildContext context, String teamName) {
    final isPlaceholder = teamName.startsWith('Group ') ||
        teamName.startsWith('Match ') ||
        RegExp(r'^[A-L]-[123]$').hasMatch(teamName.toUpperCase()) ||
        RegExp(r'^[A-L](?:/[A-L])+-3$').hasMatch(teamName.toUpperCase());
    final team = _findTeamByName(teamName);
    final canOpenTeam = !isPlaceholder && team != null;

    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: canOpenTeam
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamDetailScreen(team: team),
                      ),
                    );
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: isPlaceholder
                    ? const Icon(Icons.help_outline, size: 28, color: Colors.grey)
                    : ClipOval(
                        child: SvgPicture.asset(
                          roundFlagAssetForTeam(teamName),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: canOpenTeam
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamDetailScreen(team: team),
                      ),
                    );
                  }
                : null,
            child: Text(
              teamName.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroScoreDisplay(MatchFixture match) {
    final homeScore = match.homeScore.trim().isEmpty ? '-' : match.homeScore;
    final awayScore = match.awayScore.trim().isEmpty ? '-' : match.awayScore;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            '$homeScore : $awayScore',
            style: GoogleFonts.bebasNeue(
              fontSize: 64,
              color: const Color(0xFFFEC20C),
              letterSpacing: 4,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'MATCH ${match.matchNumber}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.blueGrey[300],
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF001D3D)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF001D3D),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  String _stripYearFromDate(String date) {
    return date
        .replaceAll(RegExp(r'\b20\d{2}\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
