import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'exercise_library.dart';
import 'active_workout.dart';
import 'history_screen.dart';
import 'programs_screen.dart';
import 'test_data_generator.dart';
import 'muscle_recovery_screen.dart';
import 'dart:io';
import 'program_card.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent database race conditions on boot
  await DatabaseHelper.instance.database;

  // Hides the bottom navigation bar but keeps the top status bar
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );

  runApp(const MyApp());
}

void showAppErrorDialog(BuildContext context, String title, dynamic error) {
  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          error.toString(),
          style: const TextStyle(color: Colors.redAccent, fontSize: 14),
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: () => Navigator.pop(context),
          child: const Text('OK', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Navigation State
  int _currentIndex = 0;

  // Data State for Dashboard
  List<Map<String, dynamic>> _recentPrograms = [];
  Map<int, Map<String, dynamic>> _recentTrackingData = {};
  bool _isLoadingPrograms = true;

  @override
  void initState() {
    super.initState();
    _loadRecentPrograms();
  }

  Future<void> _loadRecentPrograms() async {
    try {
      setState(() => _isLoadingPrograms = true);

      // Only fetch the single most recent program for the dashboard to keep it clean
      final programs = await DatabaseHelper.instance.getRecentPrograms(limit: 1);
      Map<int, Map<String, dynamic>> tracking = {};

      for (var program in programs) {
        int pid = int.parse(program['id'].toString());
        tracking[pid] = await DatabaseHelper.instance.getProgramTrackingInfo(pid);
      }

      if (mounted) {
        setState(() {
          _recentPrograms = programs;
          _recentTrackingData = tracking;
          _isLoadingPrograms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPrograms = false);
        showAppErrorDialog(context, 'Dashboard Load Error', e);
      }
    }
  }

  Map<String, dynamic> _calculateRecovery(String? lastTrainedStr) {
    if (lastTrainedStr == null) return {'percentage': 100, 'color': Colors.green};
    DateTime lastTrained = DateTime.parse(lastTrainedStr);
    double hoursElapsed = DateTime.now().difference(lastTrained).inHours.toDouble();
    double recoveryPercent = (hoursElapsed / 48.0) * 100;
    if (recoveryPercent > 100) recoveryPercent = 100;

    Color color;
    if (recoveryPercent < 40) color = Colors.redAccent;
    else if (recoveryPercent < 80) color = Colors.orangeAccent;
    else if (recoveryPercent < 100) color = Colors.lightGreen;
    else color = Colors.green;

    return {'percentage': recoveryPercent.toInt(), 'color': color};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      // IndexedStack keeps the state of your tabs alive when you switch between them
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(), // 0
          const ProgramsScreen(), // 1
          const ExerciseLibraryScreen(), // 2
          const HistoryScreen(), // 3
        ],
      ),

      // --- THE NEW BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 0) _loadRecentPrograms(); // Refresh dashboard data when returning
          });
        },
        backgroundColor: const Color(0xFF1C1C1C),
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Programs'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'History'),
        ],
      ),

      // --- QUICK START FAB ---
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()),
          ).then((_) => _loadRecentPrograms());
        },
        icon: const Icon(Icons.play_arrow, color: Colors.white),
        label: const Text('Quick Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
      ) : null,
    );
  }

  // --- THE NEW DASHBOARD UI ---
  Widget _buildDashboardTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Gym Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            tooltip: 'Developer Tools',
              onPressed: null,
            // onPressed: () {
            //   bool extractData = false;
            //   bool extractAllData = false;
            //   bool clearHistory = false;
            //   bool clearPrograms = false; // NEW STATE VARIABLE
            //   bool seedData = false;
            //
            //   showDialog(
            //     context: context,
            //     builder: (context) {
            //       return StatefulBuilder(
            //         builder: (context, setDialogState) {
            //           return AlertDialog(
            //             backgroundColor: Colors.grey[900],
            //             title: const Row(
            //               children: [
            //                 Icon(Icons.settings_applications, color: Colors.orange),
            //                 SizedBox(width: 8),
            //                 Text('Developer Tools', style: TextStyle(color: Colors.white)),
            //               ],
            //             ),
            //             content: SingleChildScrollView(
            //               child: Column(
            //                 mainAxisSize: MainAxisSize.min,
            //                 children: [
            //                   CheckboxListTile(
            //                     title: const Text('Extract Templates (SQL)', style: TextStyle(color: Colors.white, fontSize: 15)),
            //                     subtitle: const Text('Export exercises & programs to Downloads', style: TextStyle(color: Colors.grey, fontSize: 12)),
            //                     value: extractData,
            //                     activeColor: Colors.teal,
            //                     checkColor: Colors.white,
            //                     contentPadding: EdgeInsets.zero,
            //                     onChanged: (bool? value) => setDialogState(() => extractData = value ?? false),
            //                   ),
            //                   CheckboxListTile(
            //                     title: const Text('Full Backup (.db)', style: TextStyle(color: Colors.white, fontSize: 15)),
            //                     subtitle: const Text('Export the entire database file to Downloads', style: TextStyle(color: Colors.grey, fontSize: 12)),
            //                     value: extractAllData,
            //                     activeColor: Colors.blueAccent,
            //                     checkColor: Colors.white,
            //                     contentPadding: EdgeInsets.zero,
            //                     onChanged: (bool? value) => setDialogState(() => extractAllData = value ?? false),
            //                   ),
            //                   CheckboxListTile(
            //                     title: const Text('Clear Workout History', style: TextStyle(color: Colors.white, fontSize: 15)),
            //                     subtitle: const Text('Wipe all past sessions, sets, and logs', style: TextStyle(color: Colors.grey, fontSize: 12)),
            //                     value: clearHistory,
            //                     activeColor: Colors.redAccent,
            //                     checkColor: Colors.white,
            //                     contentPadding: EdgeInsets.zero,
            //                     onChanged: (bool? value) => setDialogState(() => clearHistory = value ?? false),
            //                   ),
            //                   // --- NEW CHECKBOX FOR CLEARING PROGRAMS ---
            //                   CheckboxListTile(
            //                     title: const Text('Clear All Programs', style: TextStyle(color: Colors.white, fontSize: 15)),
            //                     subtitle: const Text('Delete all custom programs and templates', style: TextStyle(color: Colors.grey, fontSize: 12)),
            //                     value: clearPrograms,
            //                     activeColor: Colors.redAccent,
            //                     checkColor: Colors.white,
            //                     contentPadding: EdgeInsets.zero,
            //                     onChanged: (bool? value) => setDialogState(() => clearPrograms = value ?? false),
            //                   ),
            //                   CheckboxListTile(
            //                     title: const Text('Inject Mock Data', style: TextStyle(color: Colors.white, fontSize: 15)),
            //                     subtitle: const Text('Add realistic past sessions for charts', style: TextStyle(color: Colors.grey, fontSize: 12)),
            //                     value: seedData,
            //                     activeColor: Colors.teal,
            //                     checkColor: Colors.white,
            //                     contentPadding: EdgeInsets.zero,
            //                     onChanged: (bool? value) => setDialogState(() => seedData = value ?? false),
            //                   ),
            //                 ],
            //               ),
            //             ),
            //             actions: [
            //               TextButton(
            //                 onPressed: () => Navigator.pop(context),
            //                 child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            //               ),
            //               ElevatedButton(
            //                 style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            //                 onPressed: () async {
            //                   Navigator.pop(context);
            //                   List<String> executionLogs = [];
            //
            //                   try {
            //                     if (extractData) {
            //                       String sqlExerciseExport = await DatabaseHelper.instance.exportCustomExercisesAsSql();
            //                       String sqlProgramsExport = await DatabaseHelper.instance.exportProgramsAsSql();
            //                       final exerciseFile = File('/storage/emulated/0/Download/custom_exercises_export.sql');
            //                       await exerciseFile.writeAsString(sqlExerciseExport);
            //                       final programsFile = File('/storage/emulated/0/Download/programs_export.sql');
            //                       await programsFile.writeAsString(sqlProgramsExport);
            //                       executionLogs.add('✅ Exercises backed up successfully!');
            //                       executionLogs.add('✅ Programs exported successfully!');
            //                     }
            //
            //                     if (extractAllData) {
            //                       String result = await DatabaseHelper.instance.exportFullDatabase();
            //                       executionLogs.add(result);
            //                     }
            //
            //                     if (clearHistory) executionLogs.add(await TestDataGenerator.clearHistoryData());
            //
            //                     // --- NEW EXECUTION LOGIC TO WIPE PROGRAMS ---
            //                     if (clearPrograms) {
            //                       final db = await DatabaseHelper.instance.database;
            //                       await db.delete('Program_Day_Exercises');
            //                       await db.delete('Program_Days');
            //                       await db.delete('Program_Weeks');
            //                       await db.delete('Programs');
            //                       executionLogs.add('🗑️ All program templates deleted successfully!');
            //                     }
            //
            //                     if (seedData) executionLogs.add(await TestDataGenerator.injectRealisticHistoryData());
            //
            //                     if (executionLogs.isNotEmpty && context.mounted) {
            //                       showDialog(
            //                         context: context,
            //                         builder: (context) => AlertDialog(
            //                           backgroundColor: Colors.grey[900],
            //                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            //                           title: const Row(
            //                             children: [
            //                               Icon(Icons.check_circle, color: Colors.green),
            //                               SizedBox(width: 8),
            //                               Text('Execution Complete', style: TextStyle(color: Colors.white, fontSize: 18)),
            //                             ],
            //                           ),
            //                           content: SingleChildScrollView(
            //                             child: Column(
            //                               mainAxisSize: MainAxisSize.min,
            //                               crossAxisAlignment: CrossAxisAlignment.start,
            //                               children: executionLogs.map((log) => Padding(
            //                                 padding: const EdgeInsets.only(bottom: 8.0),
            //                                 child: Text(log, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            //                               )).toList(),
            //                             ),
            //                           ),
            //                           actions: [
            //                             TextButton(
            //                               onPressed: () {
            //                                 Navigator.pop(context);
            //                                 _loadRecentPrograms();
            //                               },
            //                               child: const Text('OK', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            //                             )
            //                           ],
            //                         ),
            //                       );
            //                     }
            //                   } catch (e) {
            //                     if (context.mounted) showAppErrorDialog(context, 'Execution Error', e);
            //                   }
            //                 },
            //                 child: const Text('Execute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            //               ),
            //             ],
            //           );
            //         },
            //       );
            //     },
            //   );
            // },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. RECENT PROGRAMS ELEVATED ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Up Next', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 1), // Jump to Programs Tab
                  child: const Text('View All', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoadingPrograms)
              const Padding(padding: EdgeInsets.all(40.0), child: Center(child: CircularProgressIndicator(color: Colors.teal)))
            else if (_recentPrograms.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('No active programs yet.\nHead to the Programs tab to build one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _recentPrograms.length,
                itemBuilder: (context, index) {
                  final program = _recentPrograms[index];
                  int programId = int.parse(program['id'].toString());
                  return ProgramCard(
                    program: program,
                    tracking: _recentTrackingData[programId] ?? {},
                    onRefresh: _loadRecentPrograms,
                  );
                },
              ),

            const SizedBox(height: 24),

            // --- 2. FLATTENED MUSCLE READINESS ---
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MuscleRecoveryScreen()),
                ).then((_) => setState(() {}));
              },
              child: Container(
                color: Colors.transparent, // Ensures the whole block is tappable
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Muscle Readiness', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 80,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: DatabaseHelper.instance.getMuscleRecoveryData(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('Tap bug button to load sample data', style: TextStyle(color: Colors.grey, fontSize: 12)));
                          }

                          final muscles = List<Map<String, dynamic>>.from(snapshot.data!);
                          muscles.sort((a, b) {
                            int pctA = _calculateRecovery(a['last_trained'])['percentage'];
                            int pctB = _calculateRecovery(b['last_trained'])['percentage'];
                            return pctA.compareTo(pctB);
                          });

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: muscles.length,
                            itemBuilder: (context, index) {
                              final m = muscles[index];
                              final recovery = _calculateRecovery(m['last_trained']);
                              int pct = recovery['percentage'];
                              Color col = recovery['color'];

                              return Container(
                                width: 85,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: col.withOpacity(0.1), // Soft flat background
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(m['muscle_name'], style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text('$pct%', style: TextStyle(color: col, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 80), // Padding so scrolling clears the FAB
          ],
        ),
      ),
    );
  }
}