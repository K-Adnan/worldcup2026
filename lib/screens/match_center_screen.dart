import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/world_cup_data.dart';
import '../utils/flag_asset.dart';
import '../utils/knockout_round32_resolver.dart';
import 'team_detail_screen.dart';
import 'widgets/match_pitch.dart';

class MatchCenterScreen extends StatefulWidget {
  const MatchCenterScreen({
    super.key,
    required this.match,
    required this.teams,
    this.allScheduleMatchesForBracket,
  });

  final MatchFixture match;
  final List<TeamInfo> teams;
  final List<MatchFixture>? allScheduleMatchesForBracket;

  @override
  State<MatchCenterScreen> createState() => _MatchCenterScreenState();
}

class _MatchCenterScreenState extends State<MatchCenterScreen> {
  late final Future<MatchFixture> _matchFuture;
  late final ScrollController _scrollController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _matchFuture = _loadLatestMatch();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final next = _scrollController.offset;
    if ((next - _scrollOffset).abs() < 1) return;
    setState(() => _scrollOffset = next);
  }

  Future<MatchFixture> _loadLatestMatch() async {
    final doc = await FirebaseFirestore.instance
        .collection('schedule')
        .doc(widget.match.matchNumber.toString())
        .get();
    if (!doc.exists) return widget.match;
    final data = doc.data();
    if (data == null) return widget.match;
    var updated = MatchFixture.fromJson(data);
    final ctx = widget.allScheduleMatchesForBracket;
    if (ctx != null && ctx.isNotEmpty) {
      updated = KnockoutRound32Resolver.applyToSingle(updated, ctx, widget.teams);
    }
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;

    final collapseProgress = (_scrollOffset / 200).clamp(0.0, 1.0);

    // Lerp heights for the background space
    final headerHeight = lerpDouble(205, 112, collapseProgress)!;
    final panelTop = safeTop + headerHeight;
    final fixedPitchHeight = (screenHeight * 0.78).clamp(460.0, 860.0);

    return FutureBuilder<MatchFixture>(
      future: _matchFuture,
      builder: (context, snapshot) {
        final match = snapshot.data ?? widget.match;
        final loading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Scaffold(
          backgroundColor: const Color(0xFF001D3D),
          body: Stack(
            children: [
              // HERO SCOREBOARD with Translation
              Positioned(
                top: safeTop + 20,
                left: 16,
                right: 16,
                child: _buildHeroScoreboard(
                  context,
                  match,
                  collapseProgress: collapseProgress,
                ),
              ),

              // CONTENT PANEL
              Positioned.fill(
                top: panelTop,
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
                      return SingleChildScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                                '${match.matchNumber}-${match.homeFormation}-${match.awayFormation}'
                                    '-${_slotPlayersKey(match.homeSlotPlayers)}'
                                    '-${_slotPlayersKey(match.awaySlotPlayers)}',
                              ),
                              height: fixedPitchHeight,
                              matchNumber: match.matchNumber,
                              initialHomeFormation: match.homeFormation,
                              initialAwayFormation: match.awayFormation,
                              homeSquad: _findTeamByName(match.homeTeam)?.squad ??
                                  const <TeamPlayer>[],
                              awaySquad: _findTeamByName(match.awayTeam)?.squad ??
                                  const <TeamPlayer>[],
                              initialHomeSlotPlayers: match.homeSlotPlayers,
                              initialAwaySlotPlayers: match.awaySlotPlayers,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // BACK BUTTON
              Positioned(
                top: safeTop + 8,
                left: 8,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              if (loading)
                Positioned(
                  top: safeTop + 10,
                  right: 16,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroScoreboard(
      BuildContext context,
      MatchFixture match, {
        required double collapseProgress,
      }) {
    // This value determines how far up the scoreboard moves.
    // -80 means it will slide up by 80 pixels as you scroll.
    final translateY = lerpDouble(0, -80, collapseProgress)!;

    final teamScale = lerpDouble(1, 0.70, collapseProgress)!;
    final scoreScale = lerpDouble(1, 0.65, collapseProgress)!;
    final stageOpacity = (1 - (collapseProgress * 2.0)).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: stageOpacity,
            child: Text(
              match.stage.toUpperCase(),
              style: GoogleFonts.bebasNeue(
                letterSpacing: 2,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _heroTeam(context, match.homeTeam, scale: teamScale, collapseProgress: collapseProgress),
              _heroScoreDisplay(match, scale: scoreScale, collapseProgress: collapseProgress),
              _heroTeam(context, match.awayTeam, scale: teamScale, collapseProgress: collapseProgress),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroTeam(
      BuildContext context,
      String teamName, {
        required double scale,
        required double collapseProgress,
      }) {
    final team = _findTeamByName(teamName);
    final canOpenTeam = team != null;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: canOpenTeam
                  ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TeamDetailScreen(team: team)),
              )
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3 * (1 - collapseProgress)),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: SvgPicture.asset(
                      roundFlagAssetForTeam(teamName),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholderBuilder: (_) => const Icon(Icons.help_outline, size: 28, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // We reduce the spacing as we scroll to keep it tight
          SizedBox(height: lerpDouble(12, 4, collapseProgress)!),
          Text(
            teamName.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: lerpDouble(14, 10, collapseProgress)!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroScoreDisplay(MatchFixture match, {required double scale, required double collapseProgress}) {
    final homeScore = match.homeScore.trim().isEmpty ? '-' : match.homeScore;
    final awayScore = match.awayScore.trim().isEmpty ? '-' : match.awayScore;

    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$homeScore : $awayScore',
            style: GoogleFonts.bebasNeue(
              fontSize: 64,
              color: const Color(0xFFFEC20C),
              letterSpacing: 4,
            ),
          ),
          // Hide the "Match Number" tag early to save space when collapsed
          Opacity(
            opacity: (1 - (collapseProgress * 3)).clamp(0.0, 1.0),
            child: Container(
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
            ),
          )
        ],
      ),
    );
  }

  // ... (Rest of the helper methods remain exactly the same)

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

  String _slotPlayersKey(List<PitchSlotPlayer>? slots) {
    if (slots == null || slots.isEmpty) return '0';
    return slots.map((s) => '${s.number}:${s.name}').join(',');
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