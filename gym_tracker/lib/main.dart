import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'exercise_library.dart';
import 'active_workout.dart';
import 'history_screen.dart';
import 'programs_screen.dart';
import 'test_data_generator.dart';
import 'muscle_recovery_screen.dart'; // --- IMPORT RECOVERY SCREEN ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
  // Helper to calculate recovery status for the dashboard preview
  Map<String, dynamic> _calculateRecovery(String? lastTrainedStr) {
    if (lastTrainedStr == null) {
      return {'percentage': 100, 'color': Colors.green};
    }
    DateTime lastTrained = DateTime.parse(lastTrainedStr);
    double hoursElapsed = DateTime.now().difference(lastTrained).inHours.toDouble();
    double recoveryPercent = (hoursElapsed / 48.0) * 100;
    if (recoveryPercent > 100) recoveryPercent = 100;

    Color color;
    if (recoveryPercent < 40) {
      color = Colors.redAccent;
    } else if (recoveryPercent < 80) {
      color = Colors.orangeAccent;
    } else if (recoveryPercent < 100) {
      color = Colors.lightGreen;
    } else {
      color = Colors.green;
    }
    return {'percentage': recoveryPercent.toInt(), 'color': color};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            tooltip: 'Run Test Suite',
            onPressed: () async {
              try {
                List<String> testLogs = await TestDataGenerator.runAllTests();
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: Colors.grey[900],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Test Suite Executed', style: TextStyle(color: Colors.white, fontSize: 18)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: testLogs.map((log) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(log, style: const TextStyle(color: Colors.grey)),
                          )).toList(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {}); // Refresh dashboard data after test suite run!
                            },
                            child: const Text('OK', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          )
                        ],
                      );
                    },
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Database Error', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                        content: Text(e.toString(), style: const TextStyle(color: Colors.redAccent)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CLOSE', style: TextStyle(color: Colors.grey)),
                          )
                        ],
                      );
                    },
                  );
                }
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),

            // Mode 1: Ad-Hoc Workout
            _buildNavCard(
              context: context,
              title: 'Start Ad-Hoc Workout',
              subtitle: 'Free play session',
              icon: Icons.play_circle_fill,
              color: Colors.blueAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()),
                ).then((_) => setState(() {})); // Refresh when returning
              },
            ),
            const SizedBox(height: 12),

            // Mode 2: Multi-Day Programs
            _buildNavCard(
              context: context,
              title: 'Multi-Day Programs',
              subtitle: 'Structured routines',
              icon: Icons.calendar_month,
              color: Colors.deepPurpleAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProgramsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // Exercise Library
            _buildNavCard(
              context: context,
              title: 'Exercise Library',
              subtitle: 'Search & add custom movements',
              icon: Icons.fitness_center,
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExerciseLibraryScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            // --- LIVE MUSCLE READINESS PREVIEW CARD ---
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MuscleRecoveryScreen()),
                ).then((_) => setState(() {}));
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.accessibility_new, color: Colors.amberAccent, size: 20),
                            SizedBox(width: 8),
                            Text('Muscle Readiness Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 75,
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
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: col.withOpacity(0.5)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(m['muscle_name'], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text('$pct%', style: TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.bold)),
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

            const Spacer(),

            // Analytics Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                );
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('Historical Logs & Analytics'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}