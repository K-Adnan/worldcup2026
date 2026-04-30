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
    required this.matchNumber,
    required this.time,
    required this.homeTeam,
    required this.awayTeam,
    required this.broadcaster,
    required this.stage,
    this.stadium = 'TBC',
    this.city = 'TBC',
  });

  final int matchNumber;
  final String time;
  final String homeTeam;
  final String awayTeam;
  final String broadcaster;
  final String stage;
  final String stadium;
  final String city;

  factory MatchFixture.fromJson(Map<String, dynamic> json) {
    return MatchFixture(
      matchNumber: json['matchNumber'] as int? ?? 0,
      time: json['time'] as String? ?? '',
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      broadcaster: json['broadcaster'] as String? ?? '',
      stage: json['stage'] as String? ?? 'TBC',
      stadium: json['stadium'] as String? ?? 'TBC',
      city: json['city'] as String? ?? 'TBC',
    );
  }
}

class TeamInfo {
  const TeamInfo(this.name, {this.note, this.group});

  final String name;
  final String? note;
  final String? group;

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      json['name'] as String? ?? '',
      note: json['note'] as String?,
      group: json['group'] as String?,
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
