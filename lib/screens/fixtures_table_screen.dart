import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/world_cup_data.dart';
import 'schedule_screen.dart';
import 'table_screen.dart';

/// Schedule (fixtured) and group tables in one bottom-nav destination, matching
/// [SearchScreen] tab styling.
class FixturesTableScreen extends StatefulWidget {
  const FixturesTableScreen({
    super.key,
    required this.scheduleKey,
    required this.scheduleByDay,
    required this.teams,
    required this.onRefresh,
    this.onEditStateChanged,
    this.onPrimaryTabChanged,
  });

  final GlobalKey<ScheduleScreenState> scheduleKey;
  final List<DaySchedule> scheduleByDay;
  final List<TeamInfo> teams;
  final Future<void> Function() onRefresh;
  final VoidCallback? onEditStateChanged;
  final ValueChanged<int>? onPrimaryTabChanged;

  @override
  State<FixturesTableScreen> createState() => _FixturesTableScreenState();
}

class _FixturesTableScreenState extends State<FixturesTableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_notifyTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPrimaryTabChanged?.call(_tabController.index);
    });
  }

  void _notifyTab() {
    if (_tabController.indexIsChanging) return;
    widget.onPrimaryTabChanged?.call(_tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_notifyTab);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF001D3D),
            unselectedLabelColor: Colors.blueGrey[300],
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(
                width: 4,
                color: Color(0xFFFEC20C),
              ),
              insets: EdgeInsets.symmetric(horizontal: 16),
            ),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('FIXTURES'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.table_chart_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('TABLE'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF5F7F9),
            child: TabBarView(
              controller: _tabController,
              children: [
                ScheduleScreen(
                  key: widget.scheduleKey,
                  scheduleByDay: widget.scheduleByDay,
                  teams: widget.teams,
                  onRefresh: widget.onRefresh,
                  onEditStateChanged: widget.onEditStateChanged,
                ),
                TableScreen(
                  scheduleByDay: widget.scheduleByDay,
                  teams: widget.teams,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
