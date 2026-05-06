import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/world_cup_data.dart';
import '../../utils/player_position.dart';

const List<String> kFormationOptions = [
  '3-2-4-1',
  '3-5-2',
  '3-4-3',
  '4-1-2-3',
  '4-1-3-2',
  '4-1-4-1',
  '4-2-3-1',
  '4-3-2-1',
  '4-3-3',
  '4-4-2',
  '5-3-2',
  '5-4-1',
];

class MatchPitch extends StatefulWidget {
  const MatchPitch({
    super.key,
    required this.height,
    required this.matchNumber,
    required this.initialHomeFormation,
    required this.initialAwayFormation,
    required this.homeSquad,
    required this.awaySquad,
    this.initialHomeSlotPlayers,
    this.initialAwaySlotPlayers,
  });

  final double height;
  final int matchNumber;
  final String initialHomeFormation;
  final String initialAwayFormation;
  final List<TeamPlayer> homeSquad;
  final List<TeamPlayer> awaySquad;
  final List<PitchSlotPlayer>? initialHomeSlotPlayers;
  final List<PitchSlotPlayer>? initialAwaySlotPlayers;

  @override
  State<MatchPitch> createState() => _MatchPitchState();
}

class _MatchPitchState extends State<MatchPitch> {
  late String _homeFormation;
  late String _awayFormation;
  late List<PitchSlotPlayer> _homeLabels;
  late List<PitchSlotPlayer> _awayLabels;

  @override
  void initState() {
    super.initState();
    _homeFormation = _coerceFormation(widget.initialHomeFormation);
    _awayFormation = _coerceFormation(widget.initialAwayFormation);
    _homeLabels = _labelsFromInitial(_homeFormation, widget.initialHomeSlotPlayers);
    _awayLabels = _labelsFromInitial(_awayFormation, widget.initialAwaySlotPlayers);
  }

