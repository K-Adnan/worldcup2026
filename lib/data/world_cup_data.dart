import 'package:cloud_firestore/cloud_firestore.dart';

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
    required this.date,
    required this.time,
    required this.homeTeam,
    required this.awayTeam,
    required this.broadcaster,
    required this.stage,
    this.stadium = 'TBC',
    this.city = 'TBC',
    this.homeScore = '-',
    this.awayScore = '-',
  });

  final int matchNumber;
  final String date;
  final String time;
  final String homeTeam;
  final String awayTeam;
  final String broadcaster;
  final String stage;
  final String stadium;
  final String city;
  final String homeScore;
  final String awayScore;

  factory MatchFixture.fromJson(Map<String, dynamic> json) {
    return MatchFixture(
      matchNumber: json['matchNumber'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      homeTeam: json['homeTeam'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      broadcaster: json['broadcaster'] as String? ?? '',
      stage: json['stage'] as String? ?? 'TBC',
      stadium: json['stadium'] as String? ?? 'TBC',
      city: json['city'] as String? ?? 'TBC',
      homeScore: json['homeScore'] as String? ?? '-',
      awayScore: json['awayScore'] as String? ?? '-',
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
    final teamsSnapshot = await FirebaseFirestore.instance
        .collection('teams')
        .orderBy('name')
        .get();

    final scheduleSnapshot = await FirebaseFirestore.instance
        .collection('schedule')
        .orderBy('matchNumber')
        .get();

    final teams = teamsSnapshot.docs
        .map((doc) => TeamInfo.fromJson(doc.data()))
        .toList();

    final matches = scheduleSnapshot.docs
        .map((doc) => MatchFixture.fromJson(doc.data()))
        .toList();

    final grouped = <String, List<MatchFixture>>{};
    for (final match in matches) {
      grouped.putIfAbsent(match.date, () => <MatchFixture>[]).add(match);
    }

    final scheduleByDay = grouped.entries
        .map((entry) => DaySchedule(date: entry.key, matches: entry.value))
        .toList();

    return WorldCupData(
      scheduleByDay: scheduleByDay,
      teams: teams,
    );
  }
}
