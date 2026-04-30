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
  const TeamInfo(this.name, {this.note, this.group, this.squad, this.coach});

  final String name;
  final String? note;
  final String? group;
  final List<TeamPlayer>? squad;
  final TeamCoach? coach;

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      json['name'] as String? ?? '',
      note: json['note'] as String?,
      group: json['group'] as String?,
      squad: (json['squad'] as List<dynamic>?)
          ?.map((item) => TeamPlayer.fromJson(item as Map<String, dynamic>))
          .toList(),
      coach: json['coach'] is Map<String, dynamic>
          ? TeamCoach.fromJson(json['coach'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TeamCoach {
  const TeamCoach({
    required this.name,
    required this.since,
    required this.previousRole,
    required this.nationality,
  });

  final String name;
  final String since;
  final String previousRole;
  final String nationality;

  factory TeamCoach.fromJson(Map<String, dynamic> json) {
    return TeamCoach(
      name: json['name'] as String? ?? '',
      since: json['since'] as String? ?? '',
      previousRole: json['previousRole'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
    );
  }
}

class TeamPlayer {
  const TeamPlayer({
    this.number,
    required this.name,
    required this.position,
    required this.dateOfBirth,
    required this.club,
    required this.heightCm,
    required this.preferredFoot,
    required this.caps,
    required this.goals,
    required this.debut,
    required this.marketValue,
  });

  final int? number;
  final String name;
  final String position;
  final DateTime? dateOfBirth;
  final String club;
  final int heightCm;
  final String preferredFoot;
  final int caps;
  final int goals;
  final DateTime? debut;
  final int marketValue;

  String get categoryPosition {
    final pos = position.toLowerCase();
    if (pos == 'goalkeeper') return 'Goalkeeper';
    if (pos == 'centre-back' || pos == 'left-back' || pos == 'right-back') {
      return 'Defender';
    }
    if (pos == 'right winger' ||
        pos == 'left winger' ||
        pos == 'second striker' ||
        pos == 'centre-forward') {
      return 'Attacker';
    }
    return 'Midfielder';
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    final raw = value?.toString() ?? '';
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final dateOnly = raw.split('(').first.trim();
    try {
      final parts = dateOnly.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  factory TeamPlayer.fromJson(Map<String, dynamic> json) {
    return TeamPlayer(
      number: _parseNullableInt(json['number']),
      name: json['name'] as String? ?? '',
      position: json['position'] as String? ?? '',
      dateOfBirth: _parseDate(json['dateOfBirth']),
      club: json['club'] as String? ?? '',
      heightCm: _parseInt(json['height']),
      preferredFoot: json['preferredFoot'] as String? ?? '',
      caps: _parseInt(json['caps']),
      goals: _parseInt(json['goals']),
      debut: _parseDate(json['debut']),
      marketValue: _parseInt(json['marketValue']),
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
