import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/world_cup_data.dart';
import 'match_center_screen.dart';
import 'team_detail_screen.dart';
import '../utils/flag_asset.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.scheduleByDay,
    required this.teams,
    required this.onRefresh,
    this.onEditStateChanged,
  });

  final List<DaySchedule> scheduleByDay;
  final List<TeamInfo> teams;
  final Future<void> Function() onRefresh;
  final VoidCallback? onEditStateChanged;

  @override
  State<ScheduleScreen> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final Map<int, GlobalKey> _dateChipKeys = <int, GlobalKey>{};
  int _selectedDateIndex = 0;
  bool _isProgrammaticScroll = false;
  bool _isEditing = false;
  bool _isSaving = false;
  final Map<int, TextEditingController> _homeScoreControllers = {};
  final Map<int, TextEditingController> _awayScoreControllers = {};
  final Set<String> _selectedGroups = <String>{};
  final Set<String> _selectedCities = <String>{};
  final Set<String> _selectedTimes = <String>{};
  final Set<String> _selectedBroadcasters = <String>{};

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_syncSelectedDate);
    _pruneInvalidFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onEditStateChanged?.call();
    });
  }

  @override
  void didUpdateWidget(covariant ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Data refresh can change available filter options; remove stale selections.
    _pruneInvalidFilters();
  }

  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_syncSelectedDate);
    for (final controller in _homeScoreControllers.values) {
      controller.dispose();
    }
    for (final controller in _awayScoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncSelectedDate() {
    if (_isProgrammaticScroll) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final visible = positions.where((item) => item.itemTrailingEdge > 0).toList();
    if (visible.isEmpty) return;

    visible.sort((a, b) {
      final aDistance = (a.itemLeadingEdge).abs();
      final bDistance = (b.itemLeadingEdge).abs();
      return aDistance.compareTo(bDistance);
    });

    final current = visible.first;
    if (current.index != _selectedDateIndex && mounted) {
      setState(() {
        _selectedDateIndex = current.index;
      });
      _ensureSelectedDateChipVisible();
    }
  }

  Future<void> _jumpToDate(int index) async {
    setState(() {
      _selectedDateIndex = index;
      _isProgrammaticScroll = true;
    });
    await _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.02,
    );
    if (!mounted) return;
    setState(() {
      _isProgrammaticScroll = false;
      _selectedDateIndex = index;
    });
    _ensureSelectedDateChipVisible();
  }

  void _ensureSelectedDateChipVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _dateChipKeys[_selectedDateIndex];
      final context = key?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  Map<String, String> get _teamToGroup {
    final map = <String, String>{};
    for (final team in widget.teams) {
      final group = team.group?.trim() ?? '';
      if (group.isNotEmpty) {
        map[team.name] = group;
      }
    }
    return map;
  }

  List<String> get _availableGroups {
    final groupSet = <String>{};
    for (final team in widget.teams) {
      final group = team.group?.trim() ?? '';
      if (group.isNotEmpty) {
        groupSet.add(group);
      }
    }
    final groups = groupSet.toList()..sort();
    return groups;
  }

  List<String> get _availableCities {
    final cities = <String>{};
    for (final day in widget.scheduleByDay) {
      for (final match in day.matches) {
        final city = match.city.trim();
        if (city.isNotEmpty) {
          cities.add(city);
        }
      }
    }
    final values = cities.toList()..sort();
    return values;
  }

  Map<String, List<String>> get _citiesByCountry {
    const canadianCities = {'Toronto', 'Vancouver'};
    const mexicanCities = {'Guadalajara', 'Mexico City', 'Monterrey'};

    final canada = <String>[];
    final mexico = <String>[];
    final usa = <String>[];

    for (final city in _availableCities) {
      if (canadianCities.contains(city)) {
        canada.add(city);
      } else if (mexicanCities.contains(city)) {
        mexico.add(city);
      } else {
        usa.add(city);
      }
    }

    return {
      'Canada': canada,
      'Mexico': mexico,
      'USA': usa,
    };
  }

  List<String> get _availableTimes {
    final times = <String>{};
    for (final day in widget.scheduleByDay) {
      for (final match in day.matches) {
        final time = match.time.trim();
        if (time.isNotEmpty) {
          times.add(time);
        }
      }
    }
    final values = times.toList()..sort();
    return values;
  }

  List<String> get _availableBroadcasters {
    final broadcasters = <String>{};
    for (final day in widget.scheduleByDay) {
      for (final match in day.matches) {
        final broadcaster = match.broadcaster.trim();
        if (broadcaster.isNotEmpty) {
          broadcasters.add(broadcaster);
        }
      }
    }
    final values = broadcasters.toList()..sort();
    return values;
  }

  void _pruneInvalidFilters() {
    _selectedGroups.removeWhere((g) => !_availableGroups.contains(g));
    _selectedCities.removeWhere((c) => !_availableCities.contains(c));
    _selectedTimes.removeWhere((t) => !_availableTimes.contains(t));
    _selectedBroadcasters
        .removeWhere((b) => !_availableBroadcasters.contains(b));
  }

  List<DaySchedule> get _filteredScheduleByDay {
    final filteredDays = <DaySchedule>[];
    for (final day in widget.scheduleByDay) {
      final matches = day.matches.where(_matchPassesFilters).toList();
      if (matches.isNotEmpty) {
        filteredDays.add(DaySchedule(date: day.date, matches: matches));
      }
    }
    return filteredDays;
  }

  bool _matchPassesFilters(MatchFixture match) {
    final city = match.city.trim();
    final time = match.time.trim();
    final broadcaster = match.broadcaster.trim();
    if (_selectedGroups.isNotEmpty && !_matchBelongsToSelectedGroups(match)) {
      return false;
    }
    if (_selectedCities.isNotEmpty && !_selectedCities.contains(city)) {
      return false;
    }
    if (_selectedTimes.isNotEmpty && !_selectedTimes.contains(time)) {
      return false;
    }
    if (_selectedBroadcasters.isNotEmpty &&
        !_selectedBroadcasters.contains(broadcaster)) {
      return false;
    }
    return true;
  }

  bool _matchBelongsToSelectedGroups(MatchFixture match) {
    final teamToGroup = _teamToGroup;
    final homeGroups = _resolveTeamGroups(match.homeTeam, teamToGroup);
    final awayGroups = _resolveTeamGroups(match.awayTeam, teamToGroup);
    if (homeGroups.any(_selectedGroups.contains)) {
      return true;
    }
    if (awayGroups.any(_selectedGroups.contains)) {
      return true;
    }
    return false;
  }

  Set<String> _resolveTeamGroups(String teamName, Map<String, String> teamToGroup) {
    final groups = <String>{};
    final direct = teamToGroup[teamName];
    if (direct != null && direct.isNotEmpty) {
      groups.add(direct);
    }

    final normalized = teamName.toUpperCase();
    final tokenMatch = RegExp(r'([A-L])-[123]').firstMatch(normalized);
    if (tokenMatch != null) {
      groups.add('Group ${tokenMatch.group(1)}');
    }

    final combinedThirdPlace = RegExp(r'^([A-L](?:/[A-L])+)-3$').firstMatch(normalized);
    if (combinedThirdPlace != null) {
      final letters = combinedThirdPlace.group(1)!.split('/');
      for (final letter in letters) {
        groups.add('Group $letter');
      }
    }

    return groups;
  }

  void _toggleFilter(Set<String> selectedSet, String value, bool isSelected) {
    setState(() {
      if (isSelected) {
        selectedSet.add(value);
      } else {
        selectedSet.remove(value);
      }
      _selectedDateIndex = 0;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedGroups.clear();
      _selectedCities.clear();
      _selectedTimes.clear();
      _selectedBroadcasters.clear();
      _selectedDateIndex = 0;
    });
  }

  void enterEditMode() {
    for (final day in widget.scheduleByDay) {
      for (final match in day.matches) {
        _homeScoreControllers.putIfAbsent(
          match.matchNumber,
          () => TextEditingController(
            text: match.homeScore == '-' ? '' : match.homeScore,
          ),
        );
        _awayScoreControllers.putIfAbsent(
          match.matchNumber,
          () => TextEditingController(
            text: match.awayScore == '-' ? '' : match.awayScore,
          ),
        );
      }
    }
    setState(() {
      _isEditing = true;
    });
    widget.onEditStateChanged?.call();
  }

  void cancelEditMode() {
    setState(() {
      _isEditing = false;
    });
    widget.onEditStateChanged?.call();
  }

  String _normalizeScoreInput(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  Future<void> saveResults() async {
    setState(() {
      _isSaving = true;
    });
    widget.onEditStateChanged?.call();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      var updates = 0;

      for (final day in widget.scheduleByDay) {
        for (final match in day.matches) {
          final homeController = _homeScoreControllers[match.matchNumber];
          final awayController = _awayScoreControllers[match.matchNumber];
          if (homeController == null || awayController == null) continue;

          final homeScore = _normalizeScoreInput(homeController.text);
          final awayScore = _normalizeScoreInput(awayController.text);

          if (homeScore == match.homeScore && awayScore == match.awayScore) {
            continue;
          }

          final docRef = firestore
              .collection('schedule')
              .doc(match.matchNumber.toString());
          batch.update(docRef, {
            'homeScore': homeScore,
            'awayScore': awayScore,
          });
          updates++;
        }
      }

      if (updates > 0) {
        await batch.commit();
      }

      await widget.onRefresh();

      if (!mounted) return;
      setState(() {
        _isEditing = false;
      });
      widget.onEditStateChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results saved')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save results')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        widget.onEditStateChanged?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredScheduleByDay = _filteredScheduleByDay;
    final filteredMatchCount = filteredScheduleByDay.fold<int>(
      0,
      (total, day) => total + day.matches.length,
    );
    final hasActiveFilters = _selectedGroups.isNotEmpty ||
        _selectedCities.isNotEmpty ||
        _selectedTimes.isNotEmpty ||
        _selectedBroadcasters.isNotEmpty;
    if (_selectedDateIndex >= filteredScheduleByDay.length) {
      _selectedDateIndex = filteredScheduleByDay.isEmpty
          ? 0
          : filteredScheduleByDay.length - 1;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7F9), // Light grey background
      endDrawer: _buildFilterDrawer(context),
      body: Column(
        children: [
          SizedBox(
            height: 74,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredScheduleByDay.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final day = filteredScheduleByDay[index];
                      final isSelected = index == _selectedDateIndex;
                      final chipParts = _dateChipParts(day.date);
                      final chipKey =
                          _dateChipKeys.putIfAbsent(index, () => GlobalKey());
                      return ChoiceChip(
                        key: chipKey,
                        showCheckmark: false,
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              chipParts.$1,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              chipParts.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              chipParts.$3,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (_) => _jumpToDate(index),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Badge(
                    isLabelVisible: hasActiveFilters,
                    child: IconButton(
                      icon: const Icon(Icons.filter_alt_outlined),
                      tooltip: 'Filters',
                      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$filteredMatchCount result${filteredMatchCount == 1 ? '' : 's'} found',
                  style: TextStyle(
                    color: Colors.blueGrey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: filteredScheduleByDay.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text('No matches found for selected filters'),
                        ),
                      ],
                    )
                  : ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredScheduleByDay.length,
                itemBuilder: (context, dayIndex) {
                  final daySchedule = filteredScheduleByDay[dayIndex];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          _stripYearFromDate(daySchedule.date).toUpperCase(),
                          style: TextStyle(
                            color: Colors.blueGrey[800],
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      ...daySchedule.matches.map(
                        (match) => _buildMatchCard(context, match),
                      ),
                      const SizedBox(height: 6),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'Filter Matches',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              trailing: TextButton(
                onPressed: _clearAllFilters,
                child: const Text('Clear'),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  _multiSelectSection(
                    title: 'Group',
                    options: _availableGroups,
                    selected: _selectedGroups,
                  ),
                  _cityMultiSelectSection(),
                  _multiSelectSection(
                    title: 'Time',
                    options: _availableTimes,
                    selected: _selectedTimes,
                  ),
                  _multiSelectSection(
                    title: 'Broadcaster',
                    options: _availableBroadcasters,
                    selected: _selectedBroadcasters,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityMultiSelectSection() {
    final groupedCities = _citiesByCountry;
    const countries = ['Canada', 'Mexico', 'USA'];

    return ExpansionTile(
      title: const Text('City'),
      subtitle: _selectedCities.isEmpty
          ? const Text('All')
          : Text('${_selectedCities.length} selected'),
      children: [
        for (var i = 0; i < countries.length; i++) ...[
          if (i > 0) const Divider(height: 16, thickness: 0.6),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                countries[i],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ),
          ...groupedCities[countries[i]]!.map(
            (city) => CheckboxListTile(
              value: _selectedCities.contains(city),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(city),
              onChanged: (checked) =>
                  _toggleFilter(_selectedCities, city, checked ?? false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _multiSelectSection({
    required String title,
    required List<String> options,
    required Set<String> selected,
  }) {
    return ExpansionTile(
      title: Text(title),
      subtitle: selected.isEmpty ? const Text('All') : Text('${selected.length} selected'),
      children: options
          .map(
            (option) => CheckboxListTile(
              value: selected.contains(option),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(option),
              onChanged: (checked) => _toggleFilter(selected, option, checked ?? false),
            ),
          )
          .toList(),
    );
  }

  (String, String, String) _dateChipParts(String fullDate) {
    final dateWithoutYear = _stripYearFromDate(fullDate);
    final parts = dateWithoutYear.split(' ');
    if (parts.length >= 3) {
      final weekday = parts[0];
      final shortWeekday = weekday.length >= 3
          ? weekday.substring(0, 3)
          : weekday;
      return (shortWeekday, parts[1], parts[2]);
    }
    return (dateWithoutYear, '', '');
  }

  String _stripYearFromDate(String date) {
    return date
        .replaceAll(RegExp(r'\b20\d{2}\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  Widget _buildMatchCard(BuildContext context, MatchFixture match) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchCenterScreen(match: match, teams: widget.teams),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 1. Stage Sidebar
                Container(
                  width: 22,
                  color: _getStageColor(match.stage),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        match.stage.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      children: [
                        // 2. Main Match Row (Teams & Scores)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _teamSlot(
                              context,
                              match.homeTeam,
                              isHome: true,
                              matchNumber: match.matchNumber,
                              score: match.homeScore,
                            ),

                            // Center Info: Match Number & Time
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'MATCH ${match.matchNumber}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Colors.blueGrey.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _timeSlot(match.time),
                              ],
                            ),

                            _teamSlot(
                              context,
                              match.awayTeam,
                              isHome: false,
                              matchNumber: match.matchNumber,
                              score: match.awayScore,
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1, thickness: 0.5),
                        ),

                        // 3. Footer Row (Venue & Broadcaster)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${match.city} | ${match.stadium}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _broadcasterBadge(match.broadcaster),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _broadcasterBadge(String broadcaster) {
    final color = _getBroadcasterColor(broadcaster);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        broadcaster,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _teamSlot(
    BuildContext context,
    String teamName, {
    required bool isHome,
    required int matchNumber,
    String? score,
  }) {
    final isPlaceholder = teamName.startsWith('Group ') ||
        teamName.startsWith('Match ') ||
        RegExp(r'^[A-L]-[123]$').hasMatch(teamName.toUpperCase()) ||
        RegExp(r'^[A-L](?:/[A-L])+-3$').hasMatch(teamName.toUpperCase());
    final controller = isHome
        ? _homeScoreControllers[matchNumber]
        : _awayScoreControllers[matchNumber];

    final team = _findTeamByName(teamName);
    final canOpenTeam = !isPlaceholder && team != null;
    void openTeam() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeamDetailScreen(team: team!),
        ),
      );
    }

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: canOpenTeam ? openTeam : null,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: isPlaceholder
                    ? const Icon(Icons.help_outline, size: 16, color: Colors.grey)
                    : ClipOval(
                  child: SvgPicture.asset(
                    roundFlagAssetForTeam(teamName),
                    key: ValueKey(teamName),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: canOpenTeam
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamDetailScreen(team: team),
                      ),
                    );
                  }
                : null,
            child: Text(
              teamName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Score Display
          const SizedBox(height: 2),
          if (_isEditing && !isPlaceholder && controller != null)
            SizedBox(
              width: 36,
              height: 28,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            )
          else
            Text(
              score ?? '-',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: score != null ? Colors.black : Colors.grey[300],
                height: 1,
              ),
            ),
        ],
      ),
    );
  }

  TeamInfo? _findTeamByName(String teamName) {
    final normalizedTarget = _normalizeTeamName(teamName);
    for (final team in widget.teams) {
      if (_normalizeTeamName(team.name) == normalizedTarget) {
        return team;
      }
    }
    return null;
  }

  String _normalizeTeamName(String name) {
    return name
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
  }

  Widget _timeSlot(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        time,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Color _getBroadcasterColor(String broadcaster) {
    if (broadcaster.contains('ARD') || broadcaster.contains('ZDF')) return Colors.orange[700]!;
    if (broadcaster.contains('BBC')) return Colors.red[800]!;
    if (broadcaster.contains('ITV')) return Colors.blue[800]!;
    return Colors.blueGrey;
  }

  Color _getStageColor(String stage) {
    const colors = {
      'Group A': Color(0xFF1E88E5),
      'Group B': Color(0xFF00897B),
      'Group C': Color(0xFFD81B60),
      'Group D': Color(0xFF43A047),
      'Group E': Color(0xFFF4511E),
      'Group F': Color(0xFF8E24AA),
      'Group G': Color(0xFFFDD835),
      'Group H': Color(0xFF7CB342),
      'Group I': Color(0xFFE53935),
      'Group J': Color(0xFF00ACC1),
      'Group K': Color(0xFF5E35B1),
      'Group L': Color(0xFFFB8C00),
      'Round of 32': Color(0xFF757575),
      'Round of 16': Color(0xFF424242),
      'Quarter Final': Color(0xFF1565C0),
      'Semi Final': Color(0xFF6A1B9A),
      'Third Place': Color(0xFFCD7F32),
      'Final': Color(0xFFD4AF37),
    };
    return colors[stage] ?? Colors.blueGrey;
  }
}