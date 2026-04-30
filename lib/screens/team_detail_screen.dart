import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/world_cup_data.dart';
import '../utils/flag_asset.dart';

class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({super.key, required this.team});

  final TeamInfo team;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  // Logic remains mostly the same, but we update the UI components
  late List<TeamPlayer> _squad;
  String _sortField = 'Default Name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _squad = [...?widget.team.squad];
    _applySquadSort();
  }

  void _applySquadSort() {
    int compareNum(int? a, int? b) => (a ?? 9999).compareTo(b ?? 9999);
    int compareString(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

    _squad.sort((a, b) {
      int result;
      switch (_sortField) {
        case 'Age':
          result = _ageInYears(a.dateOfBirth).compareTo(_ageInYears(b.dateOfBirth));
          break;
        case 'Value':
          result = a.marketValue.compareTo(b.marketValue);
          break;
        case 'Height':
          result = a.heightCm.compareTo(b.heightCm);
          break;
        case 'Caps':
          result = a.caps.compareTo(b.caps);
          break;
        case 'Goals':
          result = a.goals.compareTo(b.goals);
          break;
        case 'Number':
          result = compareNum(a.number, b.number);
          break;
        case 'Default Name':
        default:
          result = compareString(a.name, b.name);
      }
      return _sortAscending ? result : -result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: CustomScrollView(
        slivers: [
          // 1. BEAUTIFUL COLLAPSIBLE HEADER
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                widget.team.name.toUpperCase(),
                style: GoogleFonts.bebasNeue(
                  letterSpacing: 2,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Subtle gradient background
                  Container(color: const Color(0xFF001D3D)),
                  Center(
                    child: Opacity(
                      opacity: 0.2,
                      child: SvgPicture.asset(
                        roundFlagAssetForTeam(widget.team.name),
                        width: 120,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. TEAM SUMMARY STRIP
          SliverToBoxAdapter(
            child: _buildTeamSummary(),
          ),

          // 3. UPCOMING/PAST MATCHES SECTION
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text("FIXTURES", style: _sectionHeaderStyle()),
            ),
          ),
          _buildMatchListSliver(),

          // 4. SQUAD LIST SECTION
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text("SQUAD", style: _sectionHeaderStyle()),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Sort field',
                    initialValue: _sortField,
                    onSelected: (value) {
                      setState(() {
                        _sortField = value;
                        _applySquadSort();
                      });
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'Default Name', child: Text('Default Name')),
                      PopupMenuItem(value: 'Age', child: Text('Age')),
                      PopupMenuItem(value: 'Value', child: Text('Value')),
                      PopupMenuItem(value: 'Height', child: Text('Height')),
                      PopupMenuItem(value: 'Caps', child: Text('Caps')),
                      PopupMenuItem(value: 'Goals', child: Text('Goals')),
                      PopupMenuItem(value: 'Number', child: Text('Number')),
                    ],
                    child: Row(
                      children: [
                        const Icon(Icons.sort, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _sortField,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _sortAscending ? 'Ascending' : 'Descending',
                    onPressed: () {
                      setState(() {
                        _sortAscending = !_sortAscending;
                        _applySquadSort();
                      });
                    },
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
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPlayerCard(_squad[index]),
                childCount: _squad.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  TextStyle _sectionHeaderStyle() => GoogleFonts.bebasNeue(
    fontSize: 20,
    letterSpacing: 1.5,
    color: Colors.blueGrey[800],
  );

  Widget _buildTeamSummary() {
    final totalValue = _squad.fold(0, (total, p) => total + p.marketValue);
    final avgAge = _squad.isEmpty
        ? 0
        : _squad.map((p) => _ageInYears(p.dateOfBirth)).reduce((a, b) => a + b) / _squad.length;
    final avgHeightCm = _squad.isEmpty
        ? 0
        : _squad.map((p) => p.heightCm).reduce((a, b) => a + b) / _squad.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem("Avg. Age", avgAge.toStringAsFixed(1)),
          _summaryItem("Avg. Height", _formatHeight(avgHeightCm.round())),
          _summaryItem("Value", _formatMarketValue(totalValue)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMatchListSliver() {
    return FutureBuilder<List<MatchFixture>>(
      future: _loadMatches(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: LinearProgressIndicator()));
        final matches = snapshot.data!;
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: matches.length,
              itemBuilder: (context, i) => _buildCompactMatchCard(matches[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactMatchCard(MatchFixture m) {
    final isHome = m.homeTeam == widget.team.name;
    final opponent = isHome ? m.awayTeam : m.homeTeam;

    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const Spacer(),
          Row(
            children: [
              Text(isHome ? "vs " : "@ ", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Expanded(
                child: Text(
                  opponent,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${m.homeScore} - ${m.awayScore}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(TeamPlayer p) {
    final categoryColor = _positionCategoryColor(p.categoryPosition);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: categoryColor, width: 6),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          trailing: Text(
            _formatMarketValue(p.marketValue),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.blueGrey[50],
            child: Text(
                p.number?.toString() ?? "-",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
            ),
          ),
          title: Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                  p.position,
                  style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.w500)
              ),
              const SizedBox(width: 8),
              Text(
                  "•  ${_ageInYears(p.dateOfBirth)}y",
                  style: const TextStyle(color: Colors.grey, fontSize: 12)
              ),
              const SizedBox(width: 8),
              Text(
                  "•  ${p.caps} / ${p.goals}",
                  style: TextStyle(color: Colors.blueGrey[400], fontSize: 11, fontWeight: FontWeight.w600)
              ),
              const SizedBox(width: 8),
              _buildFootBadge(p.preferredFoot),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 12),
                  _playerDetailRow("Club", p.club),
                  _playerDetailRow("Height", _formatHeight(p.heightCm)),
                  _playerDetailRow(
                    "Full DOB",
                    p.dateOfBirth != null
                        ? "${p.dateOfBirth!.day.toString().padLeft(2, '0')}/${p.dateOfBirth!.month.toString().padLeft(2, '0')}/${p.dateOfBirth!.year}"
                        : "-",
                  ),
                  _playerDetailRow("Debut Date", p.debut != null
                      ? "${p.debut!.day.toString().padLeft(2, '0')}/${p.debut!.month.toString().padLeft(2, '0')}/${p.debut!.year}"
                      : "N/A"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _positionCategoryColor(String category) {
    switch (category) {
      case 'Goalkeeper':
        return Colors.amber.shade700;
      case 'Defender':
        return Colors.blue.shade700;
      case 'Attacker':
        return Colors.red.shade700;
      case 'Midfielder':
      default:
        return Colors.green.shade700;
    }
  }

  Widget _buildFootBadge(String foot) {
    // Normalize string to handle "left", "Right", "both", etc.
    final f = foot.toLowerCase();
    String label = "R";
    Color color = Colors.blueGrey;

    if (f.contains("left")) {
      label = "L";
      color = Colors.orange[700]!;
    } else if (f.contains("both")) {
      label = "B";
      color = Colors.green[700]!;
    } else {
      label = "R";
      color = Colors.blue[700]!;
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color
        ),
      ),
    );
  }
  Widget _playerDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatMarketValue(int value) {
    if (value >= 1000000000) {
      return '€${(value / 1000000000).toStringAsFixed(3)}B';
    }
    if (value >= 1000000) return '€${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '€${(value / 1000).toStringAsFixed(0)}k';
    return '€$value';
  }

  String _formatHeight(int cm) => '${(cm / 100).toStringAsFixed(2)}m';

  int _ageInYears(DateTime? dob) {
    if (dob == null) return 0;
    final now = DateTime.now();
    return now.year - dob.year - (now.month < dob.month || (now.month == dob.month && now.day < dob.day) ? 1 : 0);
  }

  Future<List<MatchFixture>> _loadMatches() async {
    final firestore = FirebaseFirestore.instance;
    final homeQuery = await firestore.collection('schedule').where('homeTeam', isEqualTo: widget.team.name).get();
    final awayQuery = await firestore.collection('schedule').where('awayTeam', isEqualTo: widget.team.name).get();
    return [...homeQuery.docs, ...awayQuery.docs]
        .map((doc) => MatchFixture.fromJson(doc.data()))
        .toList()
      ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
  }
}