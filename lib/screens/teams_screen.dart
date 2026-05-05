import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/world_cup_data.dart';
import 'team_detail_screen.dart';
import '../utils/flag_asset.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({
    super.key,
    required this.teams,
    required this.starredTeams,
    required this.onToggleStarredTeam,
  });

  final List<TeamInfo> teams;
  final Set<String> starredTeams;
  final ValueChanged<String> onToggleStarredTeam;

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _sortField = 'Name';
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TeamInfo> get _visibleTeams {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.teams.where((team) {
      if (query.isEmpty) return true;
      final inName = team.name.toLowerCase().contains(query);
      final inNote = (team.note ?? '').toLowerCase().contains(query);
      final inGroup = (team.group ?? '').toLowerCase().contains(query);
      return inName || inNote || inGroup;
    }).toList();

    int compareString(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      int result;
      switch (_sortField) {
        case 'Group':
          result = compareString(a.group ?? '', b.group ?? '');
          break;
        case 'Market Value':
          result = _totalMarketValue(a).compareTo(_totalMarketValue(b));
          break;
        case 'Name':
        default:
          result = compareString(a.name, b.name);
          break;
      }
      return _sortAscending ? result : -result;
    });
    return filtered;
  }

  int _totalMarketValue(TeamInfo team) {
    return (team.squad ?? const <TeamPlayer>[])
        .fold<int>(0, (sum, player) => sum + player.marketValue);
  }

  String _formatMarketValue(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)}B';
    }
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return '$value';
  }

  Color _getGroupColor(String? group) {
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
    };
    return colors[group] ?? Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final teams = _visibleTeams;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search teams',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${teams.length} team${teams.length == 1 ? '' : 's'} visible',
                    style: TextStyle(
                      color: Colors.blueGrey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Sort field',
                  initialValue: _sortField,
                  onSelected: (value) => setState(() => _sortField = value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'Name', child: Text('Name')),
                    PopupMenuItem(value: 'Group', child: Text('Group')),
                    PopupMenuItem(value: 'Market Value', child: Text('Market Value')),
                  ],
                  child: Row(
                    children: [
                      const Icon(Icons.sort, size: 20),
                      const SizedBox(width: 4),
                      Text(_sortField, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _sortAscending ? 'Ascending' : 'Descending',
                  onPressed: () => setState(() => _sortAscending = !_sortAscending),
                  icon: Icon(
                    _sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: teams.isEmpty
                ? const Center(child: Text('No nations found.'))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                return _buildTeamTile(teams[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTile(TeamInfo team) {
    final value = _totalMarketValue(team);
    final groupColor = _getGroupColor(team.group);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TeamDetailScreen(team: team),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                // Flag Container
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade100, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: SvgPicture.asset(
                        roundFlagAssetForTeam(team.name),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Team Name and Group
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: const Color(0xFF001D3D),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: groupColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${team.group ?? '-'}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: groupColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Market Value (Right Aligned & Prominent)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: widget.starredTeams.contains(team.name)
                          ? 'Remove from starred teams'
                          : 'Add to starred teams',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onToggleStarredTeam(team.name),
                      icon: Icon(
                        widget.starredTeams.contains(team.name)
                            ? Icons.star
                            : Icons.star_outline,
                        color: const Color(0xFFFEC20C),
                        size: 20,
                      ),
                    ),
                    Text(
                      '€${_formatMarketValue(value)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1B8F3A), // Football Green
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[300],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}