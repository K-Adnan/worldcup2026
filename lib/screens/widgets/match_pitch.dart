import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/world_cup_data.dart';

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

  /// Last whitespace-separated token, or the whole string if single token.
  static String _surname(String fullName) {
    final t = fullName.trim();
    if (t.isEmpty) return '';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first;
    return parts.last;
  }

  /// Surname for UI; if longer than 12 chars, `first9..last`.
  static String _surnameForDisplay(String fullName) {
    final s = _surname(fullName);
    if (s.length <= 12) return s;
    return '${s.substring(0, 11)}.';
  }

  static String _playerKey(TeamPlayer p) {
    return '${p.number ?? -1}:::${p.name}';
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

  Future<void> _openPlayerPicker({
    required BuildContext context,
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

    final current = home ? _homeLabels[slotIndex] : _awayLabels[slotIndex];
    final squadKeys = sorted.map(_playerKey).toSet();
    final savedKey = _keyForLabel(current) ?? '';
    final orphanAssigned = current.isAssigned &&
        savedKey.isNotEmpty &&
        !squadKeys.contains(savedKey);
    var dialogSelection =
        current.isAssigned && (squadKeys.contains(savedKey) || orphanAssigned)
            ? savedKey
            : '';

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select player'),
          content: StatefulBuilder(
            builder: (ctx, setDialog) {
              final items = <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('— Unassigned —'),
                ),
                if (orphanAssigned)
                  DropdownMenuItem<String>(
                    value: savedKey,
                    child: Text(
                      '${current.number != null ? '#${current.number} ' : ''}${_surnameForDisplay(current.name)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ...sorted.map(
                  (p) => DropdownMenuItem<String>(
                    value: _playerKey(p),
                    child: Text(
                      '${p.number != null ? '#${p.number} ' : ''}${_surnameForDisplay(p.name)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ];
              final validValues = items.map((e) => e.value!).toSet();
              final dropdownValue = dialogSelection.isNotEmpty &&
                      validValues.contains(dialogSelection)
                  ? dialogSelection
                  : '';
              return InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Player',
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: dropdownValue.isEmpty ? '' : dropdownValue,
                    items: items,
                    onChanged: (v) {
                      if (v == null) return;
                      setDialog(() => dialogSelection = v);
                    },
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, dialogSelection),
              child: const Text('OK'),
            ),
          ],
        );
      },
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
    const Color pitchLineColor = Colors.white70;

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
        borderRadius: BorderRadius.circular(18),
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
                  width: widget.height * 0.22,
                  height: widget.height * 0.22,
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
              Positioned(
                top: 4,
                left: 8,
                right: 8,
                child: _formationDropdown(true),
              ),
              Positioned(
                bottom: 4,
                left: 8,
                right: 8,
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
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          iconEnabledColor: Colors.white,
          dropdownColor: const Color(0xFF001D3D),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          items: kFormationOptions
              .map(
                (f) => DropdownMenuItem(value: f, child: Text(f)),
              )
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

  static const double _dotR = 10;
  static const double _dotD = _dotR * 2;
  static const double _colW = 76;

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
          top: yCenterPx - _dotR,
          width: _colW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _openPlayerPicker(
                  context: context,
                  home: home,
                  slotIndex: index,
                ),
                child: Container(
                  width: _dotD,
                  height: _dotD,
                  margin: EdgeInsets.symmetric(horizontal: (_colW - _dotD) / 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFF001D3D), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label.isAssigned && label.number != null
                        ? '${label.number}'
                        : (label.isAssigned ? '•' : ''),
                    style: TextStyle(
                      fontSize: label.number != null && label.number! >= 10 ? 9 : 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF001D3D),
                      height: 1,
                    ),
                  ),
                ),
              ),
              if (label.isAssigned) ...[
                const SizedBox(height: 2),
                Text(
                  _surnameForDisplay(label.name),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.05,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      slotIndex++;
    }

    if (home) {
      addSlot(0.5, 40);
      final nRows = rows.length;
      for (var j = 0; j < nRows; j++) {
        final count = rows[j];
        final xs = _getSmartXs(count);
        final t = j / (nRows - 1 == 0 ? 1 : nRows - 1);
        final y = (halfH * 0.30) + (t * (halfH * (0.85 - 0.30)));
        for (final x in xs) {
          addSlot(x, y);
        }
      }
    } else {
      addSlot(0.5, innerH - 40);
      final nRows = rows.length;
      for (var j = 0; j < nRows; j++) {
        final count = rows[j];
        final xs = _getSmartXs(count);
        final t = j / (nRows - 1 == 0 ? 1 : nRows - 1);
        final y = innerH - ((halfH * 0.30) + (t * (halfH * (0.85 - 0.30))));
        for (final x in xs) {
          addSlot(x, y);
        }
      }
    }

    return out;
  }

  Widget _buildPenaltyArea({
    double? top,
    double? bottom,
    required bool isTop,
    required Color lineColor,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isTop) _buildArc(lineColor, showBottomHalf: true),
          Stack(
            alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            children: [
              Container(
                width: 180,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: lineColor, width: 1.5),
                ),
              ),
              Container(
                width: 70,
                height: 30,
                decoration: BoxDecoration(
                  border: Border.all(color: lineColor, width: 1.5),
                ),
              ),
              Positioned(
                top: isTop ? 60 : null,
                bottom: isTop ? null : 60,
                child: CircleAvatar(radius: 2, backgroundColor: lineColor),
              ),
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCorners(Color color) {
    const double sz = 12;
    return [
      Positioned(top: 16, left: 16, child: _corner(color, br: sz)),
      Positioned(top: 16, right: 16, child: _corner(color, bl: sz)),
      Positioned(bottom: 16, left: 16, child: _corner(color, tr: sz)),
      Positioned(bottom: 16, right: 16, child: _corner(color, tl: sz)),
    ];
  }

  Widget _corner(Color c, {double? tl, double? tr, double? bl, double? br}) {
    return Container(
      width: 12,
      height: 12,
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
