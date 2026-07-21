import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // --- NEW: Required for the Timer ---
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
  List<WorkoutSet> sets = [WorkoutSet()];

  ActiveExercise(this.exerciseData);
}

class ActiveWorkoutScreen extends StatefulWidget {
  final int? sessionId;
  const ActiveWorkoutScreen({super.key, this.sessionId});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final List<ActiveExercise> _workoutExercises = [];

  // --- NEW: Timer State Variables ---
  Timer? _restTimer;
  int _restSeconds = 90; // Default rest time: 1m 30s
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      _loadRoutineExercises();
    }
  }

  // --- NEW: Clean up the timer when leaving the screen ---
  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  // --- NEW: Timer Logic Methods ---
  void _startTimer() {
    if (_restTimer != null) _restTimer!.cancel();
    setState(() => _isTimerRunning = true);

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSeconds > 0) {
          _restSeconds--;
        } else {
          _stopTimer();
          // Optional: Add haptic feedback or a sound here later!
        }
      });
    });
  }

  void _stopTimer() {
    _restTimer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  void _resetTimer(int seconds) {
    _stopTimer();
    setState(() => _restSeconds = seconds);
  }

  void _adjustTimer(int seconds) {
    setState(() {
      _restSeconds += seconds;
      if (_restSeconds < 0) _restSeconds = 0;
    });
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  // --------------------------------

  Future<void> _loadRoutineExercises() async {
    final exercisesData = await DatabaseHelper.instance.getSessionExercises(widget.sessionId!);
    setState(() {
      for (var exData in exercisesData) {
        _workoutExercises.add(ActiveExercise(exData));
      }
    });
  }

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
          'exercise_id': activeEx.exerciseData['id'] ?? activeEx.exerciseData['exercise_id'],
          'sets': completedSets,
        });
      }
    }

    if (exercisesToSave.isEmpty) {
      Navigator.pop(context);
      return;
    }

    try {
      await DatabaseHelper.instance.saveWorkoutSession(exercisesToSave);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e'), backgroundColor: Colors.red),
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
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _workoutExercises.length,
        itemBuilder: (context, exerciseIndex) {
          final activeExercise = _workoutExercises[exerciseIndex];
          return _buildExerciseCard(activeExercise);
        },
      ),
      // --- NEW: Persistent Rest Timer Banner ---
      bottomNavigationBar: BottomAppBar(
        color: Colors.grey[900],
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => _adjustTimer(-15),
              child: const Text('-15s', style: TextStyle(color: Colors.grey)),
            ),
            Text(
              _formatTime(_restSeconds),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                // Glows teal when running
                color: _isTimerRunning ? Colors.tealAccent : Colors.white,
              ),
            ),
            TextButton(
              onPressed: () => _adjustTimer(15),
              child: const Text('+15s', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: _isTimerRunning ? _stopTimer : _startTimer,
              icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow, color: Colors.white),
              label: Text(_isTimerRunning ? 'PAUSE' : 'START', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTimerRunning ? Colors.orange : Colors.teal,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
        backgroundColor: Colors.blueAccent,
      ),
      // Move FAB up slightly so it doesn't overlap the timer
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            Text(
              activeExercise.exerciseData['name'] ?? 'Exercise',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(width: 40, child: Text('Set', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                Expanded(child: Center(child: Text('kg / lbs', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('Reps', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                SizedBox(width: 48, child: Center(child: Icon(Icons.check, color: Colors.grey, size: 18))),
              ],
            ),
            const Divider(color: Colors.grey),

            ...List.generate(activeExercise.sets.length, (setIndex) {
              final workoutSet = activeExercise.sets[setIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text('${setIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
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


                            }
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
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