import 'package:flutter/material.dart';

import '../data/world_cup_data.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key, required this.teams});

  final List<TeamInfo> teams;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: teams.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final team = teams[index];
        return ListTile(
          title: Text(team.name),
          subtitle: team.note == null ? null : Text(team.note!),
        );
      },
    );
  }
}
