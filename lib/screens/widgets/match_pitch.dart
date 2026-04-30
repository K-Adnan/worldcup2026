import 'package:flutter/material.dart';

class MatchPitch extends StatelessWidget {
  const MatchPitch({
    super.key,
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    const Color pitchLineColor = Colors.white70;

    return Container(
      height: height,
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
      child: Stack(
        children: [
          // Outer Boundary
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

          // Halfway Line
          Center(
            child: Container(
              height: 1.5,
              color: pitchLineColor,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),

          // Center Circle
          Center(
            child: Container(
              width: height * 0.22,
              height: height * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: pitchLineColor, width: 1.5),
              ),
            ),
          ),
          const Center(child: CircleAvatar(radius: 2, backgroundColor: pitchLineColor)),

          // Areas
          _buildPenaltyArea(top: 16, isTop: true, lineColor: pitchLineColor),
          _buildPenaltyArea(bottom: 16, isTop: false, lineColor: pitchLineColor),

          ..._buildCorners(pitchLineColor),
        ],
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
          // Bottom goal arc sits above the box and bulges toward midfield.
          if (!isTop) _buildArc(lineColor, showBottomHalf: true),
          Stack(
            alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            children: [
              // 18-Yard Box
              Container(
                width: 180,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: lineColor, width: 1.5),
                ),
              ),
              // 6-Yard Box
              Container(
                width: 70,
                height: 30,
                decoration: BoxDecoration(
                  border: Border.all(color: lineColor, width: 1.5),
                ),
              ),
              // Penalty Spot
              Positioned(
                top: isTop ? 60 : null,
                bottom: isTop ? null : 60,
                child: CircleAvatar(radius: 2, backgroundColor: lineColor),
              ),
            ],
          ),
          // Top goal arc sits below the box and bulges toward midfield.
          if (isTop) _buildArc(lineColor, showBottomHalf: false),
        ],
      ),
    );
  }

  Widget _buildArc(Color color, {required bool showBottomHalf}) {
    return ClipRect(
      child: Align(
        // To show the bottom half of the circle, we align the circle to the TOP of the clipper
        // To show the top half of the circle, we align the circle to the BOTTOM of the clipper
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