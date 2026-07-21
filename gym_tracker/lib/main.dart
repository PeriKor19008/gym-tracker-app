import 'package:flutter/material.dart';
import 'database_helper.dart'; // Import your new helper file
import 'exercise_library.dart';
import 'active_workout.dart';
import 'history_screen.dart';
import 'programs_screen.dart';
import 'test_data_generator.dart';
import 'muscle_recovery_screen.dart';

void main() async {
  // Required before calling native plugins (like sqflite) in main()
  WidgetsFlutterBinding.ensureInitialized();

  // Fire the test query
  print('--- DATABASE TEST START ---');
  try {
    final exercises = await DatabaseHelper.instance.getTestExercises();
    for (var exercise in exercises) {
      print(exercise);
    }
  } catch (e) {
    print('Database Error: $e');
  }
  print('--- DATABASE TEST END ---');

  // Boot up the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: ThemeData(
        // A clean, dark theme suited for a gym environment
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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          // --- MASTER TEST SUITE BUTTON ---
          // --- MASTER TEST SUITE BUTTON ---
          // --- MASTER TEST SUITE BUTTON ---
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            tooltip: 'Run Test Suite',
            onPressed: () async {
              try {
                // 1. Try to run the tests
                List<String> testLogs = await TestDataGenerator.runAllTests();

                // 2. If successful, display the success logs
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
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                            )
                          ],
                        );
                      }
                  );
                }
              } catch (e) {
                // 3. IF IT CRASHES, CATCH IT AND SHOW THE ERROR ON SCREEN
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
                          content: Text(
                            e.toString(),
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('CLOSE', style: TextStyle(color: Colors.grey)),
                            )
                          ],
                        );
                      }
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
            const SizedBox(height: 20),

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
                );
              },
            ),
            const SizedBox(height: 16),

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
            const SizedBox(height: 16),

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

            const Spacer(),

            // Analytics Button (Bottom)
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // A helper widget to keep our buttons looking uniform and clean
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
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
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