  @override
  void didUpdateWidget(covariant MatchPitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchNumber != widget.matchNumber) {
      _homeFormation = _coerceFormation(widget.initialHomeFormation);
      _awayFormation = _coerceFormation(widget.initialAwayFormation);
      _homeLabels = _labelsFromInitial(_homeFormation, widget.initialHomeSlotPlayers);
      _awayLabels = _labelsFromInitial(_awayFormation, widget.initialAwaySlotPlayers);
      return;
    }
    if (oldWidget.initialHomeFormation != widget.initialHomeFormation) {
      _homeFormation = _coerceFormation(widget.initialHomeFormation);
      _homeLabels = _labelsFromInitial(_homeFormation, widget.initialHomeSlotPlayers);
    } else {
      _maybeApplyRemoteLabels(
        formation: _homeFormation,
        remote: widget.initialHomeSlotPlayers,
        isHome: true,
      );
    }
    if (oldWidget.initialAwayFormation != widget.initialAwayFormation) {
      _awayFormation = _coerceFormation(widget.initialAwayFormation);
      _awayLabels = _labelsFromInitial(_awayFormation, widget.initialAwaySlotPlayers);
    } else {
      _maybeApplyRemoteLabels(
        formation: _awayFormation,
        remote: widget.initialAwaySlotPlayers,
        isHome: false,
      );
    }
  }

  void _maybeApplyRemoteLabels({
    required String formation,
    required List<PitchSlotPlayer>? remote,
    required bool isHome,
  }) {
    final n = _slotCount(formation);
    final local = isHome ? _homeLabels : _awayLabels;
    if (remote == null || remote.length != n || remote.length != local.length) {
      return;
    }
    var same = true;
    for (var i = 0; i < n; i++) {
      if (local[i].number != remote[i].number || local[i].name != remote[i].name) {
        same = false;
        break;
      }
    }
    if (same) return;
    setState(() {
      if (isHome) {
        _homeLabels = List<PitchSlotPlayer>.from(remote);
      } else {
        _awayLabels = List<PitchSlotPlayer>.from(remote);
      }
    });
  }

  List<PitchSlotPlayer> _labelsFromInitial(
      String formation,
      List<PitchSlotPlayer>? initial,
      ) {
    final n = _slotCount(formation);
    if (initial != null && initial.length == n) {
      return List<PitchSlotPlayer>.from(initial);
    }
    return List<PitchSlotPlayer>.generate(n, (_) => const PitchSlotPlayer());
  }

  String _coerceFormation(String value) {
    final v = value.trim();
    if (v.isEmpty || !kFormationOptions.contains(v)) {
      return '4-4-2';
    }
    return v;
  }

  static List<int> _parseFormation(String label) {
    return label.split('-').map((s) => int.tryParse(s.trim()) ?? 0).where((n) => n > 0).toList();
  }

  static int _slotCount(String formation) {
    final rows = _parseFormation(formation);
    if (rows.isEmpty) return 0;
    return 1 + rows.fold<int>(0, (a, b) => a + b);
  }

  Future<void> _persistFormation({required bool home, required String formation}) async {
    final field = home ? 'homeFormation' : 'awayFormation';
    final labels = home ? _homeLabels : _awayLabels;
    final slotField = home ? 'homeSlotPlayers' : 'awaySlotPlayers';
    try {
      await FirebaseFirestore.instance.collection('schedule').doc(widget.matchNumber.toString()).update({
        field: formation,
        slotField: labels.map((e) => e.toFirestoreMap()).toList(),
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save formation')),
      );
    }
  }

  Future<void> _persistSlotPlayers({required bool home}) async {
    final field = home ? 'homeSlotPlayers' : 'awaySlotPlayers';
    final labels = home ? _homeLabels : _awayLabels;
    try {
      await FirebaseFirestore.instance
          .collection('schedule')
          .doc(widget.matchNumber.toString())
          .update({field: labels.map((e) => e.toFirestoreMap()).toList()});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save lineup')),
      );
    }
  }

  static String _surname(String fullName) {
    final t = fullName.trim();
    if (t.isEmpty) return '';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first;
    return parts.last;
  }

  static String _surnameForDisplay(String fullName) {
    final s = _surname(fullName);
    if (s.length <= 10) return s;
    return '${s.substring(0, 10)}.';
  }

  static PitchSlotPlayer _slotFromKey(String key) {
    if (key.isEmpty) return const PitchSlotPlayer();
    final sep = key.indexOf(':::');
    if (sep < 0) return const PitchSlotPlayer();
    final numPart = int.tryParse(key.substring(0, sep));
    final name = key.substring(sep + 3);
    final number = (numPart == null || numPart < 0) ? null : numPart;
    return PitchSlotPlayer(number: number, name: name);
  }

  String? _keyForLabel(PitchSlotPlayer label) {
    if (!label.isAssigned) return '';
    return '${label.number ?? -1}:::${label.name}';
  }

  String _positionForKey(List<TeamPlayer> squad, String key) {
    for (final p in squad) {
      if ('${p.number ?? -1}:::${p.name}' == key) return p.position;
    }
    return '';
  }

  Future<void> _openPlayerPicker({
    required bool home,
    required int slotIndex,
  }) async {
    final squad = home ? widget.homeSquad : widget.awaySquad;
    if (squad.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No squad data for this team yet')),
      );
      return;
    }

    final sorted = List<TeamPlayer>.from(squad)
      ..sort((a, b) => (a.number ?? 9999).compareTo(b.number ?? 9999));

    final isGoalkeeperSlot = slotIndex == 0;
    final sideLabels = home ? _homeLabels : _awayLabels;
    final occupiedKeys = sideLabels
        .asMap()
        .entries
        .where((e) => e.key != slotIndex && e.value.isAssigned)
        .map((e) => '${e.value.number ?? -1}:::${e.value.name}')
        .toSet();

    final eligiblePlayers = sorted.where((p) {
      final key = '${p.number ?? -1}:::${p.name}';
      if (occupiedKeys.contains(key)) return false;
      if (isGoalkeeperSlot) {
        return p.categoryPosition == 'Goalkeeper';
      }
      return p.categoryPosition != 'Goalkeeper';
    }).toList();

    final current = home ? _homeLabels[slotIndex] : _awayLabels[slotIndex];
    final savedKey = _keyForLabel(current) ?? '';
    final orphanAssigned = current.isAssigned &&
        savedKey.isNotEmpty &&
        !eligiblePlayers.any((p) => '${p.number ?? -1}:::${p.name}' == savedKey);

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchablePlayerPicker(
        players: eligiblePlayers,
        savedKey: savedKey,
        orphanAssigned: orphanAssigned,
        orphanLabel: current.name,
        orphanPosition: _positionForKey(squad, savedKey),
      ),
    );

    if (!mounted || picked == null) return;

    setState(() {
      final slot = _slotFromKey(picked);
      if (home) {
        _homeLabels = List<PitchSlotPlayer>.from(_homeLabels)..[slotIndex] = slot;
      } else {
        _awayLabels = List<PitchSlotPlayer>.from(_awayLabels)..[slotIndex] = slot;
      }
    });
    await _persistSlotPlayers(home: home);
  }

  static List<double> _getSmartXs(int count) {
    if (count <= 1) return [0.5];
    double widthFactor;
    if (count == 2) {
      widthFactor = 0.30;
    } else if (count == 3) {
      widthFactor = 0.55;
    } else if (count == 4) {
      widthFactor = 0.80;
    } else {
      widthFactor = 0.85;
    }
    final startX = (1.0 - widthFactor) / 2;
    return List<double>.generate(
      count,
          (i) => startX + (i * widthFactor / (count - 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color pitchLineColor = Colors.white54;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1B8F3A),
            const Color(0xFF167A31),
            const Color(0xFF1B8F3A),
            const Color(0xFF167A31),
            const Color(0xFF1B8F3A),
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cw = constraints.maxWidth;
          final ch = constraints.maxHeight;
          final innerW = cw - 32;
          final innerH = ch - 32;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Pitch Markings
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: pitchLineColor, width: 1.5),
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  height: 1.5,
                  color: pitchLineColor,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              Center(
                child: Container(
                  width: widget.height * 0.20,
                  height: widget.height * 0.20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: pitchLineColor, width: 1.5),
                  ),
                ),
              ),
              const Center(
                child: CircleAvatar(radius: 2, backgroundColor: pitchLineColor),
              ),
              _buildPenaltyArea(top: 16, isTop: true, lineColor: pitchLineColor),
              _buildPenaltyArea(bottom: 16, isTop: false, lineColor: pitchLineColor),
              ..._buildCorners(pitchLineColor),

              // Tactical Overlay (Players)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ..._buildFormationPlayersWithLabels(
                        context,
                        innerW,
                        innerH,
                        home: true,
                        formation: _homeFormation,
                        labels: _homeLabels,
                      ),
                      ..._buildFormationPlayersWithLabels(
                        context,
                        innerW,
                        innerH,
                        home: false,
                        formation: _awayFormation,
                        labels: _awayLabels,
                      ),
                    ],
                  ),
                ),
              ),

              // Modern Formation Selectors
              Positioned(
                top: 12,
                left: 20,
                right: 20,
                child: _formationDropdown(true),
              ),
              Positioned(
                bottom: 12,
                left: 20,
                right: 20,
                child: _formationDropdown(false),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _formationDropdown(bool isHome) {
    final value = isHome ? _homeFormation : _awayFormation;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      alignment: Alignment.center,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          icon: const Icon(Icons.shield_outlined, color: Colors.white70, size: 16),
          dropdownColor: const Color(0xFF001D3D),
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
          items: kFormationOptions
              .map((f) => DropdownMenuItem(value: f, child: Center(child: Text(f))))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            setState(() {
              if (isHome) {
                _homeFormation = v;
                _homeLabels = List<PitchSlotPlayer>.generate(
                  _slotCount(v),
                      (_) => const PitchSlotPlayer(),
                );
              } else {
                _awayFormation = v;
                _awayLabels = List<PitchSlotPlayer>.generate(
                  _slotCount(v),
                      (_) => const PitchSlotPlayer(),
                );
              }
            });
            await _persistFormation(home: isHome, formation: v);
          },
        ),
      ),
    );
  }

  static const double _colW = 80;

  List<Widget> _buildFormationPlayersWithLabels(
      BuildContext context,
      double innerW,
      double innerH, {
        required bool home,
        required String formation,
        required List<PitchSlotPlayer> labels,
      }) {
    final rows = _parseFormation(formation);
    if (rows.isEmpty) return [];

    final halfH = innerH * 0.5;
    final out = <Widget>[];
    var slotIndex = 0;

    void addSlot(double fracX, double yCenterPx) {
      final index = slotIndex;
      final label = labels[index];
      out.add(
        Positioned(
          left: fracX * innerW - _colW / 2,
          top: yCenterPx - 25,
          width: _colW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _openPlayerPicker(home: home, slotIndex: index),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: label.isAssigned ? Colors.white : Colors.white24,
                    border: Border.all(
                      color: const Color(0xFF001D3D),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label.isAssigned && label.number != null ? '${label.number}' : '+',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: label.isAssigned ? const Color(0xFF001D3D) : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (label.isAssigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _surnameForDisplay(label.name).toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      slotIndex++;
    }

    if (home) {
      addSlot(0.5, 45); // GK
      final nRows = rows.length;
      for (var j = 0; j < nRows; j++) {
        final count = rows[j];
        final xs = _getSmartXs(count);
        final t = j / (nRows - 1 == 0 ? 1 : nRows - 1);
        final y = 100 + (t * (halfH - 140));
        for (final x in xs) {
          addSlot(x, y);
        }
      }
    } else {
      addSlot(0.5, innerH - 45); // GK
      final nRows = rows.length;
      for (var j = 0; j < nRows; j++) {
        final count = rows[j];
        final xs = _getSmartXs(count);
        final t = j / (nRows - 1 == 0 ? 1 : nRows - 1);
        final y = innerH - (100 + (t * (halfH - 140)));
        for (final x in xs) {
          addSlot(x, y);
        }
      }
    }

    return out;
  }

  Widget _buildPenaltyArea({double? top, double? bottom, required bool isTop, required Color lineColor}) {
    return Positioned(
      left: 0, right: 0, top: top, bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isTop) _buildArc(lineColor, showBottomHalf: true),
          Stack(
            alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            children: [
              Container(width: 170, height: 75, decoration: BoxDecoration(border: Border.all(color: lineColor, width: 1.5))),
              Container(width: 60, height: 25, decoration: BoxDecoration(border: Border.all(color: lineColor, width: 1.5))),
            ],
          ),
          if (isTop) _buildArc(lineColor, showBottomHalf: false),
        ],
      ),
    );
  }

  Widget _buildArc(Color color, {required bool showBottomHalf}) {
    return ClipRect(
      child: Align(
        alignment: showBottomHalf ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 0.5,
        child: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
        ),
      ),
    );
  }

  List<Widget> _buildCorners(Color color) {
    const double sz = 10;
    return [
      Positioned(top: 16, left: 16, child: _corner(color, br: sz)),
      Positioned(top: 16, right: 16, child: _corner(color, bl: sz)),
      Positioned(bottom: 16, left: 16, child: _corner(color, tr: sz)),
      Positioned(bottom: 16, right: 16, child: _corner(color, tl: sz)),
    ];
  }

  Widget _corner(Color c, {double? tl, double? tr, double? bl, double? br}) {
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: (bl != null || br != null) ? c : Colors.transparent, width: 1.5),
          bottom: BorderSide(color: (tl != null || tr != null) ? c : Colors.transparent, width: 1.5),
          left: BorderSide(color: (tr != null || br != null) ? c : Colors.transparent, width: 1.5),
          right: BorderSide(color: (tl != null || bl != null) ? c : Colors.transparent, width: 1.5),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(tl ?? 0),
          topRight: Radius.circular(tr ?? 0),
          bottomLeft: Radius.circular(bl ?? 0),
          bottomRight: Radius.circular(br ?? 0),
        ),
      ),
    );
  }
}

