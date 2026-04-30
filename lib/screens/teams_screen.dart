import 'package:flutter/material.dart';

import '../data/world_cup_data.dart';
import 'team_detail_screen.dart';
import '../utils/flag_asset.dart';

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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TeamDetailScreen(team: team),
              ),
            );
          },
          leading: SizedBox(
            width: 30,
            child: Image.asset(
              flagAssetForTeam(team.name),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.flag_outlined),
            ),
          ),
          title: Text(team.name),
          subtitle: team.note == null ? null : Text(team.note!),
        );
      },
    );
  }
}
