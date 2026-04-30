import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'data/world_cup_data.dart';
import 'firebase_options.dart';
import 'screens/schedule_screen.dart';
import 'screens/table_screen.dart';
import 'screens/teams_screen.dart';

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
  int _selectedIndex = 0;
  late WorldCupData _data;
  final GlobalKey<ScheduleScreenState> _scheduleKey =
      GlobalKey<ScheduleScreenState>();

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  Future<void> _refreshFromFirestore() async {
    final freshData = await WorldCupDataLoader.load();
    if (!mounted) return;
    setState(() {
      _data = freshData;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = _scheduleKey.currentState;
    final showScheduleActions = _selectedIndex == 0;
    final scheduleReady = scheduleState != null;
    final isEditing = scheduleState?.isEditing ?? false;
    final isSaving = scheduleState?.isSaving ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FIFA World Cup 2026'),
        actions: showScheduleActions
            ? [
                if (isEditing) ...[
                  TextButton(
                    onPressed: (!scheduleReady || isSaving)
                        ? null
                        : scheduleState.cancelEditMode,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton(
                      onPressed: (!scheduleReady || isSaving)
                          ? null
                          : scheduleState.saveResults,
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
                          scheduleReady ? scheduleState.enterEditMode : null,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit results',
                    ),
                  ),
              ]
            : null,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ScheduleScreen(
            key: _scheduleKey,
            scheduleByDay: _data.scheduleByDay,
            onRefresh: _refreshFromFirestore,
            onEditStateChanged: () {
              if (mounted) setState(() {});
            },
          ),
          TeamsScreen(teams: _data.teams),
          const TableScreen(),
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
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Teams',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_chart_outlined),
            selectedIcon: Icon(Icons.table_chart),
            label: 'Table',
          ),
        ],
      ),
    );
  }
}