class _SearchablePlayerPicker extends StatefulWidget {
  const _SearchablePlayerPicker({
    required this.players,
    required this.savedKey,
    required this.orphanAssigned,
    required this.orphanLabel,
    required this.orphanPosition,
  });

  final List<TeamPlayer> players;
  final String savedKey;
  final bool orphanAssigned;
  final String orphanLabel;
  final String orphanPosition;

  @override
  State<_SearchablePlayerPicker> createState() => _SearchablePlayerPickerState();
}

class _SearchablePlayerPickerState extends State<_SearchablePlayerPicker> {
  String _query = '';

  String _formatMarketValue(int value) {
    if (value >= 1000000000) return '€${(value / 1000000000).toStringAsFixed(2)}B';
    if (value >= 1000000) return '€${(value / 1000000).toStringAsFixed(1)}M';
    return '€${(value / 1000).toStringAsFixed(0)}k';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.players.where((p) =>
    p.name.toLowerCase().contains(_query.toLowerCase()) ||
        p.position.toLowerCase().contains(_query.toLowerCase())
    ).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search squad...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF001D3D)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  child: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (widget.orphanAssigned)
                  _buildPlayerTile(context, widget.orphanLabel, widget.orphanPosition, widget.savedKey, 0, 0, 0, ""),

                _buildSection("Goalkeepers", filtered.where((p) => p.categoryPosition == "Goalkeeper")),
                _buildSection("Defenders", filtered.where((p) => p.categoryPosition == "Defender")),
                _buildSection("Midfielders", filtered.where((p) => p.categoryPosition == "Midfielder")),
                _buildSection("Attackers", filtered.where((p) => p.categoryPosition == "Attacker")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Iterable<TeamPlayer> players) {
    if (players.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(title.toUpperCase(), style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.2, color: Colors.blueGrey)),
        ),
        ...players.map((p) => _buildPlayerTile(
            context, p.name, p.position, '${p.number ?? -1}:::${p.name}',
            p.number ?? 0, p.marketValue, p.heightCm, p.preferredFoot
        )),
      ],
    );
  }

  Widget _buildPlayerTile(BuildContext context, String name, String pos, String key, int num, int val, int h, String foot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: () => Navigator.pop(context, key),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF001D3D),
          radius: 18,
          child: Text('$num', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('$pos • ${h}cm • $foot'),
        trailing: Text(_formatMarketValue(val), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF1B8F3A), fontSize: 13)),
      ),
    );
  }
}