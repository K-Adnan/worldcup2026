import 'dart:convert';

import 'package:flutter/services.dart';

class DaySchedule {
  const DaySchedule({required this.date, required this.matches});

  final String date;
  final List<MatchFixture> matches;

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    final matchesJson = json['matches'] as List<dynamic>? ?? <dynamic>[];
    return DaySchedule(
      date: json['date'] as String? ?? '',
      matches: matchesJson
          .map((item) => MatchFixture.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MatchFixture {
  const MatchFixture({
    required this.time,
    required this.homeTeam,
    required this.awayTeam,
    required this.broadcaster,
    this.stadium = 'TBC',
  });

  final String time;
  final String homeTeam;
  final String awayTeam;
  final String broadcaster;
  final String stadium;

  factory MatchFixture.fromJson(Map<String, dynamic> json) {
    return MatchFixture(
      time: json['time'] as String? ?? '',
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      broadcaster: json['broadcaster'] as String? ?? '',
      stadium: json['stadium'] as String? ?? 'TBC',
    );
  }
}

class TeamInfo {
  const TeamInfo(this.name, {this.note});

  final String name;
  final String? note;

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      json['name'] as String? ?? '',
      note: json['note'] as String?,
    );
  }
}

class WorldCupData {
  const WorldCupData({required this.scheduleByDay, required this.teams});

  final List<DaySchedule> scheduleByDay;
  final List<TeamInfo> teams;
}

class WorldCupDataLoader {
  static Future<WorldCupData> load() async {
    final scheduleSource = await rootBundle.loadString(
      'assets/data/schedule.json',
    );
    final teamsSource = await rootBundle.loadString('assets/data/teams.json');

    final scheduleList = jsonDecode(scheduleSource) as List<dynamic>;
    final teamsList = jsonDecode(teamsSource) as List<dynamic>;

    return WorldCupData(
      scheduleByDay: scheduleList
          .map((item) => DaySchedule.fromJson(item as Map<String, dynamic>))
          .toList(),
      teams: teamsList
          .map((item) => TeamInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
