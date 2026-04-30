import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/world_cup_data.dart';
import '../utils/flag_asset.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.scheduleByDay});

  final List<DaySchedule> scheduleByDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9), // Light grey background
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: scheduleByDay.length,
        itemBuilder: (context, dayIndex) {
          final daySchedule = scheduleByDay[dayIndex];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DATE HEADER ---
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                child: Text(
                  daySchedule.date.toUpperCase(),
                  style: TextStyle(
                    color: Colors.blueGrey[800],
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 14,
                  ),
                ),
              ),
              // --- MATCH CARDS ---
              ...daySchedule.matches.map((match) => _buildMatchCard(context, match)),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, MatchFixture match) {
    return Container(
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
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 25,
                color: _getStageColor(match.stage),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      match.stage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match ${match.matchNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _teamSlot(match.homeTeam, isHome: true),
                          _timeSlot(match.time),
                          _teamSlot(match.awayTeam, isHome: false),
                        ],
                      ),
                      const Divider(height: 24, thickness: 0.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${match.city} | ${match.stadium}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _teamSlot(String teamName, {required bool isHome}) {
    final isPlaceholder =
        teamName.startsWith('Group ') || teamName.startsWith('Match ');

    return Expanded(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: isPlaceholder
                  ? const Icon(Icons.help_outline, size: 18)
                  : ClipOval(
                      child: SvgPicture.asset(
                        roundFlagAssetForTeam(teamName),
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        placeholderBuilder: (context) =>
                            const Icon(Icons.flag_outlined, size: 18),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            teamName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _timeSlot(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        time,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.blueGrey),
      ),
    );
  }

  Color _getBroadcasterColor(String broadcaster) {
    if (broadcaster.contains('ARD') || broadcaster.contains('ZDF')) return Colors.orange;
    if (broadcaster.contains('BBC')) return Colors.red[900]!;
    if (broadcaster.contains('ITV')) return Colors.blue[900]!;
    return Colors.blueAccent;
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