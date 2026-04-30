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
    return Scaffold(
      appBar: AppBar(title: const Text('FIFA World Cup 2026')),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ScheduleScreen(
            scheduleByDay: _data.scheduleByDay,
            onRefresh: _refreshFromFirestore,
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
