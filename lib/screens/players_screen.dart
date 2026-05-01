import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/world_cup_data.dart';
import '../utils/flag_asset.dart';
import '../utils/player_position.dart';
import 'team_detail_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key, required this.teams});

  final List<TeamInfo> teams;

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayerRow {
  const _PlayerRow({
    required this.teamName,
    required this.player,
  });

  final String teamName;
  final TeamPlayer player;
}

class _PlayersScreenState extends State<PlayersScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _sortField = 'Name';
  bool _sortAscending = true;

  final Set<String> _selectedPositions = <String>{};
  /// Per position category — whether individual position tick boxes are visible.
  final Map<String, bool> _positionDetailExpandedByCategory = <String, bool>{};
  final Set<String> _selectedCountries = <String>{};
  final TextEditingController _minHeightController = TextEditingController();
  final TextEditingController _maxHeightController = TextEditingController();
  final TextEditingController _minValueController = TextEditingController();
  final TextEditingController _maxValueController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _minHeightController.dispose();
    _maxHeightController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    super.dispose();
  }

  List<_PlayerRow> get _allPlayers {
    final out = <_PlayerRow>[];
    for (final team in widget.teams) {
      for (final player in team.squad ?? const <TeamPlayer>[]) {
        out.add(
          _PlayerRow(
            teamName: team.name,
            player: player,
          ),
        );
      }
    }
    return out;
  }

  Map<String, List<String>> get _positionsByCategory {
    final buckets = <String, Set<String>>{
      'Goalkeeper': {},
      'Defender': {},
      'Midfielder': {},
      'Attacker': {},
    };
    for (final row in _allPlayers) {
      final pos = row.player.position.trim();
      if (pos.isEmpty) continue;
      buckets[row.player.categoryPosition]?.add(pos);
    }
    return {
      for (final e in buckets.entries)
        e.key: e.value.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    };
  }

  List<String> get _availableCountries {
    final set = widget.teams.map((t) => t.name).toSet();
    final list = set.toList()..sort();
    return list;
  }

  int? _toNullableInt(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  bool _passesFilters(_PlayerRow row) {
    final p = row.player;
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final inName = p.name.toLowerCase().contains(q);
      final inTeam = row.teamName.toLowerCase().contains(q);
      final inPos = p.position.toLowerCase().contains(q);
      if (!inName && !inTeam && !inPos) return false;
    }

    if (_selectedPositions.isNotEmpty &&
        !_selectedPositions.contains(p.position.trim())) {
      return false;
    }
    if (_selectedCountries.isNotEmpty &&
        !_selectedCountries.contains(row.teamName)) {
      return false;
    }
    final minH = _toNullableInt(_minHeightController.text);
    final maxH = _toNullableInt(_maxHeightController.text);
    if (minH != null && p.heightCm < minH) return false;
    if (maxH != null && p.heightCm > maxH) return false;

    final minV = _toNullableInt(_minValueController.text);
    final maxV = _toNullableInt(_maxValueController.text);
    if (minV != null && p.marketValue < minV) return false;
    if (maxV != null && p.marketValue > maxV) return false;

    return true;
  }

  String _firstName(String name) {
    final t = name.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first.toLowerCase();
  }

  List<_PlayerRow> get _visiblePlayers {
    final filtered = _allPlayers.where(_passesFilters).toList();

    int compareNum(int? a, int? b) => (a ?? 9999).compareTo(b ?? 9999);
    int compareString(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      int result;
      switch (_sortField) {
        case 'Age':
          result = _ageInYears(a.player.dateOfBirth).compareTo(
            _ageInYears(b.player.dateOfBirth),
          );
          break;
        case 'Value':
          result = a.player.marketValue.compareTo(b.player.marketValue);
          break;
        case 'Height':
          result = a.player.heightCm.compareTo(b.player.heightCm);
          break;
        case 'Caps':
          result = a.player.caps.compareTo(b.player.caps);
          break;
        case 'Goals':
          result = a.player.goals.compareTo(b.player.goals);
          break;
        case 'Number':
          result = compareNum(a.player.number, b.player.number);
          break;
        case 'Default':
          result = compareString(a.teamName, b.teamName);
          break;
        case 'Name':
        default:
          result = _firstName(a.player.name).compareTo(_firstName(b.player.name));
      }
      return _sortAscending ? result : -result;
    });
    return filtered;
  }

  void _toggleSetValue(Set<String> set, String value, bool enabled) {
    setState(() {
      if (enabled) {
        set.add(value);
      } else {
        set.remove(value);
      }
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedPositions.clear();
      _selectedCountries.clear();
      _minHeightController.clear();
      _maxHeightController.clear();
      _minValueController.clear();
      _maxValueController.clear();
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final players = _visiblePlayers;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      endDrawer: _buildFilterDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search players',
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
                const SizedBox(width: 8),
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Filters',
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    icon: const Icon(Icons.filter_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${players.length} player${players.length == 1 ? '' : 's'} visible',
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
                    PopupMenuItem(value: 'Default', child: Text('Default')),
                    PopupMenuItem(value: 'Name', child: Text('Name')),
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
            child: players.isEmpty
                ? const Center(child: Text('No players match current filters'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: players.length,
                    itemBuilder: (context, i) => _buildPlayerCard(players[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'Filter Players',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              trailing: TextButton(
                onPressed: _clearAllFilters,
                child: const Text('Clear'),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  _positionFilterSection(),
                  _rangeSection(
                    title: 'Height (cm)',
                    minController: _minHeightController,
                    maxController: _maxHeightController,
                  ),
                  _rangeSection(
                    title: 'Market Value (EUR)',
                    minController: _minValueController,
                    maxController: _maxValueController,
                  ),
                  _multiSelectSection(
                    title: 'Country',
                    options: _availableCountries,
                    selected: _selectedCountries,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeSection({
    required String title,
    required TextEditingController minController,
    required TextEditingController maxController,
  }) {
    return ExpansionTile(
      title: Text(title),
      subtitle: const Text('Set min / max'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Min',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: maxController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Max',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TeamInfo? _teamByName(String name) {
    for (final t in widget.teams) {
      if (t.name == name) return t;
    }
    return null;
  }

  Widget _positionFilterSection() {
    return ExpansionTile(
      title: const Text('Position'),
      subtitle: Text(
        _selectedPositions.isEmpty
            ? 'All'
            : '${_selectedPositions.length} position${_selectedPositions.length == 1 ? '' : 's'} selected',
      ),
      children: [
        _positionCategoryBlock('Goalkeeper', 'Goalkeeper'),
        _positionCategoryBlock('Defender', 'Defence'),
        _positionCategoryBlock('Midfielder', 'Midfield'),
        _positionCategoryBlock('Attacker', 'Attack'),
      ],
    );
  }

  Widget _positionCategoryBlock(String categoryKey, String label) {
    final positions = _positionsByCategory[categoryKey] ?? [];
    if (positions.isEmpty) return const SizedBox.shrink();

    final allSelected =
        positions.isNotEmpty && positions.every(_selectedPositions.contains);
    final someSelected = positions.any(_selectedPositions.contains);
    final detailExpanded =
        _positionDetailExpandedByCategory[categoryKey] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              tristate: true,
              value: someSelected && !allSelected ? null : allSelected,
              onChanged: (_) {
                setState(() {
                  if (allSelected) {
                    for (final p in positions) {
                      _selectedPositions.remove(p);
                    }
                  } else {
                    _selectedPositions.addAll(positions);
                  }
                });
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All $label',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    positions.map(abbreviatePlayerPosition).join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: Colors.blueGrey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: detailExpanded ? 'Hide positions' : 'Show positions',
              visualDensity: VisualDensity.compact,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () {
                setState(() {
                  _positionDetailExpandedByCategory[categoryKey] =
                      !detailExpanded;
                });
              },
              icon: Icon(
                detailExpanded ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ],
        ),
        if (detailExpanded) ...[
          const Divider(height: 1),
          ...positions.map(
            (pos) => CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selectedPositions.contains(pos),
              title: Text(abbreviatePlayerPosition(pos)),
              subtitle: Text(
                pos,
                style:
                    TextStyle(fontSize: 11, color: Colors.blueGrey[500]),
              ),
              onChanged: (checked) => setState(() {
                if (checked ?? false) {
                  _selectedPositions.add(pos);
                } else {
                  _selectedPositions.remove(pos);
                }
              }),
            ),
          ),
        ],
        const Divider(height: 16, thickness: 0.8),
      ],
    );
  }

  Widget _multiSelectSection({
    required String title,
    required List<String> options,
    required Set<String> selected,
  }) {
    return ExpansionTile(
      title: Text(title),
      subtitle: selected.isEmpty ? const Text('All') : Text('${selected.length} selected'),
      children: options
          .map(
            (option) => CheckboxListTile(
              value: selected.contains(option),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(option),
              onChanged: (checked) =>
                  _toggleSetValue(selected, option, checked ?? false),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPlayerCard(_PlayerRow row) {
    final p = row.player;
    final categoryColor = _positionCategoryColor(p.categoryPosition);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: categoryColor, width: 6)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          visualDensity: const VisualDensity(vertical: -4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final team = _teamByName(row.teamName);
                    if (team == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TeamDetailScreen(team: team),
                      ),
                    );
                  },
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blueGrey[50],
                    child: ClipOval(
                      child: SvgPicture.asset(
                        roundFlagAssetForTeam(row.teamName),
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
                trailing: Text(
                  _formatMarketValue(p.marketValue),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
          title: Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                p.position,
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '•  ${_ageInYears(p.dateOfBirth)}y | ${_formatHeight(p.heightCm)}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '•  ${p.caps}/${p.goals}',
                  style: TextStyle(
                    color: Colors.blueGrey[400],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              _buildFootBadge(p.preferredFoot),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 8),
                  _playerDetailRow('Club', p.club),
                  _playerDetailRow(
                    'DOB',
                    p.dateOfBirth != null
                        ? '${p.dateOfBirth!.day.toString().padLeft(2, '0')}/'
                            '${p.dateOfBirth!.month.toString().padLeft(2, '0')}/'
                            '${p.dateOfBirth!.year}'
                        : '-',
                  ),
                  _playerDetailRow(
                    'Debut',
                    p.debut != null
                        ? '${p.debut!.day.toString().padLeft(2, '0')}/'
                            '${p.debut!.month.toString().padLeft(2, '0')}/'
                            '${p.debut!.year}'
                        : 'N/A',
                  ),
                ],
              ),
            ),
          ],
        ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildFootBadge(String foot) {
    final f = foot.toLowerCase();
    String label;
    Color color;
    if (f.contains('left')) {
      label = 'L';
      color = Colors.orange[700]!;
    } else if (f.contains('both')) {
      label = 'B';
      color = Colors.green[700]!;
    } else {
      label = 'R';
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
          color: color,
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
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
    return now.year -
        dob.year -
        (now.month < dob.month ||
                (now.month == dob.month && now.day < dob.day)
            ? 1
            : 0);
  }
}
