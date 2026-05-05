import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/world_cup_data.dart';
import 'players_screen.dart';
import 'teams_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, required this.teams});

  final List<TeamInfo> teams;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Styled Header for Tabs
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
              // Professional Sports Styling
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
                  color: Color(0xFFFEC20C), // Golden Yellow Accent
                ),
                insets: EdgeInsets.symmetric(horizontal: 16),
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_rounded, size: 20),
                      SizedBox(width: 8),
                      Text("TEAMS"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded, size: 20),
                      SizedBox(width: 8),
                      Text("PLAYERS"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7F9), // Subtle light grey background
              child: TabBarView(
                children: [
                  TeamsScreen(teams: teams),
                  PlayersScreen(teams: teams),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}