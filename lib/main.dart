import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/world_cup_data.dart';
import 'firebase_options.dart';
import 'screens/fixtures_table_screen.dart';
import 'screens/home_screen.dart';
import 'screens/predictor_fixtures_table_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/search_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const WorldCupApp());
}

class WorldCupApp extends StatelessWidget {
  const WorldCupApp({super.key, this.dataFuture});

  final Future<WorldCupData>? dataFuture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIFA World Cup 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF001D3D),
          foregroundColor: Colors.white,
          surfaceTintColor: Color(0xFF001D3D),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: FutureBuilder<WorldCupData>(
        future: dataFuture ?? WorldCupDataLoader.load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Failed to load World Cup data from Firestore.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return HomeScreen(data: snapshot.data!);
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.data});

  final WorldCupData data;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _starredTeamsPrefsKey = 'starred_teams';
  int _selectedIndex = 0;
  int _fixturesTableTab = 0;
  int _predictorTableTab = 0;
  late WorldCupData _data;
  final Set<String> _starredTeams = <String>{};
  final GlobalKey<ScheduleScreenState> _scheduleKey =
      GlobalKey<ScheduleScreenState>();
  final GlobalKey<ScheduleScreenState> _predictorScheduleKey =
      GlobalKey<ScheduleScreenState>();

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _loadStarredTeams();
  }

  Future<void> _refreshFromFirestore() async {
    final freshData = await WorldCupDataLoader.load();
    if (!mounted) return;
    setState(() {
      _data = freshData;
    });
  }

  Future<void> _loadStarredTeams() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTeams = prefs.getStringList(_starredTeamsPrefsKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _starredTeams
        ..clear()
        ..addAll(savedTeams);
    });
  }

  Future<void> _persistStarredTeams() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _starredTeamsPrefsKey,
      _starredTeams.toList()..sort(),
    );
  }

  void _toggleStarredTeam(String teamName) {
    setState(() {
      if (_starredTeams.contains(teamName)) {
        _starredTeams.remove(teamName);
      } else {
        _starredTeams.add(teamName);
      }
    });
    _persistStarredTeams();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = _scheduleKey.currentState;
    final predictorState = _predictorScheduleKey.currentState;

    final showTournamentFixtureActions =
        _selectedIndex == 1 && _fixturesTableTab == 0;
    final showPredictorFixtureActions =
        _selectedIndex == 3 && _predictorTableTab == 0;

    final scheduleReady = showTournamentFixtureActions
        ? scheduleState != null
        : showPredictorFixtureActions
            ? predictorState != null
            : false;
    final isEditing = showTournamentFixtureActions
        ? (scheduleState?.isEditing ?? false)
        : showPredictorFixtureActions
            ? (predictorState?.isEditing ?? false)
            : false;
    final isSaving = showTournamentFixtureActions
        ? (scheduleState?.isSaving ?? false)
        : showPredictorFixtureActions
            ? (predictorState?.isSaving ?? false)
            : false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FIFA World Cup 2026'),
        actions: [
          if (showTournamentFixtureActions) ...[
            if (isEditing) ...[
              TextButton(
                onPressed: (!scheduleReady || isSaving)
                    ? null
                    : scheduleState!.cancelEditMode,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: (!scheduleReady || isSaving)
                      ? null
                      : scheduleState!.saveResults,
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed:
                      scheduleState != null ? scheduleState.enterEditMode : null,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit results',
                ),
              ),
          ],
          if (showPredictorFixtureActions) ...[
            if (isEditing) ...[
              PopupMenuButton<String>(
                tooltip: 'Prediction tools',
                enabled: scheduleReady && !isSaving,
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  final p = predictorState;
                  if (p == null || isSaving) return;
                  if (value == 'random') {
                    p.populateRandomScores();
                  } else if (value == 'clear') {
                    p.clearAllScores();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'random',
                    child: Text('Populate random predictions'),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('Clear all predictions'),
                  ),
                ],
              ),
              TextButton(
                onPressed: (!scheduleReady || isSaving)
                    ? null
                    : predictorState!.cancelEditMode,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: (!scheduleReady || isSaving)
                      ? null
                      : predictorState!.saveResults,
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed:
                      predictorState != null ? predictorState.enterEditMode : null,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit predictions',
                ),
              ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeTabScreen(
            scheduleByDay: _data.scheduleByDay,
            teams: _data.teams,
            starredTeams: _starredTeams,
          ),
          FixturesTableScreen(
            scheduleKey: _scheduleKey,
            scheduleByDay: _data.scheduleByDay,
            teams: _data.teams,
            onRefresh: _refreshFromFirestore,
            onEditStateChanged: () {
              if (mounted) setState(() {});
            },
            onPrimaryTabChanged: (index) {
              if (_fixturesTableTab != index) {
                setState(() => _fixturesTableTab = index);
              }
            },
          ),
          SearchScreen(
            teams: _data.teams,
            starredTeams: _starredTeams,
            onToggleStarredTeam: _toggleStarredTeam,
          ),
          PredictorFixturesTableScreen(
            scheduleKey: _predictorScheduleKey,
            scheduleByDay: _data.scheduleByDay,
            teams: _data.teams,
            onRefresh: _refreshFromFirestore,
            onEditStateChanged: () {
              if (mounted) setState(() {});
            },
            onPrimaryTabChanged: (index) {
              if (_predictorTableTab != index) {
                setState(() => _predictorTableTab = index);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Tournament',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'Predictor',
          ),
        ],
      ),
    );
  }
}
