import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'exercise_library.dart';
import 'database_helper.dart';

// Data model for a single set
class WorkoutSet {
  TextEditingController weightController = TextEditingController();
  TextEditingController repsController = TextEditingController();
  bool isCompleted = false;
}

// Data model for an exercise added to the workout
class ActiveExercise {
  final Map<String, dynamic> exerciseData;
  List<WorkoutSet> sets = [WorkoutSet()]; // Always start with 1 set

  ActiveExercise(this.exerciseData);
}

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final List<ActiveExercise> _workoutExercises = [];

  // Launch library and wait for user to select an exercise
  Future<void> _addExercise() async {
    final selectedExercise = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExerciseLibraryScreen()),
    );

    if (selectedExercise != null) {
      setState(() {
        _workoutExercises.add(ActiveExercise(selectedExercise));
      });
    }
  }

  void _finishWorkout() async {
    List<Map<String, dynamic>> exercisesToSave = [];

    for (var activeEx in _workoutExercises) {
      List<Map<String, dynamic>> completedSets = [];

      for (var s in activeEx.sets) {
        if (s.isCompleted) {
          completedSets.add({
            'weight': double.tryParse(s.weightController.text) ?? 0.0,
            'reps': int.tryParse(s.repsController.text) ?? 0,
          });
        }
      }

      if (completedSets.isNotEmpty) {
        exercisesToSave.add({
          'exercise_id': activeEx.exerciseData['id'],
          'sets': completedSets,
        });
      }
    }

    if (exercisesToSave.isEmpty) {
      Navigator.pop(context);
      return;
    }

    // Try to save, but catch any SQLite errors and show them on screen
    try {
      await DatabaseHelper.instance.saveWorkoutSession(exercisesToSave);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Workout'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _finishWorkout,
            child: const Text('FINISH', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _workoutExercises.isEmpty
          ? const Center(child: Text("Tap '+' to add your first exercise", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.only(bottom: 80), // Space for floating button
        itemCount: _workoutExercises.length,
        itemBuilder: (context, exerciseIndex) {
          final activeExercise = _workoutExercises[exerciseIndex];
          return _buildExerciseCard(activeExercise);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildExerciseCard(ActiveExercise activeExercise) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Exercise Name
            Text(
              activeExercise.exerciseData['name'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 12),

            // Table Headers
            const Row(
              children: [
                SizedBox(width: 40, child: Text('Set', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                Expanded(child: Center(child: Text('kg / lbs', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('Reps', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                SizedBox(width: 48, child: Center(child: Icon(Icons.check, color: Colors.grey, size: 18))),
              ],
            ),
            const Divider(color: Colors.grey),

            // Dynamic Rows for Sets
            ...List.generate(activeExercise.sets.length, (setIndex) {
              final workoutSet = activeExercise.sets[setIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text('${setIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),

                    // Weight Input
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: workoutSet.weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: workoutSet.isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey[800],
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),

                    // Reps Input
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: workoutSet.repsController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: workoutSet.isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey[800],
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),

                    // Checkbox
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        icon: Icon(
                          workoutSet.isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                          color: workoutSet.isCompleted ? Colors.green : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            workoutSet.isCompleted = !workoutSet.isCompleted;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            // Add Set Button
            TextButton(
              onPressed: () {
                setState(() {
                  activeExercise.sets.add(WorkoutSet());
                });
              },
              child: const Text('+ Add Set', style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }
}