import 'package:flutter/material.dart';

class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Table coming soon.\nGroup standings will be shown here once matches are complete.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
