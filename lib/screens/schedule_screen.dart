import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/world_cup_data.dart';
import '../utils/flag_asset.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.scheduleByDay,
    required this.onRefresh,
  });

  final List<DaySchedule> scheduleByDay;
  final Future<void> Function() onRefresh;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  int _selectedDateIndex = 0;
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_syncSelectedDate);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_syncSelectedDate);
    super.dispose();
  }

  void _syncSelectedDate() {
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
    if (current.index != _selectedDateIndex && mounted) {
      setState(() {
        _selectedDateIndex = current.index;
      });
    }
  }

  Future<void> _jumpToDate(int index) async {
    setState(() {
      _selectedDateIndex = index;
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
      _selectedDateIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9), // Light grey background
      body: Column(
        children: [
          SizedBox(
            height: 74,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: widget.scheduleByDay.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = widget.scheduleByDay[index];
                final isSelected = index == _selectedDateIndex;
                final chipParts = _dateChipParts(day.date);
                return ChoiceChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        chipParts.$1,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chipParts.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chipParts.$3,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => _jumpToDate(index),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: widget.scheduleByDay.length,
                itemBuilder: (context, dayIndex) {
                  final daySchedule = widget.scheduleByDay[dayIndex];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
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
                      ...daySchedule.matches.map(
                        (match) => _buildMatchCard(context, match),
                      ),
                      const SizedBox(height: 6),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, String, String) _dateChipParts(String fullDate) {
    final parts = fullDate.split(' ');
    if (parts.length >= 4) {
      final weekday = parts[0];
      final shortWeekday = weekday.length >= 3
          ? weekday.substring(0, 3)
          : weekday;
      return (shortWeekday, parts[1], parts[2]);
    }
    return (fullDate, '', '');
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
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 1. Stage Sidebar
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    children: [
                      // 2. Main Match Row (Teams & Scores)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _teamSlot(
                              match.homeTeam,
                              isHome: true,
                              score: match.homeScore // Pass home score here
                          ),

                          // Center Info: Match Number & Time
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
                            ],
                          ),

                          _teamSlot(
                              match.awayTeam,
                              isHome: false,
                              score: match.awayScore // Pass away score here
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1, thickness: 0.5),
                      ),

                      // 3. Footer Row (Venue & Broadcaster)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
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

  Widget _teamSlot(String teamName, {required bool isHome, String? score}) {
    final isPlaceholder = teamName.startsWith('Group ') || teamName.startsWith('Match ');

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            teamName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Score Display
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

  Color _getBroadcasterColor(String broadcaster) {
    if (broadcaster.contains('ARD') || broadcaster.contains('ZDF')) return Colors.orange[700]!;
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