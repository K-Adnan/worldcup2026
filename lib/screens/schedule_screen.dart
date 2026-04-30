import 'package:flutter/material.dart';

import '../data/world_cup_data.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.scheduleByDay});

  final List<DaySchedule> scheduleByDay;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: scheduleByDay.length,
      itemBuilder: (context, index) {
        final daySchedule = scheduleByDay[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daySchedule.date,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                ...daySchedule.matches.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${match.time} ${match.homeTeam} v ${match.awayTeam}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text('Stadium: ${match.stadium}'),
                        Text('Broadcaster: ${match.broadcaster}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
