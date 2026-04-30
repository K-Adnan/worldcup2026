import 'package:flutter/material.dart';

const List<String> kFormationOptions = [
  '3-5-2',
  '3-4-3',
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
  });

  final double height;

  @override
  State<MatchPitch> createState() => _MatchPitchState();
}

class _MatchPitchState extends State<MatchPitch> {
  String _homeFormation = '4-4-2';
  String _awayFormation = '4-4-2';

  static List<int> _parseFormation(String label) {
    return label.split('-').map((s) => int.tryParse(s.trim()) ?? 0).where((n) => n > 0).toList();
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
                      ..._buildFormationPlayers(
                        cw - 32,
                        ch - 32,
                        isTopHalf: true,
                        formation: _homeFormation,
                      ),
                      ..._buildFormationPlayers(
                        cw - 32,
                        ch - 32,
                        isTopHalf: false,
                        formation: _awayFormation,
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
              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              if (isHome) {
                _homeFormation = v;
              } else {
                _awayFormation = v;
              }
            });
          },
        ),
      ),
    );
  }

  List<Widget> _buildFormationPlayers(
      double innerW,
      double innerH, {
        required bool isTopHalf,
        required String formation,
      }) {
    const double r = 8;
    const double diameter = r * 2;
    final rows = _parseFormation(formation);
    if (rows.isEmpty) return [];

    final halfH = innerH * 0.5;
    final List<Widget> out = [];

    void addDotFracXCentery(double fracXFromLeft, double yCenterPx) {
      out.add(
        Positioned(
          left: fracXFromLeft * innerW - r,
          top: yCenterPx - r,
          child: _playerDot(diameter),
        ),
      );
    }

    final nRows = rows.length;

    // Custom X-spacing: Rows of 2 or 3 only occupy 50% width (0.25 to 0.75)
    List<double> getSmartXs(int count) {
      if (count <= 1) return [0.5];
      double widthFactor;
      if (count == 2) {
        widthFactor = 0.30; // 2 players use 30% width
      } else if (count == 3) {
        widthFactor = 0.55; // 3 players use 50% width
      } else {
        widthFactor = 0.85; // 4+ players spread out
      }
      double startX = (1.0 - widthFactor) / 2;
      return List.generate(count, (i) => startX + (i * widthFactor / (count - 1)));
    }

    if (isTopHalf) {
      // Top Half GK (Home)
      addDotFracXCentery(0.5, 40);

      for (var j = 0; j < nRows; j++) {
        final count = rows[j];
        final xs = getSmartXs(count);
        // Vertically occupy from 20% to 90% of the half-pitch
        final t = j / (nRows - 1 == 0 ? 1 : nRows - 1);
        final y = (halfH * 0.30) + (t * (halfH * (0.85 - 0.30)));

        for (var x in xs) {
          addDotFracXCentery(x, y);
        }
      }
    } else {
      // Bottom Half GK (Away)
      addDotFracXCentery(0.5, innerH - 40);

      for (var j = 0; j < nRows; j++) {
        final count = rows[j];
        final xs = getSmartXs(count);
        // Vertically occupy from 20% to 90% of the half-pitch (inverted)
        final t = j / (nRows - 1 == 0 ? 1 : nRows - 1);
        final y = innerH - ((halfH * 0.30) + (t * (halfH * (0.85 - 0.30))));

        for (var x in xs) {
          addDotFracXCentery(x, y);
        }
      }
    }

    return out;
  }

  Widget _playerDot(double diameter) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
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
      ),
    );
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